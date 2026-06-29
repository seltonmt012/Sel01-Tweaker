# ============================================================================
#  Module 08 - FiveM  (Gaming profile only)
#  ONLY safe, reversible, FiveM-relevant tweaks. Every write goes through
#  Set-Reg so -Revert can undo it. Deliberately EXCLUDES the popular-but-harmful
#  "hitreg" tweaks (SystemResponsiveness=0, Win32PrioritySeparation, QoS/Pacer
#  disable, fixed TcpWindowSize, MouseSensitivity override, WaitToKillAppTimeout,
#  TdrLevel=0, large pages, page-file/service kills) - see PROGRESS.md notes.
#
#  Honest scope note: FiveM gameplay traffic is UDP; the TCP Nagle/ACK tweaks
#  below only help the connection/handshake/download path, NOT in-game ping.
# ============================================================================

function Get-FiveMExePaths {
    # Returns full paths of FiveM executables that actually exist on this box.
    $found = [System.Collections.Generic.List[string]]::new()
    $base = Join-Path $env:LOCALAPPDATA 'FiveM'
    $cand = @(Join-Path $base 'FiveM.exe')
    if (Test-Path $base) {
        # FiveM_GTAProcess.exe lives somewhere under the FiveM app dir; find it.
        Get-ChildItem -Path $base -Filter 'FiveM_GTAProcess.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName | ForEach-Object { $cand += $_ }
    }
    foreach ($p in $cand) { if (Test-Path $p) { $found.Add($p) | Out-Null } }
    return $found
}

function Get-ActiveInterfaceGuids {
    # GUIDs of UP adapters that own a default route (the real internet NIC(s)).
    try {
        return (Get-NetIPConfiguration -ErrorAction Stop |
            Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
            ForEach-Object { $_.NetAdapter.InterfaceGuid } | Where-Object { $_ })
    } catch { return @() }
}

function Invoke-Module-FiveM {
    Write-Log '=== Module: FiveM tweaks (safe, Gaming only) ===' 'STEP'

    if ($Global:Sel01Tweaker.Profile -ne 'Gaming') {
        Write-Log 'FiveM module runs only in Gaming profile - skipped.' 'INFO'
        return
    }

    # --- 1) GPU TDR delay: prevent FiveM streaming GPU-reset crashes ------
    # Raise the GPU "hung" timeout from 2s to 8s. NOT TdrLevel=0 (that would
    # remove crash recovery entirely). System-wide but safe + reversible.
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'TdrDelay' DWord 8 -Note 'GPU TdrDelay 8s (FiveM crash guard)'
    $Global:Sel01Tweaker.RebootNeeded = $true

    # --- 2) Persistent process priority: Above Normal (6), never High/Realtime
    foreach ($exe in 'FiveM.exe','FiveM_GTAProcess.exe') {
        $po = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exe\PerfOptions"
        Set-Reg $po 'CpuPriorityClass' DWord 6 -Note "$exe -> Above Normal CPU priority"
    }

    # --- 3) Per-app tweaks that need the real exe path --------------------
    $exes = Get-FiveMExePaths
    if ($exes.Count -eq 0) {
        Write-Log 'FiveM install not found in %LOCALAPPDATA%\FiveM - skipping per-app FSO/GPU tweaks.' 'WARN'
    } else {
        foreach ($path in $exes) {
            # 3a) Disable Fullscreen Optimizations per-app (surgical; lower latency)
            Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' `
                    $path String '~ DISABLEDXMAXIMIZEDWINDOWEDMODE' -Note "FSO off for $(Split-Path $path -Leaf)"
            # 3b) Force High Performance GPU (helps hybrid-graphics laptops; no-op on desktop)
            Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' `
                    $path String 'GpuPreference=2;' -Note "High-Perf GPU for $(Split-Path $path -Leaf)"
        }
    }

    # --- 4) Network: Nagle/Delayed-ACK off on the ACTIVE adapter only -----
    # Helps TCP connect/handshake/resource-download path. Per-interface, so
    # revert (delete) restores defaults; does not touch other adapters.
    $guids = Get-ActiveInterfaceGuids
    if (-not $guids) {
        Write-Log 'No active internet adapter found - skipping network tweaks.' 'WARN'
    } else {
        foreach ($g in $guids) {
            $if = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g"
            Set-Reg $if 'TcpAckFrequency' DWord 1 -Note "Nagle delayed-ACK off ($g)"
            Set-Reg $if 'TcpNoDelay'      DWord 1
        }
        Write-Log 'Network tweaks affect the TCP path only; FiveM gameplay is UDP.' 'INFO'
    }
}
