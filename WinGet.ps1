# We don't *need* this, but it does make things a bit easier
Install-Module -Name Microsoft.WinGet.Client -Force

Set-WinGetUserSetting -UserSettings @{
    visual = @{
        progressBar = 'rainbow' # Very important
    }
    installBehavior = @{
        preferences = @{
            scope = 'machine'
            architectures = ,'x64' # Not sure this actually does anything here but may as well be explicit
        }
    }
}
# Install PowerShell 7 first because VS Build Tools uses MsiExec after returning and blocks it sometimes
winget install Microsoft.PowerShell --accept-source-agreements
# Build Tools is a dependancy for Rustup and also has some chunky arguments so also do it before the loop
winget install Microsoft.VisualStudio.2022.BuildTools --override (
    '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ' + 
    '--add Microsoft.VisualStudio.Component.Windows11SDK.22621 ' +
    '--quiet ' +
    '--norestart'
)
# We're just using WinGet directly instead of the cmdlet wrappers because those don't have the cool progress bar :(
$NicePackages = @(
    'Discord.Discord',
    'ezwinports.make',
    'Git.Git',
    'LLVM.LLVM',
    'Microsoft.PowerToys',
    'Microsoft.VisualStudioCode',
    'RamenSoftware.Windhawk',
    'Rustlang.Rustup',
    'ShareX.ShareX',
    'Valve.Steam',
    'voidtools.everything'
)
foreach($Package in $NicePackages) {
    winget install --id $Package --source winget
    Start-Sleep -Milliseconds 100 # This seems to help it not have random errors apparently
}
winget install Mozilla.Firefox --custom /PrivateBrowsingShortcut=false --source winget
# Spotify won't install from an elevated session so we have to do this nonsense
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut("$PSScriptRoot\Install.lnk")
$Shortcut.TargetPath = 'winget'
$Shortcut.Arguments = 'install Spotify.Spotify'
$Shortcut.Save()
explorer.exe "$PSScriptRoot\Install.lnk"
Start-Sleep 1 # We love race conditions don't we folks
Remove-Item -Path "$PSScriptRoot\Install.lnk"
