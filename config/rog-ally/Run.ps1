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

# Import shared helper functions (used by tests too)
$helpersPath = Join-Path $PSScriptRoot "lib/helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}
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

function Initialize-WingetSources {
    <#
    .SYNOPSIS
        Ensures winget sources are healthy before any package operations.
        Resets, updates, and verifies sources. Reports source list to output.
    #>
    Write-Header "WINGET SOURCE INITIALIZATION"

    # Step 1: Reset sources to clean state
    Write-Status "Resetting winget sources..." "Info"
    $resetResult = winget source reset --force 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Source reset warning: $resetResult" "Warning"
    } else {
        Write-Status "Sources reset successfully" "Success"
    }

    # Step 2: Update sources
    Write-Status "Updating winget sources..." "Info"
    $updateResult = winget source update 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Status "Source update warning: $updateResult" "Warning"
    } else {
        Write-Status "Sources updated successfully" "Success"
    }

    # Step 3: List and verify sources
    Write-Status "Verifying winget sources..." "Info"
    $sourceList = winget source list 2>&1

    # Check if winget source exists
    $hasWingetSource = $sourceList -match "winget"
    $hasMsStoreSource = $sourceList -match "msstore"

    # If winget source missing, add it explicitly
    if (-not $hasWingetSource) {
        Write-Status "Winget source missing - adding explicitly..." "Warning"
        $addResult = winget source add --name winget --arg "https://cdn.winget.microsoft.com/cache" --type "Microsoft.PreIndexed.Package" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "Failed to add winget source: $addResult" "Error"
        } else {
            Write-Status "Winget source added successfully" "Success"
            $hasWingetSource = $true
        }
        # Refresh source list
        $sourceList = winget source list 2>&1
    }

    # Display source status
    Write-Host ""
    Write-Host "  Available Sources:" -ForegroundColor Cyan
    Write-Host "  ------------------" -ForegroundColor Cyan
    foreach ($line in $sourceList) {
        if ($line -match "^\s*\w") {
            Write-Host "  $line" -ForegroundColor White
        }
    }
    Write-Host ""

    # Report source availability
    if ($hasWingetSource) {
        Write-Status "Primary source (winget) available" "Success"
    } else {
        Write-Status "Primary source (winget) NOT available" "Error"
    }

    if ($hasMsStoreSource) {
        Write-Status "Fallback source (msstore) available" "Success"
    } else {
        Write-Status "Fallback source (msstore) NOT available" "Warning"
    }

    # Store source availability in script scope for Install-WingetPackage
    $Script:HasWingetSource = $hasWingetSource
    $Script:HasMsStoreSource = $hasMsStoreSource

    Write-Host ""
    return $hasWingetSource -or $hasMsStoreSource
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

function Ensure-YamlModule {
    <#
    .SYNOPSIS
        Ensures the powershell-yaml module is installed for proper YAML parsing.
    .DESCRIPTION
        For offline environments, pre-install the module:
        Install-Module -Name powershell-yaml -Scope CurrentUser
    #>
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Status "Installing powershell-yaml module..." "Info"
        try {
            # Check for network connectivity first
            $galleryHost = "www.powershellgallery.com"
            $canReachGallery = Test-Connection -ComputerName $galleryHost -Count 1 -Quiet -ErrorAction SilentlyContinue
            if (-not $canReachGallery) {
                Write-Status "Cannot reach PowerShell Gallery (offline or blocked)" "Warning"
                Write-Host ""
                Write-Host "  To use Bootible offline, pre-install the YAML module:" -ForegroundColor Yellow
                Write-Host "    Install-Module -Name powershell-yaml -Scope CurrentUser" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  Or on another machine, save it for transfer:" -ForegroundColor Yellow
                Write-Host "    Save-Module -Name powershell-yaml -Path C:\Modules" -ForegroundColor Cyan
                Write-Host ""
                return $false
            }

            Install-Module -Name powershell-yaml -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            Write-Status "powershell-yaml module installed" "Success"
        } catch {
            Write-Status "Failed to install powershell-yaml: $($_.Exception.Message)" "Error"
            Write-Host ""
            Write-Host "  Manual installation:" -ForegroundColor Yellow
            Write-Host "    Install-Module -Name powershell-yaml -Scope CurrentUser" -ForegroundColor Cyan
            Write-Host ""
            return $false
        }
    }

    try {
        Import-Module powershell-yaml -ErrorAction Stop
        return $true
    } catch {
        Write-Status "Failed to import powershell-yaml: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Import-YamlConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return @{}
    }

    $content = Get-Content $Path -Raw

    # Use powershell-yaml for proper YAML parsing
    try {
        $config = ConvertFrom-Yaml $content -ErrorAction Stop

        # ConvertFrom-Yaml returns OrderedDictionary, convert to hashtable for consistency
        if ($config -is [System.Collections.Specialized.OrderedDictionary]) {
            $config = Convert-OrderedDictToHashtable $config
        }

        return $config
    } catch {
        Write-Status "YAML parse error in ${Path}: $($_.Exception.Message)" "Error"
        throw "Failed to parse YAML config: $Path"
    }
}

# Note: Convert-OrderedDictToHashtable and Merge-Configs are imported from lib/helpers.ps1

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name,
        [switch]$Force
    )

    # Check if already installed first (even in DryRun)
    try {
        # Check both sources for existing installation
        $installed = winget list --id $PackageId --accept-source-agreements 2>$null
        if ($installed -match $PackageId) {
            Write-Status "$Name already installed - skipping" "Success"
            return $true
        }
    } catch {
        # winget list failed, continue with install attempt
    }

    if ($Script:DryRun) {
        # Validate package exists (check winget first, then msstore)
        Write-Host "    Validating $PackageId..." -ForegroundColor Gray -NoNewline

        $foundInWinget = $false
        $foundInMsStore = $false

        if ($Script:HasWingetSource) {
            $showResult = winget show --id $PackageId --source winget --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0 -and $showResult -match "Found") {
                $foundInWinget = $true
            }
        }

        if (-not $foundInWinget -and $Script:HasMsStoreSource) {
            $showResult = winget show --id $PackageId --source msstore --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0 -and $showResult -match "Found") {
                $foundInMsStore = $true
            }
        }

        if ($foundInWinget) {
            Write-Host " OK (winget)" -ForegroundColor Green
            Write-Status "[DRY RUN] Would install: $Name ($PackageId) from winget" "Info"
            return $true
        } elseif ($foundInMsStore) {
            Write-Host " OK (msstore)" -ForegroundColor Yellow
            Write-Status "[DRY RUN] Would install: $Name ($PackageId) from msstore (fallback)" "Info"
            return $true
        } else {
            Write-Host " NOT FOUND" -ForegroundColor Red
            Write-Status "[DRY RUN] Package not found in any source: $PackageId" "Warning"
            return $false
        }
    }

    Write-Status "Installing $Name..." "Info"

    # Try winget source first
    if ($Script:HasWingetSource) {
        Write-Host "    Trying winget source..." -ForegroundColor Gray
        $result = winget install --id $PackageId --source winget --architecture x64 --accept-source-agreements --accept-package-agreements --silent 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Status "$Name installed (winget)" "Success"
            return $true
        }

        # If x64 failed, try without architecture constraint
        if ($exitCode -eq -1978335138) {
            Write-Host "    x64 not available, trying any architecture..." -ForegroundColor Gray
            $result = winget install --id $PackageId --source winget --accept-source-agreements --accept-package-agreements --silent 2>&1
            $exitCode = $LASTEXITCODE
            if ($exitCode -eq 0) {
                Write-Status "$Name installed (winget)" "Success"
                return $true
            }
        }

        Write-Host "    Winget source failed (exit code $exitCode)" -ForegroundColor Yellow
    }

    # Fallback to msstore
    if ($Script:HasMsStoreSource) {
        Write-Host "    Falling back to msstore..." -ForegroundColor Yellow
        $result = winget install --id $PackageId --source msstore --accept-source-agreements --accept-package-agreements --silent 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Status "$Name installed (msstore fallback)" "Success"
            return $true
        }

        Write-Host "    msstore also failed (exit code $exitCode)" -ForegroundColor Red
    }

    # Both sources failed - show error details
    Write-Status "Failed to install $Name from all sources" "Warning"
    $errorLines = $result | Where-Object { $_ -match "error|fail|not found|applicable" } | Select-Object -First 3
    foreach ($line in $errorLines) {
        Write-Host "    $line" -ForegroundColor Yellow
    }
    return $false
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

# Initialize and verify winget sources
if (-not (Initialize-WingetSources)) {
    Write-Status "No package sources available - cannot continue" "Error"
    exit 1
}

# Ensure YAML module is available for config parsing
if (-not (Ensure-YamlModule)) {
    Write-Status "Cannot parse YAML configs without powershell-yaml module" "Error"
    exit 1
}
Write-Status "YAML parser ready" "Success"

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
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  - Restart your device to apply all changes"
    Write-Host "  - Configure Armoury Crate for performance profiles"
    Write-Host "  - Set up game streaming apps (Moonlight, Chiaki, etc.)"
    Write-Host "  - Check README for additional configuration"
    Write-Host ""
}
