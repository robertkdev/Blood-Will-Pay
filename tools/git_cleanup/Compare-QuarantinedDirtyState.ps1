param(
    [Parameter(Mandatory = $true)]
    [string]$PrimaryPath,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $true)]
    [string]$BaseCommit,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$pullRequests = [ordered]@{
    5  = 'bbc59d55f45fd3b139ea8c05c46280d2369bdf0d'
    6  = 'b08965bd87368f2744d05488d3f27959c2de291a'
    7  = '1debe922aa4482ebdc48bddf3cb6783cfa80da4b'
    8  = 'e7164d31da1261e0272c62b24bf0119bf84a6041'
    9  = 'c78b339a14155dc9a2288e4905055c4f7bdf8a84'
    10 = 'a5046255d8e3c869c5d5bc63875d47d1b7f5a983'
    11 = '538638683b704cd57d6a487cc05b7d011b198b80'
    12 = '4fdd49962e887efe255d7f99b1e21e88e81c5ea8'
    13 = 'e8382b8f0546c49d6ea97d656fdfdf6879f0f3ff'
    14 = '060ac67b1f4f18645df86345b7483f36ddc8fdcb'
    15 = '168037a0c6d53598d8f41b4d2d703c3e7c6b5413'
    16 = '9b2d17a8b5e2136997e5653cb16495eae541c91e'
    17 = 'e1ffe7cbab2d4cbf363bf48e00df9eae7437f560'
    18 = '8a46ae297da2b3b46ad6ac6be3138723387cb841'
    19 = '69680363f6f445a17eaf0468bf1787f50b121912'
    20 = '2b8dca0e15511a5a519dd8f128ea4a2c12bd52ec'
}

$supersededPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($path in @(
    'docs/endless_chapters_plan_2026-07-03.md',
    'docs/procedural_difficulty_balance_plan_2026-07-03.md',
    'docs/stage_progression.md',
    'scripts/game/progression/endless_chapter_generator.gd',
    'tests/rga_testing/validation/difficulty_rating_audit.gd',
    'tests/rga_testing/validation/endless_chapter_generation_probe.gd',
    'tests/rga_testing/validation/endless_runtime_integration_probe.gd',
    'tests/rga_testing/validation/DifficultyCoefficientGate.tscn',
    'tests/rga_testing/validation/GeneratedCampaignSpecProbe.tscn',
    'tests/rga_testing/validation/difficulty_coefficient_gate.gd',
    'tests/rga_testing/validation/difficulty_coefficient_gate.gd.uid',
    'tests/rga_testing/validation/generated_campaign_spec_probe.gd',
    'tests/rga_testing/validation/generated_campaign_spec_probe.gd.uid',
    'scripts/combat_view.gd',
    'scripts/main.gd',
    'scripts/ui/combat/gothic_ui_theme.gd',
    'scripts/ui/combat/unit_actor.gd',
    'scripts/ui/combat/unit_view.gd',
    'scripts/ui/shop/shop_card.gd',
    'tests/visual/actual_run_loop_smoke.gd',
    'tests/visual/all_starter_main_flow_smoke.gd',
    'tests/visual/endless_entry_main_flow_smoke.gd',
    'tests/visual/item_drag_safety_smoke.gd',
    'tests/visual/mid_run_progression_smoke.gd',
    'tests/visual/opening_fight_visual_smoke.gd'
)) {
    [void]$supersededPaths.Add($path)
}

function Invoke-GitText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$AllowFailure
    )

    [string[]]$output = @(& git -C $WorkingDirectory @Arguments 2>$null)
    [int]$exitCode = $LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "git failed ($exitCode): git -C $WorkingDirectory $($Arguments -join ' ')"
    }
    return $output
}

function Get-PorcelainEntries {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory)

    [string[]]$tokens = @(Invoke-GitText -WorkingDirectory $WorkingDirectory -Arguments @('-c', 'core.quotePath=false', 'status', '--porcelain=v1', '--untracked-files=all'))
    [System.Collections.Generic.List[object]]$entries = [System.Collections.Generic.List[object]]::new()
    foreach ($token in $tokens) {
        if ($token.Length -lt 4) {
            throw "Unexpected porcelain token: $token"
        }
        [string]$status = $token.Substring(0, 2)
        [string]$path = $token.Substring(3).Replace('\', '/')
        [string]$originalPath = ''
        if ($status.Contains('R') -or $status.Contains('C')) {
            [string[]]$renameParts = $path.Split(@(' -> '), 2, [System.StringSplitOptions]::None)
            if ($renameParts.Count -eq 2) {
                $originalPath = $renameParts[0]
                $path = $renameParts[1]
            }
        }
        $entries.Add([pscustomobject]@{
            status = $status
            path = $path
            original_path = $originalPath
        })
    }
    return $entries
}

function Get-TreeBlobMap {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Commit
    )

    $map = @{}
    [string[]]$result = @(Invoke-GitText -WorkingDirectory $WorkingDirectory -Arguments @('-c', 'core.quotePath=false', 'ls-tree', '-r', '--full-tree', $Commit))
    foreach ($line in $result) {
        if ($line -match '^[0-9]+\s+blob\s+([0-9a-f]{40})\t(.+)$') {
            $map[$Matches[2].Replace('\', '/')] = $Matches[1]
        }
    }
    return $map
}

function Get-WorkingBlob {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Canonical
    )

    [string]$fullPath = Join-Path $WorkingDirectory $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $null
    }
    [string[]]$arguments = if ($Canonical) {
        @('hash-object', "--path=$Path", '--', $Path)
    } else {
        @('hash-object', '--no-filters', '--', $Path)
    }
    [string[]]$result = @(Invoke-GitText -WorkingDirectory $WorkingDirectory -Arguments $arguments)
    return $result[0].Trim()
}

function Get-CoarseCategory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -like 'addons/godot_ai/*') {
        return 'generated_vendor_noise'
    }
    if ($Path -like 'hooks/*' -or $Path -like '*.import' -or
        $Path -match '(^|/)(\.godot|build|dist|tmp|temp|logs?|outputs?)(/|$)' -or
        $Path -match '\.(tmp|bak|log|pyc)$' -or
        $Path -match '(^|/)nul$') {
        return 'generated_vendor_noise'
    }
    if ($Path -like 'assets/units/*' -or $Path -like 'artifacts/*') {
        return 'generated_vendor_noise'
    }
    return 'unresolved_authored'
}

[string]$baseResolved = ([string](Invoke-GitText -WorkingDirectory $RepositoryPath -Arguments @('rev-parse', $BaseCommit))).Trim()
[string]$primaryHead = ([string](Invoke-GitText -WorkingDirectory $PrimaryPath -Arguments @('rev-parse', 'HEAD'))).Trim()
[object[]]$entries = @(Get-PorcelainEntries -WorkingDirectory $PrimaryPath)
[hashtable]$baseBlobMap = Get-TreeBlobMap -WorkingDirectory $RepositoryPath -Commit $baseResolved
[hashtable]$prBlobMaps = @{}
foreach ($item in $pullRequests.GetEnumerator()) {
    $prBlobMaps[$item.Key] = Get-TreeBlobMap -WorkingDirectory $RepositoryPath -Commit $item.Value
}

$prPathSets = @{}
foreach ($item in $pullRequests.GetEnumerator()) {
    [string[]]$paths = @(Invoke-GitText -WorkingDirectory $RepositoryPath -Arguments @('diff', '--name-only', "$baseResolved...$($item.Value)", '--'))
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($path in $paths) {
        [void]$set.Add($path.Replace('\', '/'))
    }
    $prPathSets[$item.Key] = $set
}

[System.Collections.Generic.List[object]]$records = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $entries) {
    [string]$path = $entry.path
    [string]$workingBlob = Get-WorkingBlob -WorkingDirectory $PrimaryPath -Path $path
    [string]$canonicalWorkingBlob = Get-WorkingBlob -WorkingDirectory $PrimaryPath -Path $path -Canonical
    [string]$baseBlob = $baseBlobMap[$path]
    [bool]$equalBase = $workingBlob -eq $baseBlob
    [System.Collections.Generic.List[int]]$overlapPrs = [System.Collections.Generic.List[int]]::new()
    [System.Collections.Generic.List[int]]$exactPrs = [System.Collections.Generic.List[int]]::new()
    [System.Collections.Generic.List[int]]$patchEquivalentPrs = [System.Collections.Generic.List[int]]::new()

    foreach ($item in $pullRequests.GetEnumerator()) {
        if (-not $prPathSets[$item.Key].Contains($path)) {
            continue
        }
        $overlapPrs.Add([int]$item.Key)
        [string]$prBlob = $prBlobMaps[$item.Key][$path]
        if ($workingBlob -eq $prBlob) {
            $exactPrs.Add([int]$item.Key)
        } elseif ($canonicalWorkingBlob -eq $prBlob) {
            $patchEquivalentPrs.Add([int]$item.Key)
        }
    }

    [string]$category = if ($equalBase) {
        'represented_main_exact'
    } elseif ($exactPrs.Count -gt 0) {
        'represented_pr_exact'
    } elseif ($patchEquivalentPrs.Count -gt 0) {
        'represented_pr_patch_equivalent'
    } elseif ((Get-CoarseCategory -Path $path) -eq 'generated_vendor_noise') {
        'generated_vendor_noise'
    } elseif ($supersededPaths.Contains($path)) {
        'superseded'
    } else {
        'current_direction_unique'
    }

    $records.Add([pscustomobject]@{
        status = $entry.status
        path = $path
        original_path = $entry.original_path
        working_blob = $workingBlob
        canonical_working_blob = $canonicalWorkingBlob
        base_blob = $baseBlob
        equal_base = $equalBase
        exact_prs = @($exactPrs)
        patch_equivalent_prs = @($patchEquivalentPrs)
        overlap_prs = @($overlapPrs)
        category = $category
    })
}

[object[]]$genuine = @($records | Where-Object { -not $_.equal_base })
[int]$classifiedGenuineCount = @($genuine | Where-Object {
    $_.category -in @(
        'represented_pr_exact',
        'represented_pr_patch_equivalent',
        'generated_vendor_noise',
        'superseded',
        'current_direction_unique'
    )
}).Count
if ($classifiedGenuineCount -ne $genuine.Count) {
    throw "Classification mismatch: classified=$classifiedGenuineCount genuine=$($genuine.Count)"
}
$summary = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    primary_path = $PrimaryPath
    primary_head = $primaryHead
    base_commit = $baseResolved
    pull_request_heads = @($pullRequests.GetEnumerator() | ForEach-Object {
        [pscustomobject]@{ number = [int]$_.Key; head = [string]$_.Value }
    })
    status_path_count = $records.Count
    represented_main_exact_count = @($records | Where-Object equal_base).Count
    genuine_difference_count = $genuine.Count
    represented_pr_exact_count = @($genuine | Where-Object { $_.category -eq 'represented_pr_exact' }).Count
    represented_pr_patch_equivalent_count = @($genuine | Where-Object { $_.category -eq 'represented_pr_patch_equivalent' }).Count
    generated_vendor_noise_count = @($genuine | Where-Object { $_.category -eq 'generated_vendor_noise' }).Count
    superseded_count = @($genuine | Where-Object { $_.category -eq 'superseded' }).Count
    current_direction_unique_count = @($genuine | Where-Object { $_.category -eq 'current_direction_unique' }).Count
    records = @($records)
}

[string]$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory)
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output ([pscustomobject]@{
    status_path_count = $summary.status_path_count
    represented_main_exact_count = $summary.represented_main_exact_count
    genuine_difference_count = $summary.genuine_difference_count
    represented_pr_exact_count = $summary.represented_pr_exact_count
    represented_pr_patch_equivalent_count = $summary.represented_pr_patch_equivalent_count
    generated_vendor_noise_count = $summary.generated_vendor_noise_count
    superseded_count = $summary.superseded_count
    current_direction_unique_count = $summary.current_direction_unique_count
} | ConvertTo-Json)
