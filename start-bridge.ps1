# WhatsApp MCP bridge startup
# Run this when the bridge needs to be started/restarted.
# The MCP server (Python side) is managed automatically by Claude Code.
# The store/ directory lives inside whatsapp-bridge/ — no need to cd elsewhere.

Set-Location "$PSScriptRoot\whatsapp-bridge"
Write-Host "Starting WhatsApp bridge from $PWD ..."
.\whatsapp-bridge.exe
