# Optimization Module - Windows Gaming Tweaks
# ============================================
# System optimizations for gaming on ROG Ally X.
#
# CAUTION:
# - Some tweaks may affect Windows features you use
# - Test after applying to ensure nothing breaks
# - You can re-enable features manually if needed
#
# ROG Ally Notes:
# - Windows 11 is generally well-optimized for gaming
# - Game Mode is already enabled by default
# - Most "debloat" scripts are unnecessary and can cause issues

if (-not (Get-ConfigValue "install_optimization" $true)) {
    Write-Status "Optimization module disabled in config" "Info"
    return
}

# Game Mode
# ---------
# Windows Game Mode prioritizes game processes

if (Get-ConfigValue "enable_game_mode" $true) {
    Write-Status "Enabling Windows Game Mode..." "Info"
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord
        Write-Status "Game Mode enabled" "Success"
    } catch {
        Write-Status "Could not enable Game Mode" "Warning"
    }
}

# Hardware-accelerated GPU Scheduling
# -----------------------------------
# Can improve performance and reduce latency

if (Get-ConfigValue "enable_hardware_gpu_scheduling" $true) {
    Write-Status "Enabling Hardware-accelerated GPU Scheduling..." "Info"
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
        Write-Status "GPU Scheduling enabled (restart required)" "Success"
    } catch {
        Write-Status "Could not enable GPU Scheduling" "Warning"
    }
}

# Disable Game DVR (Background Recording)
# ----------------------------------------
# Saves resources if you don't use Xbox Game Bar recording

if (Get-ConfigValue "disable_game_dvr" $true) {
    Write-Status "Disabling Game DVR background recording..." "Info"
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-Status "Game DVR disabled" "Success"
    } catch {
        Write-Status "Could not fully disable Game DVR" "Warning"
    }
}

# Disable Xbox Game Bar (Optional)
# ---------------------------------
# Only if you don't use any Game Bar features

if (Get-ConfigValue "disable_xbox_game_bar" $false) {
    Write-Status "Disabling Xbox Game Bar..." "Info"
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "GameDVR_Enabled" -Value 0 -Type DWord
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord
        Write-Status "Xbox Game Bar disabled" "Success"
    } catch {
        Write-Status "Could not disable Xbox Game Bar" "Warning"
    }
}

# Disable Windows Tips and Suggestions
# ------------------------------------
# Reduces background activity and notifications

if (Get-ConfigValue "disable_tips" $true) {
    Write-Status "Disabling Windows tips and suggestions..." "Info"
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -Type DWord
        Write-Status "Tips disabled" "Success"
    } catch {
        Write-Status "Could not disable tips" "Warning"
    }
}

# Storage Sense
# -------------
# Automatically clean up temporary files

if (Get-ConfigValue "enable_storage_sense" $true) {
    Write-Status "Enabling Storage Sense..." "Info"
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Write-Status "Storage Sense enabled" "Success"
    } catch {
        Write-Status "Could not enable Storage Sense (may need manual setup)" "Warning"
    }
}

# Power Plan
# ----------
# Note: Armoury Crate manages power on ROG Ally - these are Windows-level settings

if (Get-ConfigValue "configure_power_plans" $true) {
    Write-Status "Power plans are managed by Armoury Crate on ROG Ally" "Info"
    Write-Status "Use Armoury Crate to switch between Silent/Performance/Turbo modes" "Info"
}

Write-Status "Optimization complete" "Success"
Write-Status "Some changes require a restart to take effect" "Warning"
