[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LiveRepository,

    [Parameter(Mandatory = $true)]
    [string]$RecoveryRoot,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryChecksumPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$WorkingDirectory = $script:LiveRoot,
        [switch]$AllowFailure
    )

    function ConvertTo-WindowsCommandLineArgument {
        param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
        if (($Value.Length -gt 0) -and ($Value -notmatch '[\s"]')) {
            return $Value
        }

        $builder = [System.Text.StringBuilder]::new()
        [void]$builder.Append('"')
        $backslashes = 0
        foreach ($character in $Value.ToCharArray()) {
            if ($character -eq '\') {
                $backslashes += 1
                continue
            }
            if ($character -eq '"') {
                [void]$builder.Append(('\' * (($backslashes * 2) + 1)))
                [void]$builder.Append('"')
                $backslashes = 0
                continue
            }
            if ($backslashes -gt 0) {
                [void]$builder.Append(('\' * $backslashes))
                $backslashes = 0
            }
            [void]$builder.Append($character)
        }
        if ($backslashes -gt 0) {
            [void]$builder.Append(('\' * ($backslashes * 2)))
        }
        [void]$builder.Append('"')
        return $builder.ToString()
    }

    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = 'git.exe'
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $true
    $processInfo.Arguments = (($Arguments | ForEach-Object {
        ConvertTo-WindowsCommandLineArgument -Value $_
    }) -join ' ')

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if (($process.ExitCode -ne 0) -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed with exit code $($process.ExitCode): $stderr"
    }

    [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Get-TextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $algorithm.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $algorithm.Dispose()
    }
}

function Get-NulTokens {
    param([Parameter(Mandatory = $true)][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) {
        return @()
    }
    return @($Text.Split(@([char]0), [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Get-Classification {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path.StartsWith('scripts/', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('data/', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('scenes/', [System.StringComparison]::Ordinal)) {
        return 'game-runtime-content'
    }
    if ($Path.StartsWith('tests/', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('tools/', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('docs/', [System.StringComparison]::Ordinal)) {
        return 'validation-docs-tools'
    }
    if ($Path.StartsWith('addons/godot_ai/', [System.StringComparison]::Ordinal)) {
        return 'vendor-godot-ai'
    }
    if ($Path.StartsWith('assets/', [System.StringComparison]::Ordinal)) {
        return 'unit-art-binaries'
    }
    if ($Path.StartsWith('hooks/', [System.StringComparison]::Ordinal) -or
        $Path.StartsWith('.merge_file_', [System.StringComparison]::Ordinal)) {
        return 'provenance-noise-candidates'
    }
    return 'other'
}

function Get-GitDiffEntries {
    $tokens = Get-NulTokens -Text (Invoke-GitText -Arguments @(
        'diff', '--name-status', '-z', '--no-ext-diff', 'HEAD', '--'
    )).StdOut
    $entries = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $tokens.Count; $index += 2) {
        $statusToken = $tokens[$index]
        if ($statusToken.StartsWith('R') -or $statusToken.StartsWith('C')) {
            $oldPath = $tokens[$index + 1]
            $newPath = $tokens[$index + 2]
            $entries.Add([pscustomobject]@{
                Status = $statusToken
                Path = $newPath
                OldPath = $oldPath
                Source = 'tracked'
            })
            $index += 1
            continue
        }

        $entries.Add([pscustomobject]@{
            Status = $statusToken
            Path = $tokens[$index + 1]
            OldPath = $null
            Source = 'tracked'
        })
    }
    return @($entries)
}

function Get-TrackedStatusPaths {
    $tokens = Get-NulTokens -Text (Invoke-GitText -Arguments @(
        'status', '--porcelain=v1', '-z', '--untracked-files=all'
    )).StdOut
    $paths = [System.Collections.Generic.List[string]]::new()
    for ($index = 0; $index -lt $tokens.Count; $index++) {
        $record = $tokens[$index]
        if ($record.StartsWith('?? ')) {
            continue
        }
        if ($record.Length -lt 4) {
            continue
        }
        $paths.Add($record.Substring(3))
        if ($record[0] -in @('R', 'C') -or $record[1] -in @('R', 'C')) {
            $index += 1
        }
    }
    return @($paths)
}

function Get-FileEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Status
    )

    $classification = Get-Classification -Path $RelativePath
    $excluded = $classification -eq 'provenance-noise-candidates'
    $absolutePath = Join-Path $script:LiveRoot ($RelativePath.Replace('/', '\'))
    $exists = Test-Path -LiteralPath $absolutePath -PathType Leaf
    $size = $null
    $sha256 = $null
    $gitBlob = $null
    $lastWriteUtc = $null

    if ($exists) {
        $item = Get-Item -LiteralPath $absolutePath
        $size = $item.Length
        $lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
        $sha256 = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $gitBlob = (Invoke-GitText -Arguments @('hash-object', '--no-filters', '--', $RelativePath)).StdOut.Trim()
    }

    [pscustomobject]@{
        path = $RelativePath
        status = $Status
        source = if ($Status -eq '??') { 'untracked' } else { 'tracked' }
        classification = $classification
        includedInPayload = (-not $excluded) -and $exists
        exclusionReason = if ($excluded) { 'Proven duplicate hook or historical merge temporary; retained in live checkout but excluded from authored payload.' } else { $null }
        exists = $exists
        sizeBytes = $size
        sha256 = $sha256
        gitBlob = $gitBlob
        lastWriteUtc = $lastWriteUtc
    }
}

$script:LiveRoot = (Resolve-Path -LiteralPath $LiveRepository).Path.TrimEnd('\')
$recoveryParent = [System.IO.Path]::GetFullPath($RecoveryRoot).TrimEnd('\')
$repositoryManifestFullPath = [System.IO.Path]::GetFullPath($RepositoryManifestPath)
$repositoryChecksumFullPath = [System.IO.Path]::GetFullPath($RepositoryChecksumPath)

if (-not (Test-Path -LiteralPath (Join-Path $script:LiveRoot '.git'))) {
    throw "Not a Git worktree: $script:LiveRoot"
}
if ($recoveryParent.StartsWith($script:LiveRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'RecoveryRoot must be outside the live repository.'
}

$head = (Invoke-GitText -Arguments @('rev-parse', 'HEAD')).StdOut.Trim()
$branch = (Invoke-GitText -Arguments @('branch', '--show-current')).StdOut.Trim()
$upstreamResult = Invoke-GitText -Arguments @('rev-parse', '--abbrev-ref', '@{upstream}') -AllowFailure
$upstream = if ($upstreamResult.ExitCode -eq 0) { $upstreamResult.StdOut.Trim() } else { $null }
$remoteUrl = (Invoke-GitText -Arguments @('remote', 'get-url', 'origin')).StdOut.Trim()
$statusBefore = (Invoke-GitText -Arguments @('status', '--porcelain=v1', '-z', '--untracked-files=all')).StdOut
$statusBeforeSha256 = Get-TextSha256 -Text $statusBefore
$stagedResult = Invoke-GitText -Arguments @('diff', '--cached', '--quiet', '--') -AllowFailure
if ($stagedResult.ExitCode -notin @(0, 1)) {
    throw "Unable to inspect staged changes: $($stagedResult.StdErr)"
}

$trackedEntries = @(Get-GitDiffEntries)
$untrackedPaths = @(Get-NulTokens -Text (Invoke-GitText -Arguments @(
    'ls-files', '--others', '--exclude-standard', '-z'
)).StdOut)
$entries = [System.Collections.Generic.List[object]]::new()
foreach ($entry in $trackedEntries) {
    $entries.Add((Get-FileEvidence -RelativePath $entry.Path -Status $entry.Status))
}
foreach ($path in $untrackedPaths) {
    $entries.Add((Get-FileEvidence -RelativePath $path -Status '??'))
}
$orderedEntries = @($entries | Sort-Object path)

$trackedStatusPaths = @(Get-TrackedStatusPaths)
$trueTrackedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($entry in $trackedEntries) {
    [void]$trueTrackedSet.Add($entry.Path)
}
$statOnlyTracked = @(
    $trackedStatusPaths |
        Where-Object { -not $trueTrackedSet.Contains($_) } |
        Sort-Object -Unique
)

$groupRows = @(
    $orderedEntries |
        Group-Object classification |
        ForEach-Object {
            $groupEntries = @($_.Group)
            $classificationName = $_.Name
            [long]$payloadBytes = 0
            foreach ($groupEntry in $groupEntries) {
                if ($groupEntry.includedInPayload) {
                    $payloadBytes += [long]$groupEntry.sizeBytes
                }
            }
            [pscustomobject]@{
                classification = $classificationName
                total = $groupEntries.Count
                tracked = @($groupEntries | Where-Object source -eq 'tracked').Count
                untracked = @($groupEntries | Where-Object source -eq 'untracked').Count
                deleted = @($groupEntries | Where-Object { -not $_.exists }).Count
                payloadFiles = @($groupEntries | Where-Object includedInPayload).Count
                payloadBytes = $payloadBytes
            }
        } |
        Sort-Object classification
)

$unexpected = @($orderedEntries | Where-Object classification -eq 'other')
if ($unexpected.Count -ne 0) {
    throw "Unexpected true-change paths require manual classification: $($unexpected.path -join ', ')"
}

$hookEvidence = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($orderedEntries | Where-Object { $_.path.StartsWith('hooks/') })) {
    $hookName = Split-Path -Leaf $entry.path
    $installedHook = Join-Path (Join-Path $script:LiveRoot '.git\hooks') $hookName
    $installedSha = if (Test-Path -LiteralPath $installedHook -PathType Leaf) {
        (Get-FileHash -LiteralPath $installedHook -Algorithm SHA256).Hash.ToLowerInvariant()
    } else {
        $null
    }
    $hookEvidence.Add([pscustomobject]@{
        path = $entry.path
        sha256 = $entry.sha256
        installedHookPath = $installedHook
        installedHookSha256 = $installedSha
        exactDuplicate = ($null -ne $installedSha) -and ($installedSha -eq $entry.sha256)
    })
}
if (@($hookEvidence | Where-Object { -not $_.exactDuplicate }).Count -ne 0) {
    throw 'A hook noise candidate is not an exact duplicate of its installed Git hook.'
}

$mergeEvidence = [System.Collections.Generic.List[object]]::new()
$historicalObjects = (Invoke-GitText -Arguments @('rev-list', '--objects', '--all')).StdOut
foreach ($entry in @($orderedEntries | Where-Object { $_.path.StartsWith('.merge_file_') })) {
    $normalizedBlob = (Invoke-GitText -Arguments @(
        'hash-object', '--path=scripts/ui/shop/shop_panel.gd', '--', $entry.path
    )).StdOut.Trim()
    $historyNeedle = "$normalizedBlob scripts/ui/shop/shop_panel.gd"
    $mergeEvidence.Add([pscustomobject]@{
        path = $entry.path
        rawGitBlob = $entry.gitBlob
        normalizedGitBlob = $normalizedBlob
        historicalObjectRecord = $historyNeedle
        provenHistoricalBlob = $historicalObjects.Contains($historyNeedle)
    })
}
if (@($mergeEvidence | Where-Object { -not $_.provenHistoricalBlob }).Count -ne 0) {
    throw 'A merge-file noise candidate could not be proven as a historical ShopPanel blob.'
}

$secretPatterns = @(
    '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]\s*["''][^"'']{12,}["'']',
    '(?i)gh[pousr]_[A-Za-z0-9]{20,}',
    '(?i)sk-[A-Za-z0-9]{20,}'
)
$secretHits = [System.Collections.Generic.List[object]]::new()
foreach ($entry in @($orderedEntries | Where-Object includedInPayload)) {
    $absolutePath = Join-Path $script:LiveRoot ($entry.path.Replace('/', '\'))
    if ($entry.sizeBytes -gt 2MB) {
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($absolutePath)
    if ($bytes -contains 0) {
        continue
    }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            $secretHits.Add([pscustomobject]@{ path = $entry.path; pattern = $pattern })
        }
    }
}
if ($secretHits.Count -ne 0) {
    throw "Potential secret material found; snapshot stopped: $($secretHits.path -join ', ')"
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$snapshotName = "gamble-battle-live-dirty-$timestamp"
$snapshotDirectory = Join-Path $recoveryParent $snapshotName
$stagingDirectory = Join-Path $snapshotDirectory 'staging'
$payloadDirectory = Join-Path $stagingDirectory 'payload'
$archivePath = Join-Path $snapshotDirectory "$snapshotName.zip"
$archiveChecksumPath = "$archivePath.sha256"

[void][System.IO.Directory]::CreateDirectory($payloadDirectory)
[void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $repositoryManifestFullPath))
[void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $repositoryChecksumFullPath))

foreach ($entry in @($orderedEntries | Where-Object includedInPayload)) {
    $sourcePath = Join-Path $script:LiveRoot ($entry.path.Replace('/', '\'))
    $destinationPath = Join-Path $payloadDirectory ($entry.path.Replace('/', '\'))
    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $destinationPath))
    [System.IO.File]::Copy($sourcePath, $destinationPath, $true)
    [System.IO.File]::SetLastWriteTimeUtc($destinationPath, [DateTime]::Parse($entry.lastWriteUtc).ToUniversalTime())
}

$patchResult = Invoke-GitText -Arguments @(
    'diff', '--binary', '--full-index', '--no-ext-diff', 'HEAD', '--'
)
$patchPath = Join-Path $stagingDirectory 'tracked-changes.patch'
[System.IO.File]::WriteAllText($patchPath, $patchResult.StdOut, [System.Text.UTF8Encoding]::new($false))

$statusTextPath = Join-Path $stagingDirectory 'status-porcelain.txt'
$statusLines = @(Get-NulTokens -Text $statusBefore)
[System.IO.File]::WriteAllLines($statusTextPath, $statusLines, [System.Text.UTF8Encoding]::new($false))

$patchCheck = Invoke-GitText -Arguments @(
    'apply', '--reverse', '--check', '--binary', '--', $patchPath
) -AllowFailure
if ($patchCheck.ExitCode -ne 0) {
    throw "Generated tracked patch did not reverse-apply to the captured live tree: $($patchCheck.StdErr)"
}

$payloadMismatches = [System.Collections.Generic.List[string]]::new()
foreach ($entry in @($orderedEntries | Where-Object includedInPayload)) {
    $copiedPath = Join-Path $payloadDirectory ($entry.path.Replace('/', '\'))
    $copiedSha = (Get-FileHash -LiteralPath $copiedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($copiedSha -ne $entry.sha256) {
        $payloadMismatches.Add($entry.path)
    }
}
if ($payloadMismatches.Count -ne 0) {
    throw "Copied payload failed hash verification: $($payloadMismatches -join ', ')"
}

$statusAfter = (Invoke-GitText -Arguments @('status', '--porcelain=v1', '-z', '--untracked-files=all')).StdOut
$statusAfterSha256 = Get-TextSha256 -Text $statusAfter
$headAfter = (Invoke-GitText -Arguments @('rev-parse', 'HEAD')).StdOut.Trim()
if (($headAfter -ne $head) -or ($statusAfterSha256 -ne $statusBeforeSha256)) {
    throw 'Live source changed during capture; snapshot is intentionally not finalized.'
}

$manifestCore = [ordered]@{
    schemaVersion = 1
    snapshotKind = 'preservation-only-live-working-tree'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    source = [ordered]@{
        repositoryRoot = $script:LiveRoot
        branch = $branch
        head = $head
        upstream = $upstream
        origin = $remoteUrl
        stagedChangesPresent = ($stagedResult.ExitCode -eq 1)
        statusFingerprintSha256 = $statusBeforeSha256
        statusEntryCount = $statusLines.Count
        trueTrackedChangeCount = $trackedEntries.Count
        untrackedCount = $untrackedPaths.Count
        statOnlyTrackedCount = $statOnlyTracked.Count
        sourceStableDuringCapture = $true
    }
    policy = [ordered]@{
        liveCheckoutMutated = $false
        payloadRule = 'All true tracked and untracked files except seven proven duplicate/temporary noise candidates; tracked patch records modifications and deletions.'
        publicationRule = 'Archive is local-only. Vendor and image assets were not pushed because provenance/license review is incomplete.'
        exclusions = @(
            'Four untracked hooks exactly duplicate installed Git LFS hooks.',
            'Three .merge_file_* files resolve to a historical scripts/ui/shop/shop_panel.gd blob.',
            '129 stat-only tracked entries are content-identical to HEAD and are inventoried but not copied.'
        )
    }
    validation = [ordered]@{
        potentialSecretHits = $secretHits.Count
        payloadHashMismatches = $payloadMismatches.Count
        trackedPatchApplyCheck = 'passed'
        liveHeadStable = ($headAfter -eq $head)
        liveStatusStable = ($statusAfterSha256 -eq $statusBeforeSha256)
        hookDuplicateEvidence = @($hookEvidence)
        mergeTemporaryEvidence = @($mergeEvidence)
    }
    groups = $groupRows
    entries = $orderedEntries
    statOnlyTrackedPaths = $statOnlyTracked
}

$internalManifestPath = Join-Path $stagingDirectory 'manifest.json'
$manifestCore | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $internalManifestPath -Encoding utf8

Compress-Archive -LiteralPath @(
    $payloadDirectory,
    $patchPath,
    $statusTextPath,
    $internalManifestPath
) -DestinationPath $archivePath -CompressionLevel Optimal

$archiveSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$patchSha256 = (Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash.ToLowerInvariant()
$archiveSize = (Get-Item -LiteralPath $archivePath).Length
[System.IO.File]::WriteAllText(
    $archiveChecksumPath,
    "$archiveSha256  $([System.IO.Path]::GetFileName($archivePath))`n",
    [System.Text.UTF8Encoding]::new($false)
)

$repositoryManifest = [ordered]@{
    schemaVersion = 1
    snapshotKind = $manifestCore.snapshotKind
    createdUtc = $manifestCore.createdUtc
    source = $manifestCore.source
    policy = $manifestCore.policy
    validation = $manifestCore.validation
    artifact = [ordered]@{
        archivePath = $archivePath
        archiveSizeBytes = $archiveSize
        archiveSha256 = $archiveSha256
        archiveChecksumPath = $archiveChecksumPath
        trackedPatchSha256 = $patchSha256
        payloadFileCount = @($orderedEntries | Where-Object includedInPayload).Count
    }
    groups = $manifestCore.groups
    entries = $manifestCore.entries
    statOnlyTrackedPaths = $manifestCore.statOnlyTrackedPaths
}
$repositoryManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $repositoryManifestFullPath -Encoding utf8
[System.IO.File]::WriteAllLines(
    $repositoryChecksumFullPath,
    @(
        "$archiveSha256  $archivePath",
        "$patchSha256  tracked-changes.patch"
    ),
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    archivePath = $archivePath
    archiveSha256 = $archiveSha256
    archiveSizeBytes = $archiveSize
    repositoryManifestPath = $repositoryManifestFullPath
    trueTrackedChanges = $trackedEntries.Count
    untracked = $untrackedPaths.Count
    statOnlyTracked = $statOnlyTracked.Count
    payloadFiles = @($orderedEntries | Where-Object includedInPayload).Count
    excludedNoise = @($orderedEntries | Where-Object { -not $_.includedInPayload -and $_.classification -eq 'provenance-noise-candidates' }).Count
    groups = $groupRows
} | ConvertTo-Json -Depth 8
