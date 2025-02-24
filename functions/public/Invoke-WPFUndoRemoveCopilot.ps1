# This script will attempt to reinstall and re-enable Microsoft Copilot, with also restoring the respective registry keys to their default values.

function Invoke-WPFUndoRemoveCopilot {

# --- Undo Registry Changes ---

# Remove TurnOffWindowsCopilot from HKLM policies if it exists
if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot") {
    try {
        if (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
            Write-Host "Removed TurnOffWindowsCopilot from HKLM."
        }
    } catch {
        Write-Host "Error removing TurnOffWindowsCopilot from HKLM: $_"
    }
}

# Remove TurnOffWindowsCopilot from HKCU policies if it exists
if (Test-Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot") {
    try {
        if (Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
            Write-Host "Removed TurnOffWindowsCopilot from HKCU policies."
        }
    } catch {
        Write-Host "Error removing TurnOffWindowsCopilot from HKCU policies: $_"
    }
}

# Reset ShowCopilotButton to 1 in HKCU Explorer Advanced
if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced") {
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 1 -Type DWord
        Write-Host "Set ShowCopilotButton to 1 in HKCU Explorer Advanced."
    } catch {
        Write-Host "Error setting ShowCopilotButton: $_"
    }
}

# --- Reinstall Copilot Package ---

Write-Host "Attempting to reinstall the Copilot package using winget..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Start-Process -FilePath "winget" -ArgumentList "install", "--id", "9NHT9RB2F4HD", "-e", "--accept-source-agreements", "--accept-package-agreements" -NoNewWindow -Wait
} else {
    Write-Host "winget command not found on this system. Please reinstall Copilot manually."
}

} # End Invoke-WPFUndoRemoveCopilot
