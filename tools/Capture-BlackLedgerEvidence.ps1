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

$sourceRoot = Join-Path $OutputRoot "source"
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
		file = "01_fresh_ledger_1920x1080.png"
		label = "Fresh Living Ledger"
		state = "fresh"
		viewport = "desktop-1920x1080"
		event = "fresh_open"
		scene = "res://tests/visual/BlackLedgerSmoke.tscn"
	},
	@{
		file = "03_veteran_ledger_1920x1080.png"
		label = "Veteran Living Ledger"
		state = "veteran"
		viewport = "desktop-1920x1080"
		event = "veteran_open"
		scene = "res://tests/visual/BlackLedgerSmoke.tscn"
	},
	@{
		file = "04_veteran_ledger_1280x720_compact.png"
		label = "Compact Living Ledger"
		state = "veteran"
		viewport = "compact-1280x720"
		event = "compact_living_open"
		scene = "res://tests/visual/BlackLedgerCompactSmoke.tscn"
	},
	@{
		file = "05_veteran_bounties_1280x720_compact.png"
		label = "Compact Bounties"
		state = "veteran"
		viewport = "compact-1280x720"
		event = "compact_bounties_open"
		scene = "res://tests/visual/BlackLedgerCompactSmoke.tscn"
	},
	@{
		file = "06_fresh_ledger_1280x720_compact.png"
		label = "Fresh Compact Living Ledger"
		state = "fresh"
		viewport = "compact-1280x720"
		event = "fresh_compact_open"
		scene = "res://tests/visual/BlackLedgerCompactSmoke.tscn"
	}
)

$captures = @()
foreach ($spec in $specs) {
	$sourcePath = Join-Path $sourceRoot $spec.file
	if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
		throw "Missing authoritative runtime capture: $sourcePath"
	}
	$sourceInfo = Get-Item -LiteralPath $sourcePath
	$ageSeconds = [Math]::Max(0.0, ((Get-Date).ToUniversalTime() - $sourceInfo.LastWriteTimeUtc).TotalSeconds)
	if ($ageSeconds -gt 600.0) {
		throw "Runtime capture is stale ($([Math]::Round($ageSeconds, 1))s): $sourcePath"
	}
	$targetPath = Join-Path $rawRoot $spec.file
	Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
	$targetInfo = Get-Item -LiteralPath $targetPath
	$targetInfo.LastWriteTimeUtc = (Get-Date).ToUniversalTime()
	$targetInfo = Get-Item -LiteralPath $targetPath
	$hash = (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash.ToLowerInvariant()
	$timestampMs = [DateTimeOffset]$targetInfo.LastWriteTimeUtc
	$captures += @{
		path = "raw/$($spec.file)"
		label = $spec.label
		group = "ledger"
		role = "actual"
		state = $spec.state
		viewport = $spec.viewport
		camera = "player"
		layer = "final"
		event = $spec.event
		timestamp_ms = $timestampMs.ToUnixTimeMilliseconds()
		metadata = @{
			runtime = "Godot 4.5 game framebuffer"
			entrypoint = $spec.scene
			scene = $spec.scene
			build = $branch
			branch = $branch
			commit = $commit
			worktree_dirty = $worktreeDirty
			sha256 = $hash
			capture_age_seconds = [Math]::Round([Math]::Max(0.0, ((Get-Date).ToUniversalTime() - $targetInfo.LastWriteTimeUtc).TotalSeconds), 3)
		}
	}
}

$payload = @{ captures = $captures } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh Godot framebuffer captures."
