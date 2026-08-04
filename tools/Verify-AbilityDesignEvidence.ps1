[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\ability_design_audit\captures.json'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Ability evidence manifest is missing. Run tests/visual/AbilityDesignRosterCapture.tscn through Godot MCP first: $manifestPath"
}

$manifestItem = Get-Item -LiteralPath $manifestPath
$ageSeconds = ((Get-Date).ToUniversalTime() - $manifestItem.LastWriteTimeUtc).TotalSeconds
if ($ageSeconds -gt 1800) {
    throw "Ability evidence is stale ($([Math]::Round($ageSeconds)) seconds old). Rerun the MCP capture scene."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$captures = @($manifest.captures)
$failures = @($manifest.failures)
if ($failures.Count -gt 0) {
    throw "Ability evidence manifest reports failures: $($failures -join '; ')"
}
if ($captures.Count -ne 33) {
    throw "Ability evidence requires 33 captures (11 groups x 3 beats), found $($captures.Count)."
}

$groups = @('cost1_a', 'cost1_b', 'cost1_c', 'cost2_a', 'cost2_b', 'cost2_c', 'cost3_a', 'cost3_b', 'cost4_a', 'cost4_b', 'cost5')
$events = @('setup', 'impact', 'aftermath')
foreach ($group in $groups) {
    foreach ($event in $events) {
        $matching = @($captures | Where-Object { $_.group -eq $group -and $_.event -eq $event })
        if ($matching.Count -ne 1) {
            throw "Expected one $group/$event capture, found $($matching.Count)."
        }
        if (-not (Test-Path -LiteralPath ([string]$matching[0].path) -PathType Leaf)) {
            throw "Capture file is missing: $($matching[0].path)"
        }
    }
}

Write-Output "AbilityDesignEvidence: PASS captures=33 manifest=$manifestPath"
