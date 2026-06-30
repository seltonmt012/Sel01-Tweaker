#Requires -Version 5.1
<#
  vm-autofinish.ps1 - runs once after the host reboot (registered as a logon task
  by the setup flow). Starts the test VM, waits until it reaches the desktop
  (heartbeat OkApplicationsHealthy), creates the 'clean-desktop' checkpoint, then
  unregisters its own scheduled task. Fully hands-free.
#>
[CmdletBinding()]
param(
    [string]$Name = 'Sel01-Win11-Test',
    [string]$Snapshot = 'clean-desktop',
    [string]$TaskName = 'Sel01-VM-AutoFinish',
    [int]$MaxMinutes = 75
)
$log = 'C:\Sel01TestVM\autofinish.log'
function L($m){ $line = "{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; Add-Content -Path $log -Value $line; Write-Host $line }

try {
    L "=== autofinish start ==="

    # 1) wait for the hypervisor / Hyper-V to be ready after boot
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        if ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent -and (Get-VM -Name $Name -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Seconds 10
    }
    $vm = Get-VM -Name $Name -ErrorAction Stop
    L "hypervisor ready; VM state = $($vm.State)"

    # 2) start the VM if it isn't already running (unattended install begins)
    if ($vm.State -ne 'Running') { Start-VM -Name $Name; L 'VM started' }

    # 3) poll heartbeat until the desktop is up and stable (~2 min)
    $stable = 0
    $hardStop = (Get-Date).AddMinutes($MaxMinutes)
    while ((Get-Date) -lt $hardStop) {
        Start-Sleep -Seconds 20
        $vm = Get-VM -Name $Name
        $hb = "$($vm.Heartbeat)"
        L ("state={0} heartbeat={1} uptime={2}" -f $vm.State, $hb, $vm.Uptime)
        if ($hb -like 'OkApplicationsHealthy*') { $stable++ } else { $stable = 0 }
        if ($stable -ge 6) { break }
    }
    if ($stable -lt 6) { L 'WARNING: desktop not confirmed within time budget; checkpoint anyway'; }

    # 4) checkpoint the clean desktop
    Checkpoint-VM -Name $Name -SnapshotName $Snapshot
    L "checkpoint '$Snapshot' created"

    # 5) remove this one-shot task
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    L "=== autofinish DONE; task removed ==="
} catch {
    L "ERROR: $($_.Exception.Message)"
}
