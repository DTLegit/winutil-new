# This script clears the Windows 11 Start Menu by utilizing the "-ClearStart" and "-ClearStartAllUsers" function of another script made by a well-known developer called Rapphi that is named Win11Debloat.
# It will download the script, run without user input inside a separate elevated PowerShell Session and Window, and automatically exit and returns to the main WinUtil session.

function Invoke-WPFTweaksClearStart {
    Write-Host "Invoke-WPFClearStartMenu called"

    # Build the command to download and execute the remote script with the desired parameters.
    $remoteScriptCommand = "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -ClearStart -Silent"

    # Prepare the process start info to open an elevated PowerShell window.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    # We need to properly quote the remote command.
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$remoteScriptCommand`""
    $psi.Verb = "runas"            # This requests elevation (admin privileges)
    $psi.UseShellExecute = $true

    # Start the elevated process.
    $process = [System.Diagnostics.Process]::Start($psi)
    Write-Host "Elevated process started. Waiting for it to complete..."

    # Wait until the elevated process finishes.
    $process.WaitForExit()

    Write-Host "Remote script completed. Returning to the main session."
} # End Invoke-WPFTweaksClearStart

function Invoke-WPFTweaksClearStartAllUsers {
    Write-Host "Invoke-WPFTweaksClearStartMenuAllUsers called"

    # Build the command to download and execute the remote script with the desired parameters.
    $remoteScriptCommand = "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -ClearStartAllUsers -Silent"

    # Prepare the process start info to open an elevated PowerShell window.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    # We need to properly quote the remote command.
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$remoteScriptCommand`""
    $psi.Verb = "runas"            # This requests elevation (admin privileges)
    $psi.UseShellExecute = $true

    # Start the elevated process.
    $process = [System.Diagnostics.Process]::Start($psi)
    Write-Host "Elevated process started. Waiting for it to complete..."

    # Wait until the elevated process finishes.
    $process.WaitForExit()

    Write-Host "Remote script completed. Returning to the main session."
} # End Invoke-WPFTweaksClearStartAllUsers
