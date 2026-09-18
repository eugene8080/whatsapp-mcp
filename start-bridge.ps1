# WhatsApp MCP bridge startup -- SINGLE-INSTANCE launcher.
#
# The bridge holds ONE WhatsApp linked-device session and one SQLite store (store\),
# so only one whatsapp-bridge.exe may run at a time. Two or more instances fight over
# the session + DB and produce an endless "websocket EOF -> Successfully authenticated
# -> Connected to WhatsApp" reconnect loop (observed 2026-09-18: SIX instances alive,
# all writing one messages.db). This launcher is the ONE funnel used both interactively
# (e.g. inside a Herdr pane) and by the "WhatsApp 1 - Bridge" scheduled task; the guard
# below is what keeps it single-instance across every caller.
#
# The MCP server (Python side) is managed automatically by Claude Code -- only this Go
# bridge needs launching. The store\ directory lives inside whatsapp-bridge\, so this
# script cd's there itself and can be invoked from anywhere.

$ErrorActionPreference = 'Stop'
$bridgeDir = Join-Path $PSScriptRoot 'whatsapp-bridge'
Set-Location $bridgeDir

# --- Single-instance guard -------------------------------------------------------
# Match on the process image name (Get-Process strips the .exe), which catches EVERY
# instance regardless of how it was started -- task, start-all.ps1, a bare pwsh window,
# or `herdr pane run`. If one is already up, do nothing and exit 0 (a no-op is exactly
# what the 5-min self-heal task wants when the bridge is healthy).
$existing = Get-Process -Name 'whatsapp-bridge' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host ("WhatsApp bridge already running (PID {0}) - not starting another." -f ($existing.Id -join ', '))
    return
}

# --- Rolling log -----------------------------------------------------------------
# The task runs the bridge headless (no console), so tee its output to a file to keep
# it inspectable (`Get-Content store\bridge.log -Wait` to watch it live in a Herdr pane).
# Rotate once at start-up when the log passes 10 MB, keeping a single previous file --
# a real long-running instance streams for weeks, so rotation only bites at (re)starts.
$log = Join-Path $bridgeDir 'store\bridge.log'
if ((Test-Path $log) -and ((Get-Item $log).Length -gt 10MB)) {
    Move-Item $log (Join-Path $bridgeDir 'store\bridge.log.1') -Force
}

Write-Host "Starting WhatsApp bridge from $bridgeDir ..."

# The bridge streams its own INFO/ERROR lines and exits non-zero on Ctrl+C; relax the
# error preference so a non-zero exit at shutdown doesn't surface as a script fault
# (pwsh 7.4 would otherwise throw on native non-zero under -ErrorAction Stop).
$ErrorActionPreference = 'Continue'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

# Decode the bridge's UTF-8 stdout as UTF-8 (it prints emoji + CJK chat names/bodies);
# without this PowerShell decodes those bytes as the OEM code page and the log/console
# show mojibake. Wrapped in try/catch because a headless conhost host may lack a console.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

# 2>&1 folds stderr into the pipeline so websocket errors also land in the log.
# Tee-Object streams line-by-line: live output when interactive, persistent log always.
.\whatsapp-bridge.exe 2>&1 | Tee-Object -FilePath $log -Append
