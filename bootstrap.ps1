<#
.SYNOPSIS
    Bootible - Universal Bootstrap Script (Windows)
    ================================================
    Detects your device and runs the appropriate configuration.

.DESCRIPTION
    Supported Devices:
    - ROG Ally X (Windows 11)
    - Other Windows gaming handhelds (Legion Go, etc.)

.USAGE
    # Preview what will happen (dry run - default):
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex

    # Run for real after reviewing:
    bootible

    # Or skip preview and run immediately:
    $env:BOOTIBLE_RUN = "1"
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$BootibleDir = "$env:USERPROFILE\bootible"
$RepoUrl = "https://github.com/gavinmcfall/bootible.git"
$PrivateRepo = $env:BOOTIBLE_PRIVATE
$DryRun = $env:BOOTIBLE_RUN -ne "1"  # Dry run by default, set BOOTIBLE_RUN=1 to apply
$Device = ""

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{ "Info" = "Cyan"; "Success" = "Green"; "Warning" = "Yellow"; "Error" = "Red" }
    $symbols = @{ "Info" = "->"; "Success" = "[OK]"; "Warning" = "[!]"; "Error" = "[X]" }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Sync-SystemTime {
    # Sync system time to fix certificate validation errors on fresh installs
    Write-Status "Syncing system time..." "Info"
    try {
        $svc = Get-Service w32time -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Write-Host "    Starting time service..." -ForegroundColor Gray
            Start-Service w32time -ErrorAction Stop
        }
        $result = w32tm /resync /force 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    Time sync warning: $result" -ForegroundColor Yellow
        } else {
            Write-Status "System time synced" "Success"
        }
    } catch {
        Write-Status "Time sync failed: $_ (continuing anyway)" "Warning"
    }
}

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Detect-Device {
    Write-Status "Detecting device..." "Info"

    # Check manufacturer and product name
    $system = Get-WmiObject -Class Win32_ComputerSystem
    $manufacturer = $system.Manufacturer
    $product = $system.Model

    # ROG Ally detection
    if ($manufacturer -like "*ASUS*" -and $product -like "*ROG Ally*") {
        $script:Device = "rogally"
        Write-Status "Detected: ASUS ROG Ally X" "Success"
        return
    }

    # Lenovo Legion Go detection
    if ($manufacturer -like "*Lenovo*" -and $product -like "*Legion Go*") {
        $script:Device = "rogally"  # Use ROG Ally config as base
        Write-Status "Detected: Lenovo Legion Go (using ROG Ally config)" "Success"
        return
    }

    # MSI Claw detection
    if ($manufacturer -like "*MSI*" -and $product -like "*Claw*") {
        $script:Device = "rogally"
        Write-Status "Detected: MSI Claw (using ROG Ally config)" "Success"
        return
    }

    # Default to rogally for any Windows device
    $script:Device = "rogally"
    Write-Status "Windows device detected - using ROG Ally configuration" "Info"
}

$script:GitExe = "git"  # Will be updated to full path if needed

function Find-GitExe {
    # Check if git is already in PATH
    $existing = Get-Command git -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing.Source
    }

    # Search common install locations
    $searchPaths = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\bin\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Git\cmd\git.exe",
        "$env:USERPROFILE\scoop\apps\git\current\bin\git.exe",
        "C:\Git\cmd\git.exe",
        "C:\Program Files\Git\cmd\git.exe"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    # Last resort: search Program Files recursively (slow but thorough)
    $found = Get-ChildItem -Path "$env:ProgramFiles" -Recurse -Filter "git.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return $found.FullName
    }

    return $null
}

function Install-Git {
    $gitPath = Find-GitExe
    if ($gitPath) {
        $script:GitExe = $gitPath
        Write-Status "Git found at $gitPath" "Success"
        return $true
    }

    Write-Status "Installing Git (this may take a minute)..." "Info"

    # Try winget first
    Write-Host "    Trying winget..." -ForegroundColor Gray
    try {
        $result = winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1
        if ($result) {
            $result -split "`n" | ForEach-Object {
                if ($_ -match "error|fail|certificate" ) {
                    Write-Host "    $_" -ForegroundColor Red
                } elseif ($_ -match "warning") {
                    Write-Host "    $_" -ForegroundColor Yellow
                } else {
                    Write-Host "    $_" -ForegroundColor Gray
                }
            }
        }
        Start-Sleep -Seconds 3

        $gitPath = Find-GitExe
        if ($gitPath) {
            $script:GitExe = $gitPath
            Write-Status "Git installed via winget at $gitPath" "Success"
            return $true
        }
        Write-Host "    winget completed but git not found, trying direct download..." -ForegroundColor Yellow
    } catch {
        Write-Status "winget failed: $_" "Warning"
        Write-Host "    Trying direct download instead..." -ForegroundColor Yellow
    }

    # Fallback: Download from git-scm.com
    Write-Status "Downloading Git from git-scm.com (~65MB)..." "Info"
    try {
        $gitInstaller = "$env:TEMP\Git-installer.exe"
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"

        # Show download progress
        $ProgressPreference = 'Continue'
        Write-Host "    Downloading..." -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($gitUrl, $gitInstaller)
        Write-Status "Download complete" "Success"

        if (-not (Test-Path $gitInstaller)) {
            throw "Download failed - file not found"
        }

        Write-Status "Running Git installer..." "Info"
        Write-Host "    (installer window may appear briefly)" -ForegroundColor Gray
        $process = Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/SP-" -PassThru

        # Wait with timeout
        $timeout = 120
        $timer = 0
        while (-not $process.HasExited -and $timer -lt $timeout) {
            Start-Sleep -Seconds 5
            $timer += 5
            Write-Host "    Installing... ($timer sec)" -ForegroundColor Gray
        }

        if (-not $process.HasExited) {
            Write-Status "Installer taking too long, continuing..." "Warning"
            $process.Kill()
        }

        # Clean up
        Remove-Item $gitInstaller -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        $gitPath = Find-GitExe
        if ($gitPath) {
            $script:GitExe = $gitPath
            Write-Status "Git installed at $gitPath" "Success"
            return $true
        }
    } catch {
        Write-Status "Direct download failed: $_" "Error"
    }

    Write-Status "Could not install Git automatically" "Error"
    Write-Status "Please install Git manually from https://git-scm.com then re-run" "Warning"
    return $false
}

function Run-GitWithProgress {
    param(
        [string]$Description,
        [string[]]$Arguments,
        [string]$WorkingDir = $null,
        [int]$TimeoutSeconds = 60
    )

    Write-Status "$Description..." "Info"
    Write-Host "    Command: git $($Arguments -join ' ')" -ForegroundColor DarkGray

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:GitExe
    $psi.Arguments = $Arguments -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($WorkingDir) {
        $psi.WorkingDirectory = $WorkingDir
        Write-Host "    Directory: $WorkingDir" -ForegroundColor DarkGray
    }

    try {
        $process = [System.Diagnostics.Process]::Start($psi)
    } catch {
        Write-Status "Failed to start git: $_" "Error"
        throw $_
    }

    $timer = 0
    while (-not $process.HasExited -and $timer -lt $TimeoutSeconds) {
        Start-Sleep -Seconds 2
        $timer += 2
        Write-Host "    Working... ($timer sec)" -ForegroundColor Gray
    }

    if (-not $process.HasExited) {
        Write-Status "Operation timed out after $TimeoutSeconds seconds" "Error"
        $process.Kill()
        throw "Operation timed out after $TimeoutSeconds seconds"
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    if ($process.ExitCode -ne 0) {
        Write-Status "Git failed with exit code $($process.ExitCode)" "Error"
        if ($stderr) {
            Write-Host "    Error output:" -ForegroundColor Red
            $stderr -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        if ($stdout) {
            Write-Host "    Standard output:" -ForegroundColor Yellow
            $stdout -split "`n" | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
        }
        throw "Git command failed (exit code $($process.ExitCode))"
    }

    # Show any warnings from stderr (git often writes progress to stderr)
    if ($stderr -and $stderr -notmatch "^(Cloning|Receiving|Resolving|remote:|Updating)") {
        Write-Host "    $stderr" -ForegroundColor DarkYellow
    }

    return $true
}

function Clone-Bootible {
    try {
        if (Test-Path $BootibleDir) {
            Run-GitWithProgress -Description "Updating bootible repo" -Arguments @("pull", "--progress") -WorkingDir $BootibleDir
        } else {
            Run-GitWithProgress -Description "Cloning bootible repo" -Arguments @("clone", "--progress", $RepoUrl, $BootibleDir)
        }
        Write-Status "Bootible ready at $BootibleDir" "Success"
        return $true
    } catch {
        Write-Status "Failed to clone/update bootible: $_" "Error"
        return $false
    }
}

function Setup-Private {
    # Check if already set via environment variable
    if (-not $PrivateRepo) {
        Write-Host ""
        $response = Read-Host "Do you have a private config repo? (y/N)"
        if ($response -match "^[Yy]") {
            Write-Host "Enter GitHub repo (e.g., " -NoNewline
            Write-Host "username/repo" -ForegroundColor Yellow -NoNewline
            Write-Host "): " -NoNewline
            $repoPath = Read-Host
            if ($repoPath) {
                $script:PrivateRepo = "https://github.com/$repoPath.git"
            }
        }
    }

    if ($PrivateRepo) {
        $privatePath = Join-Path $BootibleDir "private"
        Write-Host ""
        Write-Status "Repo: $PrivateRepo" "Info"

        try {
            if (Test-Path (Join-Path $privatePath ".git")) {
                Run-GitWithProgress -Description "Updating private config" -Arguments @("pull", "--progress") -WorkingDir $privatePath
            } else {
                if (Test-Path $privatePath) {
                    Write-Host "    Removing old private folder..." -ForegroundColor Gray
                    Remove-Item -Recurse -Force $privatePath
                }
                Run-GitWithProgress -Description "Cloning private config (may prompt for login)" -Arguments @("clone", "--progress", $PrivateRepo, $privatePath) -TimeoutSeconds 120
            }
            Write-Status "Private configuration linked" "Success"
        } catch {
            Write-Status "Failed to setup private repo: $_" "Warning"
            Write-Status "Continuing without private config..." "Info"
        }
    }
}

function Install-BootibleCommand {
    Write-Status "Installing 'bootible' command..." "Info"

    $cmdContent = @"
@echo off
powershell -ExecutionPolicy Bypass -Command "& '$BootibleDir\$Device\Run.ps1' %*"
"@

    # Try WindowsApps first (already in PATH)
    $cmdPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\bootible.cmd"
    try {
        Set-Content -Path $cmdPath -Value $cmdContent -Force -ErrorAction Stop
        Write-Status "Installed 'bootible' command" "Success"
        return
    } catch {
        Write-Host "    WindowsApps not writable, trying fallback..." -ForegroundColor Gray
    }

    # Fallback: put in bootible directory and add to PATH
    $cmdPath = Join-Path $BootibleDir "bootible.cmd"
    try {
        Set-Content -Path $cmdPath -Value $cmdContent -Force
        Write-Host "    Adding to PATH..." -ForegroundColor Gray
        # Add to user PATH if not already there
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$BootibleDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$BootibleDir;$userPath", "User")
            $env:Path = "$BootibleDir;$env:Path"
        }
        Write-Status "Installed 'bootible' command (added $BootibleDir to PATH)" "Success"
    } catch {
        Write-Status "Could not install bootible command: $_" "Warning"
        Write-Status "You can run manually: $BootibleDir\$Device\Run.ps1" "Info"
    }
}

function Run-DeviceSetup {
    Write-Host ""
    if ($DryRun) {
        Write-Status "Running $Device configuration (DRY RUN)..." "Warning"
    } else {
        Write-Status "Running $Device configuration..." "Info"
    }
    Write-Host ""

    $devicePath = Join-Path $BootibleDir $Device
    $runScript = Join-Path $devicePath "Run.ps1"

    switch ($Device) {
        "rogally" {
            # Use -ExecutionPolicy Bypass to avoid execution policy errors
            if ($DryRun) {
                powershell -ExecutionPolicy Bypass -File $runScript -DryRun
            } else {
                powershell -ExecutionPolicy Bypass -File $runScript
            }
        }
        default {
            Write-Status "Unknown device type: $Device" "Error"
            exit 1
        }
    }
}

function Main {
    Write-Host ""
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                      Bootible                              |" -ForegroundColor White
    Write-Host "|         Universal Gaming Device Configuration              |" -ForegroundColor Gray
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # Check admin
    if (-not (Test-Admin)) {
        Write-Status "Administrator privileges required" "Error"
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    Write-Status "Running as Administrator" "Success"

    # Sync time first (fixes certificate errors on fresh installs)
    Sync-SystemTime

    # Check winget
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Status "winget not found. Please install App Installer from Microsoft Store." "Error"
        return
    }
    Write-Status "winget available" "Success"

    Detect-Device
    Write-Host ""

    if (-not (Install-Git)) {
        return
    }
    Write-Host ""

    if (-not (Clone-Bootible)) {
        Write-Host ""
        Write-Host "Failed to clone bootible. Check your network connection." -ForegroundColor Red
        return
    }
    Write-Host ""

    # Verify Run.ps1 exists
    $runScript = Join-Path $BootibleDir "$Device\Run.ps1"
    if (-not (Test-Path $runScript)) {
        Write-Status "Run.ps1 not found at $runScript" "Error"
        return
    }

    Setup-Private
    Write-Host ""

    Install-BootibleCommand
    Write-Host ""

    Run-DeviceSetup

    Write-Host ""
    if ($DryRun) {
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host "|                  DRY RUN COMPLETE                          |" -ForegroundColor White
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Review the output above. When ready to apply changes:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  bootible" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
        Write-Host "|                   Setup Complete!                          |" -ForegroundColor White
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
        Write-Host ""
        Write-Host "Device: $Device" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow

        switch ($Device) {
            "rogally" {
                Write-Host "  • Restart your device to apply all changes"
                Write-Host "  • Configure Armoury Crate for performance profiles"
                Write-Host "  • Set up game streaming apps if installed"
            }
        }
        Write-Host ""
    }

    Write-Host "To re-run anytime:" -ForegroundColor Gray
    Write-Host "  bootible" -ForegroundColor Gray
    Write-Host ""
}

# Run
Main
