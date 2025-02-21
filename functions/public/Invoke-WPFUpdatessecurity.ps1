function Invoke-WPFUpdatessecurity {

# ===============================================
# SecurityUpdatesOnlyV2.ps1 - Adapted for use in Chris Titus Tech's WinUtil
# ===============================================
# Setup-SecurityUpdateTasks.ps1
# ===============================================
# This master script performs the following:
# 1. Ensures it’s running as Administrator.
# 2. Creates a folder (C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually) for helper scripts and a timestamp file.
# 3. Writes two helper scripts:
#    • ApplySecuritySettings.ps1 – applies/updates the registry settings (including disabling driver updates, auto‐restart, etc.),
#       deletes any pending ReapplySecuritySettings task, and writes a timestamp.
#       (Accepts an optional -Silent switch to suppress debug output.)
#    • CheckSecuritySettings.ps1 – checks the timestamp and registry settings; if conditions are met,
#       it schedules a one-time task (ReapplySecuritySettings) to run the apply script.
#       (Accepts an optional -Silent switch to suppress debug output.)
# 4. Registers a scheduled task (CheckSecuritySettings) to run at startup and weekly (with compatibility set to Win8),
#    and passes the -Silent flag and hides the window. Runs under NT AUTHORITY\SYSTEM so no credentials are needed.
# 5. Immediately runs the ApplySecuritySettings.ps1 script to set policies on initial setup.
# ===============================================

# ----- Function: Ensure running as Administrator -----
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Script is not running as Administrator. Relaunching as Administrator..."
    try {
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs
    }
    catch {
        Write-Host "Failed to relaunch as Administrator. Please re-run this script manually as an Administrator." -ForegroundColor Red
    }
    exit
}

# ----- Start logging for the mother script (this script) to Desktop -----
try {
    $DesktopPath  = [Environment]::GetFolderPath("Desktop")
    $Timestamp    = (Get-Date).ToString("yyyyMMddHHmmss")
    $MotherLog    = Join-Path $DesktopPath "Setup-SecurityUpdateTasks-$Timestamp.log"
    Start-Transcript -Path $MotherLog -Append | Out-Null
    Write-Host "Logging mother script output to: $MotherLog"
} catch {
    Write-Host "WARNING: Failed to start transcript for the mother script. $_"
}

# ----- Define folder and file paths -----
$ScheduledFolder = "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually"
if (-not (Test-Path $ScheduledFolder)) {
    New-Item -Path $ScheduledFolder -ItemType Directory -Force | Out-Null
}

# Create a Logs folder for the two helper scripts
$LogFolder = Join-Path $ScheduledFolder "Logs"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$ApplyScriptPath = Join-Path $ScheduledFolder "ApplySecuritySettings.ps1"
$CheckScriptPath = Join-Path $ScheduledFolder "CheckSecuritySettings.ps1"
$TimestampFile   = Join-Path $ScheduledFolder "LastRunTimestamp.txt"

# ----- Create the ApplySecuritySettings.ps1 script -----
$ApplyScriptContent = @'
param(
    [switch]$Silent
)
# ===============================================
# ApplySecuritySettings.ps1
# ===============================================
# This script applies Windows Update registry policies:
#  - Deletes any pending "ReapplySecuritySettings" task.
#  - Detects OS version (Windows 10 vs. Windows 11) and the Windows feature release.
#  - Updates registry keys under:
#       HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate,
#       HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata,
#       HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching, and
#       HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU.
#  - Forces a gpupdate.
#  - Writes the current date/time to the timestamp file.
#  - Accepts a -Silent switch to suppress debug output.
#  - Logs to: C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually\Logs
#     and keeps only the last 3 logs.
# ===============================================

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    if (-not $Silent) { Write-Host "ApplySecuritySettings.ps1 is not running as Administrator. Relaunching..." }
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    catch {
        if (-not $Silent) { Write-Host "Failed to relaunch as Administrator. Please run manually as Admin." -ForegroundColor Red }
    }
    exit
}

# ----- Logging Setup -----
$MainFolder = "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually"
$LogFolder  = Join-Path $MainFolder "Logs"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
$TimeStamp         = (Get-Date).ToString("yyyyMMddHHmmss")
$LogFile           = Join-Path $LogFolder ("ApplySecuritySettings-$TimeStamp.log")

try {
    Start-Transcript -Path $LogFile -Append | Out-Null
} catch {
    if (-not $Silent) { Write-Host "WARNING: Failed to start transcript for ApplySecuritySettings.ps1: $_" }
}

# ----- Begin Script Logic -----

# 1. Delete the ReapplySecuritySettings task if it exists (suppress error if it doesn't)
Write-Host "Attempting to delete 'ReapplySecuritySettings' task. If the task does not exist, an error is expected and can be ignored."
try {
    schtasks.exe /Delete /TN "ReapplySecuritySettings" /F 2>$null | Out-Null
} catch {
    Write-Host "Note: 'ReapplySecuritySettings' task was not found. This is expected if the task never existed." -ForegroundColor Yellow
}

# 2. Layered OS & Feature Release Detection
if (-not $Silent) { Write-Host "DEBUG: Beginning layered OS detection..." }

$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 22000) {
    $ProductVersion = "Windows 11"
} elseif ($osVersion.Major -eq 10) {
    $ProductVersion = "Windows 10"
} else {
    $ProductVersion = "Unknown"
}
if (-not $Silent) {
    Write-Host "DEBUG: System.Environment OSVersion: $osVersion"
    Write-Host "DEBUG: Detected OS: $ProductVersion (Build $($osVersion.Build))"
}

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$primaryFeatureRelease   = $null
$secondaryFeatureRelease = $null
$tertiaryFeatureRelease  = $null

# Try to read registry values
$regValues = $null
try {
    $regValues = Get-ItemProperty -Path $regPath -ErrorAction Stop
} catch { }

# Primary: DisplayVersion
if ($regValues -and $regValues.DisplayVersion) {
    if ($regValues.DisplayVersion -match "^\d{2}H\d$") {
        $primaryFeatureRelease = $regValues.DisplayVersion
        if (-not $Silent) { Write-Host "DEBUG: Primary Feature Release (DisplayVersion): $primaryFeatureRelease" }
    } else {
        if (-not $Silent) { Write-Host "DEBUG: DisplayVersion '$($regValues.DisplayVersion)' not matching ^\d{2}H\d$" }
    }
} else {
    if (-not $Silent) { Write-Host "DEBUG: DisplayVersion not found in registry." }
}

# Secondary: OSDisplayVersion via Get-ComputerInfo
$osInfo = $null
try {
    $osInfo = Get-ComputerInfo -ErrorAction Stop
} catch { }

if ($osInfo -and $osInfo.OSDisplayVersion) {
    if ($osInfo.OSDisplayVersion -match "^\d{2}H\d$") {
        $secondaryFeatureRelease = $matches[0]
        if (-not $Silent) { Write-Host "DEBUG: Secondary Feature Release (OSDisplayVersion): $secondaryFeatureRelease" }
    } else {
        if (-not $Silent) { Write-Host "DEBUG: OSDisplayVersion '$($osInfo.OSDisplayVersion)' not matching ^\d{2}H\d$" }
    }
} else {
    if (-not $Silent) { Write-Host "DEBUG: OSDisplayVersion not found from Get-ComputerInfo." }
}

# Tertiary: ReleaseId (if primary is null)
if (-not $primaryFeatureRelease -and $regValues -and $regValues.ReleaseId) {
    if ($regValues.ReleaseId -match "^\d{2}H\d$") {
        $tertiaryFeatureRelease = $regValues.ReleaseId
        if (-not $Silent) { Write-Host "DEBUG: Tertiary Feature Release (ReleaseId): $tertiaryFeatureRelease" }
    } else {
        if (-not $Silent) { Write-Host "DEBUG: ReleaseId '$($regValues.ReleaseId)' not matching ^\d{2}H\d$" }
    }
}

# Decide final feature release
$finalFeatureRelease = $primaryFeatureRelease
if (-not $finalFeatureRelease) {
    $finalFeatureRelease = $secondaryFeatureRelease
    if (-not $finalFeatureRelease) {
        $finalFeatureRelease = $tertiaryFeatureRelease
    }
}

if ($finalFeatureRelease) {
    $TargetReleaseVersionInfo = $finalFeatureRelease
    if (-not $Silent) { Write-Host "DEBUG: Final Detected Feature Release: $TargetReleaseVersionInfo" }
} else {
    $TargetReleaseVersionInfo = "24H2"  # fallback
    if (-not $Silent) { Write-Host "DEBUG: No valid feature release detected; defaulting to $TargetReleaseVersionInfo" }
}

# ----- Verification Check -----
$allGood = $true

# Check main WindowsUpdate settings
$WURegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
try {
    $WUSettings = Get-ItemProperty -Path $WURegPath -ErrorAction Stop
} catch {
    $allGood = $false
}
if ($allGood) {
    if ( ($WUSettings.ProductVersion -ne $ProductVersion) -or
         ($WUSettings.TargetReleaseVersionInfo -ne $TargetReleaseVersionInfo) -or
         ($WUSettings.TargetReleaseVersion -ne 1) -or
         ($WUSettings.DeferQualityUpdates -ne 1) -or
         ($WUSettings.DeferQualityUpdatesPeriodInDays -ne 4) -or
         ($WUSettings.ExcludeWUDriversInQualityUpdate -ne 1) ) {
        $allGood = $false
    }
}

# Check Device Metadata settings
$DevMetaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
try {
    $DevMetaSettings = Get-ItemProperty -Path $DevMetaPath -ErrorAction Stop
} catch {
    $allGood = $false
}
if ($allGood -and ($DevMetaSettings.PreventDeviceMetadataFromNetwork -ne 1)) {
    $allGood = $false
}

# Check DriverSearching settings
$DriverSearchPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
try {
    $DriverSearchSettings = Get-ItemProperty -Path $DriverSearchPath -ErrorAction Stop
} catch {
    $allGood = $false
}
if ($allGood -and ( ($DriverSearchSettings.DontPromptForWindowsUpdate -ne 1) -or
                     ($DriverSearchSettings.DontSearchWindowsUpdate -ne 1) -or
                     ($DriverSearchSettings.DriverUpdateWizardWuSearchEnabled -ne 0) )) {
    $allGood = $false
}

# Check WindowsUpdate\AU settings
$AUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
try {
    $AUSettings = Get-ItemProperty -Path $AUPath -ErrorAction Stop
} catch {
    $allGood = $false
}
if ($allGood -and ( ($AUSettings.NoAutoRebootWithLoggedOnUsers -ne 1) -or
                     ($AUSettings.AUPowerManagement -ne 0) )) {
    $allGood = $false
}

if ($allGood) {
    if (-not $Silent) { Write-Host "All registry settings are already up-to-date. No changes needed." }
    Stop-Transcript | Out-Null
    exit
} else {
    if (-not $Silent) { Write-Host "Registry settings differ or are missing. Proceeding to apply updates." }
}

# 3. Apply Registry Settings

# -- WindowsUpdate key settings --
$RegistrySettings = @{
    "ProductVersion"                  = $ProductVersion
    "TargetReleaseVersion"            = 1
    "TargetReleaseVersionInfo"        = $TargetReleaseVersionInfo
    "DeferQualityUpdates"             = 1
    "DeferQualityUpdatesPeriodInDays" = 4
    "ExcludeWUDriversInQualityUpdate" = 1
}

if (-not (Test-Path $WURegPath)) { New-Item -Path $WURegPath -Force | Out-Null }
foreach ($Name in $RegistrySettings.Keys) {
    $Value = $RegistrySettings[$Name]
    $Type = if ($Value -is [int]) { "DWord" } else { "String" }
    try {
        $existingValue = Get-ItemProperty -Path $WURegPath -Name $Name -ErrorAction SilentlyContinue
        if ($null -eq $existingValue) {
            New-ItemProperty -Path $WURegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        }
        else {
            Set-ItemProperty -Path $WURegPath -Name $Name -Value $Value -Force
        }
        if (-not $Silent) { Write-Host "Set $Name to $Value ($Type)" }
    }
    catch {
        if (-not $Silent) { Write-Host "Failed to set $($Name): $_" -ForegroundColor Red }
    }
}

# -- Additional settings: Device Metadata, DriverSearching, and AU --

# Device Metadata: disable device metadata retrieval
$DevMetaKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
if (-not (Test-Path $DevMetaKey)) { New-Item -Path $DevMetaKey -Force | Out-Null }
Set-ItemProperty -Path $DevMetaKey -Name "PreventDeviceMetadataFromNetwork" -Type DWord -Value 1
if (-not $Silent) { Write-Host "Set PreventDeviceMetadataFromNetwork to 1 in Device Metadata" }

# Driver Searching: disable Windows Update driver prompts and searches
$DriverSearchKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
if (-not (Test-Path $DriverSearchKey)) { New-Item -Path $DriverSearchKey -Force | Out-Null }
Set-ItemProperty -Path $DriverSearchKey -Name "DontPromptForWindowsUpdate" -Type DWord -Value 1
Set-ItemProperty -Path $DriverSearchKey -Name "DontSearchWindowsUpdate" -Type DWord -Value 1
Set-ItemProperty -Path $DriverSearchKey -Name "DriverUpdateWizardWuSearchEnabled" -Type DWord -Value 0
if (-not $Silent) { Write-Host "Applied DriverSearching settings." }

# WindowsUpdate AU: disable automatic restart with logged on users
$AUKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $AUKey)) { New-Item -Path $AUKey -Force | Out-Null }
Set-ItemProperty -Path $AUKey -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1
Set-ItemProperty -Path $AUKey -Name "AUPowerManagement" -Type DWord -Value 0
if (-not $Silent) { Write-Host "Applied WindowsUpdate AU settings." }

gpupdate /force
if (-not $Silent) { Write-Host "Registry settings applied successfully." }

# 4. Update Timestamp File
$TimestampFile = Join-Path $MainFolder "LastRunTimestamp.txt"
(Get-Date).ToString("o") | Out-File -FilePath $TimestampFile -Encoding UTF8
if (-not $Silent) { Write-Host "Timestamp updated to current date/time." }

# 5. Stop Transcript & Clean Up Old Logs
try {
    Stop-Transcript | Out-Null
} catch {
    # no-op
}

# Remove older logs (keep only last 3)
try {
    $logs = Get-ChildItem -Path $LogFolder -Filter "ApplySecuritySettings-*.log" | Sort-Object CreationTime -Descending
    $oldLogs = $logs | Select-Object -Skip 3
    foreach ($log in $oldLogs) {
        Remove-Item $log.FullName -Force
    }
} catch {
    if (-not $Silent) { Write-Host "WARNING: Failed to clean old ApplySecuritySettings logs: $_" }
}
'@

Set-Content -Path $ApplyScriptPath -Value $ApplyScriptContent -Force -Encoding UTF8

# ----- Create the CheckSecuritySettings.ps1 script -----
$CheckScriptContent = @'
param(
    [switch]$Silent
)
# ===============================================
# CheckSecuritySettings.ps1
# ===============================================
# This script checks if security settings need reapplication.
# It:
#  - Reads the timestamp file and calculates the elapsed time.
#  - Performs OS and feature-release detection (simplified version).
#  - Checks if the registry settings are missing or differ from expected values.
#     (This includes WindowsUpdate, Device Metadata, DriverSearching, and AU settings.)
#  - If at least 364 days have elapsed or a discrepancy is found, schedules ReapplySecuritySettings.
#  - Accepts a -Silent switch to suppress debug output.
#  - Logs to: C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually\Logs
#     and keeps only the last 3 logs.
# ===============================================

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    if (-not $Silent) { Write-Host "CheckSecuritySettings.ps1 is not running as Administrator. Relaunching..." }
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    catch {
        if (-not $Silent) { Write-Host "Failed to relaunch as Administrator. Please run manually as Admin." -ForegroundColor Red }
    }
    exit
}

# ----- Logging Setup -----
$MainFolder = "C:\ProgramData\UpdateWindowsUpdatePoliciesAnnually"
$LogFolder  = Join-Path $MainFolder "Logs"
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}
$TimeStamp = (Get-Date).ToString("yyyyMMddHHmmss")
$LogFile   = Join-Path $LogFolder ("CheckSecuritySettings-$TimeStamp.log")

try {
    Start-Transcript -Path $LogFile -Append | Out-Null
} catch {
    if (-not $Silent) { Write-Host "WARNING: Failed to start transcript for CheckSecuritySettings.ps1: $_" }
}

$TimestampFile   = Join-Path $MainFolder "LastRunTimestamp.txt"
$ApplyScriptPath = Join-Path $MainFolder "ApplySecuritySettings.ps1"

if (-not (Test-Path $TimestampFile)) {
    if (-not $Silent) { Write-Host "Timestamp file not found. Exiting check." }
    try { Stop-Transcript | Out-Null } catch {}
    return
}

# Read and debug the timestamp
$LastRunStr = Get-Content $TimestampFile -ErrorAction SilentlyContinue
$LastRun = $null
try {
    $LastRun = Get-Date $LastRunStr -ErrorAction Stop
} catch {
    if (-not $Silent) { Write-Host "DEBUG: Failed to parse timestamp: '$LastRunStr'" }
    try { Stop-Transcript | Out-Null } catch {}
    return
}
if (-not $Silent) { Write-Host "DEBUG: LastRun date: $LastRun" }

$CurrentDate = Get-Date
if (-not $Silent) { Write-Host "DEBUG: Current date: $CurrentDate" }
$TimeSpan = New-TimeSpan -Start $LastRun -End $CurrentDate
if (-not $Silent) {
    Write-Host ("DEBUG: Elapsed: {0} days, {1} hours, {2} minutes, {3} seconds." -f $TimeSpan.Days, $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds)
}

$ReapplyNeeded = $false

if ($TimeSpan.TotalDays -ge 364) {
    if (-not $Silent) { Write-Host "At least 364 days have elapsed. Checking OS and registry..." }

    # ----- OS Version Check -----
    $OSVersion = [System.Environment]::OSVersion.Version
    $Major = $OSVersion.Major
    $Build = $OSVersion.Build

    if ($Major -eq 10 -and $Build -ge 22000) {
        $ProductVersion = "Windows 11"
    } elseif ($Major -eq 10) {
        $ProductVersion = "Windows 10"
    } else {
        $ProductVersion = "Unknown"
    }
    if (-not $Silent) { Write-Host "DEBUG: Detected OS: $ProductVersion" }

    # ----- Feature Release Check (simplified fallback) -----
    $TargetReleaseVersionInfo = $null
    try {
        $OSInfo = Get-ComputerInfo -ErrorAction Stop
        if (-not $Silent) { Write-Host "DEBUG: WindowsVersion: $($OSInfo.WindowsVersion)" }
        if ($OSInfo.WindowsVersion -match "(\d{2}H\d)") {
            $TargetReleaseVersionInfo = $matches[1]
        }
    } catch {
        try {
            $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
            if ($regInfo -and $regInfo.ReleaseId) {
                $TargetReleaseVersionInfo = $regInfo.ReleaseId
            }
        } catch {
            $TargetReleaseVersionInfo = "24H2"
        }
    }
    if (-not $TargetReleaseVersionInfo) {
        $TargetReleaseVersionInfo = "24H2"
    }
    if (-not $Silent) { Write-Host "DEBUG: Detected Release Version: $TargetReleaseVersionInfo" }

    # ----- Registry Check -----
    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $ExistingRegSettings = $null
    try {
        $ExistingRegSettings = Get-ItemProperty -Path $RegPath -ErrorAction Stop
    } catch {
        $ExistingRegSettings = $null
    }

    if ($null -eq $ExistingRegSettings) {
        if (-not $Silent) { Write-Host "DEBUG: WindowsUpdate registry settings not found." }
        $ReapplyNeeded = $true
    } else {
        if (($ExistingRegSettings.ProductVersion -ne $ProductVersion) -or
            ($ExistingRegSettings.TargetReleaseVersionInfo -ne $TargetReleaseVersionInfo)) {
            if (-not $Silent) { Write-Host "DEBUG: WindowsUpdate registry discrepancy found." }
            $ReapplyNeeded = $true
        }
    }

    # Additional Registry Checks:

    # Device Metadata
    $DevMetaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata"
    $DevMetaSettings = $null
    try { $DevMetaSettings = Get-ItemProperty -Path $DevMetaPath -ErrorAction Stop } catch {}
    if ($null -eq $DevMetaSettings -or $DevMetaSettings.PreventDeviceMetadataFromNetwork -ne 1) {
        if (-not $Silent) { Write-Host "DEBUG: Device Metadata settings discrepancy found." }
        $ReapplyNeeded = $true
    }

    # Driver Searching
    $DriverSearchPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
    $DriverSearchSettings = $null
    try { $DriverSearchSettings = Get-ItemProperty -Path $DriverSearchPath -ErrorAction Stop } catch {}
    if ($null -eq $DriverSearchSettings -or
        ($DriverSearchSettings.DontPromptForWindowsUpdate -ne 1) -or
        ($DriverSearchSettings.DontSearchWindowsUpdate -ne 1) -or
        ($DriverSearchSettings.DriverUpdateWizardWuSearchEnabled -ne 0)) {
        if (-not $Silent) { Write-Host "DEBUG: Driver Searching settings discrepancy found." }
        $ReapplyNeeded = $true
    }

    # WindowsUpdate AU
    $AUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $AUSettings = $null
    try { $AUSettings = Get-ItemProperty -Path $AUPath -ErrorAction Stop } catch {}
    if ($null -eq $AUSettings -or
        ($AUSettings.NoAutoRebootWithLoggedOnUsers -ne 1) -or
        ($AUSettings.AUPowerManagement -ne 0)) {
        if (-not $Silent) { Write-Host "DEBUG: WindowsUpdate AU settings discrepancy found." }
        $ReapplyNeeded = $true
    }

    if ($ReapplyNeeded) {
        if (-not $Silent) { Write-Host "Scheduling ReapplySecuritySettings in 1 minute..." }
        $startTime = (Get-Date).AddMinutes(1)
        $startTimeStr = $startTime.ToString("HH:mm")
        $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ApplyScriptPath`" -Silent"
        schtasks.exe /Create /TN "ReapplySecuritySettings" /TR $command /SC ONCE /ST $startTimeStr /RL HIGHEST /F | Out-Null
    } else {
        if (-not $Silent) { Write-Host "Registry settings are up-to-date. No reapply needed." }
    }
} else {
    if (-not $Silent) { Write-Host "Security settings update not required yet." }
}

# ----- Stop Transcript & Clean Up Old Logs -----
try {
    Stop-Transcript | Out-Null
} catch { }

try {
    $logs = Get-ChildItem -Path $LogFolder -Filter "CheckSecuritySettings-*.log" | Sort-Object CreationTime -Descending
    $oldLogs = $logs | Select-Object -Skip 3
    foreach ($log in $oldLogs) {
        Remove-Item $log.FullName -Force
    }
} catch {
    if (-not $Silent) { Write-Host "WARNING: Failed to clean old CheckSecuritySettings logs: $_" }
}
'@

Set-Content -Path $CheckScriptPath -Value $CheckScriptContent -Force -Encoding UTF8

# ----- Create or update the Timestamp file if it doesn't exist -----
if (-not (Test-Path $TimestampFile)) {
    (Get-Date).ToString("o") | Out-File -FilePath $TimestampFile -Encoding UTF8
}

# ----- Create the Scheduled Task for the Check Script -----
# This task runs at system startup and weekly (every Sunday at 03:00 AM)
$TriggerStartup = New-ScheduledTaskTrigger -AtStartup
$TriggerWeekly  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00AM"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$CheckScriptPath`" -Silent"

# Use SYSTEM account to run whether a user is logged on or not
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -Compatibility Win8

Register-ScheduledTask -TaskName "CheckSecuritySettings" `
                       -Action $Action `
                       -Trigger @($TriggerStartup, $TriggerWeekly) `
                       -Principal $Principal `
                       -Settings $settings `
                       -Description "Periodically checks and triggers reapplication of Windows Update security settings if needed." `
                       -Force

Write-Host "Setup complete. The CheckSecuritySettings task has been scheduled to run at startup and weekly under SYSTEM."

# ----- Run the ApplySecuritySettings.ps1 script immediately for initial setup -----
Write-Host "Running initial application of security settings..."
& "$ApplyScriptPath"

Write-Host "Optimal and Security-Only Update Settings Applied! Security_Only_Script log is saved to desktop." -ForegroundColor Green

# ----- Stop transcript for mother script -----
try {
    Stop-Transcript | Out-Null
} catch {
    Write-Host "No transcript was active or couldn't stop transcript: $_"
}

} # End Invoke-WPFUpdatessecurity
