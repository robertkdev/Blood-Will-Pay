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
	$OutputRoot = Join-Path $ProjectPath "outputs\visual_debug\black_ledger"
} else {
	$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}

$rawRoot = Join-Path $OutputRoot "raw"
$manifestPath = Join-Path $OutputRoot "captures.json"
New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null

$commit = (& git -C $ProjectPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git revision for capture provenance."
}
$branch = (& git -C $ProjectPath branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git branch for capture provenance."
}
$worktreeDirty = @(& git -C $ProjectPath status --porcelain=v1).Count -gt 0

$specs = @(
	@{
		scene = "res://tests/visual/BlackLedgerFreshFixture.tscn"
		file = "01_main_fresh.png"
		label = "Fresh local profile"
		state = "fresh"
		event = "f"
	},
	@{
		scene = "res://tests/visual/BlackLedgerVeteranFixture.tscn"
		file = "02_main_veteran.png"
		label = "Veteran local profile"
		state = "veteran"
		event = "v"
	}
)

$captures = @()
foreach ($spec in $specs) {
	$outputPath = Join-Path $rawRoot $spec.file
	$resultJson = & (Join-Path $ProjectPath "tools\Capture-GodotMcp.ps1") `
		-OutputPath $outputPath `
		-ProjectPath $ProjectPath `
		-Run custom `
		-Scene $spec.scene `
		-Source game `
		-MaxResolution 0 `
		-ExpectedWidth 1920 `
		-ExpectedHeight 1080 `
		-ForceRelaunch `
		-StopAfterCapture `
		-WaitSeconds 30 `
		-VisualWaitSeconds 20 `
		-SettleSeconds 1 `
		-ConnectionAttempts 3
	$result = $resultJson | ConvertFrom-Json
	if (-not $result.ok) {
		throw "Black Ledger MCP capture failed for $($spec.state)."
	}
	if (-not $result.stopped_after_capture) {
		throw "Black Ledger MCP capture did not stop the game after $($spec.state)."
	}
	$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
	$captures += @{
		path = "raw/$($spec.file)"
		label = $spec.label
		group = "ledger"
		role = "actual"
		state = $spec.state
		viewport = "desktop-1920x1080"
		camera = "player"
		layer = "final"
		event = $spec.event
		timestamp_ms = 0
		metadata = @{
			runtime = "Godot 4.5 editor game framebuffer"
			entrypoint = $spec.scene
			main_scene = "res://scenes/Main.tscn"
			branch = $branch
			commit = $commit
			worktree_dirty = $worktreeDirty
			sha256 = $hash
			actual_width = [int] $result.visual_metrics.width
			actual_height = [int] $result.visual_metrics.height
		}
	}
}

$payload = @{ captures = $captures } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh player-frame captures."
