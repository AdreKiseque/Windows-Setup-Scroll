#Requires -RunAsAdministrator

# API tomfoolery so the system stays awake :)
$ES_CONTINUOUS = 0x80000000
$ES_DISPLAY_REQUIRED = 0x00000002
$ES_SYSTEM_REQUIRED = 0x00000001
Add-Type -Name 'ThreadExecutionState' -Namespace 'Win32' -MemberDefinition @"
[DllImport("kernel32.dll", SetLastError = true)]
public static extern int SetThreadExecutionState(int esFlags);
"@
$State = $ES_CONTINUOUS -bor $ES_DISPLAY_REQUIRED -bor $ES_SYSTEM_REQUIRED
$OldState = [Win32.ThreadExecutionState]::SetThreadExecutionState($State)

Write-Host 'Process start'

# We need these guys if we're gonna take out Edge
Install-PackageProvider -Name NuGet -Force
Install-Module -Name ProcessEx -Force

Write-Host 'Configuring environment...'
#Region Environment
# Updating PATH
setx PATH "$Env:PATH;C:\Program Files\LLVM\bin" /M
# Bringing polite apps to a more suiting home
$Env:RUSTUP_HOME = "$Env:LOCALAPPDATA\Rust\Rustup"; setx RUSTUP_HOME $Env:RUSTUP_HOME
$Env:CARGO_HOME = "$Env:LOCALAPPDATA\Rust\Cargo"; setx CARGO_HOME $Env:CARGO_HOME
New-Item -ItemType Directory -Path "$Env:LOCALAPPDATA\ShareX" | Out-Null # Pipe to null to hide output
New-Item -Path 'HKLM:\SOFTWARE\ShareX' | Set-ItemProperty -Name 'PersonalPath' -Value "$Env:LOCALAPPDATA\ShareX"
# Bad and naughty apps who won't use AppData get sent to the folder of shame
New-Item -ItemType Directory -Path "$Env:USERPROFILE\AppData\Naughty" | Out-Null
$Env:HOME = "$Env:USERPROFILE\AppData\Naughty"; setx HOME $Env:HOME # Et tu, Git for Windows?
$ShellFolders = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
Set-ItemProperty -Path $ShellFolders -Name 'Personal' -Value $Env:HOME # OUT OF MY DOCUMENTS
# Saved Games isn't actually that bad but I don't want it in my User folder
Set-ItemProperty -Path $ShellFolders -Name '{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}' -Value "$Env:HOME\Saved Games"
Move-Item -Path "$Env:USERPROFILE\Saved Games" -Destination "$Env:HOME\Saved Games" -Force
#EndRegion
Write-Host "`nDone`n"

# Poking straight at the Registry because Settings has no API :/
Write-Host 'Setting more settings...'
#Region: Settings
# Enable dev mode (need for unelevated symlinks apparently?)
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1
# Notifications
New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' | # Not sure why this doesn't exist by default but ok
    Set-ItemProperty -Name 'ScoobeSystemSettingEnabled' -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-310093Enabled' -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338389Enabled' -Value 0
# Explorer and taskbar
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 # Align to left
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0
New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' | # ¯\_(ツ)_/¯
    Set-ItemProperty -Name 'TaskbarEndTask' -Value 1
New-Item -Path 'HKCU:\Software\Classes\CLSID\{E88865EA-0E1C-4E20-9AA6-EDCD0212C87C}' | # Hide Gallery in navigation pane
    Set-ItemProperty -Name 'System.IsPinnedToNameSpaceTree' -Value 0
New-Item -Path 'HKCU:\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' | # Hide Network
    Set-ItemProperty -Name 'System.IsPinnedToNameSpaceTree' -Value 0
# Touchpad gestures
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'ThreeFingerTapEnabled' -Value 4 # Middle click
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'ThreeFingerSlideEnabled' -Value 3 # Audio controls
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'FourFingerTapEnabled' -Value 0
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'FourFingerSlideEnabled' -Value 0
# These are like, extra-miscellaneous, I guess?
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 # Disable Game Bar (kinda)
Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 # Not sure this does anything on 11 but may as well be thorough
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisallowShaking' -Value 0 # Aero Shake!
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 # Disable fast startup
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Clipboard' -Name 'EnableClipboardHistory' -Value 1
Set-ItemProperty -Path 'HKCU:\Control Panel\Keyboard' -Name 'PrintScreenKeyForSnippingEnabled' -Value '0' # Love you ST but we're using ShareX
Set-ItemProperty -Path 'HKCU:\Control Panel\Accessibility\HighContrast' -Name 'Flags' -Value '4218' # Unbind Alt + Shift + PrtSc
# Reveal some sound customization options
Set-ItemProperty -Path 'HKCU:\AppEvents\EventLabels\SystemExit' -Name 'ExcludeFromCPL' -Value 0
Set-ItemProperty -Path 'HKCU:\AppEvents\EventLabels\WindowsLogoff' -Name 'ExcludeFromCPL' -Value 0
Set-ItemProperty -Path 'HKCU:\AppEvents\EventLabels\WindowsLogon' -Name 'ExcludeFromCPL' -Value 0
Set-ItemProperty -Path 'HKCU:\AppEvents\EventLabels\WindowsUnlock' -Name 'ExcludeFromCPL' -Value 0
# Just a few more
Set-ExecutionPolicy RemoteSigned
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true # Enable Task Scheduler history
attrib -h $env:USERPROFILE\AppData # Unhide AppData
attrib +h $env:USERPROFILE\Contacts 
attrib +h $env:USERPROFILE\Favorites
attrib +h $env:USERPROFILE\Links
attrib +h $env:USERPROFILE\Searches # Get these guys outta here
sudo config --enable normal
#EndRegion
Write-Host "Done`n"

# Language stuff
Write-Host 'Installing and configuring en-CA...'
# This operation is SLOW so we're having it run in the background as a job while we do other stuff
$LangJob = Install-Language en-CA -AsJob

$LanguageList = New-WinUserLanguageList en-CA
$LanguageList[0].InputMethodTips[0] = '1009:00020409' # US-International keyboard
Set-WinUserLanguageList $LanguageList -Force

Set-WinHomeLocation -GeoId 0x27

Set-WinSystemLocale en-CA

Set-Culture en-CA

Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

# Installing things
# I was originally using winget import for this but it turns out it kinda sucks so
Write-Host 'Invoking Windows Package Manager...'
&$PSScriptRoot\WinGet.ps1
Write-Host 'OK'

Write-Host 'Making arrangements for the removal of Edge...'
#Region Edge nonsense
# The process of removing Edge is a delicate one. It will typically comply with valid requests politely, but can sometimes respond unexpectedly...
# More specifically, the uninstaller is thorough and effective when invoked properly,
# but unfortunately-timed update processes can cause bizarre behaviour like immediate reïnstallation, or even block it from starting entirely.
# It's rare, but to be safe, we're doing this in two parts: disabling the automatic updates first... 
Get-Service -Name edgeupdate* | Set-Service -StartupType Disabled
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* | Disable-ScheduledTask
# ...then carrying out the actual uninstallation on next boot, before anything has the chance to get in the way.
$Action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "$PSScriptRoot\RemoveEdge.ps1"
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Compatibility Win8 # 8 = 10 = 11, naturally
# Honestly have no idea if this will work but here's hoping
Register-ScheduledTask -Action $Action -Principal $Principal -Trigger $Trigger -Settings $Settings  -TaskName 'Remove Edge'
# Remove provisioned package for good measure
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.MicrosoftEdge.Stable |
    Remove-AppxProvisionedPackage -PackageName { $_.PackageName } -Online
Write-Host "The plan is set in motion.`n"
Start-Sleep -Seconds 3 # For pacing
#EndRegion

# Taking out the trash
Write-Host 'Uninstalling common BLOAT...'
$ThingsToRemove = @(
    'Clipchamp.Clipchamp',
    'Microsoft.BingNews',
    'Microsoft.BingSearch',
    'Microsoft.BingWeather',
    'Microsoft.GamingApp',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxGamingOverlay', # If you had just coöperated it wouldn't have had to come to this
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftStickyNotes',
    'Microsoft.OutlookForWindows',
    'Microsoft.Todos',
    'MSTeams',
    'Microsoft.Windows.DevHome',
    'Microsoft.Copilot',
    'Microsoft.StartExperiencesApp'
)
foreach($Thing in $ThingsToRemove) {
    Get-AppxPackage $Thing | Remove-AppxPackage -AllUsers
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $Thing | Remove-AppxProvisionedPackage -PackageName { $_.PackageName } -Online
}
Write-Host "Done`n"

# Schedule second part of the script to run once the computer restarts
Set-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name '!Finish Setup' -Value "pwsh -NoExit $PSScriptRoot\Setup2.ps1"

# DISM tends to run into some issues when running multiple instances at once
if ($LangJob.JobStateInfo.State -eq 'Running') {
   Write-Host 'Waiting for background tasks to complete before proceeding...'
}
Receive-Job $LangJob -Wait

# Remove unneeded features
Write-Host 'Uninstalling PowerShell ISE...'
Get-WindowsCapability -Online -Name Microsoft.Windows.PowerShell.ISE* | Remove-WindowsCapability -Online
"Done`n", 'Uninstalling Edge Internet Explorer Mode...' | Write-Host
Get-WindowsCapability -Online -Name Browser.InternetExplorer* | Remove-WindowsCapability -Online
"Done`n", 'Uninstalling Windows Hello Facial Recognition...' | Write-Host
Get-WindowsCapability -Online -Name Hello.Face* | Remove-WindowsCapability -Online
"Done`n", 'Uninstalling VBScript...' | Write-Host
Get-WindowsCapability -Online -Name VBSCRIPT* | Remove-WindowsCapability -Online
"Done`n", 'Uninstalling Windows PowerShell 2.0...' | Write-Host
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
Write-Host "Done`n"

Write-Host 'Removing leftover en-GB components that are out of use...'
Get-WindowsCapability -Online -Name Language.Handwriting~~~en-GB* | Remove-WindowsCapability -Online
Get-WindowsCapability -Online -Name Language.Speech~~~en-GB* | Remove-WindowsCapability -Online
Get-WindowsCapability -Online -Name Language.TextToSpeech~~~en-GB* | Remove-WindowsCapability -Online
Get-WindowsCapability -Online -Name Language.OCR~~~en-GB* | Remove-WindowsCapability -Online
Write-Host "Done`n"

# Enable Windows Sandbox
Write-Host 'Enabling Windows Sandbox...'
#Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -NoRestart
Write-Host "Done`n"

wsl --install

$Player = New-Object System.Media.SoundPlayer
$Player.SoundLocation = "$PSScriptRoot\Assets\Notify.wav"
$Player.Play()

$Confirmation = $Host.UI.PromptForChoice(
    'Restart?',
    'The computer must restart to continue with setup. Would you like to restart now?',
    ('&Yes', '&No'),
    0)
[Win32.ThreadExecutionState]::SetThreadExecutionState($OldState) | Out-Null # Disable the forced awake state
if ($Confirmation -eq 0) {
    Write-Host 'See you soon.'
    Restart-Computer
} else {
    Write-Host 'It''s ok; take your time, sweetie.'
}
