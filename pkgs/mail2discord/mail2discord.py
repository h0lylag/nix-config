#!/usr/bin/env python3
# mail2discord.py — drop-in sendmail shim that posts to Discord
# - Reads RFC-5322 message from stdin (works with `sendmail -t -i`)
# - Parses Subject/From/To/Date, extracts text (prefers text/plain, falls back to HTML->text)
# - Splits to 2000-char chunks for Discord
# - Supports Forum/Thread targets via DISCORD_THREAD_ID or DISCORD_THREAD_NAME
# - Emits precise Discord error bodies

import os, sys, json, socket, re, time
from email import policy
from email.parser import BytesParser
from html import unescape
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode

WEBHOOK = os.environ.get("DISCORD_WEBHOOK_URL")
MAX_DISCORD = 2000  # Discord limit per message
HOST = socket.gethostname()

def die(msg, code=78):  # EX_CONFIG by default
    sys.stderr.write(msg + "\n")
    sys.exit(code)

def html_to_text(html):
    # crude HTML -> text: unescape entities, drop tags, collapse whitespace
    text = unescape(re.sub(r"(?is)<(script|style).*?</\1>", "", html))
    text = re.sub(r"(?s)<br\s*/?>", "\n", text)
    text = re.sub(r"(?s)</p\s*>", "\n\n", text)
    text = re.sub(r"(?s)<.*?>", "", text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()

def extract_text(msg):
    # Prefer plain text; fallback to lightly-scrubbed HTML; fallback to str(msg)
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            disp = (part.get("Content-Disposition") or "").lower()
            if ctype == "text/plain" and "attachment" not in disp:
                return part.get_content().strip()
        for part in msg.walk():
            ctype = part.get_content_type()
            disp = (part.get("Content-Disposition") or "").lower()
            if ctype == "text/html" and "attachment" not in disp:
                return html_to_text(part.get_content())
        chunks = []
        for part in msg.walk():
            ctype = part.get_content_type()
            disp = (part.get("Content-Disposition") or "").lower()
            if ctype.startswith("text/") and "attachment" not in disp:
                chunks.append(str(part.get_content()))
        if chunks:
            return "\n\n".join(chunks).strip()
        return str(msg)
    else:
        ctype = msg.get_content_type()
        if ctype == "text/plain":
            return msg.get_content().strip()
        if ctype == "text/html":
            return html_to_text(msg.get_content())
        return msg.get_content().strip() if hasattr(msg, "get_content") else str(msg)

def post_chunk(content, username=None, avatar_url=None):
    # Add wait=true for 200 + body; support forum/thread targeting via env
    qs = {"wait": "true"}
    tid = os.environ.get("DISCORD_THREAD_ID")
    tname = os.environ.get("DISCORD_THREAD_NAME")
    if tid:
        qs["thread_id"] = tid
    elif tname:
        qs["thread_name"] = tname

    url = WEBHOOK + ("?" + urlencode(qs) if qs else "")
    payload = {"content": content}
    if username:
        payload["username"] = username
    if avatar_url:
        payload["avatar_url"] = avatar_url

    data = json.dumps(payload).encode("utf-8")
    req = Request(url, data=data, headers={
        "Content-Type": "application/json",
        "User-Agent": "mail2discord/1.1 (+cli)"
    })
    with urlopen(req, timeout=10) as resp:
        return resp.read()

def main():
    # Accept common sendmail flags but ignore them (we read all headers from stdin)
    # Common: -t (read recipients from headers), -i (don't treat lone '.' as EOF)
    if not WEBHOOK:
        die("DISCORD_WEBHOOK_URL not set in environment")

    raw = sys.stdin.buffer.read()
    if not raw.strip():
        die("Empty message on stdin", code=65)  # EX_DATAERR

    msg = BytesParser(policy=policy.default).parsebytes(raw)
    subj = msg.get("Subject", "(no subject)")
    from_h = msg.get("From", "(unknown)")
    to_h = msg.get("To", "(unknown)")
    date_h = msg.get("Date", "")

    body = extract_text(msg)

    header = f"**Subject:** {subj}\n**From:** {from_h}\n**To:** {to_h}\n**Host:** `{HOST}`"
    if date_h:
        header += f"\n**Date:** {date_h}"
    header += "\n"

    body_is_loggy = bool(re.search(r"(^|\n)(ERROR|WARN|INFO|Traceback|systemd\[)", body))
    body_block = f"```\n{body}\n```" if body_is_loggy else body

    chunks = []
    first = f"{header}\n{body_block}".strip()
    if len(first) <= MAX_DISCORD:
        chunks = [first]
    else:
        header_len = len(header) + 1
        if body_is_loggy:
            inner = body
            lines = inner.splitlines()
            current, current_len = [], 0
            while lines:
                ln = lines.pop(0)
                add = len(ln) + 1
                if header_len + 6 + current_len + add > MAX_DISCORD:  # 6 for code fences
                    chunks.append(header + "\n" + "```\n" + "\n".join(current) + "\n```")
                    header = f"**(cont.)** {subj} — `{HOST}`"
                    header_len = len(header) + 1
                    current, current_len = [ln], add
                else:
                    current.append(ln)
                    current_len += add
            if current:
                chunks.append(header + "\n" + "```\n" + "\n".join(current) + "\n```")
        else:
            text = header + "\n" + body_block
            # naive hard split; Discord is UTF-8 safe here since Python slices are by codepoints
            while text:
                chunks.append(text[:MAX_DISCORD])
                text = text[MAX_DISCORD:]

    username = f"Mail-Hook • {HOST}"
    for ch in chunks:
        try:
            post_chunk(ch, username=username)
            time.sleep(0.2)  # gentle with rate limits
        except HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            die(f"Discord webhook post failed: HTTP {e.code} — {body}", code=75)
        except URLError as e:
            die(f"Discord webhook post failed: {e}", code=75)

if __name__ == "__main__":
    main()
