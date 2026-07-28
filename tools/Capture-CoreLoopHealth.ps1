[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [ValidateRange(1, 3600)]
    [int]$DurationSeconds = 240,

    [ValidateRange(100, 10000)]
    [int]$IntervalMilliseconds = 500,

    [string]$ProjectRoot = ''
)

$ErrorActionPreference = 'Stop'

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if (Test-Path -LiteralPath $resolvedOutputPath) {
    throw "Output path already exists: $resolvedOutputPath"
}

$normalizedProjectRoot = ''
if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $normalizedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
}

Add-Type -AssemblyName System.Net.Http
$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.Timeout = [TimeSpan]::FromMilliseconds(
    [Math]::Max(100, [Math]::Min(750, $IntervalMilliseconds))
)

$serverPidFile = Join-Path $env:APPDATA 'Godot\app_userdata\Gamble Battle\godot_ai_server.pid'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$sequence = 0

try {
    while ($stopwatch.Elapsed.TotalSeconds -lt $DurationSeconds) {
        $sampleStarted = [System.Diagnostics.Stopwatch]::StartNew()
        $processRows = [System.Collections.Generic.List[object]]::new()
        $godotProcesses = @(
            Get-CimInstance Win32_Process -Filter "Name='Godot_v4.5-stable_win64.exe'" -ErrorAction SilentlyContinue
        )
        $includedProcessIds = [System.Collections.Generic.HashSet[int]]::new()
        if ($normalizedProjectRoot -eq '') {
            foreach ($cimProcess in $godotProcesses) {
                [void]$includedProcessIds.Add([int]$cimProcess.ProcessId)
            }
        }
        else {
            foreach ($cimProcess in $godotProcesses) {
                if (
                    -not [string]::IsNullOrWhiteSpace($cimProcess.CommandLine) -and
                    $cimProcess.CommandLine -like "*$normalizedProjectRoot*"
                ) {
                    [void]$includedProcessIds.Add([int]$cimProcess.ProcessId)
                }
            }

            $foundDescendant = $true
            while ($foundDescendant) {
                $foundDescendant = $false
                foreach ($cimProcess in $godotProcesses) {
                    $processId = [int]$cimProcess.ProcessId
                    $parentProcessId = [int]$cimProcess.ParentProcessId
                    if (
                        -not $includedProcessIds.Contains($processId) -and
                        $includedProcessIds.Contains($parentProcessId)
                    ) {
                        [void]$includedProcessIds.Add($processId)
                        $foundDescendant = $true
                    }
                }
            }
        }

        foreach ($cimProcess in $godotProcesses) {
            if (-not $includedProcessIds.Contains([int]$cimProcess.ProcessId)) {
                continue
            }

            $process = Get-Process -Id $cimProcess.ProcessId -ErrorAction SilentlyContinue
            if ($null -eq $process) {
                continue
            }

            $processRows.Add([ordered]@{
                pid = [int]$cimProcess.ProcessId
                parent_pid = [int]$cimProcess.ParentProcessId
                name = [string]$cimProcess.Name
                responding = [bool]$process.Responding
                cpu_seconds = [double]$process.CPU
                working_set_bytes = [int64]$process.WorkingSet64
                thread_count = [int]$process.Threads.Count
                handle_count = [int]$process.HandleCount
                window_title = [string]$process.MainWindowTitle
                command_line = [string]$cimProcess.CommandLine
            })
        }

        $serverPid = 0
        if (Test-Path -LiteralPath $serverPidFile) {
            $parsedServerPid = 0
            if ([int]::TryParse((Get-Content -LiteralPath $serverPidFile -Raw).Trim(), [ref]$parsedServerPid)) {
                $serverPid = $parsedServerPid
            }
        }

        if ($serverPid -gt 0) {
            $serverProcess = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
            if ($null -ne $serverProcess) {
                $processRows.Add([ordered]@{
                    pid = [int]$serverProcess.Id
                    parent_pid = 0
                    name = [string]$serverProcess.ProcessName
                    responding = [bool]$serverProcess.Responding
                    cpu_seconds = [double]$serverProcess.CPU
                    working_set_bytes = [int64]$serverProcess.WorkingSet64
                    thread_count = [int]$serverProcess.Threads.Count
                    handle_count = [int]$serverProcess.HandleCount
                    window_title = [string]$serverProcess.MainWindowTitle
                    command_line = ''
                })
            }
        }

        $tcpRows = @(
            Get-NetTCPConnection -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LocalPort -in 6007, 8000, 9500 -or
                    $_.RemotePort -in 6007, 8000, 9500
                } |
                ForEach-Object {
                    [ordered]@{
                        local = '{0}:{1}' -f $_.LocalAddress, $_.LocalPort
                        remote = '{0}:{1}' -f $_.RemoteAddress, $_.RemotePort
                        state = [string]$_.State
                        owning_pid = [int]$_.OwningProcess
                    }
                }
        )

        $httpStatus = 0
        try {
            $response = $httpClient.GetAsync('http://127.0.0.1:8000/godot-ai/status').GetAwaiter().GetResult()
            $httpStatus = [int]$response.StatusCode
            $response.Dispose()
        }
        catch {
            $httpStatus = 0
        }

        $row = [ordered]@{
            schema_version = 1
            kind = 'sample'
            sequence = $sequence
            timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
            elapsed_milliseconds = [int64]$stopwatch.ElapsedMilliseconds
            http_8000_status = $httpStatus
            processes = $processRows
            tcp = $tcpRows
        }
        $json = $row | ConvertTo-Json -Compress -Depth 8
        [System.IO.File]::AppendAllText(
            $resolvedOutputPath,
            $json + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )

        $sequence += 1
        $remainingMilliseconds = $IntervalMilliseconds - [int]$sampleStarted.ElapsedMilliseconds
        if ($remainingMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $remainingMilliseconds
        }
    }
}
finally {
    $httpClient.Dispose()
}

[pscustomobject]@{
    OutputPath = $resolvedOutputPath
    Samples = $sequence
    DurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
}
