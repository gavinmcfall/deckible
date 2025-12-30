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

# When running via 'irm | iex', stdin is the script content which breaks git credential manager.
# Detect this and re-run as a saved script file instead.
if (-not $env:BOOTIBLE_DIRECT) {
    $scriptPath = "$env:TEMP\bootible-bootstrap.ps1"
    $scriptUrl = "https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1"

    Write-Host "Downloading bootible..." -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing
        # Run with bypass to avoid execution policy issues, pass env var
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"& { `$env:BOOTIBLE_DIRECT='1'; & '$scriptPath' }`"" -Wait -NoNewWindow
        return
    } catch {
        Write-Host "Failed to download script: $_" -ForegroundColor Red
        return
    }
}

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

function Show-DeviceCodePopup {
    param([string]$Code, [string]$QrUrl)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "GitHub Login"
    $form.Size = New-Object System.Drawing.Size(500, 400)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Enter this code on GitHub:"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(120, 20)
    $form.Controls.Add($title)

    # Large code display
    $codeLabel = New-Object System.Windows.Forms.Label
    $codeLabel.Text = $Code
    $codeLabel.Font = New-Object System.Drawing.Font("Consolas", 48, [System.Drawing.FontStyle]::Bold)
    $codeLabel.ForeColor = [System.Drawing.Color]::FromArgb(88, 166, 255)
    $codeLabel.AutoSize = $true
    $codeLabel.Location = New-Object System.Drawing.Point(80, 60)
    $form.Controls.Add($codeLabel)

    # Instructions
    $instructions = New-Object System.Windows.Forms.Label
    $instructions.Text = "Or scan the QR code with your phone:"
    $instructions.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    $instructions.ForeColor = [System.Drawing.Color]::LightGray
    $instructions.AutoSize = $true
    $instructions.Location = New-Object System.Drawing.Point(120, 140)
    $form.Controls.Add($instructions)

    # QR Code image
    $qrPictureBox = New-Object System.Windows.Forms.PictureBox
    $qrPictureBox.Size = New-Object System.Drawing.Size(150, 150)
    $qrPictureBox.Location = New-Object System.Drawing.Point(165, 170)
    $qrPictureBox.SizeMode = "Zoom"
    $qrPictureBox.BackColor = [System.Drawing.Color]::White

    try {
        $webClient = New-Object System.Net.WebClient
        $qrImageBytes = $webClient.DownloadData($QrUrl)
        $ms = New-Object System.IO.MemoryStream(, $qrImageBytes)
        $qrPictureBox.Image = [System.Drawing.Image]::FromStream($ms)
    } catch {
        # If QR fails, just show placeholder text
        $qrPictureBox.BackColor = [System.Drawing.Color]::Gray
    }
    $form.Controls.Add($qrPictureBox)

    # Close button
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "I've completed login"
    $closeButton.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    $closeButton.Size = New-Object System.Drawing.Size(200, 40)
    $closeButton.Location = New-Object System.Drawing.Point(145, 330)
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(46, 160, 67)
    $closeButton.ForeColor = [System.Drawing.Color]::White
    $closeButton.FlatStyle = "Flat"
    $closeButton.Add_Click({ $form.Close() })
    $form.Controls.Add($closeButton)

    # Show non-blocking (will be closed by button or externally)
    $form.Show()
    return $form
}

function Authenticate-GitHub {
    # Try GitHub CLI for authentication (avoids GCM deadlock bug)
    Write-Status "Setting up GitHub authentication..." "Info"

    # Check if gh is installed
    $ghPath = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghPath) {
        Write-Host "    Installing GitHub CLI..." -ForegroundColor Gray

        # Try winget first
        winget install GitHub.cli --accept-package-agreements --accept-source-agreements --silent 2>$null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $ghPath = Get-Command gh -ErrorAction SilentlyContinue

        # If winget failed, download directly
        if (-not $ghPath) {
            Write-Host "    Downloading GitHub CLI directly..." -ForegroundColor Gray
            try {
                $ghInstaller = "$env:TEMP\gh_installer.msi"
                $ghUrl = "https://github.com/cli/cli/releases/download/v2.63.2/gh_2.63.2_windows_amd64.msi"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $ghUrl -OutFile $ghInstaller -UseBasicParsing

                Write-Host "    Installing..." -ForegroundColor Gray
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ghInstaller`" /quiet /norestart" -Wait
                Remove-Item $ghInstaller -Force -ErrorAction SilentlyContinue

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                $ghPath = Get-Command gh -ErrorAction SilentlyContinue
            } catch {
                Write-Host "    Could not install GitHub CLI: $_" -ForegroundColor Yellow
            }
        }
    }

    if (-not $ghPath) {
        Write-Status "GitHub CLI not available - private repos may not work" "Warning"
        return $false
    }

    # Check if already authenticated (suppress error output)
    Write-Host "    Checking GitHub auth status..." -ForegroundColor Gray
    $origErrorPref = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $null = & gh auth status 2>&1
    $authExitCode = $LASTEXITCODE
    $ErrorActionPreference = $origErrorPref

    if ($authExitCode -eq 0) {
        Write-Status "Already authenticated with GitHub" "Success"
        & gh auth setup-git 2>&1 | Out-Null
        return $true
    }

    # Not authenticated - need to login with nice UI
    Write-Host ""
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host "    GitHub Login Required" -ForegroundColor Cyan
    Write-Host "    ============================================" -ForegroundColor Cyan
    Write-Host ""

    # Start gh auth in background and capture output to get the device code
    $ghExe = (Get-Command gh).Source
    $outFile = "$env:TEMP\gh_auth_out.txt"
    $errFile = "$env:TEMP\gh_auth_err.txt"

    # Remove old files
    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item $errFile -Force -ErrorAction SilentlyContinue

    # Start gh auth login - it writes the code to stderr
    $env:GH_FORCE_TTY = "1"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $ghExe
    $psi.Arguments = "auth login --hostname github.com --git-protocol https --web"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables["GH_FORCE_TTY"] = "1"

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.Start() | Out-Null

    # Wait for output containing the code (up to 10 seconds)
    $deviceCode = $null
    $startTime = Get-Date
    $allOutput = ""

    while (((Get-Date) - $startTime).TotalSeconds -lt 10 -and -not $deviceCode) {
        Start-Sleep -Milliseconds 500

        # Read available output
        if (-not $proc.StandardError.EndOfStream) {
            $line = $proc.StandardError.ReadLine()
            if ($line) {
                $allOutput += "$line`n"
                # Look for the device code pattern (XXXX-XXXX)
                if ($line -match '([A-Z0-9]{4}-[A-Z0-9]{4})') {
                    $deviceCode = $matches[1]
                }
            }
        }
    }

    if ($deviceCode) {
        Write-Host "    Device code: " -ForegroundColor White -NoNewline
        Write-Host $deviceCode -ForegroundColor Cyan
        Write-Host ""

        # Generate QR code URL (pre-fills the code on GitHub)
        $githubUrl = "https://github.com/login/device?user_code=$deviceCode"
        $qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$([uri]::EscapeDataString($githubUrl))"

        # Show popup with code and QR
        Write-Host "    Opening login popup..." -ForegroundColor Gray
        $popup = Show-DeviceCodePopup -Code $deviceCode -QrUrl $qrApiUrl

        # Also open browser to GitHub
        Start-Process $githubUrl

        Write-Host ""
        Write-Host "    Complete login in browser or scan QR with phone." -ForegroundColor White
        Write-Host "    Click 'I've completed login' when done." -ForegroundColor White
        Write-Host ""

        # Wait for popup to close (user clicks button)
        while ($popup.Visible) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        $popup.Dispose()
    } else {
        # Fallback: couldn't capture code, use old method
        Write-Host "    Could not capture device code, using fallback method..." -ForegroundColor Yellow
        Write-Host "    A new window will open with a login code." -ForegroundColor White
        Write-Host ""
        Read-Host "    Press Enter to open login window"

        # Kill the background process
        try { $proc.Kill() } catch {}

        # Start in visible window
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c set GH_FORCE_TTY=1 && `"$ghExe`" auth login --hostname github.com --git-protocol https --web" -PassThru

        Write-Host ""
        Read-Host "    Press Enter after completing GitHub login"
    }

    # Kill gh process if still running
    try {
        if (-not $proc.HasExited) {
            $proc.Kill()
        }
        Get-Process -Name "gh" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-5) } | Stop-Process -Force -ErrorAction SilentlyContinue
    } catch {}

    # Verify auth worked
    $ErrorActionPreference = "SilentlyContinue"
    $null = & gh auth status 2>&1
    $authWorked = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $origErrorPref

    if (-not $authWorked) {
        Write-Status "GitHub authentication not detected - try again" "Warning"
        return $false
    }

    # Configure git to use gh as credential helper
    gh auth setup-git 2>$null
    Write-Status "GitHub authentication complete" "Success"
    return $true
}

function Run-GitWithProgress {
    param(
        [string]$Description,
        [string[]]$Arguments,
        [string]$WorkingDir = $null
    )

    Write-Status "$Description..." "Info"

    $cleanArgs = @($Arguments | Where-Object { $_ -ne "--progress" })
    $workDir = if ($WorkingDir) { $WorkingDir } else { (Get-Location).Path }

    try {
        Push-Location $workDir
        & $script:GitExe @cleanArgs
        $exitCode = $LASTEXITCODE
        Pop-Location

        if ($exitCode -ne 0) {
            throw "Git command failed (exit code $exitCode)"
        }
        return $true
    } catch {
        Write-Status "Git failed: $_" "Error"
        throw $_
    }
}

function Clone-Bootible {
    try {
        if (Test-Path $BootibleDir) {
            Run-GitWithProgress -Description "Updating bootible repo" -Arguments @("pull") -WorkingDir $BootibleDir
        } else {
            Run-GitWithProgress -Description "Cloning bootible repo" -Arguments @("clone", $RepoUrl, $BootibleDir)
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

        # Authenticate with GitHub CLI first (more reliable than GCM)
        if (-not (Authenticate-GitHub)) {
            Write-Status "Skipping private repo (authentication failed)" "Warning"
            return
        }

        try {
            if (Test-Path (Join-Path $privatePath ".git")) {
                # Update existing - use git pull
                Push-Location $privatePath
                & $script:GitExe pull 2>&1 | Out-Null
                Pop-Location
            } else {
                if (Test-Path $privatePath) {
                    Write-Host "    Removing old private folder..." -ForegroundColor Gray
                    Remove-Item -Recurse -Force $privatePath
                }

                # Try gh CLI first (avoids GCM deadlock bug)
                $ghPath = Get-Command gh -ErrorAction SilentlyContinue
                if ($ghPath) {
                    # Extract owner/repo from URL
                    $repoSlug = $PrivateRepo -replace 'https://github.com/' -replace '\.git$'
                    Write-Host "    Using GitHub CLI to clone..." -ForegroundColor Gray
                    gh repo clone $repoSlug $privatePath 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "gh clone failed"
                    }
                } else {
                    # Fall back to git with token in URL (if we can get one)
                    $token = $null
                    try { $token = gh auth token 2>$null } catch {}

                    if ($token) {
                        $repoSlug = $PrivateRepo -replace 'https://github.com/' -replace '\.git$'
                        $tokenUrl = "https://$token@github.com/$repoSlug.git"
                        Write-Host "    Cloning with token..." -ForegroundColor Gray
                        & $script:GitExe clone $tokenUrl $privatePath 2>&1 | Out-Null
                    } else {
                        # Last resort - try normal git (may hang on GCM)
                        Write-Host "    Cloning (browser auth may appear)..." -ForegroundColor Yellow
                        & $script:GitExe clone $PrivateRepo $privatePath
                    }
                }
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
