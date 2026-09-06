# Starts the WhatsApp bridge (the only component left here that needs launching).
# The MCP server (Python side) is managed automatically by Claude Code.
# NOTE 2026-09-07: the second line here used to start whatsapp-bot\bot.py (the "@claude" reply bot).
# That bot was retired -- scheduled task "WhatsApp 2 - Bot" unregistered and whatsapp-bot\ deleted
# (bot.py + requirements.txt remain recoverable from git at 40c713d). Nothing depends on it; porttracker's
# re-comms jobs read whatsapp-bridge\store\messages.db, which only the bridge writes.
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'cd D:\dev\whatsapp-mcp\whatsapp-bridge; .\whatsapp-bridge.exe'
