#!/usr/bin/env python3
import sys
import os
import json
import socket
import argparse
import time
import urllib.request
import urllib.error
import datetime
from email import policy
from email.parser import BytesParser

# --- Configuration ---
WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")
SECRET_PATH = os.environ.get("DISCORD_WEBHOOK_FILE", "/run/secrets/mail2discord-webhook")
HOSTNAME = socket.gethostname()

# Discord Limits
LIMIT_TITLE = 256
LIMIT_DESC = 4096
# We reserve space for markdown code fences (```text ... ```)
MAX_BODY_LEN = 3900

def load_secret():
    global WEBHOOK_URL
    if WEBHOOK_URL:
        return
    try:
        with open(SECRET_PATH, 'r') as f:
            WEBHOOK_URL = f.read().strip()
    except Exception:
        pass

def get_color(subject):
    """Determine color based on urgency."""
    sub_lower = subject.lower()
    if "error" in sub_lower or "fail" in sub_lower:
        return 15548997  # Red (0xED4245)
    if "test" in sub_lower:
        return 5763719   # Green (0x57F287)
    return 3447003       # Blue (0x3498DB) default

def send_to_discord(subject, sender, body):
    if not WEBHOOK_URL:
        print("ERR: No Webhook URL found.", file=sys.stderr)
        return

    # 1. Truncate Body & Wrap in Code Block
    if len(body) > MAX_BODY_LEN:
        body = body[:MAX_BODY_LEN] + "\n... [Truncated]"
    
    formatted_body = f"```text\n{body}\n```"

    # 2. Construct Embed
    embed = {
        "title": subject[:LIMIT_TITLE],
        "description": formatted_body,
        "color": get_color(subject),
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "footer": {
             "text": f"From: {sender} • Host: {HOSTNAME}"
        }
    }

    payload = {
        "username": "Smartd",
        "embeds": [embed]
    }
    
    data = json.dumps(payload).encode('utf-8')
    headers = {'Content-Type': 'application/json', 'User-Agent': 'nix-mail2discord/2.5'}
    req = urllib.request.Request(WEBHOOK_URL, data=data, headers=headers)

    # 3. Retry Logic
    max_retries = 5
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req) as response:
                return # Success
        except urllib.error.HTTPError as e:
            if e.code == 429:
                # Rate limited - Respect Retry-After
                retry_after = 2.0
                try:
                    body = json.loads(e.read().decode())
                    if isinstance(body, dict) and 'retry_after' in body:
                         retry_after = float(body['retry_after'])
                except Exception:
                    header_val = e.headers.get('Retry-After')
                    if header_val: retry_after = float(header_val)

                print(f"Rate limited (429). Sleeping {retry_after:.2f}s...", file=sys.stderr)
                time.sleep(retry_after + 0.1)
                continue
            
            elif 500 <= e.code < 600:
                sleep_time = 2 ** attempt
                print(f"Server error {e.code}. Retrying in {sleep_time}s...", file=sys.stderr)
                time.sleep(sleep_time)
                continue
            
            else:
                # 400 Bad Request usually means payload too big or invalid JSON
                if e.code == 400:
                    print(f"DEBUG: 400 Error. Payload Size: {len(data)}", file=sys.stderr)
                print(f"Discord API Error: {e.code} {e.reason}", file=sys.stderr)
                sys.exit(69)
                
        except urllib.error.URLError as e:
             sleep_time = 2 ** attempt
             print(f"Network error: {e.reason}. Retrying in {sleep_time}s...", file=sys.stderr)
             time.sleep(sleep_time)
             continue

    print("Max retries exceeded.", file=sys.stderr)
    sys.exit(69)

def extract_body(msg):
    text = ""
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                payload = part.get_payload(decode=True)
                if payload:
                    text = payload.decode('utf-8', 'replace')
                    break
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            text = payload.decode('utf-8', 'replace')
        else:
            text = str(msg.get_payload())
    return text or "No readable text content."

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", action="store_true")
    parser.add_argument("-i", action="store_true")
    parser.add_argument("-f", help="sender")
    parser.add_argument("recipients", nargs="*")
    args, unknown = parser.parse_known_args()

    load_secret()

    try:
        raw_email = sys.stdin.buffer.read()
    except Exception:
        return

    if not raw_email:
        return

    msg = BytesParser(policy=policy.default).parsebytes(raw_email)
    
    # Strip backticks from headers to prevent markdown injection
    subject = msg.get("subject", "No Subject").replace('`', '')
    sender = msg.get("from", "Unknown Sender").replace('`', '')
    body = extract_body(msg).strip()

    send_to_discord(subject, sender, body)

if __name__ == "__main__":
    main()