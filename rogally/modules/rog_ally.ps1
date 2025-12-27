# ROG Ally Module - Device-Specific Configuration
# ================================================
# ASUS ROG Ally X specific tools and optimizations.
#
# ROG Ally X Specs Reminder:
# - AMD Ryzen Z1 Extreme APU
# - AMD Radeon Graphics (RDNA 3)
# - 7" 1080p 120Hz display
# - 80Wh battery
# - Windows 11
#
# Key Software:
# - Armoury Crate SE: Main control center (pre-installed)
# - MyASUS: System updates and diagnostics
# - Handheld Companion: Alternative controller mapper

if (-not (Get-ConfigValue "install_rog_ally" $true)) {
    Write-Status "ROG Ally module disabled in config" "Info"
    return
}

# Verify we're on a ROG device
$isRogDevice = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer -like "*ASUS*"
if (-not $isRogDevice) {
    Write-Status "Not detected as ASUS device - some features may not apply" "Warning"
}

# ASUS Software
# -------------

# Armoury Crate is typically pre-installed
# Check if it's there, update if possible
$armouryInstalled = Get-AppxPackage | Where-Object { $_.Name -like "*ArmouryCrate*" -or $_.Name -like "*ASUSROGAlly*" }
if ($armouryInstalled) {
    Write-Status "Armoury Crate is installed" "Success"
} else {
    if (Get-ConfigValue "install_armoury_crate" $true) {
        Write-Status "Armoury Crate not found - install from Microsoft Store or ASUS website" "Warning"
        Write-Status "https://www.asus.com/supportonly/armoury-crate/" "Info"
    }
}

# MyASUS
if (Get-ConfigValue "install_myasus" $true) {
    $myasusInstalled = Get-AppxPackage | Where-Object { $_.Name -like "*MyASUS*" }
    if (-not $myasusInstalled) {
        Write-Status "Installing MyASUS from Microsoft Store..." "Info"
        try {
            # Try winget first
            winget install --id "ASUS.MyASUS" --accept-source-agreements --accept-package-agreements --silent 2>$null
            Write-Status "MyASUS installed" "Success"
        } catch {
            Write-Status "MyASUS: Install from Microsoft Store" "Warning"
        }
    } else {
        Write-Status "MyASUS is installed" "Success"
    }
}

# Handheld Companion (Alternative to Armoury Crate)
# -------------------------------------------------
# Open-source alternative for controller configuration

if (Get-ConfigValue "install_handheld_companion" $false) {
    Write-Status "Installing Handheld Companion..." "Info"
    # Handheld Companion from GitHub
    $hcResult = winget search "HandheldCompanion" 2>$null
    if ($hcResult -match "Companion") {
        Install-WingetPackage -PackageId "Nefarius.HandheldCompanion" -Name "Handheld Companion"
    } else {
        Write-Status "Handheld Companion: Download from https://github.com/Valkirie/HandheldCompanion" "Warning"
    }
    Write-Status "Note: Disable Armoury Crate controller features if using Handheld Companion" "Warning"
}

# Performance Monitoring Tools
# ----------------------------

if (Get-ConfigValue "install_rtss" $false) {
    Install-WingetPackage -PackageId "Guru3D.RTSS" -Name "RivaTuner Statistics Server"
    Write-Status "RTSS: Great for FPS limiting and on-screen display" "Info"
}

if (Get-ConfigValue "install_hwinfo" $false) {
    Install-WingetPackage -PackageId "REALiX.HWiNFO" -Name "HWiNFO"
    Write-Status "HWiNFO: Detailed hardware monitoring" "Info"
}

# AMD Adrenalin Software
# ----------------------
# ROG Ally uses AMD graphics - Adrenalin provides additional controls
# Usually pre-installed, but we can check

$amdInstalled = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
if ($amdInstalled) {
    Write-Status "AMD graphics detected" "Success"

    # Check for Adrenalin
    $adrenalinPath = "${env:ProgramFiles}\AMD\CNext\CNext\RadeonSoftware.exe"
    if (Test-Path $adrenalinPath) {
        Write-Status "AMD Adrenalin Software installed" "Success"
    } else {
        Write-Status "AMD Adrenalin: Consider installing for advanced GPU controls" "Info"
        Write-Status "https://www.amd.com/en/support" "Info"
    }
}

# ROG Ally Specific Tips
# ----------------------
Write-Host ""
Write-Status "ROG Ally X Tips:" "Info"
Write-Host "  - Use Armoury Crate to switch between performance modes"
Write-Host "  - Command Center (CC button): Quick access to settings"
Write-Host "  - Armoury Crate button: Opens control center"
Write-Host "  - For best battery life: Silent mode + 15W TDP"
Write-Host "  - For best performance: Turbo mode (25W+ TDP)"
Write-Host "  - Consider using GameScope or Borderless Gaming for better compatibility"
Write-Host ""

Write-Status "ROG Ally setup complete" "Success"
