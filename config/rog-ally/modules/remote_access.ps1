# Remote Access Module - VPN & Remote Desktop
# ============================================
# Access your ROG Ally remotely or connect to other devices.
#
# Tailscale Note:
# Tailscale creates a secure mesh VPN between your devices.
# Great for accessing your Ally from anywhere or connecting
# to your home network while traveling.

if (-not (Get-ConfigValue "install_remote_access" $false)) {
    Write-Status "Remote Access module disabled in config" "Info"
    return
}

# VPN
# ---

if (Get-ConfigValue "install_tailscale" $false) {
    Install-WingetPackage -PackageId "Tailscale.Tailscale" -Name "Tailscale"
    Write-Status "Tailscale: Run 'tailscale up' to connect after install" "Info"
}

# Remote Desktop
# --------------

# AnyDesk - use Chocolatey (more reliable than winget)
if (Get-ConfigValue "install_anydesk" $false) {
    # Check if already installed
    $anydeskInstalled = Test-Path "$env:ProgramFiles(x86)\AnyDesk\AnyDesk.exe"
    if (-not $anydeskInstalled) {
        $anydeskInstalled = Test-Path "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    }
    if (-not $anydeskInstalled) {
        $anydeskInstalled = Test-Path "$env:APPDATA\AnyDesk\AnyDesk.exe"
    }

    if ($anydeskInstalled) {
        Write-Status "AnyDesk already installed" "Success"
    } elseif ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install AnyDesk via Chocolatey" "Info"
    } else {
        $choco = Get-Command choco -ErrorAction SilentlyContinue
        if ($choco) {
            Write-Status "Installing AnyDesk via Chocolatey..." "Info"
            try {
                # Use --no-progress to prevent hanging, -r for reduced output
                $result = choco install anydesk -y --no-progress -r 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "AnyDesk installed" "Success"
                } else {
                    Write-Status "Chocolatey returned exit code $LASTEXITCODE" "Warning"
                }
            } catch {
                Write-Status "Chocolatey install failed: $_" "Warning"
            }
        } else {
            # Fallback to direct download if Chocolatey not available
            Write-Status "Chocolatey not available, trying direct download..." "Warning"
            Install-DirectDownload -Name "AnyDesk" -Url "https://download.anydesk.com/AnyDesk.exe" -InstallerArgs "--install `"$env:ProgramFiles\AnyDesk`" --silent"
        }
    }
}

if (Get-ConfigValue "install_rustdesk" $false) {
    Install-WingetPackage -PackageId "RustDesk.RustDesk" -Name "RustDesk"
    Write-Status "RustDesk: Open-source remote desktop, self-hostable" "Info"
}

# Windows Remote Desktop
# ----------------------
# Enable Windows built-in Remote Desktop (RDP)

$enableRdp = Get-ConfigValue "enable_rdp" $false
if ($enableRdp) {
    Write-Status "Enabling Windows Remote Desktop..." "Info"
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Status "Remote Desktop enabled" "Success"
    } catch {
        Write-Status "Could not enable Remote Desktop: $_" "Error"
    }
}

Write-Status "Remote Access setup complete" "Success"
