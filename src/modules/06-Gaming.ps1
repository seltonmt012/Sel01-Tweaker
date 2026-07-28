# ============================================================================
#  Module 06 - Gaming  (profile-gated)
#  GameDVR / background capture is disabled in BOTH profiles (pure overhead).
#  Game Mode + Hardware-accelerated GPU Scheduling (HAGS) are kept ON for the
#  Gaming profile (they help gaming) and turned OFF for the Clean profile.
#  HAGS needs WDDM 2.7+ driver and a reboot to take effect.
# ============================================================================

function Get-Sel01GtaVExePaths {
    <#  Finds installed GTA V executables (Rockstar / Steam / Epic, Legacy +
        Enhanced). Module 08 only ever covered the FiveM exes, so a plain
        GTA V install never got the per-app FSO / high-perf-GPU flags.
        Returns full paths that really exist; empty array when GTA V is absent. #>
    $dirs = [System.Collections.Generic.List[string]]::new()

    # 1) Rockstar registry: enumerate every product subkey and take any
    #    InstallFolder* value (names differ per edition/store).
    foreach ($rs in @('HKLM:\SOFTWARE\WOW6432Node\Rockstar Games','HKLM:\SOFTWARE\Rockstar Games')) {
        if (-not (Test-Path $rs)) { continue }
        Get-ChildItem $rs -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match 'Grand Theft Auto V|GTAV' } |
            ForEach-Object {
                $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if (-not $props) { return }
                $props.PSObject.Properties |
                    Where-Object { $_.Name -like 'InstallFolder*' -and "$($_.Value)".Trim() } |
                    ForEach-Object { $dirs.Add("$($_.Value)") | Out-Null }
            }
    }

    # 2) Steam libraries (libraryfolders.vdf lists every library drive).
    try {
        $steam = (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop).InstallPath
        $vdf   = Join-Path $steam 'steamapps\libraryfolders.vdf'
        $libs  = @($steam)
        if (Test-Path $vdf) {
            Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"' -ErrorAction SilentlyContinue |
                ForEach-Object { $libs += $_.Matches[0].Groups[1].Value -replace '\\\\','\' }
        }
        foreach ($l in ($libs | Select-Object -Unique)) {
            $dirs.Add((Join-Path $l 'steamapps\common\Grand Theft Auto V')) | Out-Null
        }
    } catch {}

    # 3) Epic manifests (JSON, one .item per installed game).
    $man = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (Test-Path $man) {
        Get-ChildItem $man -Filter '*.item' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $j = Get-Content $_.FullName -Raw -ErrorAction Stop | ConvertFrom-Json
                if ("$($j.DisplayName)" -match 'Grand Theft Auto' -and $j.InstallLocation) {
                    $dirs.Add("$($j.InstallLocation)") | Out-Null
                }
            } catch {}
        }
    }

    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($d in ($dirs | Where-Object { $_ } | Select-Object -Unique)) {
        foreach ($exe in @('GTA5.exe','GTA5_Enhanced.exe')) {
            $p = Join-Path $d $exe
            if (Test-Path -LiteralPath $p) { $found.Add($p) | Out-Null }
        }
    }
    return @($found | Select-Object -Unique)
}

function Invoke-Module-Gaming {
    Write-Log '=== Module: Gaming tweaks ===' 'STEP'

    $gaming = ($Global:Sel01Tweaker.Profile -eq 'Gaming')

    # --- GameDVR / capture OFF (both profiles) ---------------------------
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' DWord 0 -Note 'GameDVR off'
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' DWord 0
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR' 'value' DWord 0

    # --- Game Mode + HAGS -------------------------------------------------
    if ($gaming) {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AllowAutoGameMode' DWord 1 -Note 'Game Mode ON (gaming profile)'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' DWord 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' DWord 2 -Note 'HAGS ON (reboot needed)'
        $Global:Sel01Tweaker.RebootNeeded = $true
    } else {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AllowAutoGameMode' DWord 0 -Note 'Game Mode OFF (clean profile)'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\GameBar' 'AutoGameModeEnabled' DWord 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' DWord 1 -Note 'HAGS OFF (clean profile)'
        $Global:Sel01Tweaker.RebootNeeded = $true
    }

    # --- Multimedia scheduler: favour foreground game responsiveness -----
    $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    # 10 (not 0): leaves a small background guarantee so MMCSS audio threads
    # don't get starved (0 causes sound crackle). 10 is the safe gaming value.
    Set-Reg $mm 'SystemResponsiveness' DWord 10 -Note 'System responsiveness favours foreground (audio-safe 10)'
    if ($gaming) {
        Set-Reg $mm 'NetworkThrottlingIndex' DWord 0xffffffff -Note 'Network throttling off'
    }
    $games = "$mm\Tasks\Games"
    Set-Reg $games 'GPU Priority' DWord 8
    Set-Reg $games 'Priority'     DWord 6
    Set-Reg $games 'Scheduling Category' String 'High'
    Set-Reg $games 'SFIO Priority'       String 'High'

    # Win11 only: let DXGI upgrade legacy bitblt/flip-blt swapchains to flip model
    # (lower latency for windowed games). No-op on Win10.
    if ($Global:Sel01Tweaker.IsWin11) {
        Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings' String 'SwapEffectUpgradeEnable=1;' -Note 'DirectX flip-model upgrade (Win11)'
    }

    # --- Per-app flags for a plain GTA V install (Gaming profile) ---------
    # Same two surgical HKCU flags module 08 applies to the FiveM exes:
    #   FSO off  -> real exclusive fullscreen (less latency/tearing)
    #   GpuPreference=2 -> high-perf GPU (matters on hybrid-graphics laptops)
    # Both are per-exe and fully reverted via Set-Reg snapshots.
    if ($gaming) {
        $gta = Get-Sel01GtaVExePaths
        if (-not $gta -or $gta.Count -eq 0) {
            Write-Log 'GTA V nicht gefunden (Rockstar/Steam/Epic) - GTA-Per-App-Tweaks uebersprungen' 'INFO'
        } else {
            foreach ($path in $gta) {
                $leaf = Split-Path $path -Leaf
                Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' `
                        $path String '~ DISABLEDXMAXIMIZEDWINDOWEDMODE' -Note "FSO off for $leaf"
                Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' `
                        $path String 'GpuPreference=2;' -Note "High-Perf GPU for $leaf"
            }
            Add-Change ("GTA V: FSO aus + High-Perf-GPU ({0} exe)" -f $gta.Count)
        }
    }
}
