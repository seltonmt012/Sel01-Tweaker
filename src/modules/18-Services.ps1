# ============================================================================
#  Module 18 - Extra services  (research-vetted, ALL Manual - never Disabled)
#  Surveyed from winutil / Optimizer / privacy.sexy / Sophia / O&O and a deep
#  services audit, then adversarially safety-checked. Manual (not Disabled) so
#  anything still demand-starts -> nothing breaks, idle load drops, fully
#  reversible (Set-ServiceStart snapshots the prior Start type). The hard
#  deny-list in Set-ServiceStart still blocks anything security/network core.
# ============================================================================

function Invoke-Module-Services {
    Write-Log '=== Module: Extra services (Manual, vetted) ===' 'STEP'

    $clean = ($Global:Sel01Tweaker.Profile -eq 'Clean')

    # --- Both profiles: diagnostics / legacy-net / niche, all demand-startable
    foreach ($svc in 'WdiServiceHost','WdiSystemHost','lltdsvc','Spectrum',
                      'perceptionsimulation','lmhosts','autotimesvc',
                      'diagnosticshub.standardcollector.service') {
        Set-ServiceStart $svc Manual
    }
    # Cellular modem service: desktops only (laptops/tablets may have WWAN hw).
    if (-not $Global:Sel01Tweaker.IsLaptop) {
        Set-ServiceStart 'WwanSvc' Manual
    }
    Add-Change 'Extra diagnostics/legacy services -> Manual'

    # --- Clean-only: deeper trim of services unused on a home/gaming box -----
    # All Manual: offline-files, storage UI (trigger), ICS/NAT (trigger - WSL2/
    # Hyper-V keep working), Miracast, MTP, printer toasts, inbound RDP, WebDAV,
    # File History, cross-device, peer-name, VPN auto-dial, SSTP, problem-report
    # viewer, event forwarding, encryption plugins, SNMP traps, 802.1X wired,
    # dynamic-lock, smart-card cert, domain logon (no-op off-domain), network
    # discovery, UPnP/DLNA discovery, hardware-detection (AutoPlay).
    if ($clean) {
        foreach ($svc in 'CscService','StorSvc','SharedAccess','WFDSConMgrSvc','WPDBusEnum',
                          'PrintNotify','TermService','SessionEnv','UmRdpService','WebClient',
                          'fhsvc','CDPSvc','p2psvc','p2pimsvc','PNRPsvc','PNRPAutoReg',
                          'RasAuto','SstpSvc','wercplsupport','Wecsvc','WEPHOSTSVC','SNMPTRAP',
                          'dot3svc','NaturalAuthentication','CertPropSvc','Netlogon',
                          'fdPHost','FDResPub','SSDPSRV','upnphost','ShellHWDetection') {
            Set-ServiceStart $svc Manual
        }
        Add-Change 'Clean: deeper unused-service trim -> Manual'
    }
}
