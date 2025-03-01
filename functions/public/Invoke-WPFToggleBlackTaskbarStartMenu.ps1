function Invoke-WPFToggleBlackTaskbarStartMenu {

# Set the UI accent color to black and enable the black taskbar and Start Menu
# Define the registry key path
$keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent"

# Create the key if it doesn't exist
if (-not (Test-Path $keyPath)) {
    New-Item -Path $keyPath -Force | Out-Null
}

# Set "AccentPalette" to 32 bytes of 0x00 (i.e. 32 pairs of 0s)
$data = New-Object Byte[] 32
Set-ItemProperty -Path $keyPath -Name "AccentPalette" -Value $data

# Set "StartColorMenu" to DWORD 0
New-ItemProperty -Path $keyPath -Name "StartColorMenu" -PropertyType DWord -Value 0 -Force | Out-Null

# Set "AccentColorMenu" to DWORD 0
New-ItemProperty -Path $keyPath -Name "AccentColorMenu" -PropertyType DWord -Value 0 -Force | Out-Null

Write-Host "Dark mode and Black Taskbar + Start Menu applied."
Write-Host "You may need to restart your computer for this to take into effect."

Invoke-WinUtilExplorerUpdate
if ($sync.ThemeButton.Content -eq [char]0xF08C) {
    Invoke-WinutilThemeChange -theme "Auto"
}

} # End function Invoke-WPFToggleBlackTaskbarStartMenu


function Invoke-UndoWPFToggleBlackTaskbarStartMenu {

# Remove custom accent settings to restore the automatic system accent color

# Remove the custom AccentPalette if it exists
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentPalette" -ErrorAction SilentlyContinue

# Remove custom StartColorMenu setting (for Start menu/taskbar)
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "StartColorMenu" -ErrorAction SilentlyContinue

# Remove custom AccentColorMenu setting (for menus and title bars)
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentColorMenu" -ErrorAction SilentlyContinue

Write-Host "Custom accent color settings removed. Windows will now use the default accent color."
Write-Host "Light mode and default settings restored."
Write-Host "You may need to either sign out and sign back in, or fully restart your computer for changes to take full effect."

Invoke-WinUtilExplorerUpdate
if ($sync.ThemeButton.Content -eq [char]0xF08C) {
    Invoke-WinutilThemeChange -theme "Auto"
  }
} # End function Invoke-UndoWPFToggleBlackTaskbarStartMenu

