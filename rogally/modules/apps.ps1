# Apps Module - Desktop Applications
# ===================================
# Installs common desktop applications via winget.
# Configure which apps to install in config.yml
#
# Why winget?
# - Native to Windows 11
# - Handles updates automatically
# - Large package repository
# - Silent installation support

if (-not (Get-ConfigValue "install_apps" $true)) {
    Write-Status "Apps module disabled in config" "Info"
    return
}

# Communication Apps
# ------------------
$commApps = @(
    @{ Id = "Discord.Discord"; Name = "Discord"; Config = "install_discord" },
    @{ Id = "OpenWhisperSystems.Signal"; Name = "Signal"; Config = "install_signal" }
)

foreach ($app in $commApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Media Apps
# ----------
$mediaApps = @(
    @{ Id = "Spotify.Spotify"; Name = "Spotify"; Config = "install_spotify" },
    @{ Id = "VideoLAN.VLC"; Name = "VLC"; Config = "install_vlc" }
)

foreach ($app in $mediaApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Browsers
# --------
$browsers = @(
    @{ Id = "Mozilla.Firefox"; Name = "Firefox"; Config = "install_firefox" },
    @{ Id = "Google.Chrome"; Name = "Chrome"; Config = "install_chrome" },
    @{ Id = "Microsoft.Edge"; Name = "Edge"; Config = "install_edge" }
)

foreach ($app in $browsers) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Productivity
# ------------
$prodApps = @(
    @{ Id = "OBSProject.OBSStudio"; Name = "OBS Studio"; Config = "install_obs" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code"; Config = "install_vscode" }
)

foreach ($app in $prodApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Password Managers
# -----------------
$pwManager = Get-ConfigValue "password_manager" "none"

switch ($pwManager) {
    "1password" {
        Install-WingetPackage -PackageId "AgileBits.1Password" -Name "1Password"
    }
    "bitwarden" {
        Install-WingetPackage -PackageId "Bitwarden.Bitwarden" -Name "Bitwarden"
    }
    "keepassxc" {
        Install-WingetPackage -PackageId "KeePassXCTeam.KeePassXC" -Name "KeePassXC"
    }
}

Write-Status "Apps installation complete" "Success"
