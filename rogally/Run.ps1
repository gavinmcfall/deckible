#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Bootible - ROG Ally X PowerShell Configuration
    ===============================================
    Automates the setup and configuration of an ASUS ROG Ally X running Windows.

.DESCRIPTION
    This script configures a ROG Ally X with gaming-focused software, utilities,
    and optimizations. It uses winget for package management and supports a
    private overlay for personal configurations.

.USAGE
    .\Run.ps1                    # Run with default config
    .\Run.ps1 -Tags base,apps    # Run specific modules only
    .\Run.ps1 -DryRun            # Preview changes without applying

.CONFIGURATION
    - Defaults: config.yml
    - Your settings: ../private/rogally/config.yml (overrides defaults)
    - Private files: ../private/rogally/files/

.NOTES
    Requires Windows 10/11 and PowerShell 5.1+
    Run as Administrator
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "",
    [string[]]$Tags = @(),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$Script:BootibleRoot = Split-Path -Parent $PSScriptRoot
$Script:DeviceRoot = $PSScriptRoot
$Script:Config = @{}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    $symbols = @{
        "Info" = "→"
        "Success" = "✓"
        "Warning" = "!"
        "Error" = "✗"
    }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Blue
    Write-Host ""
}

function Test-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-Winget {
    Write-Status "Installing winget..." "Info"

    # Try to install via Microsoft Store
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        Write-Status "Winget installed via Microsoft Store" "Success"
        return $true
    } catch {
        Write-Status "Could not install winget automatically. Please install from Microsoft Store." "Error"
        return $false
    }
}

function Get-ConfigValue {
    param(
        [string]$Key,
        $Default = $null
    )

    $keys = $Key -split '\.'
    $value = $Script:Config

    foreach ($k in $keys) {
        if ($value -is [hashtable] -and $value.ContainsKey($k)) {
            $value = $value[$k]
        } else {
            return $Default
        }
    }

    return $value
}

function Import-YamlConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{}
    }

    # Simple YAML parser for flat/nested configs
    $config = @{}
    $content = Get-Content $Path -Raw
    $lines = $content -split "`n"
    $currentSection = $null
    $currentSubSection = $null

    foreach ($line in $lines) {
        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -match '^\s*$' -or $line -match '^---') {
            continue
        }

        # Top-level key with value
        if ($line -match '^(\w+):\s*(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            # Convert string booleans
            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$key] = $value
            $currentSection = $null
            $currentSubSection = $null
        }
        # Section header (no value after colon)
        elseif ($line -match '^(\w+):\s*$') {
            $currentSection = $Matches[1]
            $config[$currentSection] = @{}
            $currentSubSection = $null
        }
        # Nested key-value (2-space indent)
        elseif ($line -match '^  (\w+):\s*(.+)$' -and $currentSection) {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$currentSection][$key] = $value
        }
        # Sub-section header (2-space indent, no value)
        elseif ($line -match '^  (\w+):\s*$' -and $currentSection) {
            $currentSubSection = $Matches[1]
            $config[$currentSection][$currentSubSection] = @{}
        }
        # Sub-nested key-value (4-space indent)
        elseif ($line -match '^    (\w+):\s*(.+)$' -and $currentSection -and $currentSubSection) {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$currentSection][$currentSubSection][$key] = $value
        }
    }

    return $config
}

function Merge-Configs {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = $Base.Clone()

    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-Configs $result[$key] $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name,
        [switch]$Force
    )

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install: $Name ($PackageId)" "Info"
        return $true
    }

    # Check if already installed
    $installed = winget list --id $PackageId 2>$null
    if ($installed -match $PackageId) {
        Write-Status "$Name already installed" "Success"
        return $true
    }

    Write-Status "Installing $Name..." "Info"
    try {
        winget install --id $PackageId --accept-source-agreements --accept-package-agreements --silent
        Write-Status "$Name installed" "Success"
        return $true
    } catch {
        Write-Status "Failed to install $Name : $_" "Error"
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      Bootible                              ║" -ForegroundColor White
Write-Host "║             ROG Ally X Configuration                       ║" -ForegroundColor Gray
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verify running on Windows
if ($env:OS -ne "Windows_NT") {
    Write-Status "This script is designed for Windows" "Error"
    exit 1
}

# Verify admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Status "Please run as Administrator" "Error"
    exit 1
}

Write-Status "Running as Administrator" "Success"

# Check/install winget
if (-not (Test-WingetInstalled)) {
    Write-Status "Winget not found" "Warning"
    if (-not (Install-Winget)) {
        exit 1
    }
}
Write-Status "Winget available" "Success"

# Load configuration
$defaultConfig = Join-Path $Script:DeviceRoot "config.yml"
$privateConfig = Join-Path $Script:BootibleRoot "private\rogally\config.yml"

if ($ConfigFile -and (Test-Path $ConfigFile)) {
    $Script:Config = Import-YamlConfig $ConfigFile
    Write-Status "Using config: $ConfigFile" "Info"
} else {
    # Load default config
    if (Test-Path $defaultConfig) {
        $Script:Config = Import-YamlConfig $defaultConfig
        Write-Status "Loaded default config" "Info"
    }

    # Merge private config if exists
    if (Test-Path $privateConfig) {
        $privateSettings = Import-YamlConfig $privateConfig
        $Script:Config = Merge-Configs $Script:Config $privateSettings
        Write-Status "Merged private config overrides" "Info"
    }
}

$Script:DryRun = $DryRun

# Load and run modules
$modulesPath = Join-Path $Script:DeviceRoot "modules"

$moduleOrder = @(
    "base",
    "apps",
    "gaming",
    "streaming",
    "remote_access",
    "emulation",
    "optimization",
    "rog_ally"
)

foreach ($moduleName in $moduleOrder) {
    $modulePath = Join-Path $modulesPath "$moduleName.ps1"

    # Skip if tags specified and this module not in tags
    if ($Tags.Count -gt 0 -and $moduleName -notin $Tags) {
        continue
    }

    if (Test-Path $modulePath) {
        Write-Header $moduleName.ToUpper()
        . $modulePath
    }
}

# Complete
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                   Setup Complete!                          ║" -ForegroundColor White
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  • Restart your device to apply all changes"
Write-Host "  • Configure Armoury Crate for performance profiles"
Write-Host "  • Set up game streaming apps (Moonlight, Chiaki, etc.)"
Write-Host "  • Check README for additional configuration"
Write-Host ""
