# Base Module - Prerequisites and Setup
# =====================================
# This module sets up the foundation for everything else:
# - Configures hostname and static IP (if specified)
# - Verifies winget is working
# - Updates winget sources
# - Installs essential utilities
#
# Windows Note:
# Unlike SteamOS, Windows doesn't have an immutable filesystem.
# We use winget for package management - it's built into Windows 11
# and handles updates automatically.

# =============================================================================
# HOSTNAME CONFIGURATION
# =============================================================================
$desiredHostname = Get-ConfigValue "hostname" ""
if ($desiredHostname -and $desiredHostname -ne "") {
    $currentHostname = $env:COMPUTERNAME
    if ($currentHostname -ne $desiredHostname) {
        Write-Status "Setting hostname: $currentHostname -> $desiredHostname" "Info"
        try {
            Rename-Computer -NewName $desiredHostname -Force -ErrorAction Stop
            Write-Status "Hostname changed to '$desiredHostname' (restart required)" "Success"
            $Script:RequiresRestart = $true
        } catch {
            Write-Status "Failed to set hostname: $_" "Error"
        }
    } else {
        Write-Status "Hostname already set to '$desiredHostname'" "Success"
    }
}

# =============================================================================
# STATIC IP CONFIGURATION
# =============================================================================
$staticIpConfig = Get-ConfigValue "static_ip" @{}
$staticIpEnabled = $staticIpConfig.enabled -eq $true

if ($staticIpEnabled) {
    $adapter = $staticIpConfig.adapter
    $address = $staticIpConfig.address
    $prefixLength = $staticIpConfig.prefix_length
    $gateway = $staticIpConfig.gateway
    $dnsServers = $staticIpConfig.dns | Where-Object { $_ -and $_ -ne "" }

    if ($adapter -and $address -and $gateway) {
        Write-Status "Configuring static IP on '$adapter'..." "Info"
        try {
            # Get the network adapter
            $netAdapter = Get-NetAdapter -Name $adapter -ErrorAction Stop
            $interfaceIndex = $netAdapter.ifIndex

            # Check if already configured correctly
            $currentIP = Get-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($currentIP.IPAddress -eq $address) {
                Write-Status "Static IP already configured: $address" "Success"
            } else {
                # Remove existing IP configuration
                $netAdapter | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
                $netAdapter | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

                # Set static IP
                $null = $netAdapter | New-NetIPAddress -IPAddress $address -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
                Write-Status "Static IP set: $address/$prefixLength (gateway: $gateway)" "Success"
            }

            # Set DNS servers
            if ($dnsServers -and $dnsServers.Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceAlias $adapter -ServerAddresses $dnsServers -ErrorAction Stop
                Write-Status "DNS servers set: $($dnsServers -join ', ')" "Success"
            }
        } catch {
            Write-Status "Failed to configure static IP: $_" "Error"
            Write-Status "Attempting to restore DHCP..." "Warning"
            try {
                # Restore DHCP if static IP failed
                Set-NetIPInterface -InterfaceAlias $adapter -Dhcp Enabled -ErrorAction SilentlyContinue
                Set-DnsClientServerAddress -InterfaceAlias $adapter -ResetServerAddresses -ErrorAction SilentlyContinue
                Write-Status "DHCP restored on '$adapter'" "Info"
            } catch {
                Write-Status "Could not restore DHCP: $_" "Error"
            }
        }
    } else {
        Write-Status "Static IP enabled but missing required values (adapter, address, gateway)" "Warning"
    }
}

# =============================================================================
# WINGET SETUP
# =============================================================================

# Verify winget sources are up to date
Write-Status "Updating winget sources..." "Info"
try {
    winget source update
    Write-Status "Winget sources updated" "Success"
} catch {
    Write-Status "Could not update winget sources (continuing anyway)" "Warning"
}

# Install essential utilities
$essentials = @(
    @{ Id = "7zip.7zip"; Name = "7-Zip"; Condition = (Get-ConfigValue "install_7zip" $true) },
    @{ Id = "voidtools.Everything"; Name = "Everything Search"; Condition = (Get-ConfigValue "install_everything" $true) },
    @{ Id = "Microsoft.PowerToys"; Name = "PowerToys"; Condition = (Get-ConfigValue "install_powertoys" $true) }
)

foreach ($app in $essentials) {
    if ($app.Condition) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Ensure Windows Terminal is available (usually pre-installed on Win11)
$terminalInstalled = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if (-not $terminalInstalled) {
    Write-Status "Installing Windows Terminal..." "Info"
    try {
        winget install --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent
        Write-Status "Windows Terminal installed" "Success"
    } catch {
        Write-Status "Could not install Windows Terminal" "Warning"
    }
}

# Check for Windows updates (informational only)
Write-Status "Checking Windows Update status..." "Info"
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates.Count
    if ($pendingUpdates -gt 0) {
        Write-Status "$pendingUpdates Windows update(s) pending - consider updating" "Warning"
    } else {
        Write-Status "Windows is up to date" "Success"
    }
} catch {
    Write-Status "Could not check Windows Update status" "Warning"
}

Write-Status "Base setup complete" "Success"
