# ============================================================================
#  Module 11 - Power tweaks  (Desktop on AC only)
#  Latency/throughput power settings that HURT laptops/battery, so they are
#  applied ONLY on a desktop running on AC. Applied to the active power scheme
#  (the Ultimate Performance plan set in module 05), so -Revert removes them
#  together with that plan (reset to Balanced).
# ============================================================================

function Invoke-Module-Power {
    Write-Log '=== Module: Power tweaks (Desktop/AC only) ===' 'STEP'

    Get-Sel01PowerInfo
    if ($Global:Sel01Tweaker.IsLaptop -or $Global:Sel01Tweaker.OnBattery) {
        Write-Log ("Laptop={0} Akku={1} -> Power-Tweaks uebersprungen (geraete-/akku-sicher)" -f `
            $Global:Sel01Tweaker.IsLaptop, $Global:Sel01Tweaker.OnBattery) 'WARN'
        return
    }

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

    # --- CPU power throttling off (Desktop/AC only - raises idle power so it
    #     is correctly gated by the laptop/battery guard above). Reversible. --
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' DWord 1 -Note 'CPU power throttling off (Desktop/AC)'
    $Global:Sel01Tweaker.RebootNeeded = $true

    # --- Opt-in: Win11 global timer resolution (fixes micro-stutter) -----
    if ($Global:Sel01Tweaker.TimerFix) {
        if ($Global:Sel01Tweaker.IsWin11) {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' DWord 1 -Note 'Win11 global timer resolution (opt-in)'
            $Global:Sel01Tweaker.RebootNeeded = $true
        } else { Write-Log 'TimerFix uebersprungen (nur Win11)' 'INFO' }
    }

    # --- Opt-in: GPU MSI mode (lower interrupt latency) ------------------
    if ($Global:Sel01Tweaker.MsiMode) {
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
