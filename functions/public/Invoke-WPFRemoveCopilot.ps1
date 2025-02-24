# This script will attempt to disable and uninstall Microsoft's Copilot off of Windows.

function Invoke-WPFRemoveCopilot {

# --- Registry changes ---

# Set HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot - TurnOffWindowsCopilot = 1
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -PropertyType DWord -Force

# Set HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot - TurnOffWindowsCopilot = 1
New-Item -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -PropertyType DWord -Force

# Set HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced - ShowCopilotButton = 0
New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0 -PropertyType DWord -Force

# --- Invoke script to remove Copilot ---

Write-Host "Removing Copilot using DISM..."
dism /online /remove-package /package-name:Microsoft.Windows.Copilot

Write-Host "Attempting to remove Copilot package using APPX..."
$appxPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" }
if ($appxPackages) {
    foreach ($pkg in $appxPackages) {
        Write-Host "Removing APPX package: $($pkg.Name)"
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "No Copilot APPX package found."
}

Write-Host "Attempting to remove Copilot package using winget..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget uninstall --id 9NHT9RB2F4HD -e
} else {
    Write-Host "winget command not found on this system."
}

} # End Invoke-WPFRemoveCopilot
