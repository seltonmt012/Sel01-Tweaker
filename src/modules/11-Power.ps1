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

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN: USB selective suspend off, PCIe ASPM off, disk-timeout 0 (AC)' 'INFO'
        return
    }

    # GUIDs: USB selective suspend setting, PCIe ASPM setting.
    $usbSub = '2a737441-1930-4402-8d77-b2bebba308a3'; $usbSet = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
    $pciSub = '501a4d13-42af-4429-9fd1-a8218c268e20'; $pciSet = 'ee12f906-d277-404b-b6da-e5fa1a576df5'
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
