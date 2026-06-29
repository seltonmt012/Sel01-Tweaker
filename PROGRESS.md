# Sel01-Tweaker — Build Progress

One-click Windows 11 debloat + performance optimizer. Run once, unattended,
done. Combines Win11Debloat, RemoveWindowsAI, winutil tweaks, WinMemoryCleaner-style
RAM clean, and the standard Windows Performance Options.

> Internal code/brand currently uses the working name **Sel01Tweaker** (`$Global:Sel01Tweaker`,
> `Sel01Tweaker.ps1`). Renaming everything to **Sel01-Tweaker** is a planned step (see Pending).

## Workflow rule

**Every finished step gets logged here AND committed to git.**
1. Finish a step.
2. Tick it in the Step Log below + add a one-line note.
3. `git add -A && git commit` with a message referencing the step.
4. Record the short commit hash next to the step.

Commit message style: `step: <what>` (e.g. `step: add module 08 network tweaks`).

**Release rule: every BIG update (new module/feature) gets a version bump + a
GitHub release.** Bump `Version` in `src/lib/Common.ps1` (single source of truth),
then run `.\release.ps1 -Version X.Y.Z` (builds, zips, commits, tags, publishes).
See [RELEASING.md](RELEASING.md). Use SemVer: MINOR for new modules, PATCH for fixes.

## Status legend
- [x] done & verified
- [~] done, not yet tested on real Win11
- [ ] todo

---

## Step Log

### Phase 0 — Research & Design
- [x] Researched all 4 upstream repos (licenses, silent flags, reimplementability) `00ad74a`
- [x] Researched Win11 performance/visual-effects registry map `00ad74a`
- [x] Decisions locked: orchestrator-hybrid · Gaming/Clean presets · Restore Point + Revert `00ad74a`
- [x] Plan approved (`~/.claude/plans/1-sharded-iverson.md`) `00ad74a`

### Phase 1 — Core
- [x] `src/lib/Common.ps1` — state, logging, `Set-Reg` (typed + snapshot), `Get-RegValueSafe`, `Build-PreferencesMask`, `Broadcast-SettingChange`, `Invoke-Remote` `00ad74a`
- [x] `src/lib/Backup.ps1` — restore point, backup JSON, `Invoke-Revert` `00ad74a`

### Phase 2 — Modules
- [x] `01-Debloat.ps1` — orchestrate Win11Debloat silent (per-profile flags) `00ad74a`
- [x] `02-RemoveAI.ps1` — orchestrate RemoveWindowsAI non-interactive `00ad74a`
- [x] `03-WinutilTweaks.ps1` — native reimplementation (telemetry, activity history, consumer features, ads, location, DO, Wi-Fi Sense; Clean extras) `00ad74a`
- [x] `04-Performance.ps1` — VisualFXSetting=3, best-perf mask, keep drag/font/thumbnails, transparency/animations off, mouse accel off `00ad74a`
- [x] `05-PowerPlan.ps1` — Ultimate Performance (capture minted GUID) `00ad74a`
- [x] `06-Gaming.ps1` — GameDVR off; Game Mode + HAGS per profile; MMCSS priorities `00ad74a`
- [x] `07-RamCleaner.ps1` — native Win32 P/Invoke (no GPL code) + hourly task `00ad74a`

### Phase 3 — Entry / Build / Docs / Tests
- [x] `src/Sel01Tweaker.ps1` — self-elevate, params, flow, revert branch, summary `00ad74a`
- [x] `build.ps1` — bundle src → `dist/Sel01Tweaker.ps1`, syntax-validated `00ad74a`
- [x] `NOTICE.md` — licenses/attribution (MIT x3; GPL avoided by reimplementation) `00ad74a`
- [x] `README.md` — usage, profiles, flags, revert, caveats `00ad74a`
- [x] `tests/Sel01Tweaker.Tests.ps1` (Pester v5) + `tests/run-checks.ps1` (no-dependency) `00ad74a`

### Phase 4 — Verification
- [x] All 10 source files: syntax clean
- [x] Bundle `dist/Sel01Tweaker.ps1`: syntax clean (43 KB)
- [x] Core helpers on real registry: DWord/String/Binary write + type, snapshot, DryRun-no-write, **revert round-trip** → all PASS
- [x] All 7 modules DryRun both profiles → 0 errors (Gaming 51 snapshots, Clean 58)
- [x] Profile gating correct (Gaming HwSchMode=2/GameMode on; Clean HwSchMode=1/GameMode off + extra trim)
- [x] RAM-cleaner C# compiles (inline + minified scheduled-task twin) — fixed `using`-in-MemberDefinition + duplicate-using errors
- [x] Git repo initialized, all files committed `00ad74a`
- [x] `PROGRESS.md` + `.gitignore` (commit-per-step workflow) `e8609da`
- [x] `CLAUDE.md` (commands, architecture, invariants) `4afa58c`
- [x] `START_Sel01-Tweaker.bat` — double-click launcher, self-elevates, 1-5 menu (Gaming/Clean/DryRun/Revert)
- [x] `ANLEITUNG.md` — dead-simple German beginner guide (visual menu, FAQ, confirms perf settings auto-applied)
- [x] **v1.1.1** — simplified main menu to 3 choices (Optimieren / Testen / Mehr-Experte); advanced options (Clean, Reparatur, DNS, Revert) nested under "MEHR / EXPERTE" so non-technical users aren't overwhelmed.
- [x] **v1.1.0** — Reparatur menu (SFC/DISM RestoreHealth/WinSxS cleanup/DNS flush/Winsock+IP reset), DNS switcher (Cloudflare/Quad9/reset), Tips screen after each run, version shown in banner+log. Researched via a 5th fan-out subagent vs O&O ShutUp10/Wintoys/WinUtil/BleachBit/privacy.sexy; excluded unsafe (Edge/WebView2 removal, IPv6 disable, Modern Standby off, Defender/Update off, pagefile off, SSD defrag).
- [x] **Module 11-Power** — laptop/desktop + AC/battery detection (`Get-Sel01PowerInfo`); applies USB-selective-suspend off, PCIe ASPM off, disk no-sleep ONLY on a desktop on AC (skips on laptop/battery). Reverts with the power plan.
- [x] **Module 12-Cleaner** (`-SkipClean`) — empties user/Windows temp, Windows Update download cache, thumbnail cache, Recycle Bin; reports freed MB. DryRun reports sizes without deleting (found ~4.8 GB on the dev box).
- [x] **MIT LICENSE** added (copyright seltonmt012); README badge + Win10/11 title + license section.
- [x] **Idempotency** — `Set-Reg`/`Remove-Reg` skip when the value is already correct (no re-force, no snapshot, no change); summary reports `Geaendert / schon korrekt`. Unit-tested (DWord/String/uint32-hex).
- [x] **Module 10-Privacy+** (both profiles) — researched via 2 more fan-out subagents across OSS projects (Disassembler0, Sophia-Script, privacy.sexy, hellzerg/optimizer): CEIP + app-compat inventory off, Windows Error Reporting upload off, tailored-experiences/ad policy, online speech + inking/typing data off, feedback nags off, cloud-clipboard sync off, Find My Device off, Diagtrack ETW autologger off, Edge + Office + .NET/PowerShell telemetry off, Quick Access MRU + Aero Shake off, Update QoL (no forced reboot + active hours, updates NOT disabled), and a telemetry/feedback **scheduled-task batch** — now disabled via `Disable-Task` and **re-enabled on -Revert**. Excludes everything that weakens Defender/SmartScreen/updates.
- [x] **Fixed RemoveWindowsAI crash** ("-nonInteractive not in Options set"): `Invoke-Remote` now splats a hashtable by name; `-Options` passes as a real string[]. Modules 01/02 converted to hashtable params.
- [x] **OS detection** `Get-Sel01OSInfo` (Win10 vs Win11 by build >=22000); logged at run start; `IsWin11` gates OS-specific tweaks.
- [x] **Module 09-Extra** (both profiles, OS-aware) — researched via 2 fan-out subagents: web-search/Copilot/Cortana off, Explorer QoL (This PC, no "- Shortcut", no ad notifications), lock-screen/Settings suggestions off, Edge startup-boost/background off, NTFS last-access off + LongPaths; Win11-only (Start_TrackDocs, Taskbar End Task) / Win10-only (Bing/Cortana search) gated.
- [x] **Interactive console UI** in the dist: banner + menu (Gaming/Clean/Testlauf/Revert/Exit), an **overview screen** listing exactly what each step does before running, confirm prompt, small credits footer. Non-interactive guard (stdin redirected → exits cleanly, no loop). `-Profile X` still runs directly for the one-liner.
- [x] **build.bat** + simplified **START_Sel01-Tweaker.bat** — both launch PowerShell with `-ExecutionPolicy Bypass` (fixes the "scripts disabled" / Mark-of-the-Web build error from downloaded files). Launcher just elevates + runs the dist (UI lives in the ps1).
- [x] Fixed launcher **elevation loop** (cmd reopening forever): `net session` fails as admin when LanmanServer is off → replaced with `fltmc` + an `elevated` arg-guard.
- [x] **Module 08-FiveM** (Gaming only) — safe FiveM tweaks: per-app FSO off + High-Perf GPU (real exe paths), TdrDelay=8 (crash guard, NOT TdrLevel=0), IFEO CpuPriorityClass=6 (Above Normal), TcpAckFrequency/TcpNoDelay on the **active** adapter only. `-SkipFiveM` flag. Researched via 3 fan-out subagents; verified DryRun (FiveM detected on this box, Clean skips).
- [x] Fixed module 06 `SystemResponsiveness` 0 → **10** (0 starves MMCSS audio → crackle)
- [x] **Renamed** project Twerk/Sel01-Solver → **Sel01-Tweaker** (repo github.com/seltonmt012/Sel01-Tweaker). Code token `Twerk`→`Sel01Tweaker`, files `Sel01Tweaker.ps1`/`Sel01Tweaker.Tests.ps1`/`START_Sel01-Tweaker.bat`, data dir `%ProgramData%\Sel01Tweaker`, namespaces `Sel01Tweaker.*`. Rebuilt + retested (all checks pass, 7 modules ok, RAM type compiles).

---

## Verified vs. Pending real-machine test

**Verified now (this machine):** syntax, bundling, registry write/type/snapshot/revert, DryRun of every module, both profiles, C# compilation.

**Needs a real Win11 + admin run (user):**
- [~] Restore point creation
- [~] Win11Debloat / RemoveWindowsAI live download + silent apply
- [~] Performance Options dialog shows Custom with the 3 kept effects ON
- [~] Copilot/Recall actually gone
- [~] Ultimate Performance plan active
- [~] `-Revert` restores from backup JSON end-to-end
- [~] `UserPreferencesMask = 90 12 03 80 10 00 00 00` byte-parity vs. manual GUI setting

---

## Pending / Next

- [ ] User's **additional tweaks/repos** → add as modules `08+` (same `Set-Reg`/snapshot pipeline, auto-revertable).
- [ ] **Hosting** the one-liner URL (raw GitHub or own domain) once chosen.
- [ ] Optional: Pester 5 install for CI; current Windows Pester is 3.x (use `run-checks.ps1`).
- [ ] Optional: multi-user / default-profile (sysprep) application.

---

## FiveM safety — EXCLUDED harmful tweaks (researched, deliberately NOT shipped)

These are common in online "FiveM hitreg/booster" scripts but break things or are placebo:
- `SystemResponsiveness=0`, `Win32PrioritySeparation=38` — starve audio/background (crackle, stutter).
- QoS / Psched / Pacer disable, fixed `TcpWindowSize`, `MaxUserPort`, `DefaultTTL`, `Ndu` disable — break/placebo networking; autotuning should stay `normal`.
- `reg add ...Interfaces\*\*\*` — `reg.exe` doesn't expand `*`; creates junk keys (we enumerate the active adapter instead).
- `DWM CompositionPolicy=0` — DWM can't be disabled on Win11; ignored.
- `MouseSensitivity=20`, `WaitToKillAppTimeout=1000` — overwrite user settings / risk data loss on shutdown.
- `TdrLevel=0` (removes GPU crash recovery), DisablePagingExecutive / LargeSystemCache / IoPageLockLimit (myths), disable page file, Spectre/Meltdown off, bcdedit timer hacks, large pages, blanket service disable — all AVOID.

## Decisions Log
- **Approach:** orchestrator-hybrid — download+run Win11Debloat & RemoveWindowsAI; native reimplement winutil tweaks + perf/visual + RAM clean.
- **Profiles:** `-Profile Gaming` (default, keeps Game Mode + HAGS) / `-Profile Clean` (max debloat).
- **Safety:** System Restore point + per-value registry backup JSON → `-Revert`.
- **Licensing:** WinMemoryCleaner is GPL-3.0 → no code bundled, reimplemented via documented Win32 APIs. Others MIT, attributed in NOTICE.md.
