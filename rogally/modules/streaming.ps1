# Streaming Module - Game Streaming Clients
# ==========================================
# Stream games from your gaming PC, consoles, or cloud services.
#
# ROG Ally X Streaming Notes:
# - Moonlight + Sunshine is the best local streaming combo
# - Chiaki-ng for PlayStation Remote Play (better than official app)
# - Xbox Cloud Gaming works great via Xbox app or browser
# - Parsec is excellent for low-latency remote play

if (-not (Get-ConfigValue "install_streaming" $true)) {
    Write-Status "Streaming module disabled in config" "Info"
    return
}

# Local Streaming (from your gaming PC)
# -------------------------------------

if (Get-ConfigValue "install_moonlight" $false) {
    Install-WingetPackage -PackageId "MoonlightGameStreamingProject.Moonlight" -Name "Moonlight"
    Write-Status "Moonlight: Pair with Sunshine on your gaming PC" "Info"
    # Sunshine is the server component - install on your gaming PC, not Ally
}

if (Get-ConfigValue "install_parsec" $false) {
    Install-WingetPackage -PackageId "Parsec.Parsec" -Name "Parsec"
    Write-Status "Parsec: Low-latency streaming, also works for remote desktop" "Info"
}

if (Get-ConfigValue "install_steam_link" $false) {
    # Steam Link is typically installed via Steam - check if available in winget
    $steamLinkAvailable = winget search "Steam Link" 2>$null | Select-String "Valve"
    if ($steamLinkAvailable) {
        Install-WingetPackage -PackageId "Valve.SteamLink" -Name "Steam Link"
    } else {
        Write-Status "Steam Link: Install from Microsoft Store or Steam" "Warning"
    }
}

# Console Streaming
# -----------------

if (Get-ConfigValue "install_chiaki" $false) {
    # Chiaki-ng (improved fork) - check winget availability
    $chiakiResult = winget search "chiaki" 2>$null
    if ($chiakiResult -match "Chiaki") {
        Install-WingetPackage -PackageId "Streetpea.Chiaki-ng" -Name "Chiaki-ng"
    } else {
        Write-Status "Chiaki-ng: Download from https://github.com/streetpea/chiaki-ng/releases" "Warning"
    }
    Write-Status "Chiaki: PlayStation Remote Play - pair with your PS4/PS5" "Info"
}

if (Get-ConfigValue "install_greenlight" $false) {
    # Greenlight for Xbox streaming - might need manual install
    Write-Status "Greenlight: Download from https://github.com/unknownskl/greenlight" "Warning"
    Write-Status "Or use Xbox app for Xbox Cloud Gaming" "Info"
}

# Cloud Gaming
# ------------

if (Get-ConfigValue "install_xbox_app" $true) {
    Install-WingetPackage -PackageId "Microsoft.GamingApp" -Name "Xbox App"
    Write-Status "Xbox App: Includes Xbox Cloud Gaming (requires Game Pass Ultimate)" "Info"
}

if (Get-ConfigValue "install_geforcenow" $false) {
    Install-WingetPackage -PackageId "NVIDIA.GeForceNow" -Name "GeForce NOW"
}

Write-Status "Streaming setup complete" "Success"
