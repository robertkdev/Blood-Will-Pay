[CmdletBinding()]
param(
    [int]$MaximumAgeSeconds = 1800
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\ability_filmstrips\captures.json'
$expectedEvents = @('setup', 'impact', 'aftermath')
$expectedUnitCount = 51
$expectedCaptureCount = $expectedUnitCount * $expectedEvents.Count

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Ability filmstrip manifest is missing. Run tests/visual/AbilityFilmstripCapture.tscn through Godot MCP first: $manifestPath"
}

$manifestItem = Get-Item -LiteralPath $manifestPath
$ageSeconds = ((Get-Date).ToUniversalTime() - $manifestItem.LastWriteTimeUtc).TotalSeconds
if ($ageSeconds -gt $MaximumAgeSeconds) {
    throw "Ability filmstrip evidence is stale ($([Math]::Round($ageSeconds)) seconds old; limit $MaximumAgeSeconds)."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.schema_version -ne 2) {
    throw "Expected filmstrip manifest schema 2, found $($manifest.schema_version)."
}
$failures = @($manifest.failures)
if ($failures.Count -gt 0) {
    throw "Filmstrip manifest reports failures: $($failures -join '; ')"
}
$battles = @($manifest.battles)
$captures = @($manifest.captures)
if ($battles.Count -ne $expectedUnitCount) {
    throw "Expected $expectedUnitCount isolated battles, found $($battles.Count)."
}
if ($captures.Count -ne $expectedCaptureCount) {
    throw "Expected $expectedCaptureCount captures (51 x 3), found $($captures.Count)."
}

$unitIds = @($battles | ForEach-Object { [string]$_.unit_id } | Sort-Object -Unique)
if ($unitIds.Count -ne $expectedUnitCount) {
    throw "Expected $expectedUnitCount unique unit ids, found $($unitIds.Count)."
}

foreach ($battle in $battles) {
    $unitId = [string]$battle.unit_id
    $abilityId = [string]$battle.ability_id
    $committed = @($battle.committed_casts)
	$eventTimes = @{}
    if ([string]::IsNullOrWhiteSpace($abilityId)) {
        throw "$unitId has an empty ability id."
    }
    if (-not [bool]$battle.expected_cast_committed_once) {
        throw "$unitId did not commit its named ability exactly once."
    }
    if (-not [bool]$battle.no_overlapping_committed_casts -or $committed.Count -ne 1) {
        throw "$unitId has overlapping committed casts."
    }
    $cast = $committed[0]
    if ([string]$cast.source_team -ne 'player' -or [int]$cast.source_index -ne 0 -or [string]$cast.ability_id -ne $abilityId) {
        throw "$unitId committed cast does not match its named ability $abilityId."
    }

    foreach ($event in $expectedEvents) {
        $matching = @($captures | Where-Object { [string]$_.unit_id -eq $unitId -and [string]$_.event -eq $event })
        if ($matching.Count -ne 1) {
            throw "Expected exactly one $unitId/$event capture, found $($matching.Count)."
        }
        $capture = $matching[0]
        if ([string]$capture.ability_id -ne $abilityId) {
            throw "$unitId/$event ability id differs from the committed battle ability."
        }
        if ([string]$capture.camera -ne 'player' -or [string]$capture.layer -ne 'final' -or [string]$capture.viewport -ne '1600x900') {
            throw "$unitId/$event is not a player-scale final-layer capture."
        }
        $capturePath = [string]$capture.path
        if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
            throw "Capture file is missing: $capturePath"
        }
        $file = Get-Item -LiteralPath $capturePath
        if ([int64]$capture.file_size_bytes -ne [int64]$file.Length) {
            throw "$unitId/$event file size differs from manifest."
        }
        $actualMtime = [DateTimeOffset]::new($file.LastWriteTimeUtc).ToUnixTimeSeconds()
        if ([int64]$capture.file_mtime_unix -ne $actualMtime) {
            throw "$unitId/$event file timestamp differs from manifest."
        }
        $actualHash = (Get-FileHash -LiteralPath $capturePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ([string]$capture.sha256 -ne $actualHash) {
            throw "$unitId/$event SHA-256 differs from manifest."
        }
        if ([int64]$capture.captured_at_unix_ms -le 0) {
            throw "$unitId/$event has no exact capture timestamp."
        }
		$eventTimes[$event] = [int64]$capture.captured_at_unix_ms
		$observedAtCapture = @($capture.committed_casts_observed)
		if ($event -eq 'setup' -and $observedAtCapture.Count -ne 0) {
			throw "$unitId/setup was captured after a committed cast."
		}
		if ($event -ne 'setup' -and $observedAtCapture.Count -ne 1) {
			throw "$unitId/$event does not carry the single committed-cast proof."
		}
    }
	if ($eventTimes.setup -gt $eventTimes.impact -or $eventTimes.impact -gt $eventTimes.aftermath) {
		throw "$unitId temporal captures are not ordered setup -> impact -> aftermath."
	}
}

Write-Output "AbilityFilmstripEvidence: PASS units=$expectedUnitCount captures=$expectedCaptureCount hashes=verified timestamps=verified manifest=$manifestPath"
