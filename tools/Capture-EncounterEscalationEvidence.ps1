param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rawRoot = Join-Path $projectRoot 'outputs\visual_debug\encounter_escalation\raw'
$stagedRoot = Join-Path $projectRoot 'outputs\visual_debug\encounter_escalation\staged'
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\encounter_escalation\captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Name = '00_boss_battle_baseline.png'; Label = 'Boss battle baseline'; Group = 'overview'; Role = 'actual'; State = 'baseline'; Event = 'battle_start'; Timestamp = 0 },
	@{ Name = '00_boss_battle_baseline.png'; Label = 'Baseline temporal anchor'; Group = 'temporal'; Role = 'frame'; State = 'baseline'; Event = '00_battle_start'; Timestamp = 0 },
	@{ Name = '01_phase_one_banner.png'; Label = 'Phase one banner'; Group = 'temporal'; Role = 'frame'; State = 'phase_one'; Event = '01_threshold_65'; Timestamp = 100 },
	@{ Name = '02_phase_one_reinforcements.png'; Label = 'Phase one reinforcements'; Group = 'temporal'; Role = 'frame'; State = 'phase_one'; Event = '01_threshold_65'; Timestamp = 340 },
	@{ Name = '03_final_phase_banner.png'; Label = 'Final phase banner'; Group = 'temporal'; Role = 'frame'; State = 'phase_two'; Event = '02_threshold_30'; Timestamp = 3000 },
	@{ Name = '04_final_phase_reinforcements.png'; Label = 'Final phase reinforcements'; Group = 'temporal'; Role = 'frame'; State = 'phase_two'; Event = '02_threshold_30'; Timestamp = 3220 }
)

$captures = foreach ($spec in $specs) {
	$source = Join-Path $rawRoot $spec.Name
	if (-not (Test-Path -LiteralPath $source)) {
		throw "Missing authoritative runtime capture: $source"
	}
	$destination = Join-Path $stagedRoot $spec.Name
	Copy-Item -LiteralPath $source -Destination $destination -Force
	(Get-Item -LiteralPath $destination).LastWriteTimeUtc = [DateTime]::UtcNow
	@{
		path = "staged/$($spec.Name)"
		label = $spec.Label
		group = $spec.Group
		role = $spec.Role
		state = $spec.State
		viewport = 'desktop-1600x900'
		camera = 'player'
		layer = 'final'
		event = $spec.Event
		timestamp_ms = $spec.Timestamp
		metadata = @{ runtime = 'Godot 4.5 editor game framebuffer'; scene = 'EncounterEscalationVisualCapture.tscn' }
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh runtime captures."
