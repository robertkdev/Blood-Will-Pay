[CmdletBinding()]
param(
    [ValidateSet("campaign")]
    [string] $Lane = "campaign",

    [int] $Seed = 4401,

    [string] $Starter = "bonko",

    [ValidateSet("jev", "heuristic")]
    [string] $Mode = "jev",

    [string] $Scene = "tests/agent/JevRunHarness.tscn",

    [string] $ProjectPath = "",

    [string] $ArtifactRoot = "E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260921",

    [string] $GodotPath = "",

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

$rulesPath = Join-Path $PSScriptRoot "policy\jev_run_rules.json"
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
$env:GODOT_PATH = $GodotPath

$controllerLog = Join-Path $runDirectory "controller.log"
$controllerErrorLog = Join-Path $runDirectory "controller.error.log"
$runLog = Join-Path $runDirectory "godot.log"
$controllerProcess = $null

Write-Host "Run directory: $runDirectory"
Write-Host "Mode: $Mode  Lane: $Lane  Seed: $Seed  Starter: $Starter"

try {
    if ($Mode -eq "jev" -and -not $NoController) {
        $controllerArguments = @(
            "-u", $controllerPath,
            "--run-dir", $runDirectory,
            "--rules", $rulesPath
        )
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
