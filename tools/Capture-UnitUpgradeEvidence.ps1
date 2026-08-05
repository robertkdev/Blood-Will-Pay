param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rawRoot = Join-Path $projectRoot 'outputs\visual_debug\unit_upgrades\raw'
$stagedRoot = Join-Path $projectRoot 'outputs\visual_debug\unit_upgrades\staged'
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\unit_upgrades\captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Name = '00_blood_engine_capital.png'; Label = 'Blood Engine capital recruit with benefit and health debt'; Group = 'premium_identity'; Role = 'actual'; State = 'blood_engine'; Event = 'capital_offer'; Timestamp = 0 },
	@{ Name = '01_iron_retinue_capital.png'; Label = 'Iron Retinue capital recruit with shield and cadence tax'; Group = 'premium_identity'; Role = 'actual'; State = 'iron_retinue'; Event = 'capital_offer'; Timestamp = 100 },
	@{ Name = '02_level_four_ascension.png'; Label = 'Level-four permanent legacy decision with triggers and failure cases'; Group = 'ascension'; Role = 'actual'; State = 'level_four_choice'; Event = 'ascension'; Timestamp = 200 }
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
		viewport = 'desktop-1920x1080'
		camera = 'player'
		layer = 'final'
		event = $spec.Event
		timestamp_ms = $spec.Timestamp
		metadata = @{ runtime = 'Godot 4.5 editor game framebuffer'; scene = 'UnitUpgradeShowcase.tscn' }
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh runtime captures."
