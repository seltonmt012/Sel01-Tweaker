# ============================================================================
#  Module 19 - GPU shader cache cleaner  (OPT-IN: -ShaderClean, or menu entry)
#  Deletes the compiled shader caches of the installed GPU vendor + the two
#  Windows/DirectX ones. Drivers rebuild them automatically.
#
#  WHY opt-in and not part of the normal run: clearing costs a one-time shader
#  recompile on the next game start (GTA V ~1-2 min of stutter). It is a REPAIR
#  step for "stutter/artefacts after a driver or Windows update", not a
#  per-run optimisation. The cache exists to make things faster.
#
#  Not registry -> nothing to revert (same class as module 12 Cleaner).
# ============================================================================

function Get-Sel01ShaderCachePaths {
    <#  Returns the shader-cache directories that EXIST on this machine.
        Vendor gating is implicit: an AMD box simply has no NVIDIA\DXCache.
        Only cache dirs are listed - never a driver/program directory.  #>
    $la = $env:LOCALAPPDATA
    if (-not $la) { return @() }
    $candidates = @(
        (Join-Path $la 'NVIDIA\DXCache'),                      # NVIDIA DirectX
        (Join-Path $la 'NVIDIA\GLCache'),                      # NVIDIA OpenGL/Vulkan
        (Join-Path $la 'NVIDIA Corporation\NV_Cache'),         # NVIDIA (legacy)
        (Join-Path $la 'AMD\DxCache'),                         # AMD DirectX
        (Join-Path $la 'AMD\DxcCache'),                        # AMD DXC
        (Join-Path $la 'AMD\GLCache'),                         # AMD OpenGL
        (Join-Path $la 'AMD\VkCache'),                         # AMD Vulkan
        (Join-Path $la 'Intel\ShaderCache'),                   # Intel (iGPU/Arc)
        (Join-Path $la 'D3DSCache'),                           # DirectX (per-user)
        (Join-Path $la 'Microsoft\DirectX Shader Cache')       # Windows DX cache
    )
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ })
}

function Clear-Sel01ShaderCache {
    <#  Empties each cache dir CONTENT-wise (keeps the dir itself - drivers
        expect it to exist). Files locked by a running game are skipped.
        Honours -DryRun. Returns freed bytes.  #>
    $paths = Get-Sel01ShaderCachePaths
    if (-not $paths -or $paths.Count -eq 0) {
        Write-Log 'Keine Shader-Caches gefunden (kein NVIDIA/AMD/Intel-Cache angelegt)' 'INFO'
        return 0
    }

    # A running game re-creates shaders while we delete -> half-cleaned cache.
    # Warn (don't abort): locked files are skipped anyway.
    $busy = Get-Process -Name 'GTA5','GTA5_Enhanced','FiveM','FiveM_GTAProcess','RDR2','csgo','cs2' -ErrorAction SilentlyContinue
    if ($busy) { Write-Log 'Ein Spiel laeuft - Shader-Clean ist unvollstaendig (erst Spiel schliessen)' 'WARN' }

    $freed = 0.0
    foreach ($p in $paths) {
        $size = (Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object Length -Sum).Sum
        if (-not $size) { continue }
        $short = $p.Replace($env:LOCALAPPDATA, '%LOCALAPPDATA%')

        if ($Global:Sel01Tweaker.DryRun) {
            Write-Log ("DRYRUN shader-cache {0} (~{1} MB)" -f $short, [math]::Round($size/1MB,1)) 'INFO'
            $freed += $size; continue
        }

        Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch {}   # skip in-use
        }
        $freed += $size
        Write-Log ("Shader-Cache geleert: {0} (~{1} MB)" -f $short, [math]::Round($size/1MB,1)) 'INFO'
    }

    $mb = [math]::Round($freed/1MB,1)
    Write-Log ("Shader-Cache: ~{0} MB frei. Erster Spielstart baut die Shader neu (einmalig ruckeliger)." -f $mb) 'OK'
    return $freed
}

function Invoke-Module-ShaderCache {
    Write-Log '=== Module: Shader-Cache leeren (opt-in) ===' 'STEP'
    if (-not $Global:Sel01Tweaker.ShaderClean) {
        Write-Log 'Shader-Cache-Clean uebersprungen (nur mit -ShaderClean oder ueber das Menue)' 'INFO'
        return
    }
    $freed = Clear-Sel01ShaderCache
    $mb = [math]::Round($freed/1MB,1)
    Add-Change ("Shader-Cache geleert (~$mb MB)")
}
