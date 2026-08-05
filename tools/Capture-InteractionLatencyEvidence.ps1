[CmdletBinding()]
param(
	[string] $OutputRoot = "",
	[string] $ProjectPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
	$ProjectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
} else {
	$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $ProjectPath "outputs\visual_debug\interaction_latency"
} else {
	$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}

$sourceManifestPath = Join-Path $OutputRoot "interaction_latency_manifest.json"
$captureManifestPath = Join-Path $OutputRoot "captures.json"
$vdhInputRoot = Join-Path $OutputRoot "vdh_input"
if (-not (Test-Path -LiteralPath $sourceManifestPath -PathType Leaf)) {
	throw "Fresh MCP interaction-latency manifest is missing: $sourceManifestPath"
}

$source = Get-Content -Raw -LiteralPath $sourceManifestPath | ConvertFrom-Json
$filmstrip = @($source.filmstrip)
if ($filmstrip.Count -lt 2) {
	throw "Interaction-latency manifest must contain result and settled runtime captures."
}

$commit = (& git -C $ProjectPath rev-parse HEAD).Trim()
$branch = (& git -C $ProjectPath branch --show-current).Trim()
$firstTimestamp = [int64] $filmstrip[0].captured_at_usec
$captures = @()
New-Item -ItemType Directory -Path $vdhInputRoot -Force | Out-Null
foreach ($frame in $filmstrip) {
	$capture = $frame.capture
	$absolutePath = [System.IO.Path]::GetFullPath([string] $capture.absolute_path)
	if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
		throw "Runtime capture is missing: $absolutePath"
	}
	if (-not [bool] $capture.viewport_ok) {
		throw "Runtime capture did not provide an authoritative viewport image: $absolutePath"
	}
	$vdhInputPath = Join-Path $vdhInputRoot (([string] $frame.label) + ".png")
	Copy-Item -LiteralPath $absolutePath -Destination $vdhInputPath -Force
	(Get-Item -LiteralPath $vdhInputPath).LastWriteTimeUtc = [DateTime]::UtcNow
	$relativePath = $vdhInputPath.Substring($OutputRoot.Length).TrimStart("\", "/").Replace("\", "/")
	$hash = (Get-FileHash -LiteralPath $vdhInputPath -Algorithm SHA256).Hash.ToLowerInvariant()
	$captures += @{
		path = $relativePath
		label = [string] $frame.label
		group = "result_dismissal"
		role = "actual"
		state = [string] $frame.label
		viewport = "desktop-1920x1080"
		camera = "player"
		layer = "final"
		event = [string] $frame.label
		timestamp_ms = [int] [math]::Round(([int64] $frame.captured_at_usec - $firstTimestamp) / 1000.0, 0)
		metadata = @{
			runtime = "Godot 4.5 editor game framebuffer"
			entrypoint = "res://scenes/Main.tscn"
			branch = $branch
			commit = $commit
			sha256 = $hash
			source_runtime_capture = $absolutePath
			copy_for_vdh_packet = $true
			timeline_source = "interaction_latency_manifest.json"
		}
	}
}

$payload = @{
	captures = $captures
	metrics = @($source.interactions)
	metadata = @{
		entrypoint = "res://scenes/Main.tscn"
		runtime = "Godot 4.5 editor game framebuffer"
		branch = $branch
		commit = $commit
		captured_at = [string] $source.captured_at
		timeline_source = "interaction_latency_manifest.json"
	}
} | ConvertTo-Json -Depth 12

$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($captureManifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $captureManifestPath from fresh MCP interaction-latency captures."
