<#
.SYNOPSIS
    Bootible - Universal Bootstrap Script (Windows)
    ================================================
    Detects your device and runs the appropriate configuration.

.DESCRIPTION
    Supported Devices:
    - ROG Ally X (Windows 11)
    - Other Windows gaming handhelds (Legion Go, etc.)

.USAGE
    # Preview what will happen (dry run - default):
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex

    # Run for real after reviewing:
    bootible

    # Or skip preview and run immediately:
    $env:BOOTIBLE_RUN = "1"
    irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex
#>

$ErrorActionPreference = "Stop"

$BootibleDir = "$env:USERPROFILE\bootible"
$RepoUrl = "https://github.com/gavinmcfall/bootible.git"
$PrivateRepo = $env:BOOTIBLE_PRIVATE
$DryRun = $env:BOOTIBLE_RUN -ne "1"  # Dry run by default, set BOOTIBLE_RUN=1 to apply
$Device = ""

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{ "Info" = "Cyan"; "Success" = "Green"; "Warning" = "Yellow"; "Error" = "Red" }
    $symbols = @{ "Info" = "->"; "Success" = "[OK]"; "Warning" = "[!]"; "Error" = "[X]" }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Sync-SystemTime {
    # Sync system time to fix certificate validation errors on fresh installs
    Write-Status "Syncing system time..." "Info"
    try {
        $svc = Get-Service w32time -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Write-Host "    Starting time service..." -ForegroundColor Gray
            Start-Service w32time -ErrorAction Stop
        }
        $result = w32tm /resync /force 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    Time sync warning: $result" -ForegroundColor Yellow
        } else {
            Write-Status "System time synced" "Success"
        }
    } catch {
        Write-Status "Time sync failed: $_ (continuing anyway)" "Warning"
    }
}

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Detect-Device {
    Write-Status "Detecting device..." "Info"

    # Check manufacturer and product name
    $system = Get-WmiObject -Class Win32_ComputerSystem
    $manufacturer = $system.Manufacturer
    $product = $system.Model

    # ROG Ally detection
    if ($manufacturer -like "*ASUS*" -and $product -like "*ROG Ally*") {
        $script:Device = "rog-ally"
        Write-Status "Detected: ASUS ROG Ally X" "Success"
        return
    }

    # Lenovo Legion Go detection
    if ($manufacturer -like "*Lenovo*" -and $product -like "*Legion Go*") {
        $script:Device = "rog-ally"  # Use ROG Ally config as base
        Write-Status "Detected: Lenovo Legion Go (using ROG Ally config)" "Success"
        return
    }

    # MSI Claw detection
    if ($manufacturer -like "*MSI*" -and $product -like "*Claw*") {
        $script:Device = "rog-ally"
        Write-Status "Detected: MSI Claw (using ROG Ally config)" "Success"
        return
    }

    # Default to rog-ally for any Windows device
    $script:Device = "rog-ally"
    Write-Status "Windows device detected - using ROG Ally configuration" "Info"
}

$script:GitExe = "git"  # Will be updated to full path if needed

function Find-GitExe {
    # Check if git is already in PATH
    $existing = Get-Command git -ErrorAction SilentlyContinue
    if ($existing) {
        return $existing.Source
    }

    # Search common install locations
    $searchPaths = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "$env:ProgramFiles\Git\bin\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:USERPROFILE\AppData\Local\Programs\Git\cmd\git.exe",
        "$env:USERPROFILE\scoop\apps\git\current\bin\git.exe",
        "C:\Git\cmd\git.exe",
        "C:\Program Files\Git\cmd\git.exe"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    # Last resort: search Program Files recursively (slow but thorough)
    $found = Get-ChildItem -Path "$env:ProgramFiles" -Recurse -Filter "git.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return $found.FullName
    }

    return $null
}

function Install-Git {
    $gitPath = Find-GitExe
    if ($gitPath) {
        $script:GitExe = $gitPath
        Write-Status "Git found at $gitPath" "Success"
        return $true
    }

    Write-Status "Installing Git from GitHub (~65MB)..." "Info"
    try {
        $gitInstaller = "$env:TEMP\Git-installer.exe"
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"

        Write-Host "    Downloading..." -ForegroundColor Gray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing

        if (-not (Test-Path $gitInstaller)) {
            throw "Download failed - file not found"
        }
        Write-Status "Download complete" "Success"

        Write-Status "Running Git installer (please wait)..." "Info"
        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART", "/SP-" -Wait -NoNewWindow

        # Clean up
        Remove-Item $gitInstaller -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 2

        $gitPath = Find-GitExe
        if ($gitPath) {
            $script:GitExe = $gitPath
            Write-Status "Git installed at $gitPath" "Success"
            return $true
        }

        Write-Status "Git installed but not found in expected locations" "Warning"
        Write-Status "Please close and reopen PowerShell, then re-run" "Info"
        return $false
    } catch {
        Write-Status "Git installation failed: $_" "Error"
        Write-Status "Please install Git manually from https://git-scm.com then re-run" "Warning"
        return $false
    }
}

function Configure-GitCredentials {
    # Ensure Git Credential Manager is configured for GUI prompts
    if (-not $script:GitExe) { return }

    Write-Host "    Configuring Git credential manager..." -ForegroundColor Gray
    & $script:GitExe config --global credential.helper manager 2>$null
    & $script:GitExe config --global credential.guiPrompt true 2>$null
    & $script:GitExe config --global credential.useHttpPath true 2>$null
}

function Run-GitWithProgress {
    param(
        [string]$Description,
        [string[]]$Arguments,
        [string]$WorkingDir = $null
    )

    Write-Status "$Description..." "Info"

    # Filter out --progress (can cause stderr buffering issues)
    $cleanArgs = @($Arguments | Where-Object { $_ -ne "--progress" })

    Write-Host "    Running: git $($cleanArgs -join ' ')" -ForegroundColor Gray

    $originalLocation = Get-Location
    try {
        if ($WorkingDir) {
            Set-Location $WorkingDir
        }

        # Run git in separate cmd window to fully isolate stdin/stdout
        # This allows Git Credential Manager to work properly
        $argString = $cleanArgs -join ' '
        Write-Host "    (Git window will open - check taskbar if you don't see auth prompt)" -ForegroundColor Yellow

        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"`"$script:GitExe`" $argString`"" -WorkingDirectory (Get-Location).Path -Wait -PassThru
        $LASTEXITCODE = $proc.ExitCode

        if ($LASTEXITCODE -ne 0) {
            throw "Git command failed (exit code $LASTEXITCODE)"
        }

        return $true
    } catch {
        Write-Status "Git failed: $_" "Error"
        throw $_
    } finally {
        Set-Location $originalLocation
    }
}

function Clone-Bootible {
    try {
        if (Test-Path $BootibleDir) {
            Run-GitWithProgress -Description "Updating bootible repo" -Arguments @("pull", "--progress") -WorkingDir $BootibleDir
        } else {
            Run-GitWithProgress -Description "Cloning bootible repo" -Arguments @("clone", "--progress", $RepoUrl, $BootibleDir)
        }
        Write-Status "Bootible ready at $BootibleDir" "Success"
        return $true
    } catch {
        Write-Status "Failed to clone/update bootible: $_" "Error"
        return $false
    }
}

function Setup-Private {
    # Check if already set via environment variable
    if (-not $PrivateRepo) {
        Write-Host ""
        $response = Read-Host "Do you have a private config repo? (y/N)"
        if ($response -match "^[Yy]") {
            Write-Host "Your GitHub username: " -NoNewline
            $Script:GitHubUser = Read-Host
            Write-Host "Private repo (e.g., " -NoNewline
            Write-Host "owner/repo" -ForegroundColor Yellow -NoNewline
            Write-Host "): " -NoNewline
            $repoPath = Read-Host
            if ($repoPath) {
                $script:PrivateRepo = "https://github.com/$repoPath.git"
            }
        }
    }

    if ($PrivateRepo) {
        $privatePath = Join-Path $BootibleDir "private"
        Write-Host ""
        Write-Status "Repo: $PrivateRepo" "Info"

        try {
            if (Test-Path (Join-Path $privatePath ".git")) {
                Run-GitWithProgress -Description "Updating private config" -Arguments @("pull", "--progress") -WorkingDir $privatePath
            } else {
                if (Test-Path $privatePath) {
                    Write-Host "    Removing old private folder..." -ForegroundColor Gray
                    Remove-Item -Recurse -Force $privatePath
                }
                Run-GitWithProgress -Description "Cloning private config (may prompt for login)" -Arguments @("clone", "--progress", $PrivateRepo, $privatePath) -TimeoutSeconds 120
            }
            Write-Status "Private configuration linked" "Success"
        } catch {
            Write-Status "Failed to setup private repo: $_" "Warning"
            Write-Status "Continuing without private config..." "Info"
        }
    }
}

function Select-Config {
    $script:SelectedConfig = ""
    $privateDeviceDir = Join-Path $BootibleDir "private\$Device"
    $defaultConfig = Join-Path $BootibleDir "config\$Device\config.yml"

    # Check if private device config directory exists
    if (-not (Test-Path $privateDeviceDir)) {
        Write-Status "Using default configuration" "Info"
        $script:SelectedConfig = $defaultConfig
        return
    }

    # Find config files in private directory
    $configFiles = Get-ChildItem -Path $privateDeviceDir -Filter "config*.yml" -File -ErrorAction SilentlyContinue | Sort-Object Name

    # If no private configs, use default
    if (-not $configFiles -or $configFiles.Count -eq 0) {
        Write-Status "Using default configuration" "Info"
        $script:SelectedConfig = $defaultConfig
        return
    }

    # If only one config, use it automatically
    if ($configFiles.Count -eq 1) {
        $script:SelectedConfig = $configFiles[0].FullName
        Write-Status "Using config: $($configFiles[0].Name)" "Success"
        return
    }

    # Multiple configs - let user choose
    Write-Host ""
    Write-Host "Multiple configurations found:" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $configFiles.Count; $i++) {
        $num = $i + 1
        Write-Host "  " -NoNewline
        Write-Host "$num" -ForegroundColor Yellow -NoNewline
        Write-Host ") $($configFiles[$i].Name)"
    }
    Write-Host ""

    while ($true) {
        $selection = Read-Host "Select configuration [1-$($configFiles.Count)]"

        if ($selection -match '^\d+$') {
            $idx = [int]$selection - 1
            if ($idx -ge 0 -and $idx -lt $configFiles.Count) {
                $script:SelectedConfig = $configFiles[$idx].FullName
                Write-Host ""
                Write-Status "Selected: $($configFiles[$idx].Name)" "Success"
                return
            }
        }
        Write-Host "Invalid selection. Please enter a number between 1 and $($configFiles.Count)" -ForegroundColor Red
    }
}

function Install-BootibleCommand {
    Write-Status "Installing 'bootible' command..." "Info"

    $cmdContent = @"
@echo off
powershell -ExecutionPolicy Bypass -Command "& '$BootibleDir\config\$Device\Run.ps1' %*"
"@

    # Try WindowsApps first (already in PATH)
    $cmdPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\bootible.cmd"
    try {
        Set-Content -Path $cmdPath -Value $cmdContent -Force -ErrorAction Stop
        Write-Status "Installed 'bootible' command" "Success"
        return
    } catch {
        Write-Host "    WindowsApps not writable, trying fallback..." -ForegroundColor Gray
    }

    # Fallback: put in bootible directory and add to PATH
    $cmdPath = Join-Path $BootibleDir "bootible.cmd"
    try {
        Set-Content -Path $cmdPath -Value $cmdContent -Force
        Write-Host "    Adding to PATH..." -ForegroundColor Gray
        # Add to user PATH if not already there
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$BootibleDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$BootibleDir;$userPath", "User")
            $env:Path = "$BootibleDir;$env:Path"
        }
        Write-Status "Installed 'bootible' command (added $BootibleDir to PATH)" "Success"
    } catch {
        Write-Status "Could not install bootible command: $_" "Warning"
        Write-Status "You can run manually: $BootibleDir\config\$Device\Run.ps1" "Info"
    }
}

function Run-DeviceSetup {
    Write-Host ""
    if ($DryRun) {
        Write-Status "Running $Device configuration (DRY RUN)..." "Warning"
    } else {
        Write-Status "Running $Device configuration..." "Info"
    }

    # Show which config is being used
    if ($script:SelectedConfig -and $script:SelectedConfig -ne (Join-Path $BootibleDir "config\$Device\config.yml")) {
        Write-Status "Config: $(Split-Path $script:SelectedConfig -Leaf)" "Info"
    }
    Write-Host ""

    $devicePath = Join-Path $BootibleDir "config\$Device"
    $runScript = Join-Path $devicePath "Run.ps1"

    # Build arguments
    $arguments = @()
    if ($DryRun) {
        $arguments += "-DryRun"
    }
    if ($script:SelectedConfig) {
        $arguments += "-ConfigFile"
        $arguments += "`"$($script:SelectedConfig)`""
    }

    switch ($Device) {
        "rog-ally" {
            # Use -ExecutionPolicy Bypass to avoid execution policy errors
            if ($arguments.Count -gt 0) {
                $argString = $arguments -join " "
                powershell -ExecutionPolicy Bypass -Command "& '$runScript' $argString"
            } else {
                powershell -ExecutionPolicy Bypass -File $runScript
            }
        }
        default {
            Write-Status "Unknown device type: $Device" "Error"
            exit 1
        }
    }
}

function Save-DryRunLog {
    # Save dry run transcript to private repo logs folder and push to git
    $privatePath = Join-Path $BootibleDir "private"
    if (-not (Test-Path $privatePath)) {
        return
    }

    $logsPath = Join-Path $privatePath "logs\$Device"
    if (-not (Test-Path $logsPath)) {
        New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
    }

    $logFileName = "$(Get-Date -Format 'yyyy-MM-dd')_dryrun.log"
    $logFile = Join-Path $logsPath $logFileName

    try {
        Stop-Transcript | Out-Null
    } catch {
        # Transcript wasn't running
    }

    if (Test-Path $Script:TranscriptFile) {
        Copy-Item $Script:TranscriptFile $logFile -Force
        Remove-Item $Script:TranscriptFile -Force -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Status "Dry run log saved: $logFileName" "Success"

        # Push to git
        $gitExe = Find-GitExe
        if ($gitExe) {
            Push-Location $privatePath

            # Ensure git identity is configured for commit
            $userName = & $gitExe config user.name 2>$null
            if (-not $userName) {
                if ($Script:GitHubUser) {
                    & $gitExe config user.name $Script:GitHubUser 2>$null
                    & $gitExe config user.email "$Script:GitHubUser@users.noreply.github.com" 2>$null
                } else {
                    & $gitExe config user.name "Bootible" 2>$null
                    & $gitExe config user.email "bootible@localhost" 2>$null
                }
            }

            & $gitExe add "logs/$Device/$logFileName" 2>$null
            & $gitExe commit -m "log: $Device dry run $(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>$null

            # Use cmd.exe to avoid PowerShell stderr handling issues
            cmd /c "`"$gitExe`" push 2>nul"

            if ($LASTEXITCODE -eq 0) {
                Write-Status "Log pushed to private repo" "Success"
            } else {
                Write-Status "Could not push log (exit code: $LASTEXITCODE)" "Warning"
            }

            Pop-Location
        }
    }
}

function Main {
    # Start transcript to capture all output
    $Script:TranscriptFile = Join-Path $env:TEMP "bootible_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    try {
        Start-Transcript -Path $Script:TranscriptFile -Force | Out-Null
    } catch {
        # Transcript failed to start, continue without it
    }

    Write-Host ""
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                      Bootible                              |" -ForegroundColor White
    Write-Host "|         Universal Gaming Device Configuration              |" -ForegroundColor Gray
    Write-Host "+------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    # Check admin
    if (-not (Test-Admin)) {
        Write-Status "Administrator privileges required" "Error"
        Write-Host ""
        Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
        Write-Host ""
        return
    }
    Write-Status "Running as Administrator" "Success"

    # Sync time first (fixes certificate errors on fresh installs)
    Sync-SystemTime

    # Check winget
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Status "winget not found. Please install App Installer from Microsoft Store." "Error"
        return
    }
    Write-Status "winget available" "Success"

    Detect-Device
    Write-Host ""

    if (-not (Install-Git)) {
        return
    }
    Configure-GitCredentials
    Write-Host ""

    if (-not (Clone-Bootible)) {
        Write-Host ""
        Write-Host "Failed to clone bootible. Check your network connection." -ForegroundColor Red
        return
    }
    Write-Host ""

    # Verify Run.ps1 exists
    $runScript = Join-Path $BootibleDir "config\$Device\Run.ps1"
    if (-not (Test-Path $runScript)) {
        Write-Status "Run.ps1 not found at $runScript" "Error"
        return
    }

    Setup-Private
    Write-Host ""

    Select-Config
    Write-Host ""

    Install-BootibleCommand
    Write-Host ""

    Run-DeviceSetup

    Write-Host ""
    if ($DryRun) {
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host "|                  DRY RUN COMPLETE                          |" -ForegroundColor White
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Review the output above. When ready to apply changes:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  bootible" -ForegroundColor Green
        Write-Host ""

        # Save dry run log to private repo if available
        Save-DryRunLog
    } else {
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
        Write-Host "|                   Setup Complete!                          |" -ForegroundColor White
        Write-Host "+------------------------------------------------------------+" -ForegroundColor Green
        Write-Host ""
        Write-Host "Device: $Device" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow

        switch ($Device) {
            "rog-ally" {
                Write-Host "  - Restart your device to apply all changes"
                Write-Host "  - Configure Armoury Crate for performance profiles"
                Write-Host "  - Set up game streaming apps if installed"
            }
        }
        Write-Host ""
    }

    Write-Host "To re-run anytime:" -ForegroundColor Gray
    Write-Host "  bootible" -ForegroundColor Gray
    Write-Host ""

    # Clean up transcript if still running (non-dry-run case)
    try {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        if (Test-Path $Script:TranscriptFile) {
            Remove-Item $Script:TranscriptFile -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Ignore cleanup errors
    }
}

# Run
Main
