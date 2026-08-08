[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string]$ProjectPath,
	[ValidateRange(0, 60)][int]$TimeoutSeconds = 30,
	[ValidateRange(100, 2000)][int]$PollMilliseconds = 250,
	[switch]$AsJson
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Write-Result {
	param([Parameter(Mandatory = $true)]$Result)
	if ($AsJson) {
		$Result | ConvertTo-Json -Depth 6 -Compress
	} else {
		$Result
	}
}

function Get-HydrationState {
	param([Parameter(Mandatory = $true)][string]$Root)

	$cachePath = Join-Path $Root ".godot\global_script_class_cache.cfg"
	$requiredClasses = @("GoalCatalog", "PrimaryRole", "ShopOffer", "ShopState", "Unit", "UnitProfile")
	$missingClasses = [System.Collections.Generic.List[string]]::new()
	$missingImports = [System.Collections.Generic.List[string]]::new()
	$classCount = 0
	$checkedImportSidecars = 0

	$cacheText = ""
	if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
		try {
			$cacheText = Get-Content -LiteralPath $cachePath -Raw
			$classCount = [regex]::Matches($cacheText, '"class"\s*:').Count
		} catch [IO.IOException] {
			$cacheText = ""
		}
	}
	foreach ($className in $requiredClasses) {
		if ($cacheText -notmatch ('"class"\s*:\s*&"' + [regex]::Escape($className) + '"')) {
			$missingClasses.Add($className)
		}
	}

	$importRoots = @(
		(Join-Path $Root "assets\items"),
		(Join-Path $Root "assets\ui")
	)
	$sourceExtensions = @(".jpeg", ".jpg", ".mp3", ".ogg", ".png", ".svg", ".wav", ".webp")
	$sidecars = [System.Collections.Generic.List[object]]::new()
	foreach ($importRoot in $importRoots) {
		if (Test-Path -LiteralPath $importRoot -PathType Container) {
			foreach ($source in @(Get-ChildItem -LiteralPath $importRoot -Recurse -File | Where-Object { $sourceExtensions -contains $_.Extension.ToLowerInvariant() })) {
				$sidecarPath = $source.FullName + ".import"
				if (Test-Path -LiteralPath $sidecarPath -PathType Leaf) {
					$sidecars.Add((Get-Item -LiteralPath $sidecarPath))
				} else {
					$relativeSource = $source.FullName.Substring($Root.TrimEnd('\').Length + 1)
					$missingImports.Add($relativeSource + ".import")
				}
			}
		}
	}
	$iconSidecar = Join-Path $Root "icon.svg.import"
	if (Test-Path -LiteralPath $iconSidecar -PathType Leaf) {
		$sidecars.Add((Get-Item -LiteralPath $iconSidecar))
	} else {
		$missingImports.Add("icon.svg.import")
	}

	foreach ($sidecar in $sidecars) {
		$checkedImportSidecars++
		$sidecarPath = $sidecar.FullName
		$relativeSidecar = $sidecarPath.Substring($Root.TrimEnd('\').Length + 1)
		try {
			$sidecarText = Get-Content -LiteralPath $sidecarPath -Raw
		} catch [IO.IOException] {
			$missingImports.Add($relativeSidecar + ":import-in-progress")
			continue
		}
		$destinationMatches = [regex]::Matches($sidecarText, 'res://(\.godot/imported/[^"\r\n]+)')
		if ($destinationMatches.Count -eq 0) {
			$missingImports.Add($relativeSidecar + ":missing-remap")
			continue
		}
		foreach ($destinationMatch in $destinationMatches) {
			$destinationRelative = $destinationMatch.Groups[1].Value.Replace('/', '\')
			if (-not (Test-Path -LiteralPath (Join-Path $Root $destinationRelative) -PathType Leaf)) {
				$missingImports.Add($relativeSidecar + ":missing-imported-resource")
				break
			}
		}
	}

	return [pscustomobject][ordered]@{
		ready = $missingClasses.Count -eq 0 -and $missingImports.Count -eq 0
		projectPath = $Root
		classCachePath = $cachePath
		classCount = $classCount
		checkedImportSidecars = $checkedImportSidecars
		missingImportCount = $missingImports.Count
		missingClasses = @($missingClasses)
		missingImports = @($missingImports | Select-Object -First 25)
	}
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
	Write-Result ([pscustomobject][ordered]@{
		ready = $false
		reason = "project-path-missing"
		projectPath = $ProjectPath
	})
	exit 2
}

$root = [IO.Path]::GetFullPath($ProjectPath)
if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot") -PathType Leaf)) {
	Write-Result ([pscustomobject][ordered]@{
		ready = $false
		reason = "project-godot-missing"
		projectPath = $root
	})
	exit 2
}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
	$state = Get-HydrationState -Root $root
	if ($state.ready) {
		$state | Add-Member -NotePropertyName reason -NotePropertyValue "editor-hydration-ready"
		Write-Result $state
		exit 0
	}
	if ((Get-Date) -lt $deadline) {
		Start-Sleep -Milliseconds $PollMilliseconds
	}
} while ((Get-Date) -lt $deadline)

$state | Add-Member -NotePropertyName reason -NotePropertyValue "editor-hydration-incomplete"
Write-Result $state
exit 2
