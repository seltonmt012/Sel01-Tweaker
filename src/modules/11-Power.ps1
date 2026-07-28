# ============================================================================
#  Module 11 - Power tweaks  (AC only; device-class gated)
#  Two tiers, because they are NOT equally risky on portables:
#    * Battery       -> nothing at all (every tweak here costs runtime).
#    * Laptop on AC  -> CPU power throttling off only. That is exactly where it
#                       helps most (aggressive OEM power management clocks the
#                       CPU down mid-game); it costs idle power, not devices.
#    * Desktop on AC -> the above PLUS the device-level powercfg settings
#                       (USB selective suspend, PCIe ASPM, disk no-sleep),
#                       which would drain a battery and can upset docked/
#                       hybrid laptop hardware.
#  powercfg settings apply to the active scheme (the Ultimate Performance plan
#  from module 05), so -Revert removes them with that plan (reset to Balanced).
# ============================================================================

function Invoke-Module-Power {
    Write-Log '=== Module: Power tweaks (nur Netzstrom) ===' 'STEP'

    Get-Sel01PowerInfo
    if ($Global:Sel01Tweaker.OnBattery) {
        Write-Log 'Akkubetrieb -> Power-Tweaks komplett uebersprungen (akku-sicher)' 'WARN'
        return
    }
    $desktop = -not $Global:Sel01Tweaker.IsLaptop

    if ($desktop) {
        # GUIDs: USB selective suspend setting, PCIe ASPM setting.
        $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'; $usbSet = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        $pciSub = '501a4d13-42af-4429-9fd1-a8218c268e20'; $pciSet = 'ee12f906-d277-404b-b6da-e5fa1a576df5'
        if ($Global:Sel01Tweaker.DryRun) {
            Write-Log 'DRYRUN: USB selective suspend off, PCIe ASPM off, disk-timeout 0 (AC)' 'INFO'
        } else {
          try {
            powercfg /SETACVALUEINDEX SCHEME_CURRENT $usbSub $usbSet 0 2>$null | Out-Null   # USB suspend off
            powercfg /SETACVALUEINDEX SCHEME_CURRENT $pciSub $pciSet 0 2>$null | Out-Null   # PCIe ASPM off
            powercfg /change disk-timeout-ac 0 2>$null | Out-Null                            # disk never sleeps
            powercfg /SETACTIVE SCHEME_CURRENT 2>$null | Out-Null
            Write-Log 'USB selective suspend off, PCIe ASPM off, disk no-sleep (AC)' 'OK'
            Add-Change 'Power: USB-suspend/PCIe-ASPM off, disk no-sleep (Desktop/AC)'
            Write-Log 'Revert: entfernt sich mit dem Power-Plan (-Revert setzt auf Balanced).' 'INFO'
          } catch {
            Write-Log "Power tweaks failed: $($_.Exception.Message)" 'WARN'
          }
        }
    } else {
        Write-Log 'Laptop am Netz -> Geraete-Power-Tweaks (USB/PCIe/Disk) uebersprungen' 'INFO'
    }

    # --- CPU power throttling off (AC only; laptops included - this is where
    #     Windows throttles hardest). Costs idle power, so battery is excluded
    #     by the guard above. Reversible. ---------------------------------
    $where = if ($desktop) { 'Desktop/AC' } else { 'Laptop am Netz' }
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' DWord 1 -Note "CPU power throttling off ($where)"
    $Global:Sel01Tweaker.RebootNeeded = $true

    # --- Opt-in: Win11 global timer resolution (fixes micro-stutter) -----
    if ($Global:Sel01Tweaker.TimerFix) {
        if ($Global:Sel01Tweaker.IsWin11) {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' DWord 1 -Note 'Win11 global timer resolution (opt-in)'
            $Global:Sel01Tweaker.RebootNeeded = $true
        } else { Write-Log 'TimerFix uebersprungen (nur Win11)' 'INFO' }
    }

    # --- Opt-in: GPU MSI mode (lower interrupt latency) ------------------
    # Desktop only, unchanged: on hybrid-graphics laptops the display device
    # enumerated here can be the iGPU, and MSI changes there are riskier.
    if ($Global:Sel01Tweaker.MsiMode -and -not $desktop) {
        Write-Log 'MSI mode uebersprungen (nur Desktop - Hybrid-Grafik im Laptop)' 'INFO'
    } elseif ($Global:Sel01Tweaker.MsiMode) {
        try {
            $gpu = Get-PnpDevice -Class Display -Status OK -ErrorAction Stop | Select-Object -First 1
            if ($gpu) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                Set-Reg $path 'MSISupported' DWord 1 -Note ("GPU MSI mode on ({0})" -f $gpu.FriendlyName)
                $Global:Sel01Tweaker.RebootNeeded = $true
            } else { Write-Log 'MSI mode: keine aktive GPU gefunden' 'WARN' }
        } catch { Write-Log "MSI mode: GPU-Erkennung fehlgeschlagen: $($_.Exception.Message)" 'WARN' }
    }
}
