# Emulation Module - Retro Gaming
# ================================
# Emulators for retro gaming on ROG Ally X.
#
# Emulation Notes:
# - EmuDeck is recommended for easy setup (configures everything)
# - RetroArch is recommended for most systems (unified interface)
# - Standalone emulators often have better compatibility/features
# - Store ROMs on SD card or secondary storage
# - Legal: You must own the original games to use ROMs
#
# ROG Ally Performance:
# - PS2, GameCube, Wii: Excellent
# - PS3: Good (game-dependent)
# - Switch: Variable (use Ryujinx for better compatibility)
# - Wii U: Excellent with Cemu

if (-not (Get-ConfigValue "install_emulation" $false)) {
    Write-Status "Emulation module disabled in config" "Info"
    return
}

# =============================================================================
# EMUDECK
# =============================================================================
# EmuDeck is an all-in-one emulation setup tool that configures everything.
# It downloads emulators, sets optimal settings, and organizes ROMs.
# After install, run EmuDeck to complete the interactive setup.

if (Get-ConfigValue "install_emudeck" $false) {
    Write-Status "Setting up EmuDeck..." "Info"

    # Check for private EA script first
    $privateScriptPath = Join-Path $Script:BootibleRoot "private\rog-ally\scripts\EmuDeck EA Windows.bat"
    $localScriptPath = Join-Path $Script:DeviceRoot "scripts\EmuDeck EA Windows.bat"

    $emudeckScript = $null
    if (Test-Path $privateScriptPath) {
        $emudeckScript = $privateScriptPath
        Write-Status "Found EmuDeck EA (Patreon) script" "Success"
    } elseif (Test-Path $localScriptPath) {
        $emudeckScript = $localScriptPath
        Write-Status "Found EmuDeck EA script in local files" "Success"
    }

    if ($Script:DryRun) {
        if ($emudeckScript) {
            Write-Status "[DRY RUN] Would run EmuDeck EA installer: $emudeckScript" "Info"
        } else {
            Write-Status "[DRY RUN] Would download and run EmuDeck public installer" "Info"
        }
    } else {
        if ($emudeckScript) {
            Write-Status "Running EmuDeck EA installer..." "Info"
            try {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$emudeckScript`"" -Wait
                Write-Status "EmuDeck EA installer launched" "Success"
            } catch {
                Write-Status "Failed to run EmuDeck EA installer: $_" "Warning"
            }
        } else {
            Write-Status "Downloading EmuDeck public installer..." "Info"
            try {
                $installerUrl = "https://raw.githubusercontent.com/EmuDeck/emudeck-we/main/install.ps1"
                Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($installerUrl))
                Write-Status "EmuDeck installer launched" "Success"
            } catch {
                Write-Status "Failed to download EmuDeck installer: $_" "Warning"
                Write-Status "Visit https://www.emudeck.com/ to download manually" "Info"
            }
        }
    }

    Write-Status "After EmuDeck setup, run the EmuDeck app to configure emulators" "Info"
}

# Create emulation directories
$romsPath = Get-ConfigValue "roms_path" "C:\Emulation\ROMs"
$biosPath = Get-ConfigValue "bios_path" "C:\Emulation\BIOS"

if (-not (Test-Path $romsPath)) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would create ROMs directory: $romsPath" "Info"
    } else {
        Write-Status "Creating ROMs directory: $romsPath" "Info"
        New-Item -ItemType Directory -Path $romsPath -Force | Out-Null
    }
} else {
    Write-Status "ROMs directory exists: $romsPath" "Success"
}

if (-not (Test-Path $biosPath)) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would create BIOS directory: $biosPath" "Info"
    } else {
        Write-Status "Creating BIOS directory: $biosPath" "Info"
        New-Item -ItemType Directory -Path $biosPath -Force | Out-Null
    }
} else {
    Write-Status "BIOS directory exists: $biosPath" "Success"
}

# Frontends
# ---------

if (Get-ConfigValue "install_retroarch" $false) {
    Install-WingetPackage -PackageId "Libretro.RetroArch" -Name "RetroArch"
    Write-Status "RetroArch: Multi-system emulator - download cores from within the app" "Info"
}

if (Get-ConfigValue "install_emulationstation" $false) {
    # EmulationStation DE
    $esdeResult = winget search "EmulationStation" 2>$null
    if ($esdeResult -match "EmulationStation") {
        Install-WingetPackage -PackageId "EmulationStation.EmulationStationDE" -Name "EmulationStation DE"
    } else {
        Write-Status "EmulationStation DE: Download from https://es-de.org/" "Warning"
    }
}

# Standalone Emulators
# --------------------

$emulators = @(
    @{ Id = "DolphinEmu.DolphinEmu"; Name = "Dolphin (GC/Wii)"; Config = "install_dolphin" },
    @{ Id = "PCSX2Team.PCSX2"; Name = "PCSX2 (PS2)"; Config = "install_pcsx2" },
    @{ Id = "RPCS3.RPCS3"; Name = "RPCS3 (PS3)"; Config = "install_rpcs3" },
    @{ Id = "Ryujinx.Ryujinx"; Name = "Ryujinx (Switch)"; Config = "install_ryujinx" },
    @{ Id = "Cemu.Cemu"; Name = "Cemu (Wii U)"; Config = "install_cemu" },
    @{ Id = "DuckStation.DuckStation"; Name = "DuckStation (PS1)"; Config = "install_duckstation" },
    @{ Id = "PPSSPPTeam.PPSSPP"; Name = "PPSSPP (PSP)"; Config = "install_ppsspp" }
)

foreach ($emu in $emulators) {
    if (Get-ConfigValue $emu.Config $false) {
        Install-WingetPackage -PackageId $emu.Id -Name $emu.Name
    }
}

# Yuzu note (discontinued)
if (Get-ConfigValue "install_yuzu" $false) {
    Write-Status "Yuzu has been discontinued. Consider using Ryujinx instead." "Warning"
}

Write-Status "Emulation setup complete" "Success"
Write-Status "Remember to add your BIOS files to: $biosPath" "Info"
Write-Status "ROMs directory: $romsPath" "Info"
