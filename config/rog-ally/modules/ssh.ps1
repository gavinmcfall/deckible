# SSH Module - SSH Server & Key Setup
# ====================================
# Configures SSH server for remote access and generates keys for GitHub auth.
#
# Features:
# - Enable OpenSSH Server for remote access to this device
# - Import authorized keys from private repo (allow other machines to SSH in)
# - Generate SSH keys for this device
# - Add keys to GitHub for git operations
#
# Security notes:
# - Use Tailscale or similar for secure access over internet
# - Don't expose SSH directly to internet without proper hardening

if (-not (Get-ConfigValue "install_ssh" $false)) {
    Write-Status "SSH module disabled in config" "Info"
    return
}

# =============================================================================
# SSH SERVER (OpenSSH Server)
# =============================================================================
# Enable SSH server so other machines can SSH into this device.

$enableSshServer = Get-ConfigValue "ssh_server_enable" $false

if ($enableSshServer) {
    Write-Status "Configuring OpenSSH Server..." "Info"

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would install/enable OpenSSH Server" "Info"
    } else {
        try {
            # Check if sshd service exists (OpenSSH Server already installed)
            $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue

            if (-not $sshd) {
                Write-Status "Installing OpenSSH Server..." "Info"

                # Check if OpenSSH capability is already present (just not enabled)
                $capability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }

                if ($capability.State -eq 'NotPresent') {
                    # Need to install - use DISM which is faster than Add-WindowsCapability
                    Write-Host "    Using DISM for faster install..." -ForegroundColor Gray
                    $dismResult = dism /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0 /NoRestart 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        # DISM failed, try Add-WindowsCapability as fallback
                        Write-Host "    DISM failed, trying Add-WindowsCapability..." -ForegroundColor Yellow
                        Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null
                    }
                    Write-Status "OpenSSH Server installed" "Success"
                } elseif ($capability.State -eq 'Staged') {
                    # Already staged, just enable it
                    Write-Host "    OpenSSH Server staged, enabling..." -ForegroundColor Gray
                    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
                    Write-Status "OpenSSH Server enabled" "Success"
                } else {
                    Write-Status "OpenSSH Server capability present" "Info"
                }

                # Refresh service reference
                Start-Sleep -Seconds 2
                $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
            } else {
                Write-Status "OpenSSH Server already installed" "Success"
            }

            # Configure and start the SSH server service
            if ($sshd) {
                # Set to automatic start
                Set-Service -Name sshd -StartupType Automatic

                # Start if not running
                if ($sshd.Status -ne 'Running') {
                    Start-Service sshd
                    Write-Status "SSH Server started" "Success"
                } else {
                    Write-Status "SSH Server already running" "Info"
                }

                # Also configure ssh-agent for key management
                $agent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
                if ($agent) {
                    Set-Service -Name ssh-agent -StartupType Automatic
                    if ($agent.Status -ne 'Running') {
                        Start-Service ssh-agent -ErrorAction SilentlyContinue
                    }
                }
            } else {
                Write-Status "SSH Server service not found after install - restart may be required" "Warning"
            }

            # Configure firewall rule
            $fwRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
            if (-not $fwRule) {
                New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' `
                    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
                Write-Status "Firewall rule added for SSH (port 22)" "Success"
            }

        } catch {
            Write-Status "Failed to configure SSH Server: $_" "Error"
        }
    }
}

# =============================================================================
# AUTHORIZED KEYS (Allow other machines to SSH in)
# =============================================================================
# Import public keys from private repo to allow SSH access from those machines.

$importAuthorizedKeys = Get-ConfigValue "ssh_import_authorized_keys" $false
$authorizedKeysList = Get-ConfigValue "ssh_authorized_keys" @()

if ($importAuthorizedKeys -and $authorizedKeysList.Count -gt 0) {
    Write-Status "Importing authorized SSH keys..." "Info"

    # Windows OpenSSH uses different authorized_keys location for admins
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        # Admin users use ProgramData location
        $authorizedKeysPath = Join-Path $env:ProgramData "ssh\administrators_authorized_keys"
        $sshConfigDir = Join-Path $env:ProgramData "ssh"
    } else {
        # Regular users use ~/.ssh/authorized_keys
        $authorizedKeysPath = Join-Path $env:USERPROFILE ".ssh\authorized_keys"
        $sshConfigDir = Join-Path $env:USERPROFILE ".ssh"
    }

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would import authorized keys to: $authorizedKeysPath" "Info"
        foreach ($keyFile in $authorizedKeysList) {
            Write-Status "[DRY RUN]   - $keyFile" "Info"
        }
    } else {
        try {
            # Ensure directory exists
            if (-not (Test-Path $sshConfigDir)) {
                New-Item -ItemType Directory -Path $sshConfigDir -Force | Out-Null
            }

            # Build authorized_keys content from private repo
            $keysContent = @()
            $privateRepoPath = $Script:PrivateRoot
            $keysDir = Join-Path $privateRepoPath "files\ssh-keys"

            foreach ($keyFile in $authorizedKeysList) {
                $keyPath = Join-Path $keysDir $keyFile
                if (Test-Path $keyPath) {
                    $keyContent = Get-Content $keyPath -Raw
                    $keysContent += $keyContent.Trim()
                    Write-Status "Added key: $keyFile" "Info"
                } else {
                    Write-Status "Key file not found: $keyFile" "Warning"
                }
            }

            if ($keysContent.Count -gt 0) {
                # Write authorized_keys file
                $keysContent -join "`n" | Set-Content -Path $authorizedKeysPath -Force -NoNewline

                # Set correct permissions for Windows OpenSSH
                if ($isAdmin) {
                    # administrators_authorized_keys needs special ACL
                    $acl = Get-Acl $authorizedKeysPath
                    $acl.SetAccessRuleProtection($true, $false)

                    # Only SYSTEM and Administrators should have access
                    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        "SYSTEM", "FullControl", "None", "None", "Allow"
                    )
                    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        "Administrators", "FullControl", "None", "None", "Allow"
                    )
                    $acl.AddAccessRule($systemRule)
                    $acl.AddAccessRule($adminRule)
                    Set-Acl $authorizedKeysPath $acl
                }

                Write-Status "Authorized keys imported ($($keysContent.Count) keys)" "Success"
            }
        } catch {
            Write-Status "Failed to import authorized keys: $_" "Error"
        }
    }
}

# =============================================================================
# SSH KEY GENERATION
# =============================================================================

$sshDir = Join-Path $env:USERPROFILE ".ssh"
$keyName = Get-ConfigValue "ssh_key_name" $env:COMPUTERNAME
$keyPath = Join-Path $sshDir "id_ed25519"
$keyComment = "$keyName@bootible"

# Ensure .ssh directory exists with correct permissions
if (-not (Test-Path $sshDir)) {
    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would create ~/.ssh directory" "Info"
    } else {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        # Set permissions - only current user should have access
        $acl = Get-Acl $sshDir
        $acl.SetAccessRuleProtection($true, $false)
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.AddAccessRule($userRule)
        Set-Acl $sshDir $acl
        Write-Status "Created ~/.ssh directory" "Success"
    }
}

# Generate SSH key if it doesn't exist
$generateKey = Get-ConfigValue "ssh_generate_key" $true

if ($generateKey) {
    if (Test-Path $keyPath) {
        Write-Status "SSH key already exists: $keyPath" "Info"
    } else {
        if ($Script:DryRun) {
            Write-Status "[DRY RUN] Would generate SSH key: $keyPath" "Info"
            Write-Status "[DRY RUN] Key comment: $keyComment" "Info"
        } else {
            Write-Status "Generating SSH key (ed25519)..." "Info"
            try {
                # Generate ed25519 key (modern, secure, fast)
                # -N "" means no passphrase (for automated use)
                $sshKeygenPath = "ssh-keygen"

                # Check if ssh-keygen exists
                $sshKeygen = Get-Command $sshKeygenPath -ErrorAction SilentlyContinue
                if (-not $sshKeygen) {
                    # Try Windows OpenSSH location
                    $sshKeygenPath = Join-Path $env:SystemRoot "System32\OpenSSH\ssh-keygen.exe"
                    if (-not (Test-Path $sshKeygenPath)) {
                        throw "ssh-keygen not found. Install OpenSSH Client feature."
                    }
                }

                # Generate the key
                & $sshKeygenPath -t ed25519 -C $keyComment -f $keyPath -N '""' 2>&1 | Out-Null

                if (Test-Path $keyPath) {
                    Write-Status "SSH key generated: $keyPath" "Success"
                    Write-Status "Key comment: $keyComment" "Info"
                } else {
                    throw "Key file not created"
                }
            } catch {
                Write-Status "Failed to generate SSH key: $_" "Error"
            }
        }
    }
}

# =============================================================================
# GITHUB SSH KEY SETUP
# =============================================================================

$addToGithub = Get-ConfigValue "ssh_add_to_github" $true
$Script:GitHubSshKeyReady = $false  # Track if key is ready on GitHub

if ($addToGithub -and (Test-Path "$keyPath.pub")) {
    # Check if gh CLI is available and authenticated
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Status "GitHub CLI (gh) not found - cannot add key to GitHub" "Warning"
        Write-Status "Run bootible again after gh is installed to add key" "Info"
    } else {
        # Check if already authenticated
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "GitHub CLI not authenticated - cannot add key" "Warning"
            Write-Status "Run 'gh auth login' first, then run bootible again" "Info"
        } else {
            if ($Script:DryRun) {
                Write-Status "[DRY RUN] Would add SSH key to GitHub: $keyComment" "Info"
                $Script:GitHubSshKeyReady = $true
            } else {
                Write-Status "Adding SSH key to GitHub..." "Info"
                try {
                    # Check if key already exists on GitHub
                    $existingKeys = gh ssh-key list 2>&1
                    $pubKeyContent = Get-Content "$keyPath.pub" -Raw
                    $keyFingerprint = $pubKeyContent.Split(" ")[1]

                    if ($existingKeys -match [regex]::Escape($keyComment)) {
                        Write-Status "SSH key '$keyComment' already exists on GitHub" "Info"
                        $Script:GitHubSshKeyReady = $true
                    } else {
                        # Add the key
                        $result = gh ssh-key add "$keyPath.pub" --title $keyComment 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Status "SSH key added to GitHub: $keyComment" "Success"
                            $Script:GitHubSshKeyReady = $true
                        } else {
                            # Key might already exist with different title
                            if ($result -match "already in use") {
                                Write-Status "SSH key already registered on GitHub (different title)" "Info"
                                $Script:GitHubSshKeyReady = $true
                            } else {
                                throw $result
                            }
                        }
                    }
                } catch {
                    Write-Status "Failed to add SSH key to GitHub: $_" "Error"
                }
            }
        }
    }
}

# =============================================================================
# SAVE PUBLIC KEY TO PRIVATE REPO
# =============================================================================

$saveToPrivate = Get-ConfigValue "ssh_save_to_private" $true
$privateRepoPath = Get-ConfigValue "ssh_private_repo_path" ""

# Auto-detect private repo path if not specified
if (-not $privateRepoPath -and $Script:PrivateRoot) {
    $privateRepoPath = $Script:PrivateRoot
}

if ($saveToPrivate -and $privateRepoPath -and (Test-Path "$keyPath.pub")) {
    $keysDir = Join-Path $privateRepoPath "ssh-keys"
    $keyBackupPath = Join-Path $keysDir "$keyName.pub"

    if ($Script:DryRun) {
        Write-Status "[DRY RUN] Would save public key to: $keyBackupPath" "Info"
    } else {
        try {
            # Create ssh-keys directory if needed
            if (-not (Test-Path $keysDir)) {
                New-Item -ItemType Directory -Path $keysDir -Force | Out-Null
            }

            # Copy public key
            Copy-Item "$keyPath.pub" $keyBackupPath -Force
            Write-Status "Public key saved to private repo: ssh-keys/$keyName.pub" "Success"

            # Git add (will be committed with log push)
            Push-Location $privateRepoPath
            git add "ssh-keys/$keyName.pub" 2>&1 | Out-Null
            Pop-Location
        } catch {
            Write-Status "Failed to save public key to private repo: $_" "Warning"
        }
    }
}

# =============================================================================
# CONFIGURE GIT TO USE SSH
# =============================================================================

$configureGitSsh = Get-ConfigValue "ssh_configure_git" $true

if ($configureGitSsh) {
    # Only switch git to SSH if the key is confirmed on GitHub
    if (-not $Script:GitHubSshKeyReady) {
        Write-Status "Skipping git SSH config - key not yet on GitHub" "Warning"
        Write-Status "Run bootible again after adding SSH key to GitHub" "Info"
    } elseif ($Script:DryRun) {
        Write-Status "[DRY RUN] Would configure Git to use SSH for GitHub" "Info"
    } else {
        Write-Status "Configuring Git to use SSH for GitHub..." "Info"
        try {
            # Set Git to use SSH for GitHub URLs
            # This rewrites https://github.com/ to git@github.com:
            git config --global url."git@github.com:".insteadOf "https://github.com/"
            Write-Status "Git configured to use SSH for GitHub" "Success"

            # Ensure SSH key is in ssh-agent (for this session)
            $sshAgent = Get-Service ssh-agent -ErrorAction SilentlyContinue
            if ($sshAgent -and $sshAgent.Status -ne 'Running') {
                Start-Service ssh-agent -ErrorAction SilentlyContinue
            }

            # Add key to agent
            if (Test-Path $keyPath) {
                ssh-add $keyPath 2>&1 | Out-Null
            }
        } catch {
            Write-Status "Git SSH configuration failed: $_" "Warning"
        }
    }
}

# =============================================================================
# DISPLAY KEY INFO
# =============================================================================

if (Test-Path "$keyPath.pub") {
    $pubKey = Get-Content "$keyPath.pub" -Raw
    Write-Status "Public key fingerprint:" "Info"
    # Get fingerprint using ssh-keygen if available
    $fingerprint = ssh-keygen -lf "$keyPath.pub" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $fingerprint" -ForegroundColor Cyan
    } else {
        # Fallback: show truncated key
        $keyParts = $pubKey.Split(" ")
        if ($keyParts.Count -ge 2) {
            $truncated = $keyParts[1].Substring(0, [Math]::Min(20, $keyParts[1].Length)) + "..."
            Write-Host "  $($keyParts[0]) $truncated" -ForegroundColor Cyan
        }
    }
}

Write-Status "SSH setup complete" "Success"
