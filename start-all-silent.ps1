# Same as start-all.ps1, without the visible console window. See that file for why the
# bot line is gone and why the single-instance guard exists (2026-09-18).

$existing = Get-Process -Name 'whatsapp-bridge' -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host ("WhatsApp bridge already running (PID {0}) - not opening another window." -f ($existing.Id -join ', '))
    return
}

Start-Process pwsh -ArgumentList '-NoExit', '-Command', "& '$PSScriptRoot\start-bridge.ps1'" -WindowStyle Hidden
