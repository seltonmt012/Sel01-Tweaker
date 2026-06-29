# ============================================================================
#  Module 05 - Power Plan  (Ultimate Performance)
#  powercfg -duplicatescheme mints a NEW GUID each time; we capture it from the
#  command output and set it active. The minted GUID is stored in state so
#  -Revert can delete it and restore Balanced.
# ============================================================================

function Invoke-Module-PowerPlan {
    Write-Log '=== Module: Power Plan (Ultimate Performance) ===' 'STEP'

    if ($Global:Twerk.DryRun) {
        Write-Log 'DRYRUN: would duplicate + activate Ultimate Performance plan' 'INFO'
        return
    }

    $template = 'e9a42b02-d5df-448d-aa00-03f14749eb61'   # built-in Ultimate Performance template

    try {
        # If an Ultimate Performance plan already exists, reuse it.
        $existing = powercfg /list 2>$null | Select-String -Pattern 'Ultimate Performance|Ultimative Leistung'
        if ($existing) {
            $guid = ([regex]'([0-9a-fA-F-]{36})').Match($existing[0].ToString()).Value
            Write-Log "Existing Ultimate Performance plan found: $guid" 'INFO'
        } else {
            $out = powercfg -duplicatescheme $template 2>$null
            $guid = ([regex]'([0-9a-fA-F-]{36})').Match(($out -join ' ')).Value
            if ($guid) { $Global:Twerk.PowerSchemeGuid = $guid }   # only mark for deletion if WE minted it
            Write-Log "Minted Ultimate Performance plan: $guid" 'INFO'
        }

        if ($guid) {
            powercfg /setactive $guid 2>$null | Out-Null
            Write-Log 'Ultimate Performance plan active' 'OK'
            Add-Change 'Power plan: Ultimate Performance'
        } else {
            Write-Log 'Could not determine power scheme GUID; leaving plan unchanged' 'WARN'
        }
    } catch {
        Write-Log "Power plan setup failed: $($_.Exception.Message)" 'WARN'
    }
}
