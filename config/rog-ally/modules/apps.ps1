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

# =============================================================================
# UTILITIES
# =============================================================================

$utilityApps = @(
    @{ Id = "7zip.7zip"; Name = "7-Zip"; Config = "install_7zip" },
    @{ Id = "voidtools.Everything"; Name = "Everything Search"; Config = "install_everything" },
    @{ Id = "Microsoft.PowerToys"; Name = "PowerToys"; Config = "install_powertoys" },
    @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal"; Config = "install_windows_terminal" },
    @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7"; Config = "install_powershell7" }
)

foreach ($app in $utilityApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# =============================================================================
# COMMUNICATION
# =============================================================================

$commApps = @(
    @{ Id = "Discord.Discord"; Name = "Discord"; Config = "install_discord" },
    @{ Id = "OpenWhisperSystems.Signal"; Name = "Signal"; Config = "install_signal" }
)

foreach ($app in $commApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# =============================================================================
# MEDIA
# =============================================================================

$mediaApps = @(
    @{ Id = "Spotify.Spotify"; Name = "Spotify"; Config = "install_spotify" },
    @{ Id = "VideoLAN.VLC"; Name = "VLC"; Config = "install_vlc" }
)

foreach ($app in $mediaApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# =============================================================================
# BROWSERS
# =============================================================================

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

# =============================================================================
# PRODUCTIVITY
# =============================================================================

$prodApps = @(
    @{ Id = "OBSProject.OBSStudio"; Name = "OBS Studio"; Config = "install_obs" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code"; Config = "install_vscode" }
)

foreach ($app in $prodApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# =============================================================================
# VPN
# =============================================================================

$vpnApps = @(
    @{ Id = "Tailscale.Tailscale"; Name = "Tailscale"; Config = "install_tailscale" },
    @{ Id = "Proton.ProtonVPN"; Name = "ProtonVPN"; Config = "install_protonvpn" }
)

foreach ($app in $vpnApps) {
    if (Get-ConfigValue $app.Config $false) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# =============================================================================
# PASSWORD MANAGERS
# =============================================================================

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

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

if (Get-ConfigValue "install_dev_tools" $true) {
    $devApps = @(
        @{ Id = "Git.Git"; Name = "Git"; Config = "install_git" },
        @{ Id = "Python.Python.3.12"; Name = "Python 3.12"; Config = "install_python" },
        @{ Id = "OpenJS.NodeJS.LTS"; Name = "Node.js LTS"; Config = "install_nodejs" },
        @{ Id = "EclipseAdoptium.Temurin.21.JDK"; Name = "Java (Temurin 21)"; Config = "install_java" }
    )

    foreach ($app in $devApps) {
        if (Get-ConfigValue $app.Config $false) {
            Install-WingetPackage -PackageId $app.Id -Name $app.Name
        }
    }
}

# =============================================================================
# SYSTEM UTILITIES
# =============================================================================

if (Get-ConfigValue "install_system_utilities" $true) {
    $sysApps = @(
        @{ Id = "RevoUninstaller.RevoUninstaller"; Name = "Revo Uninstaller"; Config = "install_revo_uninstaller" },
        @{ Id = "Piriform.CCleaner"; Name = "CCleaner"; Config = "install_ccleaner" },
        @{ Id = "AntibodySoftware.WizTree"; Name = "WizTree"; Config = "install_wiztree" }
    )

    foreach ($app in $sysApps) {
        if (Get-ConfigValue $app.Config $false) {
            Install-WingetPackage -PackageId $app.Id -Name $app.Name
        }
    }
}

# =============================================================================
# RUNTIMES & DEPENDENCIES
# =============================================================================

if (Get-ConfigValue "install_runtimes" $true) {
    # .NET Runtime
    if (Get-ConfigValue "install_dotnet_runtime" $true) {
        Install-WingetPackage -PackageId "Microsoft.DotNet.Runtime.8" -Name ".NET Runtime 8"
    }

    # .NET Desktop Runtime
    if (Get-ConfigValue "install_dotnet_desktop" $true) {
        Install-WingetPackage -PackageId "Microsoft.DotNet.DesktopRuntime.8" -Name ".NET Desktop Runtime 8"
    }

    # Visual C++ Redistributable
    if (Get-ConfigValue "install_vcredist" $true) {
        Install-WingetPackage -PackageId "Microsoft.VCRedist.2015+.x64" -Name "VC++ 2015-2022 (x64)"
        Install-WingetPackage -PackageId "Microsoft.VCRedist.2015+.x86" -Name "VC++ 2015-2022 (x86)"
    }

    # DirectX
    if (Get-ConfigValue "install_directx" $true) {
        Install-WingetPackage -PackageId "Microsoft.DirectX" -Name "DirectX End-User Runtime"
    }
}

Write-Status "Apps installation complete" "Success"
