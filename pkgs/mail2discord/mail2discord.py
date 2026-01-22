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

MAX_LENGTH = 4000  # Embed description limit is 4096
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

def send_to_discord(subject, sender, body):
    if not WEBHOOK_URL:
        return

    # Construct Embed
    embed = {
        "title": subject[:256], # Title limit
        "description": body,
        "color": 0x3498db, # Blue-ish
        "timestamp": time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime()),
        "footer": {
             "text": f"From: {sender} • Host: {HOSTNAME}"
        }
    }

    payload = {
        "username": "Mail2Discord",
        "embeds": [embed]
    }
    
    data = json.dumps(payload).encode('utf-8')
    headers = {'Content-Type': 'application/json', 'User-Agent': 'nix-mail2discord/2.0'}
    req = urllib.request.Request(WEBHOOK_URL, data=data, headers=headers)

    max_retries = 5
    
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req) as response:
                return # Success
        except urllib.error.HTTPError as e:
            if e.code == 429:
                # Too Many Requests - Respect Retry-After
                retry_after = 2.0 # Default fallback
                
                try:
                    # Discord sends detailed info in body
                    body = json.loads(e.read().decode())
                    if isinstance(body, dict) and 'retry_after' in body:
                         retry_after = float(body['retry_after'])
                except Exception:
                    # Fallback to header
                    header_val = e.headers.get('Retry-After')
                    if header_val:
                        retry_after = float(header_val)

                # Add small buffer
                sleep_time = retry_after + 0.1
                print(f"Rate limited (429). Sleeping for {sleep_time:.2f}s...", file=sys.stderr)
                time.sleep(sleep_time)
                continue
            
            elif 500 <= e.code < 600:
                # Server Error - Exponential Backoff
                sleep_time = 2 ** attempt
                print(f"Server error {e.code}. Retrying in {sleep_time}s...", file=sys.stderr)
                time.sleep(sleep_time)
                continue
            
            else:
                # 4xx or other non-retriable
                print(f"Discord API Error: {e.code} {e.reason}", file=sys.stderr)
                sys.exit(69) # EX_UNAVAILABLE
                
        except urllib.error.URLError as e:
             # Network transport errors
             sleep_time = 2 ** attempt
             print(f"Network error: {e.reason}. Retrying in {sleep_time}s...", file=sys.stderr)
             time.sleep(sleep_time)
             continue

    print("Max retries exceeded. Failed to send to Discord.", file=sys.stderr)
    sys.exit(69)

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
    # Truncate body if huge (Embed limit 4096)
    if len(body) > MAX_LENGTH:
        body = body[:MAX_LENGTH] + "\n...[truncated]"

    send_to_discord(subject, sender, body)

if __name__ == "__main__":
    main()