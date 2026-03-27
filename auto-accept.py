#!/usr/bin/env python3
"""
auto-accept.py — wraps claude startup and auto-accepts interactive prompts.

Handles:
1. Workspace trust dialog ("Yes, I trust this folder")
2. Dev channels warning ("I am using this for local development")

After accepting prompts, hands control back to the interactive session.
"""
import pexpect
import sys
import os

cmd = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else os.path.expanduser("~/start.sh")

print(f"[auto-accept] Starting: {cmd}")

child = pexpect.spawn(cmd, encoding='utf-8', timeout=30)
child.logfile_read = sys.stdout

prompts_handled = 0

try:
    while prompts_handled < 5:  # max 5 prompts to handle
        idx = child.expect([
            r'Enter to confirm',        # trust dialog or dev channels
            r'Yes, I trust this folder', # workspace trust
            r'I am using this for local development',  # dev channels
            pexpect.TIMEOUT,
            pexpect.EOF,
        ], timeout=15)

        if idx == 0:
            # Generic "Enter to confirm" — just press Enter
            child.sendline('')
            prompts_handled += 1
            print(f"\n[auto-accept] Accepted prompt {prompts_handled}")
        elif idx == 1 or idx == 2:
            # Specific prompt text — press Enter to select option 1
            child.sendline('')
            prompts_handled += 1
            print(f"\n[auto-accept] Accepted prompt {prompts_handled}")
        elif idx == 3:
            # Timeout — no more prompts, session is running
            print(f"\n[auto-accept] No more prompts detected. Handing off to interactive session.")
            break
        elif idx == 4:
            # EOF — process exited
            print(f"\n[auto-accept] Process exited.")
            sys.exit(child.exitstatus or 1)

except Exception as e:
    print(f"\n[auto-accept] Error: {e}")

# Hand off to interactive mode
child.interact()
