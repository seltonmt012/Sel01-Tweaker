# Third-Party Notices

Sel01Tweaker combines, orchestrates, and reimplements functionality inspired by the
following open-source projects. Sel01Tweaker is an independent project and is not
affiliated with or endorsed by any of them.

## Orchestrated at runtime (downloaded and executed as-is, not bundled)

- **Win11Debloat** - Raphire - MIT License
  https://github.com/Raphire/Win11Debloat
  Invoked by `modules/01-Debloat.ps1` via the official `https://debloat.raphi.re/` redirect.

- **RemoveWindowsAI** - zoicware - MIT License
  https://github.com/zoicware/RemoveWindowsAI
  Invoked by `modules/02-RemoveAI.ps1` via the raw GitHub script URL.

## Reimplemented natively (no upstream code copied)

- **winutil** - ChrisTitusTech - MIT License
  https://github.com/ChrisTitusTech/winutil
  The current winutil release has no headless apply mode; `modules/03-WinutilTweaks.ps1`
  reimplements selected "Essential Tweaks" from the declarative registry/service/task
  data in its `config/tweaks.json`. MIT attribution retained here.

- **WinMemoryCleaner** - Igor Mundstein - **GPL-3.0 License**
  https://github.com/IgorMundstein/WinMemoryCleaner
  Because GPL-3.0 is copyleft, **none of its code is used or bundled.**
  `modules/07-RamCleaner.ps1` is an independent reimplementation of the same
  documented Win32 APIs (`NtSetSystemInformation`, `EmptyWorkingSet`,
  `SetSystemFileCacheSize`). The GPL does not extend to an independent
  reimplementation of the underlying public Windows APIs.

## Documentation / research reference (no code used)

- **OpenTweak** - SwisserDev - MIT License
  https://github.com/SwisserDev/OpenTweak
  A C#/WPF tool with per-tweak documentation and honest effectiveness ratings. No code
  was copied (different language, different architecture). Its documentation informed
  three changes in v1.9.0: the shader-cache cleaner (`modules/19-ShaderCache.ps1`), the
  per-app GTA V flags in `modules/06-Gaming.ps1`, and allowing `PowerThrottlingOff` on
  laptops running on mains in `modules/11-Power.ps1`. The "Honest effectiveness" table
  in README.md follows the same idea of rating tweaks openly.

## Performance / visual-effects registry values

The "Adjust for best performance" registry mapping in `modules/04-Performance.ps1`
is derived from publicly documented Windows registry behavior (UserPreferencesMask,
VisualFXSetting, and related values).
