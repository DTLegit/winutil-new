function WPF-UndoWinUtilEdgeBrowser {

# edge_vanisher.ps1 is designed to uninstall Edge and block its reinstallation. This script restores the ability for Edge to be reinstalled by the system.
# 
# Additionally, this will also automatically download and completely re-install the Edge Browser, along with a complete cache and temporary file cleanup after the reinstall to get rid of all remenants of the Edge installer.
# 
# This script is a modified version Talon's Edge Removal Unblock Script maintained by @totallynotK0 and the @ravendevteam, which itself is a fork of @mre31's original edge_unblock.ps1 script.
# Credit for the majority of this script goes to @mre31, @totallynotK0, and the @ravendevteam for this script. These developers have done an amazing job with this script and full gratitude and thanks goes to them.
# This would not have been possible without their work. This version has been tailored to work with Chris Titus Tech's WinUtil Program.
#
# Link to the original script repository source: https://github.com/mre31/edge-complete-remover 
# Link to the repository that this script was adapted from: https://github.com/ravendevteam/talon-blockedge 
#
#
# Edge folder paths
$folderPaths = @(
    "C:\Program Files (x86)\Microsoft\Edge",
    "C:\Program Files (x86)\Microsoft\EdgeCore"
)

# Create new ACL object
$acl = New-Object System.Security.AccessControl.DirectorySecurity

# Set ownership to Administrators group
$administratorsGroup = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$acl.SetOwner($administratorsGroup)

# Enable inheritance
$acl.SetAccessRuleProtection($false, $true)

# Define required SIDs
$trustedInstallerSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464")
$systemSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")
$adminsSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
$usersSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
$creatorOwnerSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-3-0")
$allAppPackagesSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-15-2-1")
$restrictedAppPackagesSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-15-2-2")

# Define and add permissions
$rules = @(
    # Permissions for TrustedInstaller
    [PSCustomObject]@{
        Identity = $trustedInstallerSid
        Rights = "FullControl"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for SYSTEM
    [PSCustomObject]@{
        Identity = $systemSid
        Rights = "FullControl"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for Administrators
    [PSCustomObject]@{
        Identity = $adminsSid
        Rights = "FullControl"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for Users
    [PSCustomObject]@{
        Identity = $usersSid
        Rights = "ReadAndExecute"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for ALL APPLICATION PACKAGES
    [PSCustomObject]@{
        Identity = $allAppPackagesSid
        Rights = "ReadAndExecute"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for RESTRICTED APPLICATION PACKAGES
    [PSCustomObject]@{
        Identity = $restrictedAppPackagesSid
        Rights = "ReadAndExecute"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    },
    # Permissions for CREATOR OWNER
    [PSCustomObject]@{
        Identity = $creatorOwnerSid
        Rights = "FullControl"
        InheritanceFlags = "ContainerInherit,ObjectInherit"
        PropagationFlags = "None"
        Type = "Allow"
    }
)

# Add permissions to ACL
foreach ($rule in $rules) {
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $rule.Identity,
        $rule.Rights,
        $rule.InheritanceFlags,
        $rule.PropagationFlags,
        $rule.Type
    )
    $acl.AddAccessRule($accessRule)
}

# Process each folder
foreach ($folderPath in $folderPaths) {
    Write-Host "`nProcessing folder: $folderPath" -ForegroundColor Cyan

    try {
        # Apply permissions to all folders and subitems
        Get-ChildItem -Path $folderPath -Recurse | ForEach-Object {
            Set-Acl $_.FullName $acl -ErrorAction Stop
            Write-Host "Success: $($_.FullName)" -ForegroundColor Green
        }

        # Apply permissions to main folder
        Set-Acl $folderPath $acl -ErrorAction Stop
        Write-Host "Main folder permissions successfully updated: $folderPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Error occurred while processing $folderPath : $_" -ForegroundColor Red
    }
}

Write-Host "`nOperation completed. Edge and EdgeCore folder permissions have been restored to default." -ForegroundColor Green


# ------------------------------
# Microsoft Edge Installation & Cleanup
# ------------------------------

# Create a unique temporary directory for the installer.
$tempDir = Join-Path $env:TEMP "EdgeInstaller_$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Build the Winget download command using the proper parameter for download directory.
$wingetDownloadArgs = "download --id Microsoft.Edge --download-directory `"$tempDir`" --accept-source-agreements --accept-package-agreements"

$maxAttempts = 3
$attempt = 1
$downloadSucceeded = $false
$installerFile = $null

while ($attempt -le $maxAttempts -and -not $downloadSucceeded) {
    Write-Host "Winget download attempt $attempt of $maxAttempts..."
    try {
        Start-Process -FilePath "winget.exe" -ArgumentList $wingetDownloadArgs -Wait

        # Look for any downloaded installer file (could be .msi, .exe, etc.)
        $installerFile = Get-ChildItem -Path $tempDir -File | Select-Object -First 1

        if ($installerFile -and $installerFile.Exists) {
            Write-Host "Download succeeded: $($installerFile.FullName)"
            $downloadSucceeded = $true
        }
        else {
            Write-Warning "Installer file not found in $tempDir after attempt $attempt."
        }
    }
    catch {
        Write-Warning "Winget download attempt $attempt failed: $($_.Exception.Message)"
    }

    if (-not $downloadSucceeded) {
        $attempt++
        if ($attempt -le $maxAttempts) {
            Write-Host "Retrying in 5 seconds..."
            Start-Sleep -Seconds 5
        }
    }
}

if (-not $downloadSucceeded) {
    Write-Error "Failed to download the Microsoft Edge installer using Winget after $maxAttempts attempts. Exiting."
    Remove-Item -Path $tempDir -Recurse -Force
    exit 1
}

# Determine installation method based on the file extension.
# --- First, run the interactive installation ---
if ($installerFile.Extension -eq ".msi") {
    Write-Host "Detected MSI installer. Launching interactive installation of Microsoft Edge..."
    # Define the log file path on the Desktop.
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $msiLogPath = Join-Path $desktopPath "msiexec.log"
    # Launch interactive install (no /quiet or /silent)
    $msiArgs = "/i `"$($installerFile.FullName)`" /norestart /l*v `"$msiLogPath`""
    $installerProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -Verb RunAs
}
else {
    Write-Host "Detected EXE installer. Launching interactive installation..."
    $installerProcess = Start-Process -FilePath $installerFile.FullName -Wait -PassThru -Verb RunAs
}

$exitCode = $installerProcess.ExitCode
Write-Host "Interactive installer exited with code: $exitCode"

# Allow some time for shortcuts to be created
Start-Sleep -Seconds 10

# --- Now, check if Edge appears via its shortcuts ---
# Define expected shortcut paths.
$edgeDesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Microsoft Edge.lnk"
# For the current user's Start Menu; adjust the subfolder if necessary.
$edgeStartMenuShortcutUser = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\Microsoft Edge.lnk"
# Also check the all-users Start Menu folder.
$edgeStartMenuShortcutAll = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"

if ((-not (Test-Path $edgeDesktopShortcut)) -and (-not (Test-Path $edgeStartMenuShortcutUser)) -and (-not (Test-Path $edgeStartMenuShortcutAll))) {
    Write-Host "Edge installation not detected (no shortcuts found). Attempting forced installation with reinstall options..."

    if ($installerFile.Extension -eq ".msi") {
        # For MSI installers, run with forced reinstall parameters and silent switches.
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $msiLogPathForced = Join-Path $desktopPath "msiexec_forced.log"
        $msiArgsForced = "/i `"$($installerFile.FullName)`" REINSTALL=ALL REINSTALLMODE=vomus /norestart /l*v `"$msiLogPathForced`""
        $installerProcessForced = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgsForced -Wait -PassThru -Verb RunAs
    }
    else {
        # For EXE installers, use silent install parameters.
        $exeArgsForced = "/passive /norestart"
        $installerProcessForced = Start-Process -FilePath $installerFile.FullName -ArgumentList $exeArgsForced -Wait -PassThru -Verb RunAs
    }

    $exitCodeForced = $installerProcessForced.ExitCode
    Write-Host "Forced installer exited with code: $exitCodeForced"
}
else {
    Write-Host "Edge installation detected (shortcuts found)."
}

# As a safeguard, terminate any lingering processes with "Edge" in their name.
$installerProcesses = Get-Process | Where-Object { $_.ProcessName -match "Edge" }
foreach ($proc in $installerProcesses) {
    try {
        Write-Host "Terminating lingering process: $($proc.ProcessName) (ID: $($proc.Id))"
        Stop-Process -Id $proc.Id -Force
    }
    catch {
        Write-Warning "Failed to terminate process ID $($proc.Id): $($_.Exception.Message)"
    }
}

# Clean up: remove the temporary directory used for the installer.
Write-Host "Cleaning up remaining temporary Edge installer files..."
Remove-Item -Path $tempDir -Recurse -Force

# Remove Winget cache directories manually.
$wingetCachePaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache\Microsoft\WinGet",
    "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache\Packages"
)
foreach ($cachePath in $wingetCachePaths) {
    if (Test-Path $cachePath) {
        Write-Host "Removing Winget cache directory: $cachePath"
        Remove-Item -Path $cachePath -Recurse -Force
    }
}

# Remove any temporary directories in the system TEMP folder that mention 'edge' (case-insensitive).
Write-Host "Removing any temporary directories with 'edge' in their name in $env:TEMP..."
Get-ChildItem -Path $env:TEMP -Directory | Where-Object { $_.Name -match '(?i)edge' } | ForEach-Object {
    try {
        Write-Host "Removing directory: $($_.FullName)"
        Remove-Item -Path $_.FullName -Recurse -Force
    }
    catch {
        Write-Warning "Failed to remove directory $($_.FullName): $($_.Exception.Message)"
    }
}

# ------------------------------
# Final System Cleanup with Disk Cleanup (excluding Windows Update Cleanup and Downloads)
# ------------------------------
Write-Host "Performing Temp Cleanup Operation to ensure all remaining Edge install files are deleted from the system."
Write-Host "Configuring Disk Cleanup profile to clean temporary/cache files (excluding Windows Update Cleanup and Downloads)..."

# Set registry flags for Disk Cleanup (SAGESET:100) for the desired categories:
# 1) Delivery Optimization Files
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Delivery Optimization Files" /v StateFlags00100 /t REG_DWORD /d 2 /f' -Wait

# 2) Thumbnail Cache
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" /v StateFlags00100 /t REG_DWORD /d 2 /f' -Wait

# 3) Microsoft Defender Antivirus
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Microsoft Defender Antivirus" /v StateFlags00100 /t REG_DWORD /d 2 /f' -Wait

# 4) Temporary Internet Files
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Internet Files" /v StateFlags00100 /t REG_DWORD /d 2 /f' -Wait

Write-Host "Running Disk Cleanup silently..."
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/SAGERUN:100" -Wait
Write-Host "Disk Cleanup completed."

# Revert Disk Cleanup registry settings to default (0) so they no longer force cleanup in subsequent runs.
Write-Host "Reverting Disk Cleanup registry settings..."
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Delivery Optimization Files" /v StateFlags00100 /t REG_DWORD /d 0 /f' -Wait
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" /v StateFlags00100 /t REG_DWORD /d 0 /f' -Wait
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Microsoft Defender Antivirus" /v StateFlags00100 /t REG_DWORD /d 0 /f' -Wait
Start-Process -FilePath "reg.exe" -ArgumentList 'add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Internet Files" /v StateFlags00100 /t REG_DWORD /d 0 /f' -Wait

Write-Host "Microsoft Edge installation and full system cleanup process is complete. You might want to ensure that all Edge install components are removed by making sure that all temporary files are cleaned via the Windows storage settings. Simply search for 'Storage' in the settings search, click on 'Storage Settings' and go to 'Temporary Files' to get to the storage cleanup menu." -ForegroundColor Cyan

Write-Host "Edge has been successfully reinstalled." -ForegroundColor Green
Write-Host "Either one or two .msi install log files have been saved to your desktop folder in case if something has gone wrong." -ForegroundColor Cyan
Write-Host "Please feel free to delete the log files and/or drag them to your Recycle Bin if the Edge install was successful and is in working order." - ForegroundColor Cyan


} # End of Uninstall-WinUtilEdgeBrowser
