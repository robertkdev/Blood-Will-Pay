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
	$OutputRoot = Join-Path $ProjectPath "outputs\visual_debug\phase5_clarity"
} else {
	$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}

$rawRoot = Join-Path $OutputRoot "raw"
$selfRoot = Join-Path $OutputRoot "self_capture"
$bootstrapRoot = Join-Path $OutputRoot "bootstrap"
$manifestPath = Join-Path $OutputRoot "captures.json"
New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null
New-Item -ItemType Directory -Path $bootstrapRoot -Force | Out-Null

function Get-PngSize {
	param([Parameter(Mandatory = $true)][string] $Path)
	$bytes = [System.IO.File]::ReadAllBytes($Path)
	if ($bytes.Length -lt 24 -or $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or $bytes[2] -ne 78 -or $bytes[3] -ne 71) {
		throw "Not a supported PNG file: $Path"
	}
	return @{
		width = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($bytes, 16))
		height = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($bytes, 20))
	}
}

$commit = (& git -C $ProjectPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git revision for capture provenance."
}
$branch = (& git -C $ProjectPath branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the Git branch for capture provenance."
}
$dirty = -not [string]::IsNullOrWhiteSpace((& git -C $ProjectPath status --porcelain))
$captures = @()

$viewports = @(
	@{ key = "1920x1080"; viewport = "desktop-1920x1080"; width = 1920; height = 1080; scene = "res://tests/visual/Phase5ClarityCapture1920.tscn" },
	@{ key = "1280x720"; viewport = "compact-1280x720"; width = 1280; height = 720; scene = "res://tests/visual/Phase5ClarityCapture1280.tscn" }
)
$states = @(
	@{ source = "00_tutorial.png"; output = "tutorial"; group = "tutorial"; label = "How to Play" },
	@{ source = "00_settings_150_percent.png"; output = "settings"; group = "accessibility"; label = "Accessibility settings at 150 percent" },
	@{ source = "02_post_shop_max_bet_selected.png"; output = "wager"; group = "wager"; label = "Planning wager affordance" },
	@{ source = "03_combat_bet_locked.png"; output = "combat"; group = "combat"; label = "Combat safe bounds" }
)

foreach ($viewportSpec in $viewports) {
	$selfDirectory = Join-Path $selfRoot $viewportSpec.key
	if (Test-Path -LiteralPath $selfDirectory -PathType Container) {
		Get-ChildItem -LiteralPath $selfDirectory -Filter "*.png" |
			Remove-Item -Force
	}

	$captureStarted = [DateTime]::UtcNow
	$bootstrapPath = Join-Path $bootstrapRoot ("launch_{0}.png" -f $viewportSpec.key)
	$resultJson = & (Join-Path $ProjectPath "tools\Capture-GodotMcp.ps1") `
		-OutputPath $bootstrapPath `
		-ProjectPath $ProjectPath `
		-Run custom `
		-Scene $viewportSpec.scene `
		-Source game `
		-MaxResolution 0 `
		-ExpectedWidth $viewportSpec.width `
		-ExpectedHeight $viewportSpec.height `
		-ForceRelaunch `
		-WaitSeconds 45 `
		-VisualWaitSeconds 25 `
		-SettleSeconds 1 `
		-ConnectionAttempts 5
	$result = $resultJson | ConvertFrom-Json
	if (-not $result.ok) {
		throw "Godot MCP capture did not finish cleanly for $($viewportSpec.scene)."
	}
	if ([int] $result.visual_metrics.width -ne $viewportSpec.width -or [int] $result.visual_metrics.height -ne $viewportSpec.height) {
		throw "Unexpected framebuffer dimensions for $($viewportSpec.scene)."
	}

	$deadline = [DateTime]::UtcNow.AddSeconds(60)
	do {
		$allReady = $true
		foreach ($stateSpec in $states) {
			$expectedPath = Join-Path $selfDirectory $stateSpec.source
			$item = Get-Item -LiteralPath $expectedPath -ErrorAction SilentlyContinue
			if ($null -eq $item -or $item.Length -le 0 -or $item.LastWriteTimeUtc -lt $captureStarted) {
				$allReady = $false
				break
			}
		}
		if (-not $allReady) {
			Start-Sleep -Milliseconds 500
		}
	} while (-not $allReady -and [DateTime]::UtcNow -lt $deadline)
	if (-not $allReady) {
		throw "Combined runtime did not produce every Phase 5 capture for $($viewportSpec.key) within 60 seconds."
	}

	foreach ($stateSpec in $states) {
		$outputFile = "{0}_{1}.png" -f $stateSpec.output, $viewportSpec.key
		$outputPath = Join-Path $rawRoot $outputFile
		$sourcePath = Join-Path $selfDirectory $stateSpec.source
		Copy-Item -LiteralPath $sourcePath -Destination $outputPath -Force
		$pngSize = Get-PngSize -Path $outputPath
		if ([int] $pngSize.width -ne $viewportSpec.width -or [int] $pngSize.height -ne $viewportSpec.height) {
			throw "Self-captured $outputFile has unexpected dimensions $($pngSize.width)x$($pngSize.height)."
		}
		$hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
		$captures += @{
			path = "raw/$outputFile"
			label = "$($stateSpec.label) at $($viewportSpec.key)"
			group = $stateSpec.group
			role = "actual"
			state = $stateSpec.output
			viewport = $viewportSpec.viewport
			camera = "player"
			layer = "final"
			event = $stateSpec.output
			timestamp_ms = 0
			metadata = @{
				runtime = "Godot 4.5 editor game framebuffer"
				entrypoint = $viewportSpec.scene
				branch = $branch
				commit = $commit
				working_tree_dirty = $dirty
				sha256 = $hash
				actual_width = $viewportSpec.width
				actual_height = $viewportSpec.height
			}
		}
	}
	Start-Sleep -Seconds 3
}

$payload = @{ captures = $captures } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh Godot runtime captures from two runs."
