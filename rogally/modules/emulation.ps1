# Emulation Module - Retro Gaming
# ================================
# Emulators for retro gaming on ROG Ally X.
#
# Emulation Notes:
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

# Create emulation directories
$romsPath = Get-ConfigValue "roms_path" "D:\Emulation\ROMs"
$biosPath = Get-ConfigValue "bios_path" "D:\Emulation\BIOS"

if (-not (Test-Path $romsPath)) {
    Write-Status "Creating ROMs directory: $romsPath" "Info"
    New-Item -ItemType Directory -Path $romsPath -Force | Out-Null
}

if (-not (Test-Path $biosPath)) {
    Write-Status "Creating BIOS directory: $biosPath" "Info"
    New-Item -ItemType Directory -Path $biosPath -Force | Out-Null
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
