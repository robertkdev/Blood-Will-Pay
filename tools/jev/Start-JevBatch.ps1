[CmdletBinding()]
param(
    [ValidateSet("campaign", "deep")]
    [string] $Lane = "deep",

    [ValidateSet("jev", "heuristic")]
    [string] $Mode = "jev",

    # Seeds are declared so two arms can be compared on the same encounters.
    [int[]] $Seeds = @(4401, 7717, 90210, 11111, 22222, 33333, 55555, 66666, 88888, 99999),

    [string] $Starter = "bonko",

    [ValidateRange(0.25, 16.0)]
    [double] $Speed = 8.0,

    [string] $ArtifactRoot = "E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260922",

    [ValidateRange(1, 240)]
    [int] $TimeoutMinutes = 45,

    # Ledger depth for this arm. -1 leaves the live account alone; 0 is a clean
    # profile and a positive value rebuilds the account at that many lifetime Omens.
    # Run the same seeds twice with different depths to measure campaign growth.
    [int] $LedgerOmens = -1,

    [string] $Rules = ""
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot "..\.."))
$python = Join-Path $env:USERPROFILE ".codex\playtest-judgment\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "The existing playtest-judgment Python environment is missing: $python"
}
$analyzer = Join-Path $scriptRoot "analyze_jev_run.py"
$single = Join-Path $scriptRoot "Start-JevRun.ps1"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ledgerLabel = if ($LedgerOmens -lt 0) { "live" } else { "ledger$LedgerOmens" }
$batchDirectory = Join-Path $ArtifactRoot ("batches\{0}-{1}-{2}-{3}" -f $Mode, $Lane, $stamp, $ledgerLabel)
New-Item -ItemType Directory -Force -Path $batchDirectory | Out-Null
$batchDirectory = (Resolve-Path -LiteralPath $batchDirectory).Path

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($seed in $Seeds) {
    Write-Host ("--- {0} {1} seed {2} ---" -f $Mode, $Lane, $seed)
    $arguments = @{
        Lane = $Lane
        Mode = $Mode
        Seed = $seed
        Starter = $Starter
        Speed = $Speed
        ArtifactRoot = $ArtifactRoot
        TimeoutMinutes = $TimeoutMinutes
    }
    if (-not [string]::IsNullOrWhiteSpace($Rules)) {
        $arguments["Rules"] = $Rules
    }
    if ($LedgerOmens -ge 0) {
        $arguments["LedgerOmens"] = $LedgerOmens
    }
    $payload = & $single @arguments | Out-String
    $result = $null
    # The single-run script streams the node runner's own summary too, so the run is
    # located by its directory name instead of by parsing stdout.
    $pattern = "{0}-{1}-seed{2}-*" -f $Mode, $Lane, $seed
    $runDirectory = Get-ChildItem -LiteralPath (Join-Path $ArtifactRoot "runs") -Directory -Filter $pattern |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if ($runDirectory) {
        $resultPath = Join-Path $runDirectory "run_result.json"
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
            $resultPath = Join-Path $runDirectory "run_summary.json"
        }
        if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
            try {
                $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
            } catch {
                Write-Warning ("seed {0}: could not parse {1}" -f $seed, $resultPath)
            }
        }
    }
    if ($null -eq $result) {
        Write-Warning ("seed {0}: no run summary was recorded" -f $seed)
        continue
    }
    # The analyzer is deterministic; run it so each seed also gets findings.json.
    & $python $analyzer --run-dir $runDirectory | Out-Null
    $findings = Join-Path $runDirectory "findings.json"
    $analysis = $null
    if (Test-Path -LiteralPath $findings -PathType Leaf) {
        $analysis = Get-Content -LiteralPath $findings -Raw | ConvertFrom-Json
    }
    $progression = if ($null -ne $analysis) { $analysis.progression } else { $null }
    $rows.Add([pscustomobject][ordered]@{
        seed = $seed
        mode = $result.mode
        lane = $Lane
        ledger_omens = $LedgerOmens
        terminal = $result.terminal
        chapter = $result.final_chapter
        round = $result.final_stage_in_chapter
        battles = $result.battles
        peak_bankroll = $result.peak_bankroll
        # run_result.json carries a count; run_summary.json carries the array.
        # run_result.json carries a count (a JSON number, which ConvertFrom-Json may
        # widen to [long]); run_summary.json carries the array of messages.
        failed = if ($result.technical_failures -is [ValueType]) { [int]$result.technical_failures } else { @($result.technical_failures).Count }
        three_star = if ($null -ne $progression) { @($progression.three_star_units).Count } else { 0 }
        max_unit_level = if ($null -ne $progression) { $progression.max_unit_level } else { $null }
        maxed_traits = if ($null -ne $progression) { @($progression.maxed_traits).Count } else { 0 }
        board = if ($null -ne $progression) { ("{0}/{1}" -f $progression.max_board_size, $progression.max_board_capacity) } else { "" }
        level_purchases = if ($null -ne $progression) { $progression.level_purchases } else { $null }
        run_directory = $runDirectory
    })
}

$table = $rows | Format-Table -AutoSize | Out-String -Width 220
$lines = @(
    ("# Jev batch: {0} / {1}" -f $Mode, $Lane),
    "",
    ("Seeds: {0}" -f ($Seeds -join ", ")),
    ("Ledger depth: {0} (-1 means the live account)" -f $LedgerOmens),
    "",
    ($rows | ConvertTo-Csv -NoTypeInformation | Out-String),
    $table
)
$lines -join "`n" | Set-Content -LiteralPath (Join-Path $batchDirectory "batch.md") -Encoding UTF8
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $batchDirectory "batch.json") -Encoding UTF8

Write-Output $table
Write-Output ("Batch directory: {0}" -f $batchDirectory)
