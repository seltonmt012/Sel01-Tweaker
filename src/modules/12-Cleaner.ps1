# ============================================================================
#  Module 12 - Temp / Disk cleaner  (both profiles, -SkipClean to skip)
#  Deletes only well-known throwaway locations (user/Windows temp, Windows
#  Update download cache, thumbnail cache) + empties the Recycle Bin. Reports
#  freed space. Not registry/revertable - it's a cleaner; only safe temp paths.
# ============================================================================

function Get-PathSizeBytes {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        return ((Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum)
    } catch { return 0 }
}

function Invoke-Module-Cleaner {
    Write-Log '=== Module: Temp / Disk cleaner ===' 'STEP'

    $targets = @(
        $env:TEMP,
        (Join-Path $env:windir 'Temp'),
        (Join-Path $env:windir 'SoftwareDistribution\Download'),
        (Join-Path $env:LOCALAPPDATA 'Temp'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer')   # thumbcache_*.db
    ) | Select-Object -Unique

    $freed = 0.0
    foreach ($t in $targets) {
        if (-not (Test-Path $t)) { continue }
        $thumbs = ($t -like '*\Explorer')
        $size = if ($thumbs) {
            (Get-ChildItem $t -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        } else { Get-PathSizeBytes $t }
        if (-not $size) { continue }

        if ($Global:Sel01Tweaker.DryRun) {
            Write-Log ("DRYRUN clean {0} (~{1} MB)" -f $t, [math]::Round($size/1MB,1)) 'INFO'
            $freed += $size; continue
        }

        $items = if ($thumbs) {
            Get-ChildItem $t -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue
        } else { Get-ChildItem $t -Force -ErrorAction SilentlyContinue }
        foreach ($i in $items) {
            try { Remove-Item $i.FullName -Recurse -Force -ErrorAction Stop } catch {}   # skip in-use
        }
        $freed += $size
        Write-Log ("cleaned {0} (~{1} MB)" -f $t, [math]::Round($size/1MB,1)) 'INFO'
    }

    # Recycle Bin
    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN empty recycle bin' 'INFO'
    } else {
        try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Log 'recycle bin emptied' 'INFO' } catch {}
    }

    $mb = [math]::Round($freed/1MB, 1)
    Write-Log ("Cleaner: ~{0} MB Temp/Cache freigegeben" -f $mb) 'OK'
    Add-Change ("Temp/Disk geleert (~$mb MB)")
}
