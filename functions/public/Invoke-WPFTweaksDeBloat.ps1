function Invoke-WPFTweaksDeBloat {
    Write-Host "Removing Microsoft Teams..."
    # Build the path to the Teams folder and its Update.exe file.
    $TeamsPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Microsoft', 'Teams')
    $TeamsUpdateExePath = [System.IO.Path]::Combine($TeamsPath, 'Update.exe')

    Write-Host "Stopping Teams process..." -ForegroundColor Cyan
    Stop-Process -Name "*teams*" -Force -ErrorAction SilentlyContinue

    Write-Host "Uninstalling Teams from AppData\Microsoft\Teams..." -ForegroundColor Cyan
    if ([System.IO.File]::Exists($TeamsUpdateExePath)) {
        # Uninstall the Teams application.
        $proc = Start-Process -FilePath $TeamsUpdateExePath -ArgumentList "-uninstall -s" -PassThru
        $proc.WaitForExit()
    }

    Write-Host "Removing Teams AppxPackage..." -ForegroundColor Cyan
    Get-AppxPackage "*Teams*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxPackage "*Teams*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

    Write-Host "Deleting Teams directory..." -ForegroundColor Cyan
    if ([System.IO.Directory]::Exists($TeamsPath)) {
        Remove-Item $TeamsPath -Force -Recurse -ErrorAction SilentlyContinue
    }

    Write-Host "Deleting Teams uninstall registry key..." -ForegroundColor Cyan
    # Search for the uninstall string for Teams in the registry.
    $us = (Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, `
           HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | `
           Get-ItemProperty | Where-Object { $_.DisplayName -like "*Teams*" }).UninstallString
    if ($us -and $us.Length -gt 0) {
        # Modify the uninstall string to run in quiet mode.
        $us = ($us.Replace('/I', '/uninstall ') + ' /quiet').Replace('  ', ' ')
        $FilePath = $us.Substring(0, $us.IndexOf('.exe') + 4).Trim()
        $ProcessArgs = $us.Substring($us.IndexOf('.exe') + 5).Trim().Replace('  ', ' ')
        $proc = Start-Process -FilePath $FilePath -Args $ProcessArgs -PassThru
        $proc.WaitForExit()
    }

    Write-Host "Teams has been removed." -ForegroundColor Green
    Write-Host "Invoking Win11Debloat to remove any remaining bloat..." -ForegroundColor Cyan

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

    Write-Host "Remaining Leftover App Removal Completed" -ForegroundColor Green
} # End Invoke-WPFTweaksDeBloat

