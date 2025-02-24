# Undo Script for Invoke-WPFOORemove
# This script will simply perform the re-installation of OneDrive and Outlook back onto the Windows system, if they have both been removed.

function Invoke-WPFUndoOORemove {

# Ensure the script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator. Please restart PowerShell with elevated privileges." -ForegroundColor Red
    exit 1
}

# Check if OneDrive is installed
$onedriveInstalled = Get-AppxPackage -Name "*OneDrive*"

# Check if the New Outlook (Package identifier "9NRX63209R7B") is installed
$outlookInstalled = Get-AppxPackage | Where-Object { $_.PackageFamilyName -like "*9NRX63209R7B*" }

if (-not $onedriveInstalled -and -not $outlookInstalled) {
    Write-Host "Neither OneDrive nor New Outlook is installed. Installing both via winget..."

    # Install OneDrive (assuming the package ID is Microsoft.OneDrive)
    Start-Process -FilePath "winget" -ArgumentList "install Microsoft.OneDrive --accept-source-agreements --accept-package-agreements -e" -NoNewWindow -Wait

    # Install New Outlook using its package identifier
    Start-Process -FilePath "winget" -ArgumentList "install 9NRX63209R7B --accept-source-agreements --accept-package-agreements -e" -NoNewWindow -Wait
}
else {
    Write-Host "One or both packages are already installed. No action taken."
}

} # End Invoke-WPFOORemove
