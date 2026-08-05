[CmdletBinding()]
param([switch]$KeepFixture)

$ErrorActionPreference = 'Stop'
$fixture = Join-Path $env:TEMP ('bwp-shared-refresh-' + [Guid]::NewGuid().ToString('N'))
$fixtureMarker = Join-Path $fixture '.fixture-marker'

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    [IO.File]::WriteAllText($fixtureMarker, 'blood-will-pay-refresh-fixture')
    $bare = Join-Path $fixture 'remote.git'
    $seed = Join-Path $fixture 'seed'
    $shared = Join-Path $fixture 'shared'
    & git init --bare $bare | Out-Null
    & git init -b main $seed | Out-Null
    & git -C $seed config user.name Test
    & git -C $seed config user.email test@example.invalid
    [IO.File]::WriteAllText((Join-Path $seed 'build.txt'), "v1`n")
    & git -C $seed add -- build.txt
    & git -C $seed commit -m baseline | Out-Null
    & git -C $seed remote add origin $bare
    & git -C $seed push -u origin main | Out-Null
    & git --git-dir=$bare symbolic-ref HEAD refs/heads/main

    $first = & (Join-Path $PSScriptRoot 'Refresh-SharedBuildCheckout.ps1') -SourceRepository $seed -Destination $shared -AsJson | ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $seed 'build.txt'), "v2`n")
    & git -C $seed add -- build.txt
    & git -C $seed commit -m update | Out-Null
    & git -C $seed push origin main | Out-Null
    $second = & (Join-Path $PSScriptRoot 'Refresh-SharedBuildCheckout.ps1') -SourceRepository $seed -Destination $shared -AsJson | ConvertFrom-Json

    [IO.File]::WriteAllText((Join-Path $shared 'dirty.txt'), 'dirty')
    $dirtyRefused = $false
    try {
        & (Join-Path $PSScriptRoot 'Refresh-SharedBuildCheckout.ps1') -SourceRepository $seed -Destination $shared -AsJson | Out-Null
    }
    catch {
        $dirtyRefused = $_.Exception.Message -like '*local changes*'
    }
    if (-not ($first.created -and -not $second.created -and $second.commit -eq $second.remoteCommit -and $dirtyRefused)) {
        throw 'Shared checkout refresh fixture failed.'
    }
    Write-Output ("SHARED_BUILD_REFRESH_PASS first={0} second={1} dirty-refused=true" -f $first.commit, $second.commit)
}
finally {
    if (-not $KeepFixture -and (Test-Path -LiteralPath $fixture)) {
        $fixtureFull = [IO.Path]::GetFullPath($fixture)
        $tempFull = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        if (-not $fixtureFull.StartsWith($tempFull, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $fixtureMarker -PathType Leaf)) {
            throw "Unsafe refresh fixture cleanup target: $fixtureFull"
        }
        Remove-Item -LiteralPath $fixtureFull -Recurse -Force
    }
}
