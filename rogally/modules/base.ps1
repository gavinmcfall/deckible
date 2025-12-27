# Base Module - Prerequisites and Setup
# =====================================
# This module sets up the foundation for everything else:
# - Verifies winget is working
# - Updates winget sources
# - Installs essential utilities
#
# Windows Note:
# Unlike SteamOS, Windows doesn't have an immutable filesystem.
# We use winget for package management - it's built into Windows 11
# and handles updates automatically.

# Verify winget sources are up to date
Write-Status "Updating winget sources..." "Info"
try {
    winget source update
    Write-Status "Winget sources updated" "Success"
} catch {
    Write-Status "Could not update winget sources (continuing anyway)" "Warning"
}

# Install essential utilities
$essentials = @(
    @{ Id = "7zip.7zip"; Name = "7-Zip"; Condition = (Get-ConfigValue "install_7zip" $true) },
    @{ Id = "voidtools.Everything"; Name = "Everything Search"; Condition = (Get-ConfigValue "install_everything" $true) },
    @{ Id = "Microsoft.PowerToys"; Name = "PowerToys"; Condition = (Get-ConfigValue "install_powertoys" $true) }
)

foreach ($app in $essentials) {
    if ($app.Condition) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}

# Ensure Windows Terminal is available (usually pre-installed on Win11)
$terminalInstalled = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if (-not $terminalInstalled) {
    Write-Status "Installing Windows Terminal..." "Info"
    try {
        winget install --id Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent
        Write-Status "Windows Terminal installed" "Success"
    } catch {
        Write-Status "Could not install Windows Terminal" "Warning"
    }
}

# Check for Windows updates (informational only)
Write-Status "Checking Windows Update status..." "Info"
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates.Count
    if ($pendingUpdates -gt 0) {
        Write-Status "$pendingUpdates Windows update(s) pending - consider updating" "Warning"
    } else {
        Write-Status "Windows is up to date" "Success"
    }
} catch {
    Write-Status "Could not check Windows Update status" "Warning"
}

Write-Status "Base setup complete" "Success"
