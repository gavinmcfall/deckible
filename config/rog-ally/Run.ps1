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
    - Your settings: ../../private/rog-ally/config.yml (overrides defaults)
    - Private files: ../../private/rog-ally/

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
$Script:BootibleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
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
        "Info" = "->"
        "Success" = "[OK]"
        "Warning" = "[!]"
        "Error" = "[X]"
    }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "=================================================================" -ForegroundColor Blue
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

    # Simple YAML parser for flat/nested configs with list support
    # Supports 2-space, 4-space, or tab indentation
    $config = @{}
    $content = Get-Content $Path -Raw
    $lines = $content -split "`n"
    $currentSection = $null
    $currentSubSection = $null
    $currentListKey = $null
    $currentListLevel = 0  # 1 = section level, 2 = subsection level

    foreach ($line in $lines) {
        # Skip comments and empty lines
        if ($line -match '^\s*#' -or $line -match '^\s*$' -or $line -match '^---') {
            continue
        }

        # Calculate indent level (normalize tabs to 2 spaces)
        $normalizedLine = $line -replace "`t", "  "
        $indent = 0
        if ($normalizedLine -match '^(\s*)') {
            $indent = $Matches[1].Length
        }

        # List item (starts with -)
        if ($normalizedLine -match '^\s*-\s*(.*)$') {
            $listValue = $Matches[1].Trim().Trim('"').Trim("'")

            # Convert string booleans
            if ($listValue -eq 'true') { $listValue = $true }
            elseif ($listValue -eq 'false') { $listValue = $false }

            # Skip empty list items
            if ($listValue -eq '') { continue }

            # Add to appropriate list based on where we are
            if ($currentListKey -and $currentListLevel -eq 2 -and $currentSection -and $currentSubSection) {
                $config[$currentSection][$currentSubSection] += @($listValue)
            }
            elseif ($currentListKey -and $currentListLevel -eq 1 -and $currentSection) {
                $config[$currentSection][$currentListKey] += @($listValue)
            }
            continue
        }

        # Top-level key with value (no indent)
        if ($indent -eq 0 -and $normalizedLine -match '^(\w+):\s*(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$key] = $value
            $currentSection = $null
            $currentSubSection = $null
            $currentListKey = $null
        }
        # Section header (no value after colon, no indent)
        elseif ($indent -eq 0 -and $normalizedLine -match '^(\w+):\s*$') {
            $currentSection = $Matches[1]
            $config[$currentSection] = @{}
            $currentSubSection = $null
            $currentListKey = $null
        }
        # Nested key-value (indent level 1: 2-4 spaces)
        elseif ($indent -ge 2 -and $indent -le 4 -and $normalizedLine -match '^\s+(\w+):\s*(.+)$' -and $currentSection -and -not $currentSubSection) {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$currentSection][$key] = $value
            $currentListKey = $null
        }
        # List key at section level (indent level 1, no value - starts a list)
        elseif ($indent -ge 2 -and $indent -le 4 -and $normalizedLine -match '^\s+(\w+):\s*$' -and $currentSection -and -not $currentSubSection) {
            $key = $Matches[1]
            # Could be a subsection or a list - we'll find out from next line
            # For now, initialize as empty array (lists) - will be converted to hashtable if needed
            $config[$currentSection][$key] = @()
            $currentListKey = $key
            $currentListLevel = 1
            $currentSubSection = $null
        }
        # Sub-section header or nested key (indent level 2: 4-6 spaces)
        elseif ($indent -ge 4 -and $indent -le 6 -and $normalizedLine -match '^\s+(\w+):\s*$' -and $currentSection) {
            # This is a subsection under the current section
            $currentSubSection = $Matches[1]
            # If parent was an empty array, convert to hashtable
            if ($currentListKey -and $config[$currentSection][$currentListKey] -is [array] -and $config[$currentSection][$currentListKey].Count -eq 0) {
                $config[$currentSection][$currentListKey] = @{}
            }
            if ($currentListKey) {
                $config[$currentSection][$currentListKey][$currentSubSection] = @()
                $currentListLevel = 2
            } else {
                $config[$currentSection][$currentSubSection] = @{}
            }
        }
        # Sub-nested key-value (indent level 2: 4-6 spaces)
        elseif ($indent -ge 4 -and $indent -le 6 -and $normalizedLine -match '^\s+(\w+):\s*(.+)$' -and $currentSection -and $currentSubSection) {
            $key = $Matches[1]
            $value = $Matches[2].Trim().Trim('"').Trim("'")

            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            $config[$currentSection][$currentSubSection][$key] = $value
            $currentListKey = $null
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

    # Check if already installed first (even in DryRun)
    try {
        $installed = winget list --id $PackageId --accept-source-agreements 2>$null
        if ($installed -match $PackageId) {
            Write-Status "$Name already installed - skipping" "Success"
            return $true
        }
    } catch {
        # winget list failed, continue with install attempt
    }

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install: $Name ($PackageId)" "Info"
        return $true
    }

    Write-Status "Installing $Name..." "Info"
    try {
        $result = winget install --id $PackageId --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "$Name installed" "Success"
            return $true
        } else {
            Write-Status "Failed to install $Name (exit code $LASTEXITCODE)" "Warning"
            return $false
        }
    } catch {
        Write-Status "Failed to install $Name : $_" "Error"
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host ""
Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "|                      Bootible                              |" -ForegroundColor White
Write-Host "|             ROG Ally X Configuration                       |" -ForegroundColor Gray
Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
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
# Priority: -ConfigFile > private repo > local ~/.config > defaults
$defaultConfig = Join-Path $Script:DeviceRoot "config.yml"
$privateConfig = Join-Path $Script:BootibleRoot "private\rog-ally\config.yml"
$localConfig = Join-Path $env:USERPROFILE ".config\bootible\rog-ally\config.yml"

if ($ConfigFile -and (Test-Path $ConfigFile)) {
    $Script:Config = Import-YamlConfig $ConfigFile
    Write-Status "Using config: $ConfigFile" "Info"
} else {
    # Load default config
    if (Test-Path $defaultConfig) {
        $Script:Config = Import-YamlConfig $defaultConfig
        Write-Status "Loaded default config" "Info"
    }

    # Merge local config if exists (~/.config/bootible/rog-ally/config.yml)
    if (Test-Path $localConfig) {
        $localSettings = Import-YamlConfig $localConfig
        $Script:Config = Merge-Configs $Script:Config $localSettings
        Write-Status "Merged local config: $localConfig" "Info"
    }

    # Merge private repo config if exists (takes priority over local)
    if (Test-Path $privateConfig) {
        $privateSettings = Import-YamlConfig $privateConfig
        $Script:Config = Merge-Configs $Script:Config $privateSettings
        Write-Status "Merged private config overrides" "Info"
    }
}

$Script:DryRun = $DryRun

# Create System Restore Point
# ---------------------------
# Creates a restore point before making changes (unless disabled or dry run)

if (Get-ConfigValue "create_restore_point" $true) {
    if (-not $Script:DryRun) {
        Write-Status "Creating System Restore Point..." "Info"
        try {
            # Enable System Restore on C: if not already enabled
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue

            # Create restore point
            Checkpoint-Computer -Description "Bootible Pre-Setup $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Status "Restore point created" "Success"
        } catch {
            if ($_.Exception.Message -match "1058") {
                Write-Status "System Restore service not running - skipping restore point" "Warning"
            } elseif ($_.Exception.Message -match "already been created") {
                Write-Status "Restore point already exists (limit: 1 per 24 hours)" "Info"
            } else {
                Write-Status "Could not create restore point: $($_.Exception.Message)" "Warning"
            }
        }
    } else {
        Write-Status "[DRY RUN] Would create System Restore Point" "Info"
    }
}

# Load and run modules
$modulesPath = Join-Path $Script:DeviceRoot "modules"

$moduleOrder = @(
    "base",
    "debloat",
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

# Gather system information for summary
function Get-NetworkSummary {
    try {
        # Get the default network adapter (the one with a default gateway)
        $defaultAdapter = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric |
            Select-Object -First 1

        if ($defaultAdapter) {
            $adapter = Get-NetAdapter -InterfaceIndex $defaultAdapter.InterfaceIndex -ErrorAction SilentlyContinue
            $ipConfig = Get-NetIPAddress -InterfaceIndex $defaultAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Select-Object -First 1
            $dhcpEnabled = (Get-NetIPInterface -InterfaceIndex $defaultAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).Dhcp -eq 'Enabled'

            return @{
                IPAddress = $ipConfig.IPAddress
                IPType = if ($dhcpEnabled) { "DHCP" } else { "Static" }
                MACAddress = $adapter.MacAddress
                Interface = $adapter.Name
            }
        }
    } catch {
        # Silently handle errors
    }

    return @{
        IPAddress = "Unknown"
        IPType = "Unknown"
        MACAddress = "Unknown"
        Interface = "Unknown"
    }
}

$networkInfo = Get-NetworkSummary

# Complete
Write-Host ""
if ($Script:DryRun) {
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "|                   DRY RUN COMPLETE                         |" -ForegroundColor White
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "No changes were made. Run without -DryRun to apply changes." -ForegroundColor Yellow
} else {
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
    Write-Host "|                   Setup Complete!                          |" -ForegroundColor White
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
}

Write-Host ""
Write-Host "System Information:" -ForegroundColor Cyan
Write-Host "  Hostname:    $env:COMPUTERNAME"
Write-Host "  IP Address:  $($networkInfo.IPAddress)"
Write-Host "  IP Type:     $($networkInfo.IPType)"
Write-Host "  MAC Address: $($networkInfo.MACAddress)"
Write-Host "  Interface:   $($networkInfo.Interface)"
Write-Host ""

if (-not $Script:DryRun) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Restart your device to apply all changes"
    Write-Host "  - Configure Armoury Crate for performance profiles"
    Write-Host "  - Set up game streaming apps (Moonlight, Chiaki, etc.)"
    Write-Host "  - Check README for additional configuration"
    Write-Host ""
}
