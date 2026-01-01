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

# AnyDesk
if (Get-ConfigValue "install_anydesk" $false) {
    Install-WingetPackage -PackageId "AnyDesk.AnyDesk" -Name "AnyDesk"
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
