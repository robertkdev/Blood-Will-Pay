[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $OutputPath,

    [string] $ProjectPath = "",

    [string] $SessionHint = "",

    [ValidateSet("none", "main", "current", "custom")]
    [string] $Run = "none",

    [string] $Scene = "",

    [ValidateSet("game", "viewport", "viewport_2d", "cinematic")]
    [string] $Source = "game",

    [ValidateRange(0, 8192)]
    [int] $MaxResolution = 0,

    [ValidateRange(1, 120)]
    [int] $WaitSeconds = 20,

    [ValidateRange(1, 120)]
    [int] $VisualWaitSeconds = 15,

    [ValidateRange(1, 10)]
    [int] $ConnectionAttempts = 3,

    [ValidateRange(1, 65535)]
    [int] $Port = 8000
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
} else {
    $ProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$clientPath = Join-Path $PSScriptRoot "godot_mcp_capture.py"
if (-not (Test-Path -LiteralPath $clientPath -PathType Leaf)) {
    throw "Godot MCP capture client is missing: $clientPath"
}

$serverProcess = Get-Process -Name "godot-ai" -ErrorAction SilentlyContinue |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Path) } |
    Select-Object -First 1
if ($null -eq $serverProcess) {
    throw "No running godot-ai server was found. Launch the project editor through Godot MCP first."
}

$pythonPath = Join-Path (Split-Path -Parent $serverProcess.Path) "python.exe"
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
    throw "The running godot-ai environment does not contain python.exe beside the server: $pythonPath"
}

$clientArguments = @(
    $clientPath,
    "--url", "http://127.0.0.1:$Port/mcp",
    "--output", $resolvedOutputPath,
    "--project-path", $ProjectPath,
    "--run", $Run,
    "--source", $Source,
    "--max-resolution", $MaxResolution.ToString(),
    "--wait-seconds", $WaitSeconds.ToString(),
    "--visual-wait-seconds", $VisualWaitSeconds.ToString(),
    "--connection-attempts", $ConnectionAttempts.ToString()
)
if (-not [string]::IsNullOrWhiteSpace($SessionHint)) {
    $clientArguments += @("--session-hint", $SessionHint)
}
if (-not [string]::IsNullOrWhiteSpace($Scene)) {
    $clientArguments += @("--scene", $Scene)
}

& $pythonPath @clientArguments
if ($LASTEXITCODE -ne 0) {
    throw "Godot MCP capture failed with exit code $LASTEXITCODE."
}
