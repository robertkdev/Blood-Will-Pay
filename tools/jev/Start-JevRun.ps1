[CmdletBinding()]
param(
    # campaign stops at the chapter-2 round-4 target; deep keeps playing so the
    # power curve (capacity, combines, trait ladders, bankroll) is observable.
    [ValidateSet("campaign", "deep")]
    [string] $Lane = "campaign",

    # -1 keeps the shipped random shop rolls; pass a seed only when a run must be
    # comparable with another run.
    [int] $Seed = -1,

    [string] $Starter = "bonko",

    [ValidateSet("jev", "heuristic")]
    [string] $Mode = "jev",

    # Rule set to play. Defaults to the shipped policy; pass a variant under
    # policy\variants\ to compare a different stance on identical seeds.
    [string] $Rules = "",

    [string] $Scene = "tests/agent/JevRunHarness.tscn",

    [string] $ProjectPath = "",

    [string] $ArtifactRoot = "E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260921",

    [string] $GodotPath = "",

    # Replay a recorded run's decisions instead of asking the model. The rig's choices
    # are held fixed so a game-side or rules-side change can be measured against the
    # same play; see jev_run_controller.py --replay-from.
    [string] $ReplayFrom = "",

    # 1.0 is the shipped game speed. Higher values are for fast sweeps only.
    [ValidateRange(0.25, 16.0)]
    [double] $Speed = 1.0,

    # Fast-sweep only: hold the planning beat open instead of the shipped countdown.
    [switch] $HoldPlanningTimer,

    # Ledger depth for this arm. -1 leaves the live account alone; 0 is a clean
    # profile and a positive value rebuilds the account at that many lifetime Omens
    # in its own profile file. Two arms on the same seeds are how campaign growth is
    # measured; see _seed_account_omens_if_requested in the harness.
    [int] $LedgerOmens = -1,

    [ValidateRange(1, 240)]
    [int] $TimeoutMinutes = 45,

    [switch] $NoController
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $ProjectPath "godot-bin\Godot_v4.5-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Pinned Godot console binary not found: $GodotPath"
}

$rulesPath = if ([string]::IsNullOrWhiteSpace($Rules)) {
    Join-Path $PSScriptRoot "policy\jev_run_rules.json"
} else {
    $candidate = Join-Path $PSScriptRoot "policy\$Rules"
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Policy variant not found: $candidate"
    }
    (Resolve-Path -LiteralPath $candidate).Path
}
$runnerPath = Join-Path $PSScriptRoot "run_jev_scene.mjs"
$controllerPath = Join-Path $PSScriptRoot "jev_run_controller.py"
$controllerPython = Join-Path $env:USERPROFILE ".codex\playtest-judgment\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $controllerPython -PathType Leaf)) {
    throw "The existing Jev lab Python environment is missing: $controllerPython"
}
$nodePath = "C:\Program Files\nodejs\node.exe"
if (-not (Test-Path -LiteralPath $nodePath -PathType Leaf)) {
    $nodePath = (Get-Command node -ErrorAction Stop).Source
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runDirectory = Join-Path $ArtifactRoot ("runs\{0}-{1}-seed{2}-{3}" -f $Mode, $Lane, $Seed, $stamp)
New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$runDirectory = (Resolve-Path -LiteralPath $runDirectory).Path

$env:JEV_RUN_DIR = $runDirectory
$env:JEV_MODE = $Mode
$env:JEV_RUN_SEED = [string]$Seed
$env:JEV_STARTER = $Starter
$env:JEV_SPEED = $Speed.ToString([System.Globalization.CultureInfo]::InvariantCulture)
$env:JEV_LANE = $Lane
$env:JEV_REAL_TIMER = if ($HoldPlanningTimer) { "0" } else { "1" }
if ($LedgerOmens -ge 0) {
    $env:JEV_LEDGER_OMENS = [string]$LedgerOmens
} else {
    Remove-Item Env:\JEV_LEDGER_OMENS -ErrorAction SilentlyContinue
}
$env:JEV_REVISION = (git -C $ProjectPath rev-parse HEAD 2>$null)
$env:JEV_RULES_SHA = if (Test-Path -LiteralPath $rulesPath) {
    (Get-FileHash -LiteralPath $rulesPath -Algorithm SHA256).Hash.ToLowerInvariant()
} else { "" }
$env:GODOT_PATH = $GodotPath

$controllerLog = Join-Path $runDirectory "controller.log"
$controllerErrorLog = Join-Path $runDirectory "controller.error.log"
$runLog = Join-Path $runDirectory "godot.log"
$controllerProcess = $null

Write-Host "Run directory: $runDirectory"
Write-Host ("Mode: {0}  Lane: {1}  Seed: {2}  Starter: {3}  Speed: {4}x  RealPlanningTimer: {5}" -f `
    $Mode, $Lane, ($(if ($Seed -lt 0) { "random" } else { [string]$Seed })), $Starter, $Speed, (-not $HoldPlanningTimer))

try {
    if ($Mode -eq "jev" -and -not $NoController) {
        $controllerArguments = @(
            "-u", $controllerPath,
            "--run-dir", $runDirectory,
            "--rules", $rulesPath
        )
        if (-not [string]::IsNullOrWhiteSpace($ReplayFrom)) {
            $controllerArguments += @("--replay-from", $ReplayFrom)
        }
        $controllerProcess = Start-Process -FilePath $controllerPython `
            -ArgumentList $controllerArguments `
            -RedirectStandardOutput $controllerLog `
            -RedirectStandardError $controllerErrorLog `
            -WindowStyle Hidden -PassThru
        Write-Host "Jev controller started (pid $($controllerProcess.Id)); waiting for it to attach."
        $attachDeadline = (Get-Date).AddSeconds(20)
        while ((Get-Date) -lt $attachDeadline) {
            if ($controllerProcess.HasExited) {
                throw "The Jev controller exited early; see $controllerErrorLog"
            }
            Start-Sleep -Milliseconds 250
        }
    }

    $runnerArguments = @(
        $runnerPath,
        "--project", $ProjectPath,
        "--scene", $Scene,
        "--log", $runLog,
        "--godot-path", $GodotPath,
        "--timeout-seconds", ([string]($TimeoutMinutes * 60))
    )
    & $nodePath @runnerArguments
    $runnerExit = $LASTEXITCODE
    Write-Host "Runner exit code: $runnerExit"
}
finally {
    if ($null -ne $controllerProcess) {
        New-Item -ItemType File -Force -Path (Join-Path $runDirectory "STOP") | Out-Null
        $shutdownDeadline = (Get-Date).AddSeconds(30)
        while (-not $controllerProcess.HasExited -and (Get-Date) -lt $shutdownDeadline) {
            Start-Sleep -Milliseconds 250
        }
        if (-not $controllerProcess.HasExited) {
            foreach ($childProcess in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($controllerProcess.Id)" -ErrorAction SilentlyContinue)) {
                Stop-Process -Id $childProcess.ProcessId -Force -ErrorAction SilentlyContinue
            }
            Stop-Process -Id $controllerProcess.Id -Force -ErrorAction SilentlyContinue
            Write-Host "Controller pid $($controllerProcess.Id) required a forced stop."
        }
    }
}

$summaryPath = Join-Path $runDirectory "run_summary.json"
$controllerSummaryPath = Join-Path $runDirectory "controller_summary.json"
$result = [ordered]@{
    run_directory = $runDirectory
    mode = $Mode
    seed = $Seed
    speed = $Speed
    real_planning_timer = (-not $HoldPlanningTimer)
    starter = $Starter
    scene = $Scene
    godot_log = $runLog
    run_summary = if (Test-Path -LiteralPath $summaryPath) { $summaryPath } else { $null }
    controller_summary = if (Test-Path -LiteralPath $controllerSummaryPath) { $controllerSummaryPath } else { $null }
}
if (Test-Path -LiteralPath $summaryPath) {
    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $result["terminal"] = $summary.terminal
    $result["final_chapter"] = $summary.final_chapter
    $result["final_stage_in_chapter"] = $summary.final_stage_in_chapter
    $result["battles"] = $summary.battles
    $result["peak_bankroll"] = $summary.peak_bankroll
    $result["technical_failures"] = @($summary.technical_failures).Count
}
if (Test-Path -LiteralPath $controllerSummaryPath) {
    $controllerSummary = Get-Content -LiteralPath $controllerSummaryPath -Raw | ConvertFrom-Json
    $result["decisions"] = $controllerSummary.decisions
    $result["controller_errors"] = $controllerSummary.errors
}
$result | ConvertTo-Json -Depth 5
# Also written to the run directory so a batch driver does not have to parse the
# combined stdout of the node runner and this script.
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory "run_result.json") -Encoding UTF8
