# Standalone, dependency-free verification for Twerk core helpers.
# Works without Pester (Windows ships Pester 3.x which can't run the v5 specs).
# Run:  powershell -ExecutionPolicy Bypass -File .\tests\run-checks.ps1
# Uses a throwaway HKCU:\Software\TwerkTest key and cleans up.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src\lib\Common.ps1')
. (Join-Path $root 'src\lib\Backup.ps1')

$script:fail = 0
function ok($n,$c){ if($c){ Write-Host "PASS $n" -ForegroundColor Green } else { Write-Host "FAIL $n" -ForegroundColor Red; $script:fail++ } }

$TestKey = 'HKCU:\Software\TwerkTest'
if (Test-Path $TestKey) { Remove-Item $TestKey -Recurse -Force }

ok 'mask bytes' ((((Build-PreferencesMask) | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') -eq '90 12 03 80 10 00 00 00')

$Global:Twerk.DryRun = $false
$Global:Twerk.Backup = [System.Collections.Generic.List[object]]::new()
Set-Reg $TestKey 'Num' DWord 7 | Out-Null
ok 'dword written'        ((Get-ItemProperty $TestKey).Num -eq 7)
ok 'snapshot existed=false' ((($Global:Twerk.Backup | Where-Object Name -eq 'Num').Existed) -eq $false)

Set-Reg $TestKey 'Str' String '1' | Out-Null
$i = Get-RegValueSafe $TestKey 'Str'
ok 'string value' ($i.Value -eq '1')
ok 'string kind'  ("$($i.Kind)" -eq 'String')

Set-Reg $TestKey 'Num' DWord 2 | Out-Null
ok 'one snapshot for Num' ((($Global:Twerk.Backup | Where-Object Name -eq 'Num') | Measure-Object).Count -eq 1)
ok 'num updated'          ((Get-ItemProperty $TestKey).Num -eq 2)

Set-Reg $TestKey 'Bin' Binary ([byte[]]@(0x90,0x12,0x03)) | Out-Null
ok 'binary roundtrip' (-not (Compare-Object (Get-RegValueSafe $TestKey 'Bin').Value ([byte[]]@(0x90,0x12,0x03))))

$Global:Twerk.DryRun = $true
$Global:Twerk.Backup = [System.Collections.Generic.List[object]]::new()
Remove-Item $TestKey -Recurse -Force
Set-Reg $TestKey 'Dry' DWord 5 | Out-Null
ok 'dryrun no write'         (-not (Test-Path $TestKey))
ok 'dryrun snapshot recorded' (($Global:Twerk.Backup | Where-Object Name -eq 'Dry') -ne $null)
$Global:Twerk.DryRun = $false

$Global:Twerk.Backup = [System.Collections.Generic.List[object]]::new()
New-Item $TestKey -Force | Out-Null
New-ItemProperty $TestKey -Name 'Keep' -PropertyType DWord -Value 100 -Force | Out-Null
Set-Reg $TestKey 'Keep' DWord 999 | Out-Null
Set-Reg $TestKey 'New'  DWord 1   | Out-Null
$Global:Twerk.DataDir = $env:TEMP
$bf = Join-Path $env:TEMP 'twerk-bk.json'
$Global:Twerk.BackupFile = $bf
([ordered]@{ Profile='Gaming'; Created='t'; PowerSchemeGuid=$null; RamTask=$null; Registry=$Global:Twerk.Backup } |
    ConvertTo-Json -Depth 6) | Set-Content $bf -Encoding UTF8
Invoke-Revert -BackupPath $bf | Out-Null
ok 'revert restored Keep=100' ((Get-ItemProperty $TestKey).Keep -eq 100)
ok 'revert removed New'        ((Get-ItemProperty $TestKey -Name New -ErrorAction SilentlyContinue) -eq $null)
Remove-Item $bf -Force -ErrorAction SilentlyContinue

Remove-Item $TestKey -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($script:fail) { Write-Host "$script:fail CHECK(S) FAILED" -ForegroundColor Red; exit 1 }
else { Write-Host 'ALL CHECKS PASSED' -ForegroundColor Green }
