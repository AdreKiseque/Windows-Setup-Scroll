#Requires -RunAsAdministrator

#Region Functions
function Set-FolderIcon { # Stole this from https://github.com/jimbrig/PSScripts/blob/main/src/Set-FolderIcon/Set-FolderIcon.ps1 (Thanks Jim)
    param (
        [Parameter(Mandatory)]
        [string]$Icon,
        [Parameter(Mandatory)]
        [string]$Path
    )
    $DesktopIni = "[.ShellClassInfo]`n" + "IconResource=$Icon`n"

    Add-Content "$Path\desktop.ini" -Value $DesktopIni
    (Get-Item "$Path\desktop.ini" -Force).Attributes = 'Hidden, System, Archive'
    (Get-Item $Path -Force).Attributes = 'ReadOnly, Directory'
}

function New-SoundScheme { # Did my best to replicate what happens when you change the scheme through the GUI... it's some nonsense I'll tell you
    param (
        [Parameter(Mandatory)]
        [string]$SchemeName,
        [switch]$SetScheme,
        [switch]$CopyFromDefault
    )
    New-Item -Path "HKCU:\AppEvents\Schemes\Names\$SchemeName" -Value $SchemeName | Out-Null # Hush
    if($CopyFromDefault){
        $Source = '.Default'
    } else {
        $Source = '.Current'
    }
    $SoundKeys = Get-ChildItem 'HKCU:\AppEvents\Schemes\Apps' | Get-ChildItem # Get-ChildItem²...
    | Where-Object Name -NotMatch 'Notification.Looping' 
    foreach($Key in $SoundKeys) {
        Copy-Item -Path "Registry::$Key\$Source" -Destination "Registry::$Key\$SchemeName"
        if($SetScheme -and $CopyFromDefault) {
            Get-ItemPropertyValue -Path "$Key\$Source" -Name '(Default)' | Set-ItemProperty -Path "$Key\.Current" -Name '(Default)'
        }
    }
    if($SetScheme) {
        Set-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(Default)' -Value $SchemeName
    }
}

function Set-SystemSound { 
    param (
        [Parameter(Mandatory)]
        [string]$EventKey,
        [Parameter(Mandatory)]
        [string]$SoundPath,
        [string]$Scheme
    )
    $EventKey = "HKCU:\AppEvents\Schemes\Apps\$EventKey"
    Set-ItemProperty -Path "$EventKey\.Current" -Name '(Default)' -Value $SoundPath
    if($Scheme) {
        Set-ItemProperty -Path "$EventKey\$Scheme" -Name '(Default)' -Value $SoundPath
    }
}
#EndRegion

# Extract assets
New-Item -ItemType Directory -Path "$env:USERPROFILE\Arcana"
$IconPath = New-Item -ItemType Directory -Path "$env:LocalAppData\CustomIcons"
Move-Item -Path "$PSScriptRoot\Assets\*.ico" -Destination $IconPath
$SoundPath = New-Item -ItemType Directory -Path "$env:WinDir\Media\CustomSounds"
Move-Item -Path "$PSScriptRoot\Assets\Windows Logon Sound.wav" -Destination "$env:WinDir\Media" -Force
Move-Item -Path "$PSScriptRoot\Assets\*.wav" -Destination $SoundPath
# One (1) font
$Shell = New-Object -ComObject Shell.Application
$Folder = $Shell.Namespace("$PSScriptRoot\Assets")
$File = $Folder.ParseName('SymbolsNerdFont-Regular.ttf')
# What the hell Windows
$File.Verbs() | Where-Object { $_.Name -Replace '\p{P}' -eq 'Install' } | ForEach-Object { $_.DoIt() }

# Set icons
Set-FolderIcon -Icon "$IconPath\programmer-2.ico" -Path "$env:USERPROFILE\Arcana"
Set-FolderIcon -Icon "$IconPath\apps.ico" -Path "$env:USERPROFILE\AppData"

# Set sounds
$Scheme = 'Mounder Special'
# Shoutouts to David Mounder and his awesome work reïmagining Windows sounds! https://youtu.be/Fto1ePGFq_o
New-SoundScheme -SchemeName $Scheme -SetScheme
#Region Setting all the sounds
Set-SystemSound -Scheme $Scheme -EventKey '.Default\.Default'               -SoundPath "$SoundPath\Ding"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\AppGPFault'             -SoundPath "$SoundPath\Default.wav" # Don't know when or if this is used
Set-SystemSound -Scheme $Scheme -EventKey '.Default\CriticalBatteryAlarm'   -SoundPath "$SoundPath\Battery Critical.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\LowBatteryAlarm'        -SoundPath "$SoundPath\Battery Low.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\PrintComplete'          -SoundPath "$SoundPath\TADA.WAV"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\SystemAsterisk'         -SoundPath "$SoundPath\Error.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\SystemExclamation'      -SoundPath "$SoundPath\Exclamation.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\SystemExit'             -SoundPath "$SoundPath\Shutdown 7.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\SystemHand'             -SoundPath "$SoundPath\Critical Stop.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\SystemNotification'     -SoundPath "$SoundPath\Notify.wav"
Set-SystemSound -Scheme $Scheme -EventKey '.Default\WindowsUAC'             -SoundPath "$SoundPath\User Account Control.wav"
#EndRegion

$AD = "$Env:AppData\Microsoft\Windows\Start Menu\Programs"
#$PD = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs"

# Configure apps
New-Item -ItemType Directory -Path "$Env:HOME\PowerShell" -ErrorAction SilentlyContinue
Add-Content $PROFILE {
    function prompt { # Secure password
      "`e[93m$Env:USERNAME`e[37m@`e[93m$Env:COMPUTERNAME `e[90m[$(Get-Date -Format HH:mm:ss)]`n" +
      "`e[94mPS`e[5;95m✦ `e[97;25m$PWD`e[0m➤ "
    }
}
rustup completions powershell > "$Env:HOME\PowerShell\RustupCompletions.ps1"
Add-Content $PROFILE '. "$Env:HOME\PowerShell\RustupCompletions.ps1"'
# Unsupported :sob:
#rustup completions powershell cargo > "$Env:HOME\PowerShell\CargoCompletions.ps1"
#Add-Content $PROFILE '. "$Env:HOME\PowerShell\CargoCompletions.ps1"'

Stop-Process -Name "PowerToys"
# HAVE tested and DOES work!
Expand-Archive -Path "$PSScriptRoot\AppConfig\PowerToysBackup.ptb" -DestinationPath "$env:LocalAppData\Microsoft\PowerToys" -Force # Also a zip file
New-Item -ItemType Directory -Path "$env:HOME\PowerToys\Backup" -Force
Copy-Item -Path "$PSScriptRoot\AppConfig\PowerToysBackup.ptb" "$env:HOME\PowerToys\Backup" -Force
Start-Process -FilePath "$env:LocalAppData\PowerToys\PowerToys.exe"

Copy-Item -Path "$PSScriptRoot\AppConfig\settings.json" "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" -Force

Stop-Process -Name 'ShareX' # Put ShareX to sleep for maintenance
Expand-Archive -Path "$PSScriptRoot\AppConfig\ShareX-21.0.0-backup.sxb" -DestinationPath "$env:LocalAppData\ShareX" -Force # Apparently this is a zip file??
$Action = New-ScheduledTaskAction -Execute 'C:\Program Files\ShareX\ShareX.exe' -Argument '-silent'
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Compatibility Win8
# Run ShareX as admin so it works on elevated windows
Register-ScheduledTask -Action $Action -RunLevel Highest -Trigger $Trigger -Settings $Settings -TaskName 'ShareX'
Remove-Item "$AD\Startup\ShareX.lnk" # Get rid of old autostart
# I couldn't tell you why but this seems to cause minor issues if you've signed into you Microsoft account beforehand (reïmporting manually fixes it)
Start-Process -FilePath 'C:\Program Files\ShareX\ShareX.exe' -ArgumentList '-silent'

Enable-ComputerRestore -Drive 'C:\'

$Player = New-Object System.Media.SoundPlayer
$Player.SoundLocation = "$SoundPath\TADA.WAV"
$Player.Play()

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("📎 Looks like you've just finished setting up your PC`n Press OK to create a System Restore point.")

Checkpoint-Computer -Description 'Complete Setup'
