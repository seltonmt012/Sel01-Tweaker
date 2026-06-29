# ============================================================================
#  Module 07 - RAM Cleaner  (NATIVE P/Invoke - NOT WinMemoryCleaner code)
#  WinMemoryCleaner is GPL-3.0, so none of its code is used. This is an
#  independent reimplementation of the same documented Win32 calls:
#    - NtSetSystemInformation(SystemMemoryListInformation) -> purge standby +
#      flush modified page list
#    - EmptyWorkingSet per process
#    - SetSystemFileCacheSize -> trim system file cache
#  Requires SeProfileSingleProcessPrivilege + SeIncreaseQuotaPrivilege, which
#  the embedded type enables. Also optionally registers an hourly clean task.
# ============================================================================

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
[DllImport("psapi.dll")] public static extern int EmptyWorkingSet(IntPtr hwProc);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetSystemFileCacheSize(IntPtr min, IntPtr max, int flags);

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

// command: 4 = purge standby list, 3 = flush modified page list, 2 = empty working sets
static uint MemoryCommand(int command) {
    int sz = Marshal.SizeOf(typeof(int));
    IntPtr p = Marshal.AllocHGlobal(sz);
    Marshal.WriteInt32(p, command);
    uint r = NtSetSystemInformation(SystemMemoryListInformation, p, sz);
    Marshal.FreeHGlobal(p);
    return r;
}

public static void PurgeStandbyList()    { MemoryCommand(4); }
public static void FlushModifiedList()   { MemoryCommand(3); }
public static void EmptyAllWorkingSets() {
    foreach (Process proc in Process.GetProcesses()) {
        try { EmptyWorkingSet(proc.Handle); } catch {}
    }
}
public static void TrimFileCache() {
    try { SetSystemFileCacheSize(new IntPtr(-1), new IntPtr(-1), 0); } catch {}
}
'@ -ErrorAction SilentlyContinue
}

function Invoke-RamClean {
    Initialize-RamCleaner
    try {
        [Sel01Tweaker.Memory]::EnablePrivileges()
        [Sel01Tweaker.Memory]::EmptyAllWorkingSets()
        [Sel01Tweaker.Memory]::FlushModifiedList()
        [Sel01Tweaker.Memory]::PurgeStandbyList()
        [Sel01Tweaker.Memory]::TrimFileCache()
        Write-Log 'RAM cleaned (working sets, modified list, standby list, file cache)' 'OK'
    } catch {
        Write-Log "RAM clean failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-Module-RamCleaner {
    param([switch]$NoTask)
    Write-Log '=== Module: RAM Cleaner (native) ===' 'STEP'

    if ($Global:Sel01Tweaker.DryRun) {
        Write-Log 'DRYRUN: would run one-shot RAM clean + register hourly task' 'INFO'
        return
    }

    # One-shot clean now.
    Invoke-RamClean

    if ($NoTask) { Write-Log 'Skipping periodic task (-NoRamTask)' 'INFO'; return }

    # Drop a standalone cleaner script + register an hourly scheduled task.
    $helper = Join-Path $Global:Sel01Tweaker.DataDir 'Sel01Tweaker-RamClean.ps1'
    $helperBody = @'
Add-Type -Namespace Sel01Tweaker -Name Memory -UsingNamespace System.Diagnostics -MemberDefinition @"
[StructLayout(LayoutKind.Sequential)] public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
[DllImport("ntdll.dll")] public static extern uint NtSetSystemInformation(int c, IntPtr i, int l);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr h,int a,ref IntPtr t);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool LookupPrivilegeValue(string h,string n,ref long l);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool AdjustTokenPrivileges(IntPtr t,bool d,ref TokPriv1Luid n,int len,IntPtr p,IntPtr r);
[DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
[DllImport("psapi.dll")] public static extern int EmptyWorkingSet(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetSystemFileCacheSize(IntPtr a,IntPtr b,int f);
static void En(string p){IntPtr t=IntPtr.Zero;OpenProcessToken(GetCurrentProcess(),0x28,ref t);TokPriv1Luid x;x.Count=1;x.Luid=0;x.Attr=2;LookupPrivilegeValue(null,p,ref x.Luid);AdjustTokenPrivileges(t,false,ref x,0,IntPtr.Zero,IntPtr.Zero);}
public static void Run(){En("SeProfileSingleProcessPrivilege");En("SeIncreaseQuotaPrivilege");
foreach(Process pr in Process.GetProcesses()){try{EmptyWorkingSet(pr.Handle);}catch{}}
int sz=Marshal.SizeOf(typeof(int));foreach(int c in new int[]{3,4}){IntPtr m=Marshal.AllocHGlobal(sz);Marshal.WriteInt32(m,c);NtSetSystemInformation(0x50,m,sz);Marshal.FreeHGlobal(m);}
try{SetSystemFileCacheSize(new IntPtr(-1),new IntPtr(-1),0);}catch{}}
"@
[Sel01Tweaker.Memory]::Run()
'@
    Set-Content -Path $helper -Value $helperBody -Encoding UTF8

    $taskName = 'Sel01Tweaker-RamCleaner'
    $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$helper`""
    try {
        schtasks /Create /TN $taskName /TR $cmd /SC HOURLY /RL HIGHEST /RU SYSTEM /F 2>$null | Out-Null
        $Global:Sel01Tweaker.RamTaskName = $taskName
        Write-Log "Registered hourly RAM-clean task: $taskName" 'OK'
        Add-Change 'Hourly RAM-clean task installed'
    } catch {
        Write-Log "Could not register RAM task: $($_.Exception.Message)" 'WARN'
    }
}
