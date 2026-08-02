param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rawRoot = Join-Path $projectRoot 'outputs\visual_debug\contract_system\raw'
$stagedRoot = Join-Path $projectRoot 'outputs\visual_debug\contract_system\staged'
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\contract_system\captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Name = '00_contract_market.png'; Label = 'Contract market with explicit tradeoffs'; Group = 'overview'; Role = 'actual'; State = 'market'; Event = 'market'; Timestamp = 0 },
	@{ Name = '01_champion_targeting.png'; Label = 'Champion writ unit targeting'; Group = 'overview'; Role = 'actual'; State = 'targeting'; Event = 'targeting'; Timestamp = 100 },
	@{ Name = '02_warded_lines_banner.png'; Label = 'Stable ward activation'; Group = 'temporal'; Role = 'frame'; State = 'stable_ward'; Event = '00_stable_ward'; Timestamp = 0 },
	@{ Name = '03_warded_lines_shields.png'; Label = 'Stable ward shield state'; Group = 'temporal'; Role = 'frame'; State = 'stable_ward'; Event = '00_stable_ward'; Timestamp = 300 },
	@{ Name = '04_cinder_clock_banner.png'; Label = 'Cinder Clock arena pulse'; Group = 'temporal'; Role = 'frame'; State = 'pit_hazard'; Event = '01_pit_hazard'; Timestamp = 2500 },
	@{ Name = '05_cinder_clock_aftermath.png'; Label = 'Cinder Clock aftermath'; Group = 'temporal'; Role = 'frame'; State = 'pit_hazard'; Event = '01_pit_hazard'; Timestamp = 2800 }
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
		metadata = @{ runtime = 'Godot 4.5 editor game framebuffer'; scene = 'ContractSystemVisualCapture.tscn' }
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh runtime captures."
