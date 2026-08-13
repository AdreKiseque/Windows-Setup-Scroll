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
Move-Item -Path "$Env:USERPROFILE\Saved Games" -Destination "$Env:HOME\Saved Games" -Force # Unreliable?
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
$LanguageList[0].InputMethodTips.Add('1009:00000409')
Set-WinUserLanguageList $LanguageList -Force

Set-WinHomeLocation -GeoId 0x27

Set-WinSystemLocale en-CA

Set-Culture en-CA

Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

# Installing things

# I'm pretty sure Docker depends on WSL, and I'm pretty sure WSL installs more nicely if Sandbox is already added so they've been moved up
Write-Host 'Enabling Windows Sandbox...'
Enable-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM -NoRestart
Write-Host "Done`n"

wsl --install

# We don't *need* this, but it does make things a bit easier
Install-Module -Name Microsoft.WinGet.Client -Force

# Make sure we're on the latest version because we depend on some more recent features
Repair-WinGetPackageManager -Force -Latest -AllUsers

Set-WinGetUserSetting -UserSettings @{
    visual = @{
        progressBar = 'rainbow' # Very important
    }
    installBehavior = @{
        preferences = @{
            architectures = ,'x64' # Not sure this actually does anything here but may as well be explicit
        }
    }
}
# winget import sucks less now!
Write-Host 'Invoking Windows Package Manager...'
winget import $PSScriptRoot\AppConfig\winget.json --accept-source-agreements --accept-package-agreements
Write-Host 'OK'

# Taking out the trash
Write-Host 'Eliminating clutter...'
$ThingsToRemove = @(
    'Clipchamp.Clipchamp',
    'Microsoft.BingNews',
    'Microsoft.BingSearch',
    'Microsoft.BingWeather',
    'Microsoft.GamingApp',
    'Microsoft.Xbox.TCUI',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftStickyNotes',
    'Microsoft.OutlookForWindows',
    'Microsoft.Todos',
    'MSTeams',
    'Microsoft.Windows.DevHome',
    'Microsoft.Copilot'
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
Remove-WindowsCapability -Online -Name Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0
"Done`n", 'Uninstalling Edge Internet Explorer Mode...' | Write-Host
Remove-WindowsCapability -Online -Name Browser.InternetExplorer~~~~0.0.11.0
"Done`n", 'Uninstalling Windows Hello Facial Recognition...' | Write-Host
Remove-WindowsCapability -Online -Name Hello.Face.20134~~~~0.0.1.0
"Done`n", 'Uninstalling VBScript...' | Write-Host
Remove-WindowsCapability -Online -Name VBSCRIPT~~~~
Write-Host "Done`n"

Write-Host 'Removing leftover en-GB components that are out of use...'
Remove-WindowsCapability -Online -Name Language.Handwriting~~~en-GB~0.0.1.0
Remove-WindowsCapability -Online -Name Language.Speech~~~en-GB~0.0.1.0
Remove-WindowsCapability -Online -Name Language.TextToSpeech~~~en-GB~0.0.1.0
Remove-WindowsCapability -Online -Name Language.OCR~~~en-GB~0.0.1.0 # This sucks
Write-Host "Done`n"

$Player = New-Object System.Media.SoundPlayer
$Player.SoundLocation = "$PSScriptRoot\Assets\Notify.wav"
$Player.Play()

$Confirmation = $Host.UI.PromptForChoice(
    'Edstart?',
    'Þe reckoner must edstart to þroughwone wiþ setup. Wouldst þu like to edstart now?',
    ('&Yea', '&Nay'),
    0)
[Win32.ThreadExecutionState]::SetThreadExecutionState($OldState) | Out-Null # Disable the forced awake state
if ($Confirmation -eq 0) {
    Write-Host 'See þee soon :)'
    Restart-Computer
} else {
    Write-Host 'It''s ok; take þy time, sweetie.'
}
