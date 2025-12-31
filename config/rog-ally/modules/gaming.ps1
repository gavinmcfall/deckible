# Gaming Module - Game Platforms & Utilities
# ===========================================
# Installs gaming platforms, launchers, and utilities.
# Configure which to install in config.yml
#
# ROG Ally X Gaming Notes:
# - Steam is highly recommended - good controller support
# - GOG Galaxy 2.0 can unify all your libraries
# - Playnite is great for a unified gaming mode experience
# - Most launchers have handheld/controller-friendly modes

if (-not (Get-ConfigValue "install_gaming" $true)) {
    Write-Status "Gaming module disabled in config" "Info"
    return
}

# Gaming Platforms
# ----------------
$platforms = @(
    @{ Id = "Valve.Steam"; Name = "Steam"; Config = "install_steam" },
    @{ Id = "GOG.Galaxy"; Name = "GOG Galaxy"; Config = "install_gog_galaxy" },
    @{ Id = "EpicGames.EpicGamesLauncher"; Name = "Epic Games Launcher"; Config = "install_epic_launcher" },
    @{ Id = "ElectronicArts.EADesktop"; Name = "EA App"; Config = "install_ea_app" },
    @{ Id = "Ubisoft.Connect"; Name = "Ubisoft Connect"; Config = "install_ubisoft_connect" },
    @{ Id = "Amazon.Games"; Name = "Amazon Games"; Config = "install_amazon_games" }
)

foreach ($platform in $platforms) {
    if (Get-ConfigValue $platform.Config $false) {
        Install-WingetPackage -PackageId $platform.Id -Name $platform.Name
    }
}

# Battle.net - installer doesn't exit cleanly, needs special handling
if (Get-ConfigValue "install_battle_net" $false) {
    # Check if already installed
    $battleNetInstalled = Test-Path "$env:ProgramFiles(x86)\Battle.net\Battle.net.exe"
    if (-not $battleNetInstalled) {
        $battleNetInstalled = Test-Path "$env:ProgramFiles\Battle.net\Battle.net.exe"
    }

    if ($battleNetInstalled) {
        Write-Status "Battle.net already installed" "Success"
    } elseif ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install Battle.net" "Info"
    } else {
        Write-Status "Installing Battle.net..." "Info"
        $battleNetLocation = Get-ConfigValue "battle_net_location" "$env:ProgramFiles(x86)\Battle.net"

        try {
            # Download installer
            $battleNetUrl = "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=live"
            $installer = Join-Path $env:TEMP "Battle.net-Setup.exe"

            Write-Host "    Downloading Battle.net installer..." -ForegroundColor Gray
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $battleNetUrl -OutFile $installer -UseBasicParsing
            $ProgressPreference = 'Continue'

            if (Test-Path $installer) {
                Write-Host "    Running installer (will not wait for completion)..." -ForegroundColor Gray

                # Start installer WITHOUT waiting - it launches the app and never exits
                Start-Process -FilePath $installer -ArgumentList "--lang=enUS --installpath=`"$battleNetLocation`""

                # Poll for Battle.net.exe to appear (max 2 minutes)
                $maxWait = 120
                $waited = 0
                $installed = $false

                while ($waited -lt $maxWait) {
                    Start-Sleep -Seconds 5
                    $waited += 5

                    if ((Test-Path "$battleNetLocation\Battle.net.exe") -or
                        (Test-Path "$env:ProgramFiles(x86)\Battle.net\Battle.net.exe") -or
                        (Test-Path "$env:ProgramFiles\Battle.net\Battle.net.exe")) {
                        $installed = $true
                        break
                    }
                    Write-Host "    Waiting for install... (${waited}s)" -ForegroundColor Gray
                }

                # Cleanup installer
                Remove-Item $installer -Force -ErrorAction SilentlyContinue

                if ($installed) {
                    Write-Status "Battle.net installed" "Success"
                } else {
                    Write-Status "Battle.net install timed out - may need manual completion" "Warning"
                }
            }
        } catch {
            Write-Status "Failed to install Battle.net: $_" "Error"
        }
    }
}

# Game Launchers & Managers
# -------------------------
# These provide unified library management and better handheld UX

if (Get-ConfigValue "install_playnite" $false) {
    Install-WingetPackage -PackageId "Playnite.Playnite" -Name "Playnite"
    Write-Status "Playnite tip: Enable Fullscreen mode for controller-friendly UI" "Info"
}

if (Get-ConfigValue "install_launchbox" $false) {
    # LaunchBox needs manual download - not in winget
    Write-Status "LaunchBox: Download from https://www.launchbox-app.com/" "Warning"
}

# Controller Utilities
# --------------------

if (Get-ConfigValue "install_ds4windows" $false) {
    Install-WingetPackage -PackageId "Ryochan7.DS4Windows" -Name "DS4Windows"
    Write-Status "DS4Windows: Configure DualShock/DualSense controllers" "Info"
}

# Mod Managers
# ------------

if (Get-ConfigValue "install_nexus_mods" $false) {
    Install-WingetPackage -PackageId "NexusMods.Vortex" -Name "Vortex Mod Manager"
}

Write-Status "Gaming setup complete" "Success"
