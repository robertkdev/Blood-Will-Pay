[CmdletBinding()]
param(
	[string] $OutputRoot = "",
	[string] $ProjectPath = "",
	[string] $SourceManifest = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
	$ProjectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
} else {
	$ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
	$OutputRoot = Join-Path $ProjectPath "outputs\visual_debug\non_unit_overhaul"
} else {
	$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
}
if ([string]::IsNullOrWhiteSpace($SourceManifest)) {
	$SourceManifest = Join-Path $ProjectPath "outputs\visual_iter\non_unit_current\capture_provenance.json"
} else {
	$SourceManifest = [System.IO.Path]::GetFullPath($SourceManifest)
}

function Assert-ChildPath {
	param(
		[string] $Parent,
		[string] $Child,
		[string] $Label
	)
	$parentPath = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
	$childPath = [System.IO.Path]::GetFullPath($Child)
	if (-not $childPath.StartsWith($parentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label escapes the allowed root: $childPath"
	}
}

function Get-TrackedWorkingTreeFingerprint {
	param([string] $RepositoryPath)
	$statusText = (& git -C $RepositoryPath status --porcelain=v1 --untracked-files=no | Out-String)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not read tracked working-tree status."
	}
	$diffText = (& git -C $RepositoryPath diff --binary HEAD -- . | Out-String)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not compute tracked working-tree diff."
	}
	$bytes = [System.Text.Encoding]::UTF8.GetBytes("git-tracked-diff-v1`n$statusText`n$diffText")
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
	} finally {
		$sha.Dispose()
	}
}

if (-not (Test-Path -LiteralPath $SourceManifest -PathType Leaf)) {
	throw "Fresh capture provenance is required. Missing: $SourceManifest"
}

$source = Get-Content -LiteralPath $SourceManifest -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($required in @("run_id", "session_id", "branch", "commit", "fingerprint_kind", "working_tree_sha256", "capture_started_utc", "captures")) {
	if ($null -eq $source.$required -or [string]::IsNullOrWhiteSpace([string] $source.$required)) {
		throw "Capture provenance is missing required field '$required'."
	}
}
if (@($source.captures).Count -eq 0) {
	throw "Capture provenance contains no captures."
}
if ([string] $source.fingerprint_kind -ne "git-tracked-diff-v1") {
	throw "Unsupported working-tree fingerprint kind: $($source.fingerprint_kind)"
}
$currentFingerprint = Get-TrackedWorkingTreeFingerprint -RepositoryPath $ProjectPath
if ($currentFingerprint -ne ([string] $source.working_tree_sha256).ToLowerInvariant()) {
	throw "The tracked working tree changed after capture. Refusing to relabel the images as current."
}

$captureStart = [System.DateTimeOffset]::Parse([string] $source.capture_started_utc)
$rawRoot = Join-Path $OutputRoot "raw"
$manifestPath = Join-Path $OutputRoot "captures.json"
New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null
Assert-ChildPath -Parent $ProjectPath -Child $rawRoot -Label "Output directory"

Add-Type -AssemblyName System.Drawing
$captures = @()
$timestamp = 0
foreach ($record in @($source.captures)) {
	foreach ($required in @("source_path", "label", "group", "state", "event", "viewport", "scene", "captured_utc", "source_last_write_utc", "sha256")) {
		if ($null -eq $record.$required -or [string]::IsNullOrWhiteSpace([string] $record.$required)) {
			throw "Capture record is missing required field '$required'."
		}
	}
	$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $ProjectPath ([string] $record.source_path)))
	Assert-ChildPath -Parent $ProjectPath -Child $sourcePath -Label "Capture source"
	if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
		throw "Capture source is missing: $sourcePath"
	}
	$sourceInfo = Get-Item -LiteralPath $sourcePath
	$capturedUtc = [System.DateTimeOffset]::Parse([string] $record.captured_utc)
	$recordedWriteUtc = [System.DateTimeOffset]::Parse([string] $record.source_last_write_utc)
	if ($capturedUtc -lt $captureStart) {
		throw "Capture predates its declared run start: $sourcePath"
	}
	if ([math]::Abs(($sourceInfo.LastWriteTimeUtc - $recordedWriteUtc.UtcDateTime).TotalSeconds) -gt 1.0) {
		throw "Capture timestamp changed after provenance was recorded: $sourcePath"
	}
	if ($sourceInfo.LastWriteTimeUtc -lt $captureStart.UtcDateTime) {
		throw "Capture file is older than the declared capture run: $sourcePath"
	}
	$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
	if ($sourceHash -ne ([string] $record.sha256).ToLowerInvariant()) {
		throw "Capture hash changed after provenance was recorded: $sourcePath"
	}
	$image = [System.Drawing.Image]::FromFile($sourcePath)
	try {
		$width = [int] $image.Width
		$height = [int] $image.Height
	} finally {
		$image.Dispose()
	}
	$destinationName = [System.IO.Path]::GetFileName($sourcePath)
	$destinationPath = Join-Path $rawRoot $destinationName
	Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
	$destinationInfo = Get-Item -LiteralPath $destinationPath
	if ([math]::Abs(($destinationInfo.LastWriteTimeUtc - $sourceInfo.LastWriteTimeUtc).TotalSeconds) -gt 1.0) {
		throw "Packaging did not preserve the immutable source timestamp: $destinationPath"
	}
	$destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
	if ($destinationHash -ne $sourceHash) {
		throw "Packaged image hash does not match source: $destinationPath"
	}
	$captures += @{
		path = "raw/$destinationName"
		label = [string] $record.label
		group = [string] $record.group
		role = "actual"
		state = [string] $record.state
		viewport = [string] $record.viewport
		camera = "player"
		layer = "final"
		event = [string] $record.event
		timestamp_ms = $timestamp
		metadata = @{
			runtime = "Godot 4.5 game framebuffer"
			capture_method = "Godot MCP"
			scene = [string] $record.scene
			session_id = [string] $source.session_id
			run_id = [string] $source.run_id
			branch = [string] $source.branch
			commit = [string] $source.commit
			working_tree_sha256 = [string] $source.working_tree_sha256
			captured_utc = $capturedUtc.ToString("o")
			source_last_write_utc = $sourceInfo.LastWriteTimeUtc.ToString("o")
			source_sha256 = $sourceHash
			packaged_sha256 = $destinationHash
			actual_width = $width
			actual_height = $height
			source_manifest = [System.IO.Path]::GetRelativePath($ProjectPath, $SourceManifest).Replace('\', '/')
		}
	}
	$timestamp += 1000
}

$payload = @{
	captures = $captures
} | ConvertTo-Json -Depth 10
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)

Write-Output "Packaged $($captures.Count) provenance-validated runtime captures from run $($source.run_id)."
