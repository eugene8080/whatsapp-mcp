<#
  install-bridge-task.ps1 - (re)register the "WhatsApp 1 - Bridge" scheduled task, HARDENED.

  RUN THIS ONCE, ELEVATED (Run as Administrator) if $logon = 'S4U', or if a plain run gets
  "Access denied" updating the existing root-folder task. Re-running updates it (-Force).

  Why this exists (2026-09-18): the pre-existing task ran whatsapp-bridge.exe DIRECTLY with:
    - only a logon trigger + a weak RestartOnFailure -> nothing restarts a mid-session death;
    - DisallowStartIfOnBatteries / StopIfGoingOnBatteries = true;
    - no single-instance guard -> the task's launch plus any manual start-all.ps1 run stacked
      duplicates (six alive on 2026-09-18, churning the one WhatsApp session + messages.db).

  This registration fixes all three:
    - Action funnels through start-bridge.ps1 (the ONE guarded, single-instance launcher) so a
      tick never duplicates an instance started any other way (task, Herdr pane, start-all.ps1);
    - At logon + every 5 min (self-heal): MultipleInstances=IgnoreNew keeps the healthy instance
      alive and blocks the tick; when it dies the next tick restarts it within ~5 min;
    - Battery flags off, ExecutionTimeLimit unlimited (the action runs for the bridge's lifetime).

  It is a porttracker DEPENDENCY: re-comms-nightly / -chase-weekly read whatsapp-bridge\store\
  messages.db. Do NOT delete the task. Watch it live:  Get-Content <dir>\store\bridge.log -Wait
#>
$ErrorActionPreference = 'Stop'

$repo   = 'D:\dev\whatsapp-mcp'
$script = Join-Path $repo 'start-bridge.ps1'
$wdir   = Join-Path $repo 'whatsapp-bridge'
$pwsh   = (Get-Command pwsh).Source
$user   = "$env:USERDOMAIN\$env:USERNAME"
$logon  = 'Interactive'   # 'Interactive' (only while logged on - matches the re-comms chain) | 'S4U' (whether logged on or not, needs elevation)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($logon -eq 'S4U' -and -not $isAdmin) {
    Write-Error "logon='S4U' needs elevation. Run as Administrator, or leave logon='Interactive'."
    exit 1
}

# conhost --headless: under an Interactive logon, Task Scheduler creates the console window
# BEFORE pwsh can honor -WindowStyle Hidden, flashing a terminal on every fire. Wrapping in
# headless conhost never allocates a window at all (the house no-flash rule). start-bridge.ps1
# runs the bridge in the FOREGROUND, so this action stays alive for the bridge's lifetime.
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" `
    -Argument "--headless `"$pwsh`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`"" `
    -WorkingDirectory $wdir

# At logon + a 5-minute self-heal loop (3650-day duration ~= indefinite; avoids the
# TimeSpan.MaxValue range bug on some Windows builds). The guard in start-bridge.ps1 makes
# every tick a no-op while the bridge is healthy.
$tLogon = New-ScheduledTaskTrigger -AtLogOn -User $user
$tEvery = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 3650)

# ExecutionTimeLimit = 0 -> no limit (the action runs for weeks); battery flags off so it
# always starts/stays; IgnoreNew so the loop never stacks a second task instance.
$set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

$prin = New-ScheduledTaskPrincipal -UserId $user -LogonType $logon -RunLevel Limited

try {
    Register-ScheduledTask -TaskName 'WhatsApp 1 - Bridge' -Action $action `
        -Trigger @($tLogon, $tEvery) -Settings $set -Principal $prin -Force | Out-Null
} catch {
    Write-Error ("Register failed: {0}`nIf this is 'Access denied', re-run this script ELEVATED (Run as Administrator)." -f $_.Exception.Message)
    exit 1
}
Write-Host "Registered/updated: 'WhatsApp 1 - Bridge' (at logon + every 5 min self-heal, LogonType $logon)." -ForegroundColor Green

# Kick it once now. Guard-safe: if the bridge is already running (e.g. in a Herdr pane) this
# is a no-op; otherwise it starts one headless.
Start-ScheduledTask -TaskName 'WhatsApp 1 - Bridge'

Write-Host "`nVerify / control:" -ForegroundColor Cyan
Write-Host "  Get-ScheduledTask 'WhatsApp 1 - Bridge' | Select TaskName,State"
Write-Host "  Get-Process whatsapp-bridge | Select Id,StartTime          # must be exactly ONE"
Write-Host "  Get-Content $wdir\store\bridge.log -Wait -Tail 20          # watch it live (e.g. in a Herdr pane)"
Write-Host "  Unregister-ScheduledTask 'WhatsApp 1 - Bridge' -Confirm:`$false   # remove it (breaks re-comms)"
