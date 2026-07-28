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
	$OutputRoot = Join-Path $ProjectPath "outputs\visual_debug\godot_visibility"
} else {
	$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}

$rawRoot = Join-Path $OutputRoot "raw"
$capturePath = Join-Path $rawRoot "title_ready.png"
$manifestPath = Join-Path $OutputRoot "captures.json"
New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null

$captureResultJson = & (Join-Path $ProjectPath "tools\Capture-GodotMcp.ps1") `
	-OutputPath $capturePath `
	-ProjectPath $ProjectPath `
	-Run main `
	-Source game `
	-MaxResolution 0 `
	-ExpectedWidth 1920 `
	-ExpectedHeight 1080 `
	-ForceRelaunch `
	-WaitSeconds 30 `
	-VisualWaitSeconds 20 `
	-ConnectionAttempts 3
$captureResult = $captureResultJson | ConvertFrom-Json
if (-not $captureResult.ok) {
	throw "Godot MCP capture did not report success."
}
$actualWidth = [int] $captureResult.visual_metrics.width
$actualHeight = [int] $captureResult.visual_metrics.height
if ($actualWidth -ne 1920 -or $actualHeight -ne 1080) {
	throw "Godot MCP capture reported unexpected dimensions: ${actualWidth}x${actualHeight}"
}

$commit = (& git -C $ProjectPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git revision for capture provenance."
}
$branch = (& git -C $ProjectPath branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git branch for capture provenance."
}
$hash = (Get-FileHash -LiteralPath $capturePath -Algorithm SHA256).Hash.ToLowerInvariant()
$capture = @{
	path = "raw/title_ready.png"
	label = "Player-facing title screen"
	group = "overview"
	role = "actual"
	state = "title_ready"
	viewport = "desktop-${actualWidth}x${actualHeight}"
	camera = "player"
	layer = "final"
	event = "title_ready"
	timestamp_ms = 0
	metadata = @{
		runtime = "Godot 4.5 editor game framebuffer"
		entrypoint = "res://scenes/Main.tscn"
		branch = $branch
		commit = $commit
		sha256 = $hash
		actual_width = $actualWidth
		actual_height = $actualHeight
	}
}
$payload = @{
	captures = @($capture)
} | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)

Write-Output "Wrote $manifestPath with one fresh nonblank Godot runtime capture."
