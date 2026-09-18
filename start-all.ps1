# Opens a VISIBLE window running the WhatsApp bridge (the only component left here that
# needs launching -- the Python MCP server is managed automatically by Claude Code).
#
# NOTE 2026-09-07: the second line here used to start whatsapp-bot\bot.py (the "@claude"
# reply bot). That bot was retired -- scheduled task "WhatsApp 2 - Bot" unregistered and
# whatsapp-bot\ deleted (bot.py + requirements.txt remain recoverable from git at 40c713d).
# Nothing depends on it; porttracker's re-comms jobs read whatsapp-bridge\store\messages.db,
# which only the bridge writes.
#
# 2026-09-18: guarded + funneled through start-bridge.ps1. Re-running this used to open a
# fresh window AND launch another whatsapp-bridge.exe every time, with no check -- that is
# how six instances stacked up and churned the WhatsApp session. The guard here skips the
# window entirely when the bridge is already up; start-bridge.ps1 guards again as backstop.

$existing = Get-Process -Name 'whatsapp-bridge' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host ("WhatsApp bridge already running (PID {0}) - not opening another window." -f ($existing.Id -join ', '))
    return
}

Start-Process pwsh -ArgumentList '-NoExit', '-Command', "& '$PSScriptRoot\start-bridge.ps1'"
