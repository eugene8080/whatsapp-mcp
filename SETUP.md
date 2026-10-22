# WhatsApp MCP — Setup & Operations

## Architecture

Two processes work together:

| Process | What it does | How it starts |
|---|---|---|
| **Go bridge** (`whatsapp-bridge.exe`) | Holds the WhatsApp session, syncs messages, serves REST API on `:8080` | Windows Scheduled Task (auto at login) |
| **Python MCP server** (`main.py`) | Exposes WhatsApp tools to Claude Code via MCP | Auto-launched by Claude Code on startup (any project) |

You don't need to do anything manually after initial setup — both start automatically.

---

## Initial Setup (one-time)

### Pairing recovery and device identity (2026-10-22)

The bridge now supplies desktop pairing metadata named **PSCAP11 WhatsApp Bridge**.
This applies to new pairings; confirm the phone's displayed label after linking.
The previous build left the device type as UNKNOWN.

The communications refresh failed on 2026-10-22 because the message store had not
updated since 2026-10-16 and the bridge was waiting for a QR scan. A running process
or scheduler result of zero does not prove authentication or message syncing.
Recovery verified 2026-10-22 at 14:54 HKT: pairing succeeded, history sync stored
4,069 messages, and all five WhatsApp property refreshes passed (four updated;
Lai Yee had no new messages). The three email properties were skipped by this
manual recovery shell because its Gmail service-account environment was absent;
their scheduled 08:00 run had already completed successfully.

Eugene prefers the bridge **headless**, independent of Orca workspace terminals.
The live `WhatsApp 1 - Bridge` task launches `start-bridge.ps1` through headless
conhost, at logon and every five minutes, with no execution time limit. A temporary
QR/log-viewer window only tails the log: closing it does not stop the bridge.
The viewer was closed after pairing. The phone's displayed device name remains
unconfirmed; desktop metadata was verified in the rebuilt executable's source.

### 1. Authenticate WhatsApp (QR scan)
Run the bridge manually the first time to scan the QR code:
```powershell
cd D:\dev\whatsapp-mcp\whatsapp-bridge
.\whatsapp-bridge.exe
```
Scan the QR code with your phone. Session is saved to `whatsapp-bridge\store\whatsapp.db`.

### 2. Register the Scheduled Task
```powershell
$action = New-ScheduledTaskAction -Execute "D:\dev\whatsapp-mcp\whatsapp-bridge\whatsapp-bridge.exe" -WorkingDirectory "D:\dev\whatsapp-mcp\whatsapp-bridge"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName "WhatsApp MCP Bridge" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
```

### 3. Register the MCP server with Claude Code
Add to your `~/.claude/.claude.json` under `mcpServers`:
```json
"whatsapp": {
  "command": "path\\to\\uv.exe",
  "args": ["--directory", "D:\\dev\\whatsapp-mcp\\whatsapp-mcp-server", "run", "main.py"]
}
```

---

## Store location

**Always run the bridge from `D:\dev\whatsapp-mcp\whatsapp-bridge\`** — it uses a relative `store/` path.

- `store\whatsapp.db` — WA session (re-scan QR if deleted)
- `store\messages.db` — message cache (safe to delete; repopulates on next sync)

---

## Manual start (if needed)

```powershell
.\start-bridge.ps1
```

Or start the Scheduled Task manually:
```powershell
Start-ScheduledTask -TaskName "WhatsApp MCP Bridge"
```

---

## Known bugs fixed (2026-07-03)

- **`list_chats` with `include_last_message=False`** — SQL references `messages.*` columns without a JOIN, causing a silent SQLite error. Always call with `include_last_message=True`.
- **Dataclass serialization** — MCP tools returned Python dataclass objects that FastMCP couldn't serialize. Fixed in `main.py` with `dataclasses.asdict()` + `datetime.isoformat()`.
