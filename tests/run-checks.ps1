# Standalone, dependency-free verification for Sel01Tweaker core helpers.
# Works without Pester (Windows ships Pester 3.x which can't run the v5 specs).
# Run:  powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1
# Uses a throwaway HKCU:\Software\Sel01TweakerTest key and cleans up.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src\lib\Common.ps1')
. (Join-Path $root 'src\lib\Backup.ps1')
. (Join-Path $root 'src\lib\Ui.ps1')
Get-ChildItem (Join-Path $root 'src\modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }

$script:fail = 0
function ok($n,$c){ if($c){ Write-Host "PASS $n" -ForegroundColor Green } else { Write-Host "FAIL $n" -ForegroundColor Red; $script:fail++ } }

$TestKey = 'HKCU:\Software\Sel01TweakerTest'
if (Test-Path $TestKey) { Remove-Item $TestKey -Recurse -Force }

ok 'mask bytes' ((((Build-PreferencesMask) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') -eq '90 12 03 80 10 00 00 00')

ok 'bar full'  ((Get-Sel01Bar 100 10) -eq ([string]([char]0x2588) * 10))
ok 'bar empty' ((Get-Sel01Bar 0 10)   -eq ([string]([char]0x2591) * 10))
ok 'bar half filled 5' ((((Get-Sel01Bar 50 10).ToCharArray() | Where-Object { $_ -eq [char]0x2588 }) | Measure-Object).Count -eq 5)
Initialize-Ui
ok 'ui non-fancy when redirected' ($Global:Sel01Tweaker.UI.Fancy -eq $false)
ok 'module Network exists' ([bool](Get-Command Invoke-Module-Network -ErrorAction SilentlyContinue))
ok 'module Gpu exists'     ([bool](Get-Command Invoke-Module-Gpu     -ErrorAction SilentlyContinue))
ok 'module Features exists'([bool](Get-Command Invoke-Module-Features -ErrorAction SilentlyContinue))
ok 'feature helper exists' ([bool](Get-Command Disable-Sel01Feature  -ErrorAction SilentlyContinue))
ok 'module AppxBloat exists'([bool](Get-Command Invoke-Module-AppxBloat -ErrorAction SilentlyContinue))
ok 'module Win10 exists'   ([bool](Get-Command Invoke-Module-Win10 -ErrorAction SilentlyContinue))
ok 'module Services exists'([bool](Get-Command Invoke-Module-Services -ErrorAction SilentlyContinue))
ok 'suspend-panel exists'  ([bool](Get-Command Suspend-Panel -ErrorAction SilentlyContinue))
ok 'module ShaderCache exists' ([bool](Get-Command Invoke-Module-ShaderCache -ErrorAction SilentlyContinue))
ok 'shader clear helper exists' ([bool](Get-Command Clear-Sel01ShaderCache -ErrorAction SilentlyContinue))
ok 'gta exe finder exists'  ([bool](Get-Command Get-Sel01GtaVExePaths -ErrorAction SilentlyContinue))

# Shader-cache paths: only ever LOCALAPPDATA cache dirs, and only existing ones.
$shPaths = @(Get-Sel01ShaderCachePaths)
ok 'shader paths all exist'  (-not ($shPaths | Where-Object { -not (Test-Path -LiteralPath $_) }))
ok 'shader paths localappdata' (-not ($shPaths | Where-Object { $_ -notlike "$env:LOCALAPPDATA*" }))

# GTA V finder must never return a path that isn't a real GTA5*.exe on disk.
$gtaPaths = @(Get-Sel01GtaVExePaths)
ok 'gta paths exist'    (-not ($gtaPaths | Where-Object { -not (Test-Path -LiteralPath $_) }))
ok 'gta paths are exes' (-not ($gtaPaths | Where-Object { (Split-Path $_ -Leaf) -notmatch '^GTA5(_Enhanced)?\.exe$' }))

# ShaderCache module is opt-in: without the flag it must not touch anything.
$Global:Sel01Tweaker.ShaderClean = $false
$Global:Sel01Tweaker.Changes = [System.Collections.Generic.List[string]]::new()
Invoke-Module-ShaderCache
ok 'shader module no-op without flag' ($Global:Sel01Tweaker.Changes.Count -eq 0)

# --- RAM cleaner: no background task, no working-set eviction ---------
# Regression lock for the v1.9.0 bug: module 07 used to install an HOURLY SYSTEM
# scheduled task that called EmptyWorkingSet() on every process and purged the
# standby list + file cache. That evicts the whole live working set to the
# pagefile once an hour = multi-minute freezes. It shipped. It must never return.
# The LAST check in this section shadows Remove-LegacyRamCleanerTask - that is
# irreversible in-session, so nothing below it may call the real function.
ok 'module RamCleaner exists'   ([bool](Get-Command Invoke-Module-RamCleaner       -ErrorAction SilentlyContinue))
ok 'ram clean helper exists'    ([bool](Get-Command Invoke-RamClean                -ErrorAction SilentlyContinue))
ok 'legacy task remover exists' ([bool](Get-Command Remove-LegacyRamCleanerTask    -ErrorAction SilentlyContinue))
ok 'pagefile-on-hdd probe exists' ([bool](Get-Command Test-Sel01PagefileOnHdd      -ErrorAction SilentlyContinue))

# Forbidden-pattern scan of the module source. Comments are stripped first: the
# module header deliberately NAMES the removed APIs to document why they are
# gone, so only live code is scanned. 'Register-ScheduledTask' is matched with a
# left word boundary so the legitimate Unregister-ScheduledTask does not trip it.
$ram07Raw  = Get-Content -Raw (Join-Path $root 'src\modules\07-RamCleaner.ps1')
$ram07Code = ($ram07Raw -replace '(?s)<#.*?#>', '') -replace '(?m)#.*$', '' -replace '(?m)//.*$', ''
$ram07Banned = [ordered]@{
    'EmptyWorkingSet'         = 'EmptyWorkingSet'
    'SetSystemFileCacheSize'  = 'SetSystemFileCacheSize'
    'Register-ScheduledTask'  = '(?<![\w-])Register-ScheduledTask'
    'New-ScheduledTaskTrigger'= 'New-ScheduledTaskTrigger'
    'RepetitionInterval'      = 'RepetitionInterval'
}
foreach ($ram07Pat in $ram07Banned.Keys) {
    ok "ram07 source free of $ram07Pat" (-not ($ram07Code -match $ram07Banned[$ram07Pat]))
}

# The native type must not even expose the removed calls. Add-Type needs a
# compiler; if it is unavailable we still report PASS/FAIL by falling back to
# the C# member names in the source instead of silently skipping.
$ram07Names = $null
try { Initialize-RamCleaner; $ram07Names = @([Sel01Tweaker.Memory].GetMethods().Name) } catch { $ram07Names = $null }
$ram07How = if ($null -ne $ram07Names) { 'type' } else { 'source' }
$ram07HasMember = {
    param([string]$MemberName)
    if ($null -ne $ram07Names) { return ($ram07Names -contains $MemberName) }
    return ($ram07Code -match ('(?<![\w])' + [regex]::Escape($MemberName)))
}
ok "ram07 [$ram07How] no EmptyAllWorkingSets" (-not (& $ram07HasMember 'EmptyAllWorkingSets'))
ok "ram07 [$ram07How] no TrimFileCache"       (-not (& $ram07HasMember 'TrimFileCache'))
ok "ram07 [$ram07How] has PurgeStandbyList"        (& $ram07HasMember 'PurgeStandbyList')
ok "ram07 [$ram07How] has FlushModifiedList"       (& $ram07HasMember 'FlushModifiedList')

# RamCleaner is opt-in like ShaderCache: without -RamClean it must change nothing.
$Global:Sel01Tweaker.RamClean = $false
$Global:Sel01Tweaker.DryRun   = $true
$Global:Sel01Tweaker.Changes  = [System.Collections.Generic.List[object]]::new()
Invoke-Module-RamCleaner
ok 'ram module no-op without flag' ($Global:Sel01Tweaker.Changes.Count -eq 0)

# Migration is UNCONDITIONAL: the legacy hourly task is uninstalled on every run,
# even when -RamClean was not passed. (shadows Remove-LegacyRamCleanerTask)
$script:ramLegacyCalls = 0
function Remove-LegacyRamCleanerTask { $script:ramLegacyCalls++ }
$Global:Sel01Tweaker.RamClean = $false
$Global:Sel01Tweaker.Changes  = [System.Collections.Generic.List[object]]::new()
Invoke-Module-RamCleaner
ok 'ram: legacy task removal runs without -RamClean' ($script:ramLegacyCalls -ge 1)


$Global:Sel01Tweaker.DryRun = $false
$Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
Set-Reg $TestKey 'Num' DWord 7 | Out-Null
ok 'dword written'        ((Get-ItemProperty $TestKey).Num -eq 7)
ok 'snapshot existed=false' ((($Global:Sel01Tweaker.Backup | Where-Object Name -eq 'Num').Existed) -eq $false)

Set-Reg $TestKey 'Str' String '1' | Out-Null
$i = Get-RegValueSafe $TestKey 'Str'
ok 'string value' ($i.Value -eq '1')
ok 'string kind'  ("$($i.Kind)" -eq 'String')

Set-Reg $TestKey 'Num' DWord 2 | Out-Null
ok 'one snapshot for Num' ((($Global:Sel01Tweaker.Backup | Where-Object Name -eq 'Num') | Measure-Object).Count -eq 1)
ok 'num updated'          ((Get-ItemProperty $TestKey).Num -eq 2)

Set-Reg $TestKey 'Bin' Binary ([byte[]]@(0x90,0x12,0x03)) | Out-Null
ok 'binary roundtrip' (-not (Compare-Object (Get-RegValueSafe $TestKey 'Bin').Value ([byte[]]@(0x90,0x12,0x03))))

$Global:Sel01Tweaker.DryRun = $true
$Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
Remove-Item $TestKey -Recurse -Force
Set-Reg $TestKey 'Dry' DWord 5 | Out-Null
ok 'dryrun no write'         (-not (Test-Path $TestKey))
ok 'dryrun snapshot recorded' (($Global:Sel01Tweaker.Backup | Where-Object Name -eq 'Dry') -ne $null)
$Global:Sel01Tweaker.DryRun = $false

$Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
New-Item $TestKey -Force | Out-Null
New-ItemProperty $TestKey -Name 'Keep' -PropertyType DWord -Value 100 -Force | Out-Null
Set-Reg $TestKey 'Keep' DWord 999 | Out-Null
Set-Reg $TestKey 'New'  DWord 1   | Out-Null
$Global:Sel01Tweaker.DataDir = $env:TEMP
$bf = Join-Path $env:TEMP 'twerk-bk.json'
$Global:Sel01Tweaker.BackupFile = $bf
([ordered]@{ Profile='Gaming'; Created='t'; PowerSchemeGuid=$null; RamTask=$null; Registry=$Global:Sel01Tweaker.Backup } |
    ConvertTo-Json -Depth 6) | Set-Content $bf -Encoding UTF8
Invoke-Revert -BackupPath $bf | Out-Null
ok 'revert restored Keep=100' ((Get-ItemProperty $TestKey).Keep -eq 100)
ok 'revert removed New'        ((Get-ItemProperty $TestKey -Name New -ErrorAction SilentlyContinue) -eq $null)
Remove-Item $bf -Force -ErrorAction SilentlyContinue

Remove-Item $TestKey -Recurse -Force -ErrorAction SilentlyContinue

# --- Power module gating (LAST: shadows Set-Reg/Get-Sel01PowerInfo) ---------
# Battery must skip everything; laptop on AC must still get PowerThrottlingOff
# (the OpenTweak finding we adopted) but NOT the device-level powercfg block.
# Set-Reg is idempotent, so a real snapshot can't be asserted on a machine that
# already has the value - record the calls instead.
$script:regCalls = [System.Collections.Generic.List[string]]::new()
function Set-Reg { param($Path,$Name,$Type,$Value,$Note) $script:regCalls.Add("$Name") | Out-Null }
$Global:Sel01Tweaker.DryRun = $true

function Get-Sel01PowerInfo { $Global:Sel01Tweaker.IsLaptop = $true; $Global:Sel01Tweaker.OnBattery = $true }
Invoke-Module-Power
ok 'power: battery skips all' ($script:regCalls.Count -eq 0)

$script:regCalls.Clear()
function Get-Sel01PowerInfo { $Global:Sel01Tweaker.IsLaptop = $true; $Global:Sel01Tweaker.OnBattery = $false }
Invoke-Module-Power
ok 'power: laptop@AC gets PowerThrottlingOff' ($script:regCalls -contains 'PowerThrottlingOff')

$script:regCalls.Clear()
$Global:Sel01Tweaker.MsiMode = $true
Invoke-Module-Power
ok 'power: MSI mode stays desktop-only' (-not ($script:regCalls -contains 'MSISupported'))
$Global:Sel01Tweaker.MsiMode = $false
$Global:Sel01Tweaker.DryRun = $false

Write-Host ''
if ($script:fail) { Write-Host "$script:fail CHECK(S) FAILED" -ForegroundColor Red; exit 1 }
else { Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green }
