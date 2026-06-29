# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Twerk (working name; target brand **Sel01-Solver**) is a one-click, unattended
Windows 11 debloat + performance optimizer written in PowerShell. One elevated
run applies debloat, AI removal, registry/service tweaks, visual-effects perf
settings, a power plan, gaming tweaks, and a native RAM cleaner — then exits.
No GUI. Creates a System Restore point and a per-value registry backup enabling `-Revert`.

## Commands

```powershell
# Build the single-file distributable (also syntax-validates it)
.\build.ps1                       # -> dist\Twerk.ps1

# Tests — use run-checks.ps1, NOT Pester. Windows ships Pester 3.x; the
# tests\Twerk.Tests.ps1 specs are Pester v5 syntax and will NOT run on 3.x.
powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1

# Run the tool (self-elevates via UAC)
.\dist\Twerk.ps1 -Profile Gaming  # default profile
.\dist\Twerk.ps1 -Profile Clean
.\dist\Twerk.ps1 -DryRun          # log intended changes, write nothing
.\dist\Twerk.ps1 -Revert          # undo last run from newest backup JSON
```

DryRun-smoke a single module without elevation (writes nothing):
```powershell
. .\src\lib\Common.ps1; . .\src\lib\Backup.ps1
Get-ChildItem .\src\modules\*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
$Global:Twerk.DryRun = $true; Initialize-TwerkState -Stamp 'smoke'
$Global:Twerk.Profile = 'Gaming'
$Global:Twerk.Backup = [System.Collections.Generic.List[object]]::new()
Invoke-Module-Performance        # or any Invoke-Module-* function
```

## Architecture

**Orchestrator-hybrid.** `src/Twerk.ps1` (entry) self-elevates, initializes
`$Global:Twerk` state, optionally makes a restore point, then runs 7 module
functions in order, each wrapped so failures are non-fatal. Two libs + seven
modules are **dot-sourced** at runtime from `src/`.

- `src/lib/Common.ps1` — shared state + every primitive. **All registry/service
  writes go through `Set-Reg` / `Remove-Reg` / `Set-ServiceStart`.** These snapshot
  the prior value into `$Global:Twerk.Backup` *before* writing and honor `DryRun`.
  Also: `Get-RegValueSafe`, `Build-PreferencesMask`, `Broadcast-SettingChange`
  (P/Invoke), `Invoke-Remote` (download+run upstream scripts).
- `src/lib/Backup.ps1` — restore point, writes `Backup` + run metadata to a
  backup JSON, and `Invoke-Revert` reads it back to restore values / delete the
  minted power scheme / remove the RAM task.
- `src/modules/01..07` — the stages. `01-Debloat` + `02-RemoveAI` **orchestrate**
  (download MIT upstream tools and run them silently). `03-WinutilTweaks`,
  `04-Performance`, `06-Gaming` are **native** (winutil has no headless mode, so
  its `tweaks.json` data is reimplemented as `Set-Reg` calls). `07-RamCleaner` is
  an independent Win32 P/Invoke reimplementation (WinMemoryCleaner is GPL — no
  code copied).

**Profiles** (`-Profile Gaming|Clean`) gate behavior inside modules via
`$Global:Twerk.Profile`. Gaming keeps Game Mode + HAGS on and trims gently;
Clean is maximum debloat.

**Bundling.** `build.ps1` inlines libs+modules at the `#__TWERK_BUNDLE_INSERT__`
marker in `src/Twerk.ps1`, producing `dist/Twerk.ps1` for `irm | iex`-style use.
`dist/Twerk.ps1` is **generated — never hand-edit it.** The entry guards its
dot-source block (`if (-not (Get-Command Invoke-Module-Performance ...))`) so the
same file works both unbundled (src) and bundled (dist).

## Invariants (break these and things silently fail)

- **Never write the registry directly.** Use `Set-Reg`/`Remove-Reg`/`Set-ServiceStart`,
  or `-Revert` won't know how to undo it. Binary values must be `byte[]`; `Set-Reg`'s
  `-Type` distinguishes `String` (REG_SZ) vs `DWord` — getting this wrong is the
  classic bug (e.g. `DragFullWindows`/`FontSmoothing`/`MouseSpeed` are REG_SZ).
- **`param()` must stay the first statement** in `src/Twerk.ps1`; the bundle marker
  sits right after it so libs/modules are injected without displacing `param`.
- **`build.ps1` uses `.Replace()`, not `-replace`** — the bundle text contains `$`
  and here-string terminators that regex replacement corrupts.
- **`Add-Type -MemberDefinition` cannot contain `using` directives** (they'd land
  inside a class body). Pass namespaces via `-UsingNamespace`, and do NOT list
  `System` or `System.Runtime.InteropServices` there (Add-Type adds those by
  default → duplicate-using compile error). See `07-RamCleaner.ps1`.
- After editing anything in `src/`, **rebuild** (`.\build.ps1`) and re-run
  `run-checks.ps1`. Runtime logs/backups live in `%ProgramData%\Twerk\`.

## Workflow

`PROGRESS.md` is the running step log. **Each finished step: tick it in
PROGRESS.md and commit** with a `step: <what>` message, recording the short hash.
Orchestrated steps need internet (they skip+log when offline); HAGS and the power
plan need a reboot; HKCU changes apply to the current user only.
