param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'outputs\visual_debug\black_ledger\main_source'
$stagedRoot = Join-Path $projectRoot 'outputs\visual_debug\black_ledger\staged'
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\black_ledger\captures.json'
$freshnessCutoff = [DateTime]::UtcNow.AddMinutes(-15)
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Source = '01_main_fresh.png'; Name = '01_main_fresh.png'; Label = 'F'; State = 'fresh'; Event = 'f'; Timestamp = 0 },
	@{ Source = '02_main_veteran.png'; Name = '02_main_veteran.png'; Label = 'V'; State = 'veteran'; Event = 'v'; Timestamp = 0 }
)

$captures = foreach ($spec in $specs) {
	$sourcePath = Join-Path $sourceRoot $spec.Source
	if (-not (Test-Path -LiteralPath $sourcePath)) {
		throw "Missing authoritative runtime capture: $sourcePath"
	}
	$source = Get-Item -LiteralPath $sourcePath
	if ($source.LastWriteTimeUtc -lt $freshnessCutoff) {
		throw "Runtime capture is stale: $sourcePath"
	}
	$destination = Join-Path $stagedRoot $spec.Name
	Copy-Item -LiteralPath $sourcePath -Destination $destination -Force
	(Get-Item -LiteralPath $destination).LastWriteTimeUtc = [DateTime]::UtcNow
	@{
		path = "staged/$($spec.Name)"
		label = $spec.Label
		group = 'ledger'
		role = 'actual'
		state = $spec.State
		viewport = '1920x1080'
		camera = 'p'
		layer = 'f'
		event = $spec.Event
		timestamp_ms = $spec.Timestamp
		metadata = @{
			runtime = 'Godot 4.5 Main scene game framebuffer'
			scene = 'Main.tscn'
			branch = 'current Black Ledger integration worktree'
			source = $spec.Source
		}
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh player-frame captures."
