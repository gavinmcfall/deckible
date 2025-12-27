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
    # Run directly from the web:
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex

    # Or with a private repo:
    $env:BOOTIBLE_PRIVATE = "https://github.com/USER/bootible-private.git"
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$BootibleDir = "$env:USERPROFILE\bootible"
$RepoUrl = "https://github.com/gavinmcfall/bootible.git"
$PrivateRepo = $env:BOOTIBLE_PRIVATE
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

function Install-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Status "Git already installed" "Success"
        return $true
    }

    Write-Status "Installing Git..." "Info"
    try {
        winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Status "Git installed" "Success"
        return $true
    } catch {
        Write-Status "Failed to install Git: $_" "Error"
        return $false
    }
}

function Clone-Bootible {
    if (Test-Path $BootibleDir) {
        Write-Status "Updating existing bootible..." "Info"
        Push-Location $BootibleDir
        git pull
        Pop-Location
    } else {
        Write-Status "Cloning bootible..." "Info"
        git clone $RepoUrl $BootibleDir
    }
    Write-Status "Bootible ready at $BootibleDir" "Success"
}

function Setup-Private {
    if ($PrivateRepo) {
        $privatePath = Join-Path $BootibleDir "private"
        Write-Status "Setting up private configuration..." "Info"

        if (Test-Path (Join-Path $privatePath ".git")) {
            Push-Location $privatePath
            git pull
            Pop-Location
        } else {
            if (Test-Path $privatePath) {
                Remove-Item -Recurse -Force $privatePath
            }
            git clone $PrivateRepo $privatePath
        }
        Write-Status "Private configuration linked" "Success"
    }
}

function Run-DeviceSetup {
    Write-Host ""
    Write-Status "Running $Device configuration..." "Info"
    Write-Host ""

    $devicePath = Join-Path $BootibleDir $Device

    switch ($Device) {
        "rogally" {
            Push-Location $devicePath
            & ".\Run.ps1"
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

    Clone-Bootible
    Write-Host ""

    Setup-Private
    Write-Host ""

    Run-DeviceSetup

    Write-Host ""
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
    Write-Host "To re-run or update:" -ForegroundColor Yellow
    Write-Host "  cd $BootibleDir"
    Write-Host "  git pull"
    Write-Host "  .\bootstrap.ps1"
    Write-Host ""
}

# Run
Main
