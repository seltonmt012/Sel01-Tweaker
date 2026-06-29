# Pester tests for Sel01Tweaker (non-destructive).
# Run:  Invoke-Pester -Path .\tests\Sel01Tweaker.Tests.ps1
# Registry tests use a throwaway HKCU:\Software\Sel01TweakerTest key and clean up.

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . (Join-Path $root 'src\lib\Common.ps1')
    . (Join-Path $root 'src\lib\Backup.ps1')
    $TestKey = 'HKCU:\Software\Sel01TweakerTest'
}

AfterAll {
    if (Test-Path 'HKCU:\Software\Sel01TweakerTest') {
        Remove-Item 'HKCU:\Software\Sel01TweakerTest' -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Build-PreferencesMask' {
    It 'returns the documented best-performance byte string' {
        $bytes = Build-PreferencesMask
        ($bytes | ForEach-Object { '{0:X2}' -f $_ }) -join ' ' | Should -Be '90 12 03 80 10 00 00 00'
    }
    It 'is 8 bytes' {
        (Build-PreferencesMask).Count | Should -Be 8
    }
}

Describe 'Set-Reg snapshot + typed write' {
    BeforeEach {
        $Global:Sel01Tweaker.DryRun = $false
        $Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
        if (Test-Path $TestKey) { Remove-Item $TestKey -Recurse -Force }
    }

    It 'writes a DWORD and records it did not exist before' {
        Set-Reg $TestKey 'Num' DWord 7
        (Get-ItemProperty $TestKey).Num | Should -Be 7
        $snap = $Global:Sel01Tweaker.Backup | Where-Object Name -eq 'Num'
        $snap.Existed | Should -BeFalse
    }

    It 'writes a String with correct type' {
        Set-Reg $TestKey 'Str' String '1'
        $info = Get-RegValueSafe $TestKey 'Str'
        $info.Value | Should -Be '1'
        "$($info.Kind)" | Should -Be 'String'
    }

    It 'snapshots the ORIGINAL value on repeated writes' {
        Set-Reg $TestKey 'Num' DWord 1
        Set-Reg $TestKey 'Num' DWord 2
        ($Global:Sel01Tweaker.Backup | Where-Object Name -eq 'Num').Count | Should -Be 1
        (Get-ItemProperty $TestKey).Num | Should -Be 2
    }

    It 'writes binary values' {
        Set-Reg $TestKey 'Bin' Binary ([byte[]]@(0x90,0x12,0x03))
        (Get-RegValueSafe $TestKey 'Bin').Value | Should -Be ([byte[]]@(0x90,0x12,0x03))
    }
}

Describe 'Set-Reg DryRun' {
    It 'records a snapshot but writes nothing' {
        $Global:Sel01Tweaker.DryRun = $true
        $Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
        if (Test-Path $TestKey) { Remove-Item $TestKey -Recurse -Force }
        Set-Reg $TestKey 'DryVal' DWord 5
        (Test-Path $TestKey) | Should -BeFalse
        ($Global:Sel01Tweaker.Backup | Where-Object Name -eq 'DryVal') | Should -Not -BeNullOrEmpty
        $Global:Sel01Tweaker.DryRun = $false
    }
}

Describe 'Revert round-trip' {
    It 'restores a pre-existing value and removes an added value' {
        $Global:Sel01Tweaker.DryRun = $false
        $Global:Sel01Tweaker.Backup = [System.Collections.Generic.List[object]]::new()
        New-Item $TestKey -Force | Out-Null
        New-ItemProperty $TestKey -Name 'Keep' -PropertyType DWord -Value 100 -Force | Out-Null

        Set-Reg $TestKey 'Keep' DWord 999   # existed -> should restore to 100
        Set-Reg $TestKey 'New'  DWord 1     # new     -> should be removed

        # Simulate a backup file + revert.
        $Global:Sel01Tweaker.DataDir = $env:TEMP
        $Global:Sel01Tweaker.BackupFile = Join-Path $env:TEMP 'backup-test.json'
        $Global:Sel01Tweaker.Stamp = 'test'
        ([ordered]@{ Profile='Gaming'; Created='test'; PowerSchemeGuid=$null; RamTask=$null; Registry=$Global:Sel01Tweaker.Backup } |
            ConvertTo-Json -Depth 6) | Set-Content $Global:Sel01Tweaker.BackupFile -Encoding UTF8

        Invoke-Revert -BackupPath $Global:Sel01Tweaker.BackupFile

        (Get-ItemProperty $TestKey).Keep | Should -Be 100
        (Get-ItemProperty $TestKey -Name 'New' -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
        Remove-Item $Global:Sel01Tweaker.BackupFile -Force -ErrorAction SilentlyContinue
    }
}
