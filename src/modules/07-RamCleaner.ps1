# ============================================================================
#  Module 07 - RAM Cleaner  (NATIVE P/Invoke - NOT WinMemoryCleaner code)
#  WinMemoryCleaner is GPL-3.0, so none of its code is used. This is an
#  independent reimplementation of documented Win32 calls.
#
#  HISTORY - why this module shrank in v1.10.0:
#  Up to v1.9.0 this module ran unconditionally and installed a scheduled task
#  that fired at boot +3 min and then HOURLY as SYSTEM. That task called
#  EmptyWorkingSet() on every process, purged the standby list, and flushed the
#  system file cache. That is actively harmful:
#    - EmptyWorkingSet on every process evicts the whole live working set of the
#      machine. Dirty pages go to the pagefile; everything the user touches next
#      has to be faulted back in. On a box whose pagefile sits on a hard disk
#      (~145 random IOPS) that is minutes of a fully unresponsive desktop, once
#      an hour, forever. It logs nothing - Resource-Exhaustion-Detector only
#      fires near the commit limit, which is never reached.
#    - Purging the standby list throws away the file cache. The standby list is
#      already reclaimable memory; Windows hands it back on demand. Dropping it
#      only forces re-reads from disk.
#  "Free RAM" going up in Task Manager is the symptom of the damage, not a win.
#
#  So: no background task, ever. EmptyWorkingSet is gone entirely. What is left
#  is an opt-in, one-shot standby-list purge (-RamClean), which is the only part
#  with a defensible use case (reclaiming a standby list stuffed with junk after
#  a huge file copy). Same opt-in shape as module 19 ShaderCache.
#
#  Every run still calls Remove-LegacyRamCleanerTask, which uninstalls the
#  hourly task and helper script left behind by <= v1.9.0.
# ============================================================================

$Script:Sel01LegacyRamTaskName   = 'Sel01Tweaker-RamCleaner'
$Script:Sel01LegacyRamHelperName = 'Sel01Tweaker-RamClean.ps1'

function Initialize-RamCleaner {
    if (([System.Management.Automation.PSTypeName]'Sel01Tweaker.Memory').Type) { return }
    Add-Type -Namespace Sel01Tweaker -Name Memory -UsingNamespace System.Diagnostics -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }

[DllImport("ntdll.dll")]
public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);
[DllImport("advapi32.dll", SetLastError=true)]
public static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
[DllImport("advapi32.dll", SetLastError=true)]
public static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
[DllImport("advapi32.dll", SetLastError=true)]
public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
[DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();

const int SE_PRIVILEGE_ENABLED = 0x00000002;
const int TOKEN_ADJUST = 0x20; const int TOKEN_QUERY = 0x08;
const int SystemMemoryListInformation = 0x50;

static void Enable(string priv) {
    IntPtr tok = IntPtr.Zero;
    OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST | TOKEN_QUERY, ref tok);
    TokPriv1Luid p; p.Count = 1; p.Luid = 0; p.Attr = SE_PRIVILEGE_ENABLED;
    LookupPrivilegeValue(null, priv, ref p.Luid);
    AdjustTokenPrivileges(tok, false, ref p, 0, IntPtr.Zero, IntPtr.Zero);
}

public static void EnablePrivileges() {
    Enable("SeProfileSingleProcessPrivilege");
    Enable("SeIncreaseQuotaPrivilege");
}

// command: 4 = purge standby list, 3 = flush modified page list.
// Deliberately NO command 2 (empty every working set) and no
// SetSystemFileCacheSize - see the header comment.
static uint MemoryCommand(int command) {
    int sz = Marshal.SizeOf(typeof(int));
    IntPtr p = Marshal.AllocHGlobal(sz);
    Marshal.WriteInt32(p, command);
    uint r = NtSetSystemInformation(SystemMemoryListInformation, p, sz);
    Marshal.FreeHGlobal(p);
    return r;
}

public static void FlushModifiedList() { MemoryCommand(3); }
public static void PurgeStandbyList()  { MemoryCommand(4); }
'@ -ErrorAction SilentlyContinue
}

# Is the pagefile on rotating rust? Then a standby purge is far more expensive
# than it looks, because everything re-read afterwards competes with paging on a
# ~145 IOPS spindle. Best effort - any failure just means "don't warn".
function Test-Sel01PagefileOnHdd {
    try {
        $pf = @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop)
        if (-not $pf) { return $false }
        foreach ($p in $pf) {
            $letter = ($p.Name -split ':')[0]
            if (-not $letter) { continue }
            $part = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
            if (-not $part) { continue }
            $disk = Get-PhysicalDisk -ErrorAction SilentlyContinue |
                    Where-Object { $_.DeviceId -eq [string]$part.DiskNumber }
            if ($disk -and $disk.MediaType -eq 'HDD') { return $true }
        }
    } catch { }
    return $false
}

# Uninstall the hourly task + helper script that <= v1.9.0 installed. Runs on
# every invocation, including DryRun reporting, so upgrading users get rid of it
# without having to know it was ever there.
function Remove-LegacyRamCleanerTask {
    $found = $false

    $task = Get-ScheduledTask -TaskName $Script:Sel01LegacyRamTaskName -ErrorAction SilentlyContinue
    if ($task) {
        $found = $true
        if ($Global:Sel01Tweaker.DryRun) {
            Write-Log "DRYRUN: would remove legacy hourly RAM task '$Script:Sel01LegacyRamTaskName'" 'INFO'
        } else {
            try {
                Unregister-ScheduledTask -TaskName $Script:Sel01LegacyRamTaskName -Confirm:$false -ErrorAction Stop
                Write-Log "Removed legacy hourly RAM task '$Script:Sel01LegacyRamTaskName' (caused periodic freezes)" 'OK'
                Add-Change 'Removed the old hourly RAM-clean task (it caused periodic system freezes)'
            } catch {
                Write-Log "Could not remove legacy RAM task: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    $helper = Join-Path $Global:Sel01Tweaker.DataDir $Script:Sel01LegacyRamHelperName
    if (Test-Path -LiteralPath $helper) {
        $found = $true
        if ($Global:Sel01Tweaker.DryRun) {
            Write-Log "DRYRUN: would delete legacy helper script $helper" 'INFO'
        } else {
            try {
                Remove-Item -LiteralPath $helper -Force -ErrorAction Stop
                Write-Log "Deleted legacy RAM helper script $helper" 'OK'
            } catch {
                Write-Log "Could not delete legacy helper script: $($_.Exception.Message)" 'WARN'
            }
        }
    }

    return $found
}

# One-shot, opt-in. Flushes the modified page list (those pages have to be
# written eventually anyway) and purges the standby list. Never touches process
# working sets.
function Invoke-RamClean {
    Initialize-RamCleaner
    try {
        [Sel01Tweaker.Memory]::EnablePrivileges()
        [Sel01Tweaker.Memory]::FlushModifiedList()
        [Sel01Tweaker.Memory]::PurgeStandbyList()
        Write-Log 'Standby list purged (working sets untouched by design)' 'OK'
    } catch {
        Write-Log "RAM clean failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-Module-RamCleaner {
    param([switch]$NoTask)   # deprecated no-op, kept so old command lines still bind
    Write-Log '=== Module: RAM Cleaner (native) ===' 'STEP'

    # Always: undo the harmful thing older versions installed.
    Remove-LegacyRamCleanerTask | Out-Null

    if (-not $Global:Sel01Tweaker.RamClean) {
        Write-Log 'One-shot RAM clean not requested (-RamClean); no background task is installed' 'INFO'
        return
    }

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN: would purge the standby list once (no task, no working-set eviction)' 'INFO'
        return
    }

    # A reboot zeroes live memory anyway, so an immediate purge would be wasted.
    if ($Global:Sel01Tweaker.RebootNeeded) {
        Write-Log 'One-shot RAM clean skipped (restart pending - it would be wiped anyway)' 'INFO'
        return
    }

    if (Test-Sel01PagefileOnHdd) {
        Write-Log 'Pagefile lives on an HDD - purging the cache here costs more than it frees. Skipped.' 'WARN'
        Write-Log 'Move the pagefile to an SSD first (System > About > Advanced system settings).' 'INFO'
        return
    }

    Invoke-RamClean
    Add-Change 'Standby list purged once (no background task installed)'
}
