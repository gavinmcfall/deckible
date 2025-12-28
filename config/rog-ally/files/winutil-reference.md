# WinUtil Configuration Reference

All available options for `winutil-config.json`. Copy items you want into the appropriate array.

**Usage:**
```powershell
iex "& { $(irm christitus.com/win) } -Config .\winutil-config.json -Run"
```

---

## WPFTweaks - System Tweaks

### Essential Tweaks (Safe)

| Key | Description |
|-----|-------------|
| `WPFTweaksRestorePoint` | Create Restore Point (recommended first!) |
| `WPFTweaksTele` | Disable Telemetry |
| `WPFTweaksConsumerFeatures` | Disable ConsumerFeatures (suggested apps, tips) |
| `WPFTweaksServices` | Set Services to Manual (reduces background usage) |
| `WPFTweaksDVR` | Disable GameDVR (improves gaming performance) |
| `WPFTweaksActivity` | Disable Activity History |
| `WPFTweaksLocation` | Disable Location Tracking |
| `WPFTweaksHiber` | Disable Hibernation (saves disk space) |
| `WPFTweaksDiskCleanup` | Run Disk Cleanup |
| `WPFTweaksDeleteTempFiles` | Delete Temporary Files |
| `WPFTweaksEndTaskOnTaskbar` | Enable End Task With Right Click |

### Customize Preferences (Toggles)

| Key | Description | Default State |
|-----|-------------|---------------|
| `WPFToggleDarkMode` | Dark Theme for Windows | Enable |
| `WPFToggleBingSearch` | Bing Search in Start Menu | Disable |
| `WPFToggleNumLock` | NumLock on Startup | Enable |
| `WPFToggleVerboseLogon` | Verbose Messages During Logon | Enable |
| `WPFToggleStartMenuRecommendations` | Recommendations in Start Menu | Disable |
| `WPFToggleHideSettingsHome` | Remove Settings Home Page | Enable |
| `WPFToggleSnapWindow` | Snap Window | Keep On |
| `WPFToggleSnapFlyout` | Snap Assist Flyout | Disable |
| `WPFToggleSnapSuggestion` | Snap Assist Suggestion | Disable |
| `WPFToggleMouseAcceleration` | Mouse Acceleration | Disable |
| `WPFToggleStickyKeys` | Sticky Keys | Disable |
| `WPFToggleHiddenFiles` | Show Hidden Files | Enable |
| `WPFToggleShowExt` | Show File Extensions | Enable |
| `WPFToggleTaskbarSearch` | Search Button in Taskbar | Disable |
| `WPFToggleTaskView` | Task View Button in Taskbar | Disable |
| `WPFToggleTaskbarWidgets` | Widgets Button in Taskbar | Disable |
| `WPFToggleTaskbarAlignment` | Center Taskbar Items | Keep/Change |
| `WPFToggleDetailedBSoD` | Detailed BSoD | Enable |
| `WPFToggleMultiplaneOverlay` | Disable Multiplane Overlay | Disable |
| `WPFToggleS3Sleep` | S3 Sleep | Enable |

### Advanced Tweaks (Use Caution)

| Key | Description | Warning | Choice |
|-----|-------------|---------|--------|
| `WPFTweaksRemoveCopilot` | Disable Microsoft Copilot | | Yes |
| `WPFTweaksRightClickMenu` | Set Classic Right-Click Menu | Win11 | Yes |
| `WPFTweaksEdgeDebloat` | Edge Debloat | | Yes |
| `WPFTweaksDisableEdge` | Disable Edge | May break things | Yes |
| `WPFTweaksMakeEdgeUninstallable` | Make Edge Uninstallable | | No |
| `WPFTweaksPowershell7` | Default Terminal: PowerShell 7 | Requires PS7 | Yes |
| `WPFTweaksPowershell7Tele` | Disable Powershell 7 Telemetry | | Yes |
| `WPFTweaksStorage` | Disable Storage Sense | | No |
| `WPFTweaksDisableBGapps` | Disable Background Apps | May break notifications | No | 
| `WPFTweaksDisableFSO` | Disable Fullscreen Optimizations | Gaming | Yes |
| `WPFTweaksDisableNotifications` | Disable Notification Tray/Calendar | | No |
| `WPFTweaksRemoveHome` | Remove Home from Explorer | Win11 | No |
| `WPFTweaksRemoveGallery` | Remove Gallery from Explorer | Win11 | No |
| `WPFTweaksDisplay` | Set Display for Performance | | Disable |
| `WPFTweaksIPv46` | Prefer IPv4 over IPv6 | | Yes |
| `WPFTweaksTeredo` | Disable Teredo | | Yes |
| `WPFTweaksDisableIPv6` | Disable IPv6 | May break some apps | No |
| `WPFTweaksUTC` | Set Time to UTC | For dual boot | No |
| `WPFTweaksBlockAdobeNet` | Adobe Network Block | | No |
| `WPFTweaksRazerBlock` | Block Razer Software Installs | | No |
| `WPFTweaksBraveDebloat` | Brave Browser Debloat | | No
| `WPFTweaksLaptopHibernation` | Set Hibernation as Default | For laptops | No
| `WPFTweaksDeBloat` | Remove ALL MS Store Apps | NOT RECOMMENDED | No |
| `WPFTweaksWPBT` | Disable Windows Platform Binary Table | | No |

### Performance Plans

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFAddUltPerf` | Add and Activate Ultimate Performance Profile | No
| `WPFRemoveUltPerf` | Remove Ultimate Performance Profile | No | 

---

## WPFInstall - Applications

### Browsers

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallbrave` | Brave Browser | off
| `WPFInstallchrome` | Google Chrome | off
| `WPFInstallchromium` | Chromium | off
| `WPFInstallfirefox` | Firefox | off
| `WPFInstallfloorp` | Floorp | off
| `WPFInstalllibrewolf` | LibreWolf | off
| `WPFInstallvivaldi` | Vivaldi | off
| `WPFInstallwaterfox` | Waterfox | off
| `WPFInstallzen` | Zen Browser | off

### Communications

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstalldiscord` | Discord | off
| `WPFInstallsignal` | Signal | off
| `WPFInstalltelegram` | Telegram | off
| `WPFInstallslack` | Slack | off
| `WPFInstallteams` | Microsoft Teams | off
| `WPFInstallzoom` | Zoom | off
| `WPFInstallthunderbird` | Thunderbird | off
| `WPFInstallmailspring` | Mailspring | off

### Media

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallvlc` | VLC Media Player | off
| `WPFInstallmpv` | mpv | off
| `WPFInstallspotify` | Spotify | off
| `WPFInstallitunes` | iTunes | off
| `WPFInstallaimp` | AIMP | off
| `WPFInstallaudacity` | Audacity | off
| `WPFInstallhandbrake` | HandBrake | off
| `WPFInstallobs` | OBS Studio | off
| `WPFInstallkodi` | Kodi | off
| `WPFInstallplex` | Plex | off
| `WPFInstalljellyfin` | Jellyfin | off
| `WPFInstallstremio` | Stremio | off

### Gaming

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallsteam` | Steam | off
| `WPFInstallepicgames` | Epic Games Launcher | off
| `WPFInstallgog` | GOG Galaxy | off
| `WPFInstalleaapp` | EA App | off
| `WPFInstallubisoftconnect` | Ubisoft Connect | off
| `WPFInstallbattlenet` | Battle.net | off
| `WPFInstallprismlauncherqt5` | Prism Launcher (Minecraft) | off
| `WPFInstallplaynite` | Playnite | off
| `WPFInstallsunshine` | Sunshine (Game Streaming Server) | off
| `WPFInstallmoonlight` | Moonlight (Game Streaming Client) | off
| `WPFInstallparsec` | Parsec | off

### Utilities

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstall7zip` | 7-Zip | on
| `WPFInstalleverything` | Everything Search | on
| `WPFInstallpowertoys` | Microsoft PowerToys | on
| `WPFInstallwindowsterminal` | Windows Terminal | on
| `WPFInstallpowershell` | PowerShell 7 | on
| `WPFInstallnotepadplusplus` | Notepad++ | off
| `WPFInstallvscode` | Visual Studio Code | off
| `WPFInstallsublime` | Sublime Text | off
| `WPFInstallwinscp` | WinSCP | off
| `WPFInstallputty` | PuTTY | off
| `WPFInstallfilezilla` | FileZilla | off
| `WPFInstallbitwarden` | Bitwarden | off
| `WPFInstall1password` | 1Password | off
| `WPFInstallkeepassxc` | KeePassXC | off
| `WPFInstallsyncthing` | Syncthing | off
| `WPFInstallnordvpn` | NordVPN | off
| `WPFInstallmullvadvpn` | Mullvad VPN | off
| `WPFInstalltailscale` | Tailscale | off
| Add protonVPN in here

### Remote Access

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallanydesk` | AnyDesk | off
| `WPFInstallrustdesk` | RustDesk | off
| `WPFInstallteamviewer` | TeamViewer | off
| `WPFInstallremotedesktop` | Microsoft Remote Desktop | off

### Development

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallgit` | Git | on
| `WPFInstallgithubdesktop` | GitHub Desktop | off
| `WPFInstallpython3` | Python 3 | on
| `WPFInstallnodejslts` | Node.js LTS | on
| `WPFInstalljava` | Java (OpenJDK) | on
| `WPFInstalldocker` | Docker Desktop | off
| `WPFInstallwsl` | WSL (Windows Subsystem for Linux) | off

### System Tools

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstallhwinfo` | HWiNFO | on
| `WPFInstallcpuz` | CPU-Z | on
| `WPFInstallgpuz` | GPU-Z | on
| `WPFInstallmsiafterburner` | MSI Afterburner | on
| `WPFInstallrtss` | RivaTuner Statistics Server | off
| `WPFInstallcoretemps` | Core Temp | off
| `WPFInstallcrystaldiskinfo` | CrystalDiskInfo | off
| `WPFInstallcrystaldiskmark` | CrystalDiskMark | off
| `WPFInstallwiztree` | WizTree | off
| `WPFInstallrevo` | Revo Uninstaller | onb
| `WPFInstallbleachbit` | BleachBit | off
| `WPFInstallccleaner` | CCleaner | on
| `WPFInstallglaryutilities` | Glary Utilities | off

### Drivers & Runtimes

| Key | Description | Choice |
|-----|-------------|--------|
| `WPFInstalldotnet` | .NET Runtime | on
| `WPFInstalldotnetdesktop` | .NET Desktop Runtime | on
| `WPFInstallvc2015_2022` | Visual C++ 2015-2022 | on
| `WPFInstalldirectx` | DirectX End-User Runtime | on
