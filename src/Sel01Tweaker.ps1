#Requires -Version 5.1
<#
.SYNOPSIS
    Sel01-Tweaker - one-click, unattended Windows 11 debloat + performance optimizer.
.DESCRIPTION
    Runs a single pass: debloat, AI removal, native tweaks, performance/visual
    effects, power plan, gaming + FiveM tweaks, and a native RAM cleaner.
    Creates a System Restore point and a per-value registry backup (-Revert).

    No -Profile  -> interactive console menu (overview + confirm before running).
    -Profile X   -> runs that profile directly (for the irm|iex one-liner).
.EXAMPLE
    .\Sel01Tweaker.ps1                 # interactive menu
.EXAMPLE
    & ([scriptblock]::Create((irm https://URL/Sel01Tweaker.ps1))) -Profile Gaming
.EXAMPLE
    .\Sel01Tweaker.ps1 -Revert
#>
[CmdletBinding()]
param(
    [ValidateSet('Gaming','Clean','')]
    [string]$Profile = '',
    [switch]$Revert,
    [switch]$NoRestore,
    [switch]$SkipDebloat,
    [switch]$SkipAI,
    [switch]$SkipFiveM,
    [switch]$SkipClean,
    [switch]$NoRamTask,
    [switch]$DryRun
)

#__SEL01TWEAKER_BUNDLE_INSERT__
# ---------------------------------------------------------------------------
#  Load parts. When bundled into dist\Sel01Tweaker.ps1 the functions already
#  exist, so dot-sourcing is skipped. When running from src\, pull lib+modules.
# ---------------------------------------------------------------------------
if (-not (Get-Command Invoke-Module-Performance -ErrorAction SilentlyContinue)) {
    $root = $PSScriptRoot
    . (Join-Path $root 'lib\Common.ps1')
    . (Join-Path $root 'lib\Backup.ps1')
    Get-ChildItem (Join-Path $root 'modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
}

# ===========================================================================
#  Console UI
# ===========================================================================
function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '   ====================================================' -ForegroundColor DarkCyan
    Write-Host '        ____  ____ _     ___  _      _____         ' -ForegroundColor Cyan
    Write-Host '       / ___|| ___| |   / _ \/ |    |_   _|_      __' -ForegroundColor Cyan
    Write-Host '       \___ \|___ \ |  | | | | |_____ | | \ \ /\ / /' -ForegroundColor Cyan
    Write-Host '        ___) |___) | |__| |_| | |_____|| |  \ V  V / ' -ForegroundColor Cyan
    Write-Host '       |____/|____/|_____\___/|_|      |_|   \_/\_/  ' -ForegroundColor Cyan
    Write-Host '   ====================================================' -ForegroundColor DarkCyan
    Write-Host ('        Windows 10/11  -  1-Klick Optimierung   v{0}' -f $Global:Sel01Tweaker.Version) -ForegroundColor White
    Write-Host '   ====================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-Credits {
    Write-Host ''
    Write-Host '   ----------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '   Sel01-Tweaker  -  by seltonmt012' -ForegroundColor DarkGray
    Write-Host '   github.com/seltonmt012/Sel01-Tweaker' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-MainMenu {
    Show-Banner
    Write-Host '   Was moechtest du tun?' -ForegroundColor White
    Write-Host ''
    Write-Host '     [1] ' -ForegroundColor Green -NoNewline; Write-Host 'GAMING       ' -ForegroundColor White -NoNewline; Write-Host '- empfohlen. Game Mode + HAGS bleiben an.' -ForegroundColor Gray
    Write-Host '     [2] ' -ForegroundColor Green -NoNewline; Write-Host 'CLEAN        ' -ForegroundColor White -NoNewline; Write-Host '- maximales Debloat (Office/Allround).' -ForegroundColor Gray
    Write-Host '     [3] ' -ForegroundColor Yellow -NoNewline; Write-Host 'TESTLAUF     ' -ForegroundColor White -NoNewline; Write-Host '- zeigt nur an, aendert NICHTS.' -ForegroundColor Gray
    Write-Host '     [4] ' -ForegroundColor Magenta -NoNewline; Write-Host 'REPARATUR    ' -ForegroundColor White -NoNewline; Write-Host '- SFC/DISM + Netzwerk-Reset (on-demand).' -ForegroundColor Gray
    Write-Host '     [5] ' -ForegroundColor Magenta -NoNewline; Write-Host 'DNS          ' -ForegroundColor White -NoNewline; Write-Host '- Cloudflare/Quad9 setzen (oder zuruecksetzen).' -ForegroundColor Gray
    Write-Host '     [6] ' -ForegroundColor Cyan -NoNewline; Write-Host 'RUECKGAENGIG ' -ForegroundColor White -NoNewline; Write-Host '- letzten Lauf wieder zurueck.' -ForegroundColor Gray
    Write-Host '     [7] ' -ForegroundColor DarkGray -NoNewline; Write-Host 'BEENDEN' -ForegroundColor White
    Show-Credits
    return (Read-Host '   Deine Wahl (1-7)')
}

function Show-Overview {
    param([string]$P,[bool]$Dry)
    Show-Banner
    $head = if ($Dry) { 'TESTLAUF (Gaming) - es wird NICHTS geaendert, nur angezeigt' }
            else       { "PROFIL: $($P.ToUpper())" }
    Write-Host "   UEBERSICHT - das wird gemacht:" -ForegroundColor White
    Write-Host "   $head" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '   Vorher: System-Wiederherstellungspunkt + Backup (fuer Rueckgaengig)' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '    1. Debloat       ' -ForegroundColor Cyan -NoNewline; Write-Host 'Bloat-Apps, Telemetrie, Bing/Werbung entfernen (Download)' -ForegroundColor Gray
    Write-Host '    2. KI entfernen  ' -ForegroundColor Cyan -NoNewline; Write-Host 'Copilot, Recall, KI-Tasks entfernen (Download)' -ForegroundColor Gray
    Write-Host '    3. System-Tweaks ' -ForegroundColor Cyan -NoNewline; Write-Host 'Telemetrie/Tracking/Werbe-ID/Standort aus' -ForegroundColor Gray
    Write-Host '       + Extra       ' -ForegroundColor Cyan -NoNewline; Write-Host 'Web-Suche/Copilot/Cortana/Edge-Hintergrund aus, Explorer-QoL' -ForegroundColor Gray
    Write-Host '       + Privacy+    ' -ForegroundColor Cyan -NoNewline; Write-Host 'CEIP/Error-Reporting/Speech/Inking/Office/Edge-Telemetrie + Telemetrie-Tasks aus' -ForegroundColor Gray
    Write-Host '    4. Performance   ' -ForegroundColor Cyan -NoNewline; Write-Host 'Beste-Leistung-Optik (3 Effekte bleiben an), kein Input-Delay' -ForegroundColor Gray
    Write-Host '    5. Power-Plan    ' -ForegroundColor Cyan -NoNewline; Write-Host 'Ultimate Performance' -ForegroundColor Gray
    if ($P -eq 'Clean') {
        Write-Host '    6. Gaming        ' -ForegroundColor Cyan -NoNewline; Write-Host 'GameDVR aus; Game Mode + HAGS AUS (Clean); MMCSS' -ForegroundColor Gray
        Write-Host '    7. FiveM         ' -ForegroundColor DarkGray -NoNewline; Write-Host 'uebersprungen (nur im Gaming-Profil)' -ForegroundColor DarkGray
        Write-Host '       + extra      ' -ForegroundColor Cyan -NoNewline; Write-Host 'Hintergrund-Apps aus, mehr Dienste auf Manuell' -ForegroundColor Gray
    } else {
        Write-Host '    6. Gaming        ' -ForegroundColor Cyan -NoNewline; Write-Host 'GameDVR aus; Game Mode + HAGS AN; MMCSS (audio-sicher)' -ForegroundColor Gray
        Write-Host '    7. FiveM         ' -ForegroundColor Cyan -NoNewline; Write-Host 'FSO/GPU/Prioritaet/Netzwerk (nur wenn FiveM installiert)' -ForegroundColor Gray
    }
    Write-Host '    8. Power (Desktop)' -ForegroundColor Cyan -NoNewline; Write-Host ' USB-Suspend/PCIe-ASPM aus (nur Desktop/Netzstrom)' -ForegroundColor Gray
    Write-Host '    9. Cleaner       ' -ForegroundColor Cyan -NoNewline; Write-Host 'Temp/Update-Cache/Papierkorb leeren' -ForegroundColor Gray
    Write-Host '   10. RAM-Cleaner   ' -ForegroundColor Cyan -NoNewline; Write-Host 'Speicher leeren + stuendlicher Hintergrund-Task' -ForegroundColor Gray
    Write-Host ''
    Write-Host '   Danach: Neustart empfohlen.  Rueckgaengig jederzeit mit Option [4].' -ForegroundColor DarkGray
    Show-Credits
    $a = Read-Host '   ENTER = STARTEN   |   X = Abbrechen'
    return ($a -notmatch '^[xX]')
}

function Show-Tips {
    # Static post-run checklist - manual things the tool can't do. Zero risk.
    Write-Host ''
    Write-Host '   ===== TIPPS (manuell, fuer mehr Leistung) =====' -ForegroundColor Yellow
    Write-Host '   - GPU-Treiber aktuell halten (direkt NVIDIA/AMD, nicht nur Windows Update)' -ForegroundColor Gray
    Write-Host '   - RAM-Speed: XMP / EXPO im BIOS aktivieren (oft RAM auf Standard-Takt!)' -ForegroundColor Gray
    Write-Host '   - Resizable BAR / Smart Access Memory im BIOS an (mehr FPS)' -ForegroundColor Gray
    Write-Host '   - Windows aktiviert? (Einstellungen > System > Aktivierung)' -ForegroundColor Gray
    Write-Host '   - Monitor auf volle Hz stellen (Anzeige > erweiterte Anzeige)' -ForegroundColor Gray
    Write-Host '   - Im Spiel: Frame-Limit etwas unter Monitor-Hz fuer stabile Frametimes' -ForegroundColor Gray
    Write-Host '   - SSD: TRIM laeuft automatisch; SSD-Firmware aktuell halten' -ForegroundColor Gray
    Write-Host ''
}

# ===========================================================================
#  Repair tools (on-demand from the menu - can take several minutes)
# ===========================================================================
function Invoke-Repair {
    Show-Banner
    Write-Host '   REPARATUR - System-Integritaet + Netzwerk. Kann einige Minuten dauern.' -ForegroundColor Cyan
    Write-Host '   (SFC + DISM pruefen/reparieren Windows; Netzwerk-Reset braucht Neustart.)' -ForegroundColor Gray
    Show-Credits
    if ((Read-Host '   ENTER = los, X = Abbrechen') -match '^[xX]') { return }
    Initialize-Run
    Write-Log 'DISM /Online /Cleanup-Image /RestoreHealth ...' 'STEP'
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Log 'sfc /scannow ...' 'STEP'
    sfc /scannow
    Write-Log 'DISM Component Cleanup (WinSxS) ...' 'STEP'
    DISM /Online /Cleanup-Image /StartComponentCleanup
    Write-Log 'Netzwerk: DNS-Cache leeren + Winsock/IP reset ...' 'STEP'
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
    Write-Log 'Reparatur fertig. NEUSTART empfohlen (Netzwerk-Reset).' 'OK'
}

# ===========================================================================
#  DNS switcher (opt-in; reversible to automatic/DHCP)
# ===========================================================================
function Invoke-DnsMenu {
    Show-Banner
    Write-Host '   DNS aendern (schnellere/privatere Namensaufloesung):' -ForegroundColor Cyan
    Write-Host '     [1] Cloudflare  (1.1.1.1)' -ForegroundColor White
    Write-Host '     [2] Quad9       (9.9.9.9)' -ForegroundColor White
    Write-Host '     [3] Zuruecksetzen (Automatisch / DHCP)' -ForegroundColor White
    Write-Host '     [X] Abbrechen' -ForegroundColor Gray
    Show-Credits
    $c = (Read-Host '   Wahl').Trim()
    $v4=@(); $v6=@(); $reset=$false
    switch ($c) {
        '1' { $v4=@('1.1.1.1','1.0.0.1');  $v6=@('2606:4700:4700::1111','2606:4700:4700::1001') }
        '2' { $v4=@('9.9.9.9','149.112.112.112'); $v6=@('2620:fe::fe','2620:fe::9') }
        '3' { $reset=$true }
        default { return }
    }
    $ifs = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up'
    foreach ($a in $ifs) {
        try {
            if ($reset) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop }
            else        { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ($v4 + $v6) -ErrorAction Stop }
            Write-Host ("   DNS gesetzt auf {0}: {1}" -f $a.Name, $(if($reset){'Auto'}else{$v4 -join ', '})) -ForegroundColor Green
        } catch { Write-Host "   DNS fehlgeschlagen auf $($a.Name)" -ForegroundColor Yellow }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# ===========================================================================
#  Pipeline
# ===========================================================================
function Initialize-Run {
    $Global:Sel01Tweaker.Stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
    Initialize-Sel01TweakerState -Stamp $Global:Sel01Tweaker.Stamp
}

function Invoke-Pipeline {
    param([string]$Profile,[bool]$DryRun)

    Initialize-Run
    $Global:Sel01Tweaker.Profile = $Profile
    $Global:Sel01Tweaker.DryRun  = $DryRun
    $Global:Sel01Tweaker.Backup  = [System.Collections.Generic.List[object]]::new()
    $Global:Sel01Tweaker.Changes = [System.Collections.Generic.List[string]]::new()
    $Global:Sel01Tweaker.SkippedCount = 0

    $os = Get-Sel01OSInfo
    Write-Log "Sel01-Tweaker v$($Global:Sel01Tweaker.Version) | $os (build $($Global:Sel01Tweaker.OSBuild)) | Profile=$Profile | DryRun=$DryRun" 'STEP'

    if (-not $Global:Sel01Tweaker.NoRestore) { New-Sel01TweakerRestorePoint }
    else { Write-Log 'Restore point skipped (-NoRestore)' 'WARN' }

    $steps = @(
        @{ Name='Debloat';       Skip=$Global:Sel01Tweaker.SkipDebloat; Run={ Invoke-Module-Debloat } },
        @{ Name='RemoveAI';      Skip=$Global:Sel01Tweaker.SkipAI;      Run={ Invoke-Module-RemoveAI } },
        @{ Name='WinutilTweaks'; Skip=$false;                           Run={ Invoke-Module-WinutilTweaks } },
        @{ Name='Extra';         Skip=$false;                           Run={ Invoke-Module-Extra } },
        @{ Name='Privacy';       Skip=$false;                           Run={ Invoke-Module-Privacy } },
        @{ Name='Performance';   Skip=$false;                           Run={ Invoke-Module-Performance } },
        @{ Name='PowerPlan';     Skip=$false;                           Run={ Invoke-Module-PowerPlan } },
        @{ Name='Gaming';        Skip=$false;                           Run={ Invoke-Module-Gaming } },
        @{ Name='FiveM';         Skip=$Global:Sel01Tweaker.SkipFiveM;   Run={ Invoke-Module-FiveM } },
        @{ Name='Power';         Skip=$false;                           Run={ Invoke-Module-Power } },
        @{ Name='Cleaner';       Skip=$Global:Sel01Tweaker.SkipClean;   Run={ Invoke-Module-Cleaner } },
        @{ Name='RamCleaner';    Skip=$false;                           Run={ Invoke-Module-RamCleaner -NoTask:$Global:Sel01Tweaker.NoRamTask } }
    )
    foreach ($s in $steps) {
        if ($s.Skip) { Write-Log "Skipping $($s.Name)" 'WARN'; continue }
        try { & $s.Run } catch { Write-Log "$($s.Name) crashed: $($_.Exception.Message)" 'ERROR' }
    }

    Broadcast-SettingChange
    Restart-Explorer
    Save-Sel01TweakerBackup

    Write-Host ''
    Write-Log '============ FERTIG - Zusammenfassung ============' 'STEP'
    foreach ($c in $Global:Sel01Tweaker.Changes) { Write-Log " - $c" 'OK' }
    Write-Log ("Geaendert: {0}  |  schon korrekt (uebersprungen): {1}" -f $Global:Sel01Tweaker.Changes.Count, $Global:Sel01Tweaker.SkippedCount) 'STEP'
    Write-Log "Backup: $($Global:Sel01Tweaker.BackupFile)" 'INFO'
    Write-Log "Log:    $($Global:Sel01Tweaker.LogFile)" 'INFO'
    if ($Global:Sel01Tweaker.RebootNeeded) { Write-Log 'NEUSTART empfohlen (HAGS / Power-Plan).' 'WARN' }
    Write-Log 'Rueckgaengig: Menue-Option oder  -Revert' 'INFO'
    Write-Log 'Done.' 'OK'
    Show-Tips
}

# ===========================================================================
#  Entry
# ===========================================================================
function Start-Sel01Tweaker {
    param($Profile,$Revert,$NoRestore,$SkipDebloat,$SkipAI,$SkipFiveM,$SkipClean,$NoRamTask,$DryRun)

    # --- Self-elevate -----------------------------------------------------
    if (-not (Test-Admin)) {
        if ($PSCommandPath) {
            Write-Host 'Sel01-Tweaker braucht Administrator-Rechte - starte neu...' -ForegroundColor Yellow
            $argline = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
            if ($Profile)     { $argline += @('-Profile',$Profile) }
            if ($Revert)      { $argline += '-Revert' }
            if ($NoRestore)   { $argline += '-NoRestore' }
            if ($SkipDebloat) { $argline += '-SkipDebloat' }
            if ($SkipAI)      { $argline += '-SkipAI' }
            if ($SkipFiveM)   { $argline += '-SkipFiveM' }
            if ($SkipClean)   { $argline += '-SkipClean' }
            if ($NoRamTask)   { $argline += '-NoRamTask' }
            if ($DryRun)      { $argline += '-DryRun' }
            Start-Process powershell.exe -Verb RunAs -ArgumentList $argline
            return
        } else {
            Write-Host 'FEHLER: In einer ERHOEHTEN PowerShell ausfuehren (Als Administrator).' -ForegroundColor Red
            return
        }
    }

    # --- Stash run-wide options in state ----------------------------------
    $Global:Sel01Tweaker.NoRestore   = [bool]$NoRestore
    $Global:Sel01Tweaker.SkipDebloat = [bool]$SkipDebloat
    $Global:Sel01Tweaker.SkipAI      = [bool]$SkipAI
    $Global:Sel01Tweaker.SkipFiveM   = [bool]$SkipFiveM
    $Global:Sel01Tweaker.SkipClean   = [bool]$SkipClean
    $Global:Sel01Tweaker.NoRamTask   = [bool]$NoRamTask

    # --- Revert -----------------------------------------------------------
    if ($Revert) { Initialize-Run; Invoke-Revert; return }

    # --- Direct (non-interactive) profile run -----------------------------
    if ($Profile -eq 'Gaming' -or $Profile -eq 'Clean') {
        Invoke-Pipeline -Profile $Profile -DryRun:([bool]$DryRun)
        return
    }

    # --- Interactive menu -------------------------------------------------
    # Guard: if there's no real console (stdin redirected/piped), Read-Host
    # returns empty forever and the menu would spin. Bail with guidance.
    try { $redir = [Console]::IsInputRedirected } catch { $redir = $false }
    if ($redir) {
        Write-Host 'Kein interaktives Terminal erkannt.' -ForegroundColor Yellow
        Write-Host 'Direkt nutzen:  -Profile Gaming   |   -Profile Clean   |   -Revert' -ForegroundColor Yellow
        return
    }

    while ($true) {
        $c = Show-MainMenu
        switch ($c.Trim()) {
            '1' { if (Show-Overview -P 'Gaming' -Dry $false) { Invoke-Pipeline -Profile 'Gaming' -DryRun $false; Read-Host "`n   ENTER zum Menue" } }
            '2' { if (Show-Overview -P 'Clean'  -Dry $false) { Invoke-Pipeline -Profile 'Clean'  -DryRun $false; Read-Host "`n   ENTER zum Menue" } }
            '3' { if (Show-Overview -P 'Gaming' -Dry $true)  { Invoke-Pipeline -Profile 'Gaming' -DryRun $true;  Read-Host "`n   ENTER zum Menue" } }
            '4' { Invoke-Repair;  Read-Host "`n   ENTER zum Menue" }
            '5' { Invoke-DnsMenu; Read-Host "`n   ENTER zum Menue" }
            '6' {
                Show-Banner
                Write-Host '   RUECKGAENGIG - letzten Lauf zurueckdrehen.' -ForegroundColor Cyan
                if ((Read-Host '   ENTER = los, X = Abbrechen') -notmatch '^[xX]') {
                    Initialize-Run; Invoke-Revert; Read-Host "`n   ENTER zum Menue"
                }
            }
            '7' { return }
            default { if ($c -match '^[xX]$') { return } }
        }
    }
}

Start-Sel01Tweaker -Profile $Profile -Revert:$Revert -NoRestore:$NoRestore -SkipDebloat:$SkipDebloat -SkipAI:$SkipAI -SkipFiveM:$SkipFiveM -NoRamTask:$NoRamTask -DryRun:$DryRun
