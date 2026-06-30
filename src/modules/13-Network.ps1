# ============================================================================
#  Module 13 - Network / Latency  (Gaming profile only)
#  Disables Nagle's algorithm per active NIC (lower small-packet latency for
#  games). Every write goes through Set-Reg -> snapshotted -> reversible.
# ============================================================================

function Invoke-Module-Network {
    Write-Log '=== Module: Network / Latency (Nagle off) ===' 'STEP'

    if ($Global:Sel01Tweaker.Profile -ne 'Gaming') {
        Write-Log 'Network-Tweaks nur im Gaming-Profil, skip' 'INFO'; return
    }
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    if (-not (Test-Path $base)) { Write-Log 'Tcpip Interfaces fehlt, skip' 'WARN'; return }

    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        $guid = $_.PSChildName
        if ($guid -notmatch '^\{[0-9a-fA-F-]+\}$') { return }   # skip non-GUID keys (e.g. "*")
        $path = Join-Path $base $guid
        $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        $dhcp  = "$($props.DhcpIPAddress)"
        $stat  = "$($props.IPAddress)"
        $hasIp = ($dhcp -and $dhcp -ne '0.0.0.0') -or ($stat -and $stat -ne '0.0.0.0')
        if ($hasIp) {
            Set-Reg $path 'TcpAckFrequency' DWord 1 -Note "Nagle off (TcpAckFrequency) auf $guid"
            Set-Reg $path 'TCPNoDelay'      DWord 1
        }
    }
}
