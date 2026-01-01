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

# VLC
if (Get-ConfigValue "install_vlc" $false) {
    Install-WingetPackage -PackageId "VideoLAN.VLC" -Name "VLC"
}

# Spotify - use Microsoft Store version (works with admin context)
if (Get-ConfigValue "install_spotify" $false) {
    # Check if already installed
    $spotifyInstalled = Get-AppxPackage -Name "SpotifyAB.SpotifyMusic" -ErrorAction SilentlyContinue
    if (-not $spotifyInstalled) {
        $spotifyInstalled = Test-Path "$env:APPDATA\Spotify\Spotify.exe"
    }

    if ($spotifyInstalled) {
        Write-Status "Spotify already installed" "Success"
    } elseif ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install Spotify from Microsoft Store" "Info"
    } else {
        Write-Status "Installing Spotify from Microsoft Store..." "Info"
        # Use Store ID for Spotify (works in admin context unlike winget Spotify.Spotify)
        $result = winget install 9NCBCSZSJRSB --source msstore --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Spotify installed" "Success"
        } else {
            Write-Status "Spotify install failed - try Microsoft Store manually" "Warning"
        }
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
        @{ Id = "AntibodySoftware.WizTree"; Name = "WizTree"; Config = "install_wiztree" },
        @{ Id = "Easeware.DriverEasy"; Name = "DriverEasy"; Config = "install_drivereasy" }
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
    # Note: winget often fails with VCRedist (NO_APPLICABLE_INSTALLER error)
    # Use Chocolatey which is more reliable for these packages
    if (Get-ConfigValue "install_vcredist" $true) {
        # Check if VC++ 2015-2022 (v14.x) is already installed via registry
        $vcx64 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
        $vcx86 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" -ErrorAction SilentlyContinue
        # Also check WOW6432Node for 32-bit detection on 64-bit systems
        if (-not $vcx86) {
            $vcx86 = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86" -ErrorAction SilentlyContinue
        }

        if ($vcx64 -and $vcx86) {
            Write-Status "VC++ 2015-2022 already installed (x64: $($vcx64.Version), x86: $($vcx86.Version))" "Success"
        } elseif ($vcx64) {
            Write-Status "VC++ 2015-2022 x64 installed, x86 may be missing" "Info"
        } else {
            $choco = Get-Command choco -ErrorAction SilentlyContinue
            if ($choco) {
                if ($Script:DryRun) {
                    Write-Status "[DRY RUN] Would install VC++ 2015-2022 via Chocolatey" "Info"
                } else {
                    Write-Status "Installing VC++ 2015-2022 via Chocolatey..." "Info"
                    try {
                        $prevEAP = $ErrorActionPreference
                        $ErrorActionPreference = "Continue"
                        try {
                            choco install vcredist140 -y 2>&1 | Out-Null
                        } finally {
                            $ErrorActionPreference = $prevEAP
                        }
                        Write-Status "VC++ 2015-2022 installed" "Success"
                    } catch {
                        Write-Status "Failed to install VC++ 2015-2022: $_" "Warning"
                    }
                }
            } else {
                # Fallback to winget if Chocolatey not available
                Install-WingetPackage -PackageId "Microsoft.VCRedist.2015+.x64" -Name "VC++ 2015-2022 (x64)"
                Install-WingetPackage -PackageId "Microsoft.VCRedist.2015+.x86" -Name "VC++ 2015-2022 (x86)"
            }
        }
    }

    # DirectX
    if (Get-ConfigValue "install_directx" $true) {
        Install-WingetPackage -PackageId "Microsoft.DirectX" -Name "DirectX End-User Runtime"
    }
}

Write-Status "Apps installation complete" "Success"
