[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Destination,
    [string]$SourceRepository = (Split-Path -Parent $PSScriptRoot),
    [string]$Remote = 'origin',
    [string]$Branch = 'main',
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Invoke-CheckedGit {
    param([Parameter(Mandatory = $true)][string]$WorkingDirectory, [Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $WorkingDirectory @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousErrorAction }
    if ($exitCode -ne 0) { throw (($output | ForEach-Object { $_.ToString() }) -join "`n") }
    return (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}

function Get-StringHash {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$source = [IO.Path]::GetFullPath($SourceRepository).TrimEnd('\')
$destinationPath = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if ($destinationPath.Equals($source, [StringComparison]::OrdinalIgnoreCase) -or $destinationPath.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The shared checkout destination must be separate from the source repository.'
}
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Source repository is missing: $source" }
$sourceRoot = Invoke-CheckedGit -WorkingDirectory $source -Arguments @('rev-parse', '--show-toplevel')
if (-not ([IO.Path]::GetFullPath($sourceRoot).TrimEnd('\')).Equals($source, [StringComparison]::OrdinalIgnoreCase)) {
    throw "SourceRepository must be a Git worktree root: $source"
}
$remoteUrl = Invoke-CheckedGit -WorkingDirectory $source -Arguments @('remote', 'get-url', $Remote)
$remoteHash = Get-StringHash -Value $remoteUrl
$created = $false

if (-not (Test-Path -LiteralPath $destinationPath)) {
    $parent = Split-Path -Parent $destinationPath
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Invoke-CheckedGit -WorkingDirectory $parent -Arguments @('clone', '--no-tags', '--single-branch', '--branch', $Branch, '--', $remoteUrl, $destinationPath) | Out-Null
    $created = $true
}
elseif (-not (Test-Path -LiteralPath $destinationPath -PathType Container)) {
    throw "Destination exists but is not a directory: $destinationPath"
}

$destinationRoot = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('rev-parse', '--show-toplevel')
if (-not ([IO.Path]::GetFullPath($destinationRoot).TrimEnd('\')).Equals($destinationPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must be a standalone Git checkout root: $destinationPath"
}
$gitDirText = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('rev-parse', '--absolute-git-dir')
$gitDir = [IO.Path]::GetFullPath($gitDirText)
$markerPath = Join-Path $gitDir 'blood-will-pay-shared-checkout.json'
if ($created) {
    $marker = [pscustomobject][ordered]@{ schemaVersion = 1; remoteHash = $remoteHash; branch = $Branch; createdUtc = [DateTime]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText($markerPath, ($marker | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
}
elseif (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
    throw 'Refusing to refresh an existing checkout that was not created by this helper.'
}

$markerState = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($markerState.remoteHash -ne $remoteHash -or $markerState.branch -ne $Branch) {
    throw 'Shared checkout marker does not match the requested remote and branch.'
}
$status = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('status', '--porcelain=v1', '-uall')
if ($status) { throw 'Shared checkout has local changes; refresh refused without reset, clean, or stash.' }
$currentBranch = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('branch', '--show-current')
if ($currentBranch -ne $Branch) { throw "Shared checkout is on '$currentBranch', expected '$Branch'." }

Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('fetch', '--no-tags', $Remote, "refs/heads/${Branch}:refs/remotes/$Remote/$Branch") | Out-Null
Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('merge', '--ff-only', "$Remote/$Branch") | Out-Null
$localHead = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('rev-parse', 'HEAD')
$remoteLine = Invoke-CheckedGit -WorkingDirectory $destinationPath -Arguments @('ls-remote', $Remote, "refs/heads/$Branch")
$remoteHead = ($remoteLine -split '\s+')[0]
if (-not $remoteHead -or -not $remoteHead.Equals($localHead, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Shared checkout verification failed: local=$localHead remote=$remoteHead"
}

$result = [pscustomobject][ordered]@{
    status = 'remote-verified'
    created = $created
    destination = $destinationPath
    branch = $Branch
    commit = $localHead
    remoteCommit = $remoteHead
    marker = $markerPath
    contract = 'clean checkout only; fast-forward only; never reset, clean, stash, or modify another checkout'
}
if ($AsJson) { $result | ConvertTo-Json -Depth 8 -Compress }
else { $result }
