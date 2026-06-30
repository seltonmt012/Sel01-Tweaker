# ============================================================================
#  Module 15 - Optional Features / Capabilities  (lean + hardening)
#  Turns off legacy/unused Windows optional features and capabilities via DISM
#  (Disable-Sel01Feature / Remove-Sel01Capability record what they touch so
#  -Revert re-enables/re-adds them). DISM changes need a reboot to finalise.
#  Research-vetted, gaming-safe; never touches anything a game/launcher needs.
# ============================================================================

function Invoke-Module-Features {
    Write-Log '=== Module: Optional Features / Capabilities (lean) ===' 'STEP'

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN: would disable legacy optional features + niche capabilities' 'INFO'
        return
    }

    $clean = ($Global:Sel01Tweaker.Profile -eq 'Clean')

    # --- Optional features (both profiles): legacy / unused / hardening ---
    # SMB1 (wormable, WannaCry vector) + PSv2 (downgrade/AMSI-bypass vector) are
    # security hardening, not weakening. Disable-Sel01Feature skips absent/already-off.
    foreach ($f in 'SMB1Protocol','MicrosoftWindowsPowerShellV2Root','Printing-XPSServices-Features',
                    'FaxServicesClientPackage','WorkFolders-Client','MSRDC-Infrastructure') {
        Disable-Sel01Feature $f
    }

    if ($clean) {
        # Internet (IPP/HTTP) printing - LAN/USB printing unaffected; SMB Direct
        # (RDMA) - no-op on consumer NICs.
        foreach ($f in 'Printing-Foundation-InternetPrinting-Client','SmbDirect') {
            Disable-Sel01Feature $f
        }
    }

    # --- Capabilities (FoD): niche, deprecated -----------------------------
    # Fetch the (slow) capability list once, then remove by prefix.
    try {
        $caps = Get-WindowsCapability -Online -ErrorAction Stop
        Remove-Sel01Capability 'MathRecognizer'    -InstalledCaps $caps
        Remove-Sel01Capability 'App.StepsRecorder' -InstalledCaps $caps
    } catch {
        Write-Log "capability enumeration failed: $($_.Exception.Message)" 'WARN'
    }

    Add-Change 'Legacy optional features + niche capabilities removed (reboot to finalise)'
}
