# Pester tests for Sel01Tweaker (non-destructive).
# Run:  Invoke-Pester -Path .\tests\Sel01Tweaker.Tests.ps1
# Registry tests use a throwaway HKCU:\Software\Sel01TweakerTest key and clean up.

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    . (Join-Path $root 'src\lib\Common.ps1')
    . (Join-Path $root 'src\lib\Backup.ps1')
    . (Join-Path $root 'src\lib\Ui.ps1')
    Get-ChildItem (Join-Path $root 'src\modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
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

Describe 'Module 07 RAM cleaner - no background task, no working-set eviction' {
    # Regression lock for the v1.9.0 bug: module 07 installed an HOURLY SYSTEM
    # scheduled task that called EmptyWorkingSet() on every process and purged the
    # standby list + file cache, evicting the machine's whole live working set to
    # the pagefile once an hour. It shipped to users. It must never come back.
    BeforeAll {
        # Comments are stripped before scanning: the module header deliberately
        # NAMES the removed APIs to document why they are gone, so only live code
        # is scanned. Register-ScheduledTask is matched with a left word boundary
        # so the legitimate Unregister-ScheduledTask does not trip it.
        $ram07Raw  = Get-Content -Raw (Join-Path $root 'src\modules\07-RamCleaner.ps1')
        $ram07Code = ($ram07Raw -replace '(?s)<#.*?#>', '') -replace '(?m)#.*$', '' -replace '(?m)//.*$', ''
        $ram07Names = $null
        try { Initialize-RamCleaner; $ram07Names = @([Sel01Tweaker.Memory].GetMethods().Name) } catch { $ram07Names = $null }
    }

    It 'exposes the expected commands' {
        (Get-Command Invoke-Module-RamCleaner    -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Invoke-RamClean             -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Remove-LegacyRamCleanerTask -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
        (Get-Command Test-Sel01PagefileOnHdd     -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It 'has no <_> in live source' -ForEach @(
        'EmptyWorkingSet'
        'SetSystemFileCacheSize'
        '(?<![\w-])Register-ScheduledTask'
        'New-ScheduledTaskTrigger'
        'RepetitionInterval'
    ) {
        $ram07Code -match $_ | Should -BeFalse
    }

    It 'does not expose the removed native calls' {
        if ($null -eq $ram07Names) { Set-ItResult -Skipped -Because 'Add-Type is unavailable here'; return }
        $ram07Names | Should -Not -Contain 'EmptyAllWorkingSets'
        $ram07Names | Should -Not -Contain 'TrimFileCache'
    }

    It 'still exposes the standby/modified list calls' {
        if ($null -eq $ram07Names) { Set-ItResult -Skipped -Because 'Add-Type is unavailable here'; return }
        $ram07Names | Should -Contain 'PurgeStandbyList'
        $ram07Names | Should -Contain 'FlushModifiedList'
    }

    It 'changes nothing without -RamClean' {
        $Global:Sel01Tweaker.RamClean = $false
        $Global:Sel01Tweaker.DryRun   = $true
        $Global:Sel01Tweaker.Changes  = [System.Collections.Generic.List[object]]::new()
        Invoke-Module-RamCleaner
        $Global:Sel01Tweaker.Changes.Count | Should -Be 0
        $Global:Sel01Tweaker.DryRun = $false
    }

    It 'removes the legacy hourly task even when -RamClean was not passed' {
        Mock Remove-LegacyRamCleanerTask { }
        $Global:Sel01Tweaker.RamClean = $false
        $Global:Sel01Tweaker.DryRun   = $true
        $Global:Sel01Tweaker.Changes  = [System.Collections.Generic.List[object]]::new()
        Invoke-Module-RamCleaner
        Should -Invoke Remove-LegacyRamCleanerTask -Times 1 -Exactly
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
