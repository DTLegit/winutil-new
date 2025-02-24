function Invoke-WPFOOSUAuto {

<#
.SYNOPSIS
    Downloads and runs O&O ShutUp10 with various modes, including:
      - GUI mode ("customize")
      - Applying recommended settings ("recommended")
      - Applying default settings ("default") – same as recommended except it uses a configuration file named OOSU10-Default.cfg

.DESCRIPTION
    The script creates a unique temporary folder where it downloads the O&O ShutUp10 executable.
    For the "recommended" and "default" actions, it downloads the configuration file from a defined URL using three download methods (each tried three times in sequence).
    The executable itself is also downloaded using these methods.

    After O&O ShutUp10 completes (or the GUI is closed), the script cleans up by deleting the temporary
    folder and its contents.

.PARAMETER default
    Launches the default mode (applies default configuration using OOSU10-Default.cfg).

.PARAMETER recommended
    Launches the recommended mode (applies recommended configuration using OOSU10.cfg).

.PARAMETER customize
    Launches the GUI mode.

.PARAMETER verbose
    Enables verbose (debug) output.

.PARAMETER silent
    Suppresses all console output.

.EXAMPLE
    .\OOSU10-Auto.ps1 -default -verbose

    Runs the script in default mode with detailed output.
#>

param (
    [switch]$default,
    [switch]$recommended,
    [switch]$customize,
    [switch]$verbose,
    [switch]$silent
)

# --- Check for Administrator Privileges ---
function Test-IsAdministrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host "OOSU10Auto is not running as Administrator. Trying to run with administrator rights..."
    $scriptPath = $PSCommandPath
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $($MyInvocation.UnboundArguments)"
    try {
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
        exit
    } catch {
        Write-Host "Failed to relaunch as administrator. Please run PowerShell as administrator and try again."
        exit 1
    }
}

# --- Check if a Mode was Specified ---
if (-not ($default -or $recommended -or $customize)) {
    if (-not $silent) {
        Write-Host "A launch argument is required. Please specify one of the following:"
        Write-Host "  -default       : Apply default configuration (looks for OOSU10-Default.cfg)"
        Write-Host "  -recommended   : Apply recommended configuration (looks for OOSU10.cfg)"
        Write-Host "  -customize     : Launch the GUI mode"
        Write-Host "Optional output level switches:"
        Write-Host "  -silent        : Suppress all output"
        Write-Host "  -verbose       : Show detailed debugging output"
    }
    exit 1
}

# --- Set Output Mode ---
if ($silent) {
    $VerbosePreference = "SilentlyContinue"
    $ProgressPreference = "SilentlyContinue"
} elseif ($verbose) {
    $VerbosePreference = "Continue"
} else {
    # Normal mode: standard output with some Write-Host messages.
    $VerbosePreference = "SilentlyContinue"
}

# --- Helper Functions for Output ---
function MyWriteHost {
    param([string]$message)
    if (-not $silent) { Write-Host $message }
}
function MyWriteVerbose {
    param([string]$message)
    if (-not $silent) { Write-Verbose $message }
}
function MyWriteError {
    param([string]$message)
    if (-not $silent) { Write-Error $message }
}

# --- Function: Download-File ---
# Tries three methods (each with 3 attempts) to download a file.
function Download-File {
    param(
        [string]$url,
        [string]$destination
    )
    $methods = @("InvokeWebRequest", "WebClient", "BitsTransfer")
    foreach ($method in $methods) {
         $success = $false
         for ($attempt=1; $attempt -le 3; $attempt++) {
             try {
                  switch ($method) {
                      "InvokeWebRequest" {
                          Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
                      }
                      "WebClient" {
                          $wc = New-Object System.Net.WebClient
                          $wc.DownloadFile($url, $destination)
                      }
                      "BitsTransfer" {
                          Start-BitsTransfer -Source $url -Destination $destination -ErrorAction Stop
                      }
                  }
                  MyWriteVerbose "Method $method attempt $attempt succeeded for $url"
                  $success = $true
                  break
             } catch {
                  MyWriteVerbose "Method $method attempt $attempt failed: $_"
             }
         }
         if ($success) {
              return $true
         }
    }
    return $false
}

# --- Function: Get-ConfigFile ---
# Downloads the configuration file from the provided URL to the destination path.
function Get-ConfigFile {
    param(
        [string]$destPath,
        [string]$DownloadURL
    )
    MyWriteHost "Downloading configuration file from $DownloadURL"
    if (-not (Download-File -url $DownloadURL -destination $destPath)) {
        MyWriteError "Failed to download configuration file after all methods and retries."
        Remove-Item $tempDir -Recurse -Force
        exit 1
    }
    MyWriteVerbose "Downloaded configuration file to: $destPath"
    MyWriteHost "Configuration file downloaded."
}

# --- Define URLs for Downloads ---
$exeURL           = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
$configURL        = "https://raw.githubusercontent.com/DTLegit/Windows-OOSU10-Auto-Script/refs/heads/main/OOSU10.cfg"
$defaultConfigURL = "https://raw.githubusercontent.com/DTLegit/Windows-OOSU10-Auto-Script/refs/heads/main/OOSU10-Default.cfg"

# --- Save Original Progress Setting ---
$Initial_ProgressPreference = $ProgressPreference

MyWriteHost "OOSU10Auto is starting..."

# --- Create a Unique Temporary Folder ---
$tempDir = Join-Path $env:TEMP ("OOSU10_temp_" + [guid]::NewGuid().ToString())
try {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    MyWriteVerbose "Created temporary directory: $tempDir"
    MyWriteHost "Temporary directory created."
} catch {
    MyWriteError "Failed to create temporary directory: $_"
    exit 1
}

# --- Download the Executable Using Robust Download Methods ---
$exePath = Join-Path $tempDir "OOSU10.exe"
MyWriteHost "Downloading O&O ShutUp10 executable..."
if (-not (Download-File -url $exeURL -destination $exePath)) {
    MyWriteError "Failed to download O&O ShutUp10 executable after all methods and retries."
    Remove-Item $tempDir -Recurse -Force
    exit 1
}
MyWriteVerbose "Downloaded O&O ShutUp10 to: $exePath"
MyWriteHost "Executable downloaded."

# --- Main Action: Select Mode Based on the Switch Provided ---
if ($customize) {
    MyWriteHost "Launching O&O ShutUp10 in GUI mode..."
    try {
        Start-Process -FilePath $exePath -Wait -Verbose
    } catch {
        MyWriteError "Failed to start O&O ShutUp10: $_"
    }
} elseif ($recommended) {
    MyWriteHost "Applying recommended configuration..."
    $configPath = Join-Path $tempDir "OOSU_10-Recommended.cfg"
    Get-ConfigFile -destPath $configPath -DownloadURL $configURL
    try {
        Start-Process -FilePath $exePath -ArgumentList $configPath, '/quiet' -Wait -Verbose
    } catch {
        MyWriteError "Failed to apply recommended configuration: $_"
    }
} elseif ($default) {
    MyWriteHost "Applying default configuration..."
    $configPath = Join-Path $tempDir "OOSU_10-Default.cfg"
    Get-ConfigFile -destPath $configPath -DownloadURL $defaultConfigURL
    try {
        Start-Process -FilePath $exePath -ArgumentList $configPath, '/quiet' -Wait -Verbose
    } catch {
        MyWriteError "Failed to apply default configuration: $_"
    }
}

# --- Cleanup ---
$ProgressPreference = $Initial_ProgressPreference
MyWriteHost "Cleaning up temporary files..."
try {
    Remove-Item $tempDir -Recurse -Force
    MyWriteVerbose "Temporary directory removed."
    MyWriteHost "Cleanup complete."
} catch {
    MyWriteVerbose "Failed to remove temporary directory: $_"
}

MyWriteHost "Script completed."

} # End Invoke-WPFOOSUAuto
