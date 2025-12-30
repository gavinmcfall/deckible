# Bootible Git Auth Test
# Tests the QR code + popup authentication flow

$ErrorActionPreference = "Stop"

function Show-DeviceCodePopup {
    param([string]$Code, [string]$QrUrl)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "GitHub Login"
    $form.Size = New-Object System.Drawing.Size(500, 420)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Text = "Scan QR or enter code:"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(140, 15)
    $form.Controls.Add($title)

    # Large code display
    $codeLabel = New-Object System.Windows.Forms.Label
    $codeLabel.Text = $Code
    $codeLabel.Font = New-Object System.Drawing.Font("Consolas", 42, [System.Drawing.FontStyle]::Bold)
    $codeLabel.ForeColor = [System.Drawing.Color]::FromArgb(88, 166, 255)
    $codeLabel.AutoSize = $true
    $codeLabel.Location = New-Object System.Drawing.Point(100, 50)
    $form.Controls.Add($codeLabel)

    # QR Code
    $qrBox = New-Object System.Windows.Forms.PictureBox
    $qrBox.Size = New-Object System.Drawing.Size(180, 180)
    $qrBox.Location = New-Object System.Drawing.Point(155, 120)
    $qrBox.SizeMode = "Zoom"
    $qrBox.BackColor = [System.Drawing.Color]::White

    try {
        $wc = New-Object System.Net.WebClient
        $bytes = $wc.DownloadData($QrUrl)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $qrBox.Image = [System.Drawing.Image]::FromStream($ms)
    } catch {
        $qrBox.BackColor = [System.Drawing.Color]::Gray
    }
    $form.Controls.Add($qrBox)

    # Status
    $status = New-Object System.Windows.Forms.Label
    $status.Text = "Waiting for login..."
    $status.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $status.ForeColor = [System.Drawing.Color]::Gray
    $status.AutoSize = $true
    $status.Location = New-Object System.Drawing.Point(175, 310)
    $form.Controls.Add($status)

    # Close button
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Done"
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $btn.Size = New-Object System.Drawing.Size(140, 40)
    $btn.Location = New-Object System.Drawing.Point(175, 340)
    $btn.BackColor = [System.Drawing.Color]::FromArgb(46, 160, 67)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.FlatStyle = "Flat"
    $btn.Add_Click({ $form.Close() })
    $form.Controls.Add($btn)

    $form.Show()
    return @{ Form = $form; Status = $status }
}

Write-Host ""
Write-Host "=== GitHub Auth Test ===" -ForegroundColor Cyan
Write-Host ""

# Install gh if needed
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
    $msi = "$env:TEMP\gh.msi"
    Invoke-WebRequest -Uri "https://github.com/cli/cli/releases/download/v2.63.2/gh_2.63.2_windows_amd64.msi" -OutFile $msi -UseBasicParsing
    Start-Process msiexec -ArgumentList "/i `"$msi`" /quiet" -Wait
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    Remove-Item $msi -Force -ErrorAction SilentlyContinue
}

# Check if already authed
$ErrorActionPreference = "SilentlyContinue"
$null = & gh auth status 2>&1
$authed = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"

if ($authed) {
    Write-Host "Already authenticated!" -ForegroundColor Green
    gh auth status
    return
}

# Get device code from GitHub API (request JSON response)
Write-Host "Getting login code..." -ForegroundColor Gray
$clientId = "178c6fc778ccc68e1d6a"
$headers = @{ "Accept" = "application/json" }
$resp = Invoke-RestMethod -Uri "https://github.com/login/device/code" -Method Post -Body "client_id=$clientId&scope=repo,read:org" -ContentType "application/x-www-form-urlencoded" -Headers $headers

$userCode = $resp.user_code
$deviceCode = $resp.device_code
$interval = $resp.interval
$url = $resp.verification_uri_complete  # GitHub provides URL with code pre-filled!

if (-not $userCode) {
    Write-Host "Failed to get code!" -ForegroundColor Red
    return
}
$qr = "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$([uri]::EscapeDataString($url))"
$ui = Show-DeviceCodePopup -Code $userCode -QrUrl $qr

Write-Host "Code: $userCode" -ForegroundColor Cyan
Write-Host "Scan QR or go to: github.com/login/device" -ForegroundColor Gray
Write-Host ""

# Poll for auth
$token = $null
$tokenHeaders = @{ "Accept" = "application/json" }
while ($ui.Form.Visible) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Seconds $interval

    try {
        $tr = Invoke-RestMethod -Uri "https://github.com/login/oauth/access_token" -Method Post -Body "client_id=$clientId&device_code=$deviceCode&grant_type=urn:ietf:params:oauth:grant-type:device_code" -ContentType "application/x-www-form-urlencoded" -Headers $tokenHeaders -ErrorAction SilentlyContinue
        if ($tr.access_token) {
            $token = $tr.access_token
            $ui.Status.Text = "Success!"
            $ui.Status.ForeColor = [System.Drawing.Color]::LightGreen
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Seconds 1
            $ui.Form.Close()
        }
    } catch {}
}

$ui.Form.Dispose()

if ($token) {
    Write-Host "Saving to gh..." -ForegroundColor Gray
    $token | & gh auth login --with-token 2>&1 | Out-Null
    Write-Host ""
    Write-Host "SUCCESS!" -ForegroundColor Green
    gh auth status
} else {
    Write-Host "Cancelled or timed out" -ForegroundColor Yellow
}
