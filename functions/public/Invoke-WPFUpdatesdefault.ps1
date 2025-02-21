function Invoke-WPFUpdatesdefault {
    <#
    .SYNOPSIS
        Fully resets Windows Update configuration by removing security-only and pause-update settings.
    .DESCRIPTION
        This script does the following:
          1. Checks for the existence of registry keys and scheduled tasks created by either the security-only update script
             (located in "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually") or the pause updates script
             (located in "C:\ProgramData\WinUtil\PauseWindowsUpdate").
          2. If neither set of settings/tasks is found, it instructs the user to run the reset updates button in WinUtil.
          3. If found, it deletes all related scheduled tasks and removes the registry settings.
          4. Then it deletes all related directories and files created by the two update scripts.
          5. Finally, it resets Windows Update–related services (stopping and restarting wuauserv and BITS) and forces a GP update.
    .NOTES
        Must be run as Administrator.
    #>

    Write-Host "Checking for existing Windows Update settings applied by WinUtil scripts..."

    # Registry paths used by the security-only script:
    $secWUKey        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $devMetaKey      = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
    $driverSearchKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
    $WU_AUKey        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

    # Registry path used by the pause updates script:
    $pauseKey        = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

    $securityRegExists = (Test-Path $secWUKey) -or (Test-Path $devMetaKey) -or (Test-Path $driverSearchKey) -or (Test-Path $WU_AUKey)
    $pauseRegExists    = Test-Path $pauseKey

    $checkTask   = Get-ScheduledTask -TaskName "CheckSecuritySettings" -ErrorAction SilentlyContinue
    $reapplyTask = Get-ScheduledTask -TaskName "ReapplySecuritySettings" -ErrorAction SilentlyContinue
    $pauseTask   = Get-ScheduledTask -TaskName "PauseWindowsUpdate" -ErrorAction SilentlyContinue

    $tasksExist = ($checkTask -or $reapplyTask -or $pauseTask)

    if (-not ($securityRegExists -or $pauseRegExists -or $tasksExist)) {
        Write-Host "No Windows Update settings or scheduled tasks from WinUtil were detected." -ForegroundColor Yellow
        Write-Host "Please run the 'Reset Updates' button in the Config tab of WinUtil instead."
        return
    }

    Write-Host "Existing settings and/or tasks found. Proceeding with reset..."

    Write-Host "Deleting scheduled tasks..."
    if ($checkTask) {
        schtasks.exe /Delete /TN "CheckSecuritySettings" /F | Out-Null
        Write-Host "Deleted scheduled task: CheckSecuritySettings"
    }
    if ($reapplyTask) {
        schtasks.exe /Delete /TN "ReapplySecuritySettings" /F | Out-Null
        Write-Host "Deleted scheduled task: ReapplySecuritySettings"
    }
    if ($pauseTask) {
        schtasks.exe /Delete /TN "PauseWindowsUpdate" /F | Out-Null
        Write-Host "Deleted scheduled task: PauseWindowsUpdate"
    }

    Write-Host "Removing registry settings applied by WinUtil scripts..."
    if (Test-Path $secWUKey) {
        Remove-Item -Path $secWUKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed registry key: $secWUKey"
    }
    if (Test-Path $devMetaKey) {
        Remove-Item -Path $devMetaKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed registry key: $devMetaKey"
    }
    if (Test-Path $driverSearchKey) {
        Remove-Item -Path $driverSearchKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed registry key: $driverSearchKey"
    }
    if (Test-Path $WU_AUKey) {
        Remove-Item -Path $WU_AUKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed registry key: $WU_AUKey"
    }
    if (Test-Path $pauseKey) {
        Remove-Item -Path $pauseKey -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed registry key: $pauseKey"
    }

    Write-Host "Deleting directories and files created by WinUtil update scripts..."
    $secFolder = "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually"
    if (Test-Path $secFolder) {
        Remove-Item -Path $secFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted folder: $secFolder"
    }
    $pauseFolder = "C:\ProgramData\WinUtil\PauseWindowsUpdate"
    if (Test-Path $pauseFolder) {
        Remove-Item -Path $pauseFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted folder: $pauseFolder"
    }

    Write-Host "Resetting Windows Update services and settings..."
    Write-Host "Stopping Windows Update (wuauserv) and BITS..."
    net stop wuauserv | Out-Null
    net stop bits | Out-Null

    $sdFolder = "C:\Windows\SoftwareDistribution"
    if (Test-Path $sdFolder) {
        Remove-Item -Path $sdFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared SoftwareDistribution folder."
    }

    Write-Host "Starting Windows Update and BITS services..."
    net start wuauserv | Out-Null
    net start bits | Out-Null

    Write-Host "Forcing group policy update..."
    gpupdate /force | Out-Null

    # If a scheduled task for checking settings is used in this script, update its settings:
    # (For example, if the task was created using a settings set that incorrectly passed $true)
    # Here we combine compatibility with StartWhenAvailable:
    $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable

    Write-Host "Windows Update settings have been reset to their original defaults." -ForegroundColor Green
}
