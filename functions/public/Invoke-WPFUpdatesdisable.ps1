function Invoke-WPFUpdatesdisable {
    <#
    .SYNOPSIS
        Pauses Windows Update (feature, quality, overall) for 7 days using ISO 8601 date/time format (with trailing "Z").
    .DESCRIPTION
        This script does the following:
          1. Creates a minimal script that sets the following keys under HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings:
             - PauseFeatureUpdatesStartTime / PauseFeatureUpdatesEndTime
             - PauseQualityUpdatesStartTime / PauseQualityUpdatesEndTime
             - PauseUpdatesStartTime / PauseUpdatesExpiryTime
             all in the format: yyyy-MM-ddTHH:mm:ssZ (UTC).
          2. Writes that minimal script to a fixed folder (C:\ProgramData\WinUtil\PauseWindowsUpdate).
          3. Creates a scheduled task ("PauseWindowsUpdate") that runs the script at startup and weekly (e.g. every Monday at 03:00 AM),
             and ensures the task runs whether a user is logged in or not.
          4. Immediately runs the script once to apply the pause right away.
    .NOTES
        Run as Administrator. Adapted for Windows 11 (24H2).
    #>

    # Define the folder for the minimal pause script.
    $global:ScheduledFolder = "C:\ProgramData\WinUtil\PauseWindowsUpdate"
    if (-not (Test-Path $global:ScheduledFolder)) {
        New-Item -Path $global:ScheduledFolder -ItemType Directory -Force | Out-Null
    }

    # Define the path for the minimal pause script.
    $ScheduledScriptPath = Join-Path -Path $global:ScheduledFolder -ChildPath "PauseWindowsUpdate.ps1"

    # Create the minimal pause script.
    $PauseScriptContent = @'
# Minimal Pause Script for Windows Update (ISO 8601 UTC Format)
# Sets:
#   - PauseFeatureUpdatesStartTime / PauseFeatureUpdatesEndTime
#   - PauseQualityUpdatesStartTime / PauseQualityUpdatesEndTime
#   - PauseUpdatesStartTime        / PauseUpdatesExpiryTime
# to a 7-day window in the format "yyyy-MM-ddTHH:mm:ssZ"

Write-Host "Pausing Windows Update with ISO 8601 UTC format..."

$nowUTC = (Get-Date).ToUniversalTime()
$endUTC = $nowUTC.AddDays(7)
$format = "yyyy-MM-ddTHH:mm:ssZ"

$pauseStart = $nowUTC.ToString($format)
$pauseEnd   = $endUTC.ToString($format)

Write-Host "Pause Start (UTC): $pauseStart"
Write-Host "Pause End   (UTC): $pauseEnd"

$UXKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
if (!(Test-Path $UXKey)) {
    New-Item -Path $UXKey -Force | Out-Null
}

Set-ItemProperty -Path $UXKey -Name "PauseFeatureUpdatesStartTime" -Value $pauseStart -Type String -Force
Set-ItemProperty -Path $UXKey -Name "PauseFeatureUpdatesEndTime"   -Value $pauseEnd   -Type String -Force
Set-ItemProperty -Path $UXKey -Name "PauseQualityUpdatesStartTime" -Value $pauseStart -Type String -Force
Set-ItemProperty -Path $UXKey -Name "PauseQualityUpdatesEndTime"   -Value $pauseEnd   -Type String -Force
Set-ItemProperty -Path $UXKey -Name "PauseUpdatesStartTime"  -Value $pauseStart -Type String -Force
Set-ItemProperty -Path $UXKey -Name "PauseUpdatesExpiryTime" -Value $pauseEnd   -Type String -Force

Write-Host "Windows Update is now paused (feature, quality, overall) until $pauseEnd"
'@

    # Write the minimal pause script to disk.
    $PauseScriptContent | Set-Content -Path $ScheduledScriptPath -Encoding UTF8 -Force
    Write-Host "Minimal pause script saved to $ScheduledScriptPath" -ForegroundColor Green

    # Create the scheduled task.
    $TaskName = "PauseWindowsUpdate"
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScheduledScriptPath`""

    # Create two triggers: one for weekly (Monday at 03:00 AM) and one for startup.
    $TriggerWeekly  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "03:00AM"
    $TriggerStartup = New-ScheduledTaskTrigger -AtStartup
    $Trigger = @($TriggerWeekly, $TriggerStartup)

    # Configure the task to run under the SYSTEM account.
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # FIX: Use the -StartWhenAvailable switch without a value.
    $TaskSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $TaskSettings -Description "Refreshes Windows Update pause settings weekly and at startup." -Force
        Write-Host "Scheduled task '$TaskName' created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create scheduled task '$TaskName': $_" -ForegroundColor Red
    }

    # Initialize the pause immediately.
    Write-Host "Initializing Windows Update pause now..."
    Start-Process -FilePath "PowerShell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ScheduledScriptPath`"" -Wait

    Write-Host "Windows Update is now paused for 7 days (feature, quality, overall) in ISO 8601 UTC format. Task set to refresh weekly and at startup." -ForegroundColor Green
}
