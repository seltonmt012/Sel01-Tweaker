# Sel01-Solver — Build Progress

One-click Windows 11 debloat + performance optimizer. Run once, unattended,
done. Combines Win11Debloat, RemoveWindowsAI, winutil tweaks, WinMemoryCleaner-style
RAM clean, and the standard Windows Performance Options.

> Internal code/brand currently uses the working name **Twerk** (`$Global:Twerk`,
> `Twerk.ps1`). Renaming everything to **Sel01-Solver** is a planned step (see Pending).

## Workflow rule

**Every finished step gets logged here AND committed to git.**
1. Finish a step.
2. Tick it in the Step Log below + add a one-line note.
3. `git add -A && git commit` with a message referencing the step.
4. Record the short commit hash next to the step.

Commit message style: `step: <what>` (e.g. `step: add module 08 network tweaks`).

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
- [x] `src/Twerk.ps1` — self-elevate, params, flow, revert branch, summary `00ad74a`
- [x] `build.ps1` — bundle src → `dist/Twerk.ps1`, syntax-validated `00ad74a`
- [x] `NOTICE.md` — licenses/attribution (MIT x3; GPL avoided by reimplementation) `00ad74a`
- [x] `README.md` — usage, profiles, flags, revert, caveats `00ad74a`
- [x] `tests/Twerk.Tests.ps1` (Pester v5) + `tests/run-checks.ps1` (no-dependency) `00ad74a`

### Phase 4 — Verification
- [x] All 10 source files: syntax clean
- [x] Bundle `dist/Twerk.ps1`: syntax clean (43 KB)
- [x] Core helpers on real registry: DWord/String/Binary write + type, snapshot, DryRun-no-write, **revert round-trip** → all PASS
- [x] All 7 modules DryRun both profiles → 0 errors (Gaming 51 snapshots, Clean 58)
- [x] Profile gating correct (Gaming HwSchMode=2/GameMode on; Clean HwSchMode=1/GameMode off + extra trim)
- [x] RAM-cleaner C# compiles (inline + minified scheduled-task twin) — fixed `using`-in-MemberDefinition + duplicate-using errors
- [x] Git repo initialized, all files committed `00ad74a`
- [x] `PROGRESS.md` + `.gitignore` (commit-per-step workflow) `e8609da`
- [x] `CLAUDE.md` (commands, architecture, invariants) `4afa58c`

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

- [ ] **Rename** internal brand Twerk → Sel01-Solver (vars `$Global:Twerk`, `Twerk.ps1`, data dir `%ProgramData%\Twerk`, task name, type namespaces). Single sweep + rebuild + retest.
- [ ] User's **additional tweaks/repos** → add as modules `08+` (same `Set-Reg`/snapshot pipeline, auto-revertable).
- [ ] **Hosting** the one-liner URL (raw GitHub or own domain) once chosen.
- [ ] Optional: Pester 5 install for CI; current Windows Pester is 3.x (use `run-checks.ps1`).
- [ ] Optional: multi-user / default-profile (sysprep) application.

---

## Decisions Log
- **Approach:** orchestrator-hybrid — download+run Win11Debloat & RemoveWindowsAI; native reimplement winutil tweaks + perf/visual + RAM clean.
- **Profiles:** `-Profile Gaming` (default, keeps Game Mode + HAGS) / `-Profile Clean` (max debloat).
- **Safety:** System Restore point + per-value registry backup JSON → `-Revert`.
- **Licensing:** WinMemoryCleaner is GPL-3.0 → no code bundled, reimplemented via documented Win32 APIs. Others MIT, attributed in NOTICE.md.
