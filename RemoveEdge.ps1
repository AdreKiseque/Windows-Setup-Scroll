#Requires -RunAsAdministrator

# Making *extra sure* these guys are off and not in the way (This task *should* run before any of them get a chance to start even if enabled)
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* | Disable-ScheduledTask
Get-Service -Name edgeupdate* | Set-Service -StartupType Disabled
<# Ok so this part is really weird, basically Edge won't uninstall unless it's called by like, an approved process
So we're kinda spoofing the parent to make it play along
The two approved guys I've identified are SystemSettings.exe when you remove through Settings and DllHost.exe for when you remove through CPL
Settings works but the process needs to be running, and Settings always opens in another window and stuff 
Also, it forces the UAC prompt even when started from an elevated terminal
DllHost runs in the background and skips the UAC confirmation...
But it's a little risky to just snag onto any running DllHost instance, since they could terminate at any moment
And we can't just start our own DllHost, as they terminate immediately with nothing to do
So we're starting a service that happens to manifest in a DllHost process, and piggybacking off of it to get rid of Edge safely #>
Start-Service -Name COMSysApp
$Parent = Get-CimInstance -ClassName Win32_Service -Filter "Name = 'COMSysApp'" | Get-Process -Id {$_.ProcessId}
$Startup = New-StartupInfo -ParentProcess $Parent
Start-ProcessEx 'C:\Program Files (x86)\Microsoft\Edge\Application\*\Installer\setup.exe' -StartupInfo $Startup -ArgumentList @(
    '--uninstall'
    '--msedge'
    '--channel=stable'
    '--system-level'
    '--verbose-logging'
    '--force-uninstall'
    '--delete-profile'
)

# Now that we're done, reënable the automatic processes (we wouldn't want to miss our WebView2 updates, after all)
Get-Service -Name edgeupdate | Set-Service -StartupType AutomaticDelayedStart
Get-Service -Name edgeupdatem | Set-Service -StartupType Manual
Get-ScheduledTask -TaskName MicrosoftEdgeUpdateTaskMachine* | Enable-ScheduledTask

Unregister-ScheduledTask -TaskName 'Remove Edge' -Confirm:$false
