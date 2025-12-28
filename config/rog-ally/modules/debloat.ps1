# Debloat Module - Windows Privacy & Performance Tweaks
# =====================================================
# Applies registry tweaks and system changes to debloat Windows.
# Based on Chris Titus Tech's WinUtil tweaks.
#
# WARNING: Some tweaks may affect Windows functionality.
# Review each option before enabling.

if (-not (Get-ConfigValue "install_debloat" $true)) {
    Write-Status "Debloat module disabled in config" "Info"
    return
}

# Helper function to set registry value
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would set: $Path\$Name = $Value" "Info"
        return
    }

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } catch {
        Write-Status "Failed to set $Path\$Name : $_" "Warning"
    }
}

# =============================================================================
# PRIVACY TWEAKS
# =============================================================================

# Disable Telemetry
if (Get-ConfigValue "disable_telemetry" $true) {
    Write-Status "Disabling Windows telemetry..." "Info"

    # Disable telemetry
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0

    # Disable diagnostic data
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "ShowedToastAtLevel" -Value 1

    # Disable feedback
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0

    Write-Status "Telemetry disabled" "Success"
}

# Disable Activity History
if (Get-ConfigValue "disable_activity_history" $true) {
    Write-Status "Disabling activity history..." "Info"

    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0

    Write-Status "Activity history disabled" "Success"
}

# Disable Location Tracking
if (Get-ConfigValue "disable_location_tracking" $true) {
    Write-Status "Disabling location tracking..." "Info"

    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1

    Write-Status "Location tracking disabled" "Success"
}

# Disable Microsoft Copilot
if (Get-ConfigValue "disable_copilot" $true) {
    Write-Status "Disabling Microsoft Copilot..." "Info"

    Set-RegistryValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1

    Write-Status "Microsoft Copilot disabled" "Success"
}

# =============================================================================
# UI TWEAKS
# =============================================================================

# Classic Right-Click Menu (Windows 11)
if (Get-ConfigValue "classic_right_click_menu" $true) {
    Write-Status "Enabling classic right-click menu..." "Info"

    Set-RegistryValue -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(Default)" -Value "" -Type "String"

    Write-Status "Classic right-click menu enabled (restart Explorer to apply)" "Success"
}

# Disable Bing Search in Start Menu
if (Get-ConfigValue "disable_bing_search" $true) {
    Write-Status "Disabling Bing search in Start Menu..." "Info"

    Set-RegistryValue -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0

    Write-Status "Bing search disabled" "Success"
}

# Show File Extensions
if (Get-ConfigValue "show_file_extensions" $true) {
    Write-Status "Enabling file extension visibility..." "Info"

    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

    Write-Status "File extensions visible" "Success"
}

# Show Hidden Files
if (Get-ConfigValue "show_hidden_files" $false) {
    Write-Status "Enabling hidden file visibility..." "Info"

    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1

    Write-Status "Hidden files visible" "Success"
}

# =============================================================================
# EDGE TWEAKS
# =============================================================================

# Debloat Edge
if (Get-ConfigValue "debloat_edge" $true) {
    Write-Status "Debloating Microsoft Edge..." "Info"

    # Disable Edge telemetry
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "PersonalizationReportingEnabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "MetricsReportingEnabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SendSiteInfoToImproveServices" -Value 0

    # Disable Edge shopping features
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "EdgeShoppingAssistantEnabled" -Value 0

    # Disable Edge sidebar
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Value 0

    # Disable Edge first run experience
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HideFirstRunExperience" -Value 1

    Write-Status "Edge debloated" "Success"
}

# Disable Edge
if (Get-ConfigValue "disable_edge" $true) {
    Write-Status "Disabling Microsoft Edge..." "Info"

    # Prevent Edge from running in background
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "StartupBoostEnabled" -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "BackgroundModeEnabled" -Value 0

    # Disable Edge as default PDF reader
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "AlwaysOpenPdfExternally" -Value 1

    Write-Status "Edge disabled (may require restart)" "Success"
}

# =============================================================================
# NETWORK TWEAKS
# =============================================================================

# Prefer IPv4 over IPv6
if (Get-ConfigValue "prefer_ipv4" $true) {
    Write-Status "Setting IPv4 preference over IPv6..." "Info"

    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 32

    Write-Status "IPv4 preferred over IPv6" "Success"
}

# Disable Teredo
if (Get-ConfigValue "disable_teredo" $true) {
    Write-Status "Disabling Teredo tunneling..." "Info"

    if (-not $Script:DryRun) {
        try {
            netsh interface teredo set state disabled | Out-Null
            Write-Status "Teredo disabled" "Success"
        } catch {
            Write-Status "Failed to disable Teredo: $_" "Warning"
        }
    } else {
        Write-Status "[DRY RUN] Would disable Teredo" "Info"
    }
}

# =============================================================================
# PERFORMANCE TWEAKS
# =============================================================================

# Disable Fullscreen Optimizations
if (Get-ConfigValue "disable_fullscreen_optimizations" $true) {
    Write-Status "Disabling fullscreen optimizations..." "Info"

    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1
    Set-RegistryValue -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2

    Write-Status "Fullscreen optimizations disabled" "Success"
}

# Set Services to Manual
if (Get-ConfigValue "set_services_manual" $true) {
    Write-Status "Setting non-essential services to manual..." "Info"

    $servicesToManual = @(
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice",    # WAP Push Message Routing Service
        "MapsBroker",          # Downloaded Maps Manager
        "lfsvc",               # Geolocation Service
        "SharedAccess",        # Internet Connection Sharing
        "RemoteRegistry",      # Remote Registry
        "WMPNetworkSvc"        # Windows Media Player Network Sharing
    )

    if (-not $Script:DryRun) {
        foreach ($service in $servicesToManual) {
            try {
                $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
                if ($svc) {
                    Set-Service -Name $service -StartupType Manual -ErrorAction SilentlyContinue
                }
            } catch {
                # Silently ignore service errors
            }
        }
        Write-Status "Non-essential services set to manual" "Success"
    } else {
        Write-Status "[DRY RUN] Would set services to manual: $($servicesToManual -join ', ')" "Info"
    }
}

# =============================================================================
# POWERSHELL TWEAKS
# =============================================================================

# Make PowerShell 7 the default terminal
if (Get-ConfigValue "powershell7_default_terminal" $true) {
    # Check if PowerShell 7 is installed
    $ps7Path = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    if (Test-Path $ps7Path) {
        Write-Status "Setting PowerShell 7 as default terminal..." "Info"

        # Set Windows Terminal default profile to PowerShell 7
        Set-RegistryValue -Path "HKCU:\Console\%%Startup" -Name "DelegationConsole" -Value "{574e775e-4f2a-5b96-ac1e-a2962a402336}" -Type "String"
        Set-RegistryValue -Path "HKCU:\Console\%%Startup" -Name "DelegationTerminal" -Value "{574e775e-4f2a-5b96-ac1e-a2962a402336}" -Type "String"

        Write-Status "PowerShell 7 set as default terminal" "Success"
    } else {
        Write-Status "PowerShell 7 not installed - skipping default terminal setting" "Warning"
    }
}

# Disable PowerShell 7 Telemetry
if (Get-ConfigValue "disable_powershell7_telemetry" $true) {
    Write-Status "Disabling PowerShell 7 telemetry..." "Info"

    # Set environment variable to disable PS7 telemetry
    if (-not $Script:DryRun) {
        [Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", "Machine")
    }

    Write-Status "PowerShell 7 telemetry disabled" "Success"
}

Write-Status "Debloat module complete" "Success"
