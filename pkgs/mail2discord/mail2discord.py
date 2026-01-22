#!/usr/bin/env python3
import sys
import os
import json
import socket
import argparse
import time
import urllib.request
import urllib.error
from email import policy
from email.parser import BytesParser

# --- Configuration ---
# 1. Try env var
# 2. Try SOPS secret file
# 3. Fail
WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL")
SECRET_PATH = os.environ.get("DISCORD_WEBHOOK_FILE", "/run/secrets/mail2discord-webhook")

MAX_LENGTH = 1900  # Leave buffer for formatting
HOSTNAME = socket.gethostname()

def load_secret():
    global WEBHOOK_URL
    if WEBHOOK_URL:
        return
    
    try:
        with open(SECRET_PATH, 'r') as f:
            WEBHOOK_URL = f.read().strip()
    except PermissionError:
        print(f"ERR: Permission denied reading {SECRET_PATH}. Check group permissions.", file=sys.stderr)
        sys.exit(77) # EX_NOPERM
    except FileNotFoundError:
        print(f"ERR: Secret not found at {SECRET_PATH}", file=sys.stderr)
        sys.exit(78) # EX_CONFIG

def send_to_discord(content):
    if not WEBHOOK_URL:
        return

    payload = {
        "username": f"Mail • {HOSTNAME}",
        "content": content
    }
    
    req = urllib.request.Request(
        WEBHOOK_URL, 
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json', 'User-Agent': 'nix-mail2discord/2.0'}
    )

    try:
        with urllib.request.urlopen(req) as response:
            pass
    except urllib.error.HTTPError as e:
        print(f"Discord API Error: {e.code} {e.reason}", file=sys.stderr)
        sys.exit(69) # EX_UNAVAILABLE

def parse_email_body(msg):
    # Simplistic preference: Plain text -> HTML -> Raw
    body = msg.get_body(preferencelist=('plain', 'html'))
    if body:
        return body.get_content()
    return "No text content found."

def main():
    # 1. Swallow sendmail flags so we don't crash when apps pass them
    parser = argparse.ArgumentParser(description="Discord Sendmail Shim")
    parser.add_argument("-t", action="store_true", help="Read recipients from message (ignored)")
    parser.add_argument("-i", action="store_true", help="Ignore dots (ignored)")
    parser.add_argument("-f", help="Set sender (ignored)")
    parser.add_argument("recipients", nargs="*", help="Recipients (ignored)")
    args, unknown = parser.parse_known_args()

    # 2. Load Secret
    load_secret()

    # 3. Read Stdin
    raw_email = sys.stdin.buffer.read()
    if not raw_email:
        return

    # 4. Parse
    msg = BytesParser(policy=policy.default).parsebytes(raw_email)
    subject = msg.get("subject", "No Subject")
    sender = msg.get("from", "Unknown Sender")
    body = parse_email_body(msg)

    # 5. Format & Send
    # Truncate body if huge
    if len(body) > MAX_LENGTH:
        body = body[:MAX_LENGTH] + "\n...[truncated]"

    message = f"**From:** `{sender}`\n**Subject:** `{subject}`\n```{body}```"
    send_to_discord(message)

if __name__ == "__main__":
    main()