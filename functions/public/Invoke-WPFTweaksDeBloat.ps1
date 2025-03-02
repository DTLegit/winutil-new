function Invoke-Win11DebloatAuto {
    Write-Host "Downloading and running the Win11Debloat Script for app removal..." -ForegroundColor Cyan

    # Build the command to download and execute the remote script with the desired parameters.
    $remoteScriptCommand = "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -RemoveApps -RemoveCommApps -RemoveGamingApps -Silent"

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

    Write-Host "Win11Debloat Script App Removal Completed" -ForegroundColor Green
} # End Invoke-Win11DebloatAuto

