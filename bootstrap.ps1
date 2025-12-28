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
    $symbols = @{ "Info" = "→"; "Success" = "✓"; "Warning" = "!"; "Error" = "✗" }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
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
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
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

    Write-Status "Installing Git..." "Info"
    try {
        winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent

        # Give it a moment to finish
        Start-Sleep -Seconds 2

        # Find where it installed
        $gitPath = Find-GitExe
        if ($gitPath) {
            $script:GitExe = $gitPath
            Write-Status "Git installed at $gitPath" "Success"
            return $true
        } else {
            Write-Status "Git installed but cannot locate git.exe" "Warning"
            Write-Status "Please close PowerShell, reopen as Admin, and run:" "Warning"
            Write-Host ""
            Write-Host "  irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex" -ForegroundColor Yellow
            Write-Host ""
            return $false
        }
    } catch {
        Write-Status "Failed to install Git: $_" "Error"
        return $false
    }
}

function Clone-Bootible {
    try {
        if (Test-Path $BootibleDir) {
            Write-Status "Updating existing bootible..." "Info"
            Push-Location $BootibleDir
            & $script:GitExe pull 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git pull failed"
            }
            Pop-Location
        } else {
            Write-Status "Cloning bootible..." "Info"
            & $script:GitExe clone $RepoUrl $BootibleDir 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "git clone failed"
            }
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
        Write-Status "Setting up private configuration..." "Info"
        Write-Status "Repo: $PrivateRepo" "Info"

        try {
            if (Test-Path (Join-Path $privatePath ".git")) {
                Push-Location $privatePath
                & $script:GitExe pull 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "git pull failed"
                }
                Pop-Location
            } else {
                if (Test-Path $privatePath) {
                    Remove-Item -Recurse -Force $privatePath
                }
                & $script:GitExe clone $PrivateRepo $privatePath
                if ($LASTEXITCODE -ne 0) {
                    throw "git clone failed - check your credentials"
                }
            }
            Write-Status "Private configuration linked" "Success"
        } catch {
            Write-Status "Failed to setup private repo: $_" "Warning"
            Write-Status "Continuing without private config..." "Info"
        }
    }
}

function Install-BootibleCommand {
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
        # WindowsApps not writable, try bootible directory
    }

    # Fallback: put in bootible directory and add to PATH
    $cmdPath = Join-Path $BootibleDir "bootible.cmd"
    try {
        Set-Content -Path $cmdPath -Value $cmdContent -Force
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

    switch ($Device) {
        "rogally" {
            Push-Location $devicePath
            if ($DryRun) {
                & ".\Run.ps1" -DryRun
            } else {
                & ".\Run.ps1"
            }
            Pop-Location
        }
        default {
            Write-Status "Unknown device type: $Device" "Error"
            exit 1
        }
    }
}

function Main {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      Bootible                              ║" -ForegroundColor White
    Write-Host "║         Universal Gaming Device Configuration              ║" -ForegroundColor Gray
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║                  DRY RUN COMPLETE                          ║" -ForegroundColor White
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Review the output above. When ready to apply changes:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  bootible" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                   Setup Complete!                          ║" -ForegroundColor White
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
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
