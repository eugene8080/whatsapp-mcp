"""
WhatsApp → Claude bot.
Polls messages.db for messages sent by the owner starting with @claude,
calls the Claude API, and sends the reply back to the same chat.

Usage: python bot.py
Trigger: type "@claude <question>" in any WhatsApp chat (or message yourself).
Reset conversation: "@claude reset"
"""

import sqlite3
import requests
import anthropic
import time
import json
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

# ── Config ─────────────────────────────────────────────────────────────────
DB_PATH      = Path(__file__).parent.parent / "whatsapp-bridge" / "store" / "messages.db"
BRIDGE_URL   = "http://localhost:8080/api/send"
TRIGGER      = "@claude"
POLL_SECS    = 2
STATE_FILE   = Path(__file__).parent / "bot_state.json"
MAX_HISTORY  = 40   # messages per chat (20 exchanges)

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

# Per-chat conversation histories: {chat_jid: [{"role": ..., "content": ...}]}
histories: dict[str, list] = {}


# ── State persistence (survive restarts without reprocessing old msgs) ──────
def load_last_timestamp() -> str | None:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text()).get("last_timestamp")
    return None


def save_last_timestamp(ts: str) -> None:
    STATE_FILE.write_text(json.dumps({"last_timestamp": ts}))


# ── DB helpers ──────────────────────────────────────────────────────────────
def get_current_max_timestamp() -> str | None:
    with sqlite3.connect(DB_PATH) as conn:
        row = conn.execute("SELECT MAX(timestamp) FROM messages").fetchone()
        return row[0] if row else None


def poll_new_triggers(after_ts: str) -> list[tuple]:
    """Return rows (id, chat_jid, content, timestamp) for new @claude messages sent by me."""
    with sqlite3.connect(DB_PATH) as conn:
        return conn.execute(
            """
            SELECT id, chat_jid, content, timestamp
            FROM messages
            WHERE is_from_me = 1
              AND LOWER(content) LIKE ?
              AND timestamp > ?
            ORDER BY timestamp ASC
            """,
            (f"{TRIGGER.lower()}%", after_ts),
        ).fetchall()


# ── Bridge REST call ────────────────────────────────────────────────────────
def send_reply(chat_jid: str, text: str) -> None:
    try:
        resp = requests.post(BRIDGE_URL, json={"recipient": chat_jid, "message": text}, timeout=10)
        resp.raise_for_status()
    except Exception as e:
        print(f"[send_reply] error: {e}")


# ── Claude API call ─────────────────────────────────────────────────────────
def call_claude(chat_jid: str, user_text: str) -> str:
    hist = histories.setdefault(chat_jid, [])
    hist.append({"role": "user", "content": user_text})

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=(
            "You are Claude, a helpful AI assistant reachable via WhatsApp. "
            "Keep responses concise and conversational — this is a chat interface. "
            "Use plain text; avoid markdown headers or bullet lists unless asked."
        ),
        messages=hist,
    )

    reply = response.content[0].text
    hist.append({"role": "assistant", "content": reply})

    # Trim history so it doesn't grow unbounded
    if len(hist) > MAX_HISTORY:
        histories[chat_jid] = hist[-MAX_HISTORY:]

    return reply


# ── Main loop ───────────────────────────────────────────────────────────────
def main() -> None:
    last_ts = load_last_timestamp()

    if last_ts is None:
        # First run — anchor to now so we don't replay history
        last_ts = get_current_max_timestamp() or "1970-01-01T00:00:00"
        save_last_timestamp(last_ts)
        print(f"[bot] First run — anchored to {last_ts}. Listening...")
    else:
        print(f"[bot] Resumed from {last_ts}. Listening for '{TRIGGER}' in any chat...")

    while True:
        try:
            rows = poll_new_triggers(last_ts)
            for msg_id, chat_jid, content, timestamp in rows:
                # Strip trigger prefix and whitespace
                user_text = content[len(TRIGGER):].strip()

                if user_text.lower() == "reset":
                    histories.pop(chat_jid, None)
                    send_reply(chat_jid, "Conversation reset. Fresh start!")
                    print(f"[bot] Reset history for {chat_jid}")
                else:
                    print(f"[bot] [{chat_jid}] {user_text[:80]}...")
                    reply = call_claude(chat_jid, user_text)
                    send_reply(chat_jid, reply)
                    print(f"[bot] → {reply[:80]}...")

                last_ts = timestamp
                save_last_timestamp(last_ts)

        except Exception as e:
            print(f"[bot] error: {e}")

        time.sleep(POLL_SECS)


if __name__ == "__main__":
    main()
