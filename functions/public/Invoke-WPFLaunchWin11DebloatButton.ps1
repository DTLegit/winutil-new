function Invoke-WPFLaunchWin11DebloatButton {
    Write-Host "Launching Win11Debloat by Rapphire..."

    # Build the command to download and execute the remote script with the desired parameters.
    $remoteScriptCommand = "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/')))"

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

    Write-Host "Returned to WinUtil Session" -ForegroundColor Green
} # End Invoke-WPFLaunchWin11DebloatButton
