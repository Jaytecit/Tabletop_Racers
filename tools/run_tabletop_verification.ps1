param(
    [Parameter(Mandatory=$true)][string]$Probe,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [int]$MaxSeconds=210,
    [switch]$WaitAndCheck,
    [switch]$EngineVerbose,
    [string[]]$UserArguments=@(),
    [string[]]$LaunchArguments=@()
)
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = 'C:/Users/jayte/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/SummerEngine/current/Summer.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Summer executable unavailable' }
$evidencePath = Join-Path $projectPath $Evidence
if ($WaitAndCheck -and (Test-Path -LiteralPath (Join-Path $evidencePath 'stdout.log'))) { throw "Evidence already exists: $evidencePath" }
New-Item -ItemType Directory -Path $evidencePath -Force | Out-Null
$engineArguments = @(
    '--path', ('"'+$projectPath+'"'), '--disable-crash-handler',
    '--summer-verify', $Probe, '--summer-verify-out', ('"'+$evidencePath+'"'),
    '--summer-verify-max', $MaxSeconds.ToString()
)
if ($EngineVerbose) { $engineArguments += '--verbose' }
if ($LaunchArguments.Count -gt 0) { $engineArguments += $LaunchArguments }
if ($UserArguments.Count -gt 0) { $engineArguments += '--'; $engineArguments += $UserArguments }
$testProcess = Start-Process -FilePath $enginePath -ArgumentList $engineArguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $evidencePath 'stdout.log') -RedirectStandardError (Join-Path $evidencePath 'stderr.log') -PassThru
$testProcess.Id | Set-Content (Join-Path $evidencePath 'pid.txt')
Write-Output $testProcess.Id
# Caller must read raw results and confirm this exact PID exits after completion.
if ($WaitAndCheck) {
    $forced = -not $testProcess.WaitForExit(($MaxSeconds+45)*1000)
    if ($forced) {
        # This retained Process handle belongs only to the child started above.
        $testProcess.Kill()
        $testProcess.WaitForExit()
    }
    if (-not $testProcess.HasExited) { throw 'Owned verification child has not exited' }
    "PID $($testProcess.Id) exited. Exit code: $($testProcess.ExitCode). Forced watchdog stop: $forced. UTC: $([DateTime]::UtcNow.ToString('o'))" | Set-Content -LiteralPath (Join-Path $evidencePath 'process-exit.txt')
    $testResult = Get-Content -LiteralPath (Join-Path $evidencePath 'results.json') -Raw | ConvertFrom-Json
    $shutdownErrors = @(Select-String -LiteralPath (Join-Path $evidencePath 'stderr.log') -Pattern '^(ERROR:|SCRIPT ERROR:|WARNING:.*(?:leak|resources? still))')
    $passed = -not $forced -and $testProcess.ExitCode -eq 0 -and $testResult.finished -and $testResult.reports.passed -and -not $testResult.reports._timeout -and $testResult.errors_seen.Count -eq 0 -and $testResult.frame_warnings.Count -eq 0 -and $shutdownErrors.Count -eq 0
    [pscustomobject]@{ Evidence=$Evidence; Passed=$passed; Seconds=$testResult.duration_ms/1000; Failures=$testResult.reports.failures; Errors=$testResult.errors_seen; ShutdownErrors=@($shutdownErrors | ForEach-Object { $_.Line }) } | ConvertTo-Json -Depth 4 -Compress
    if (-not $passed) { throw "Verification failed: $evidencePath" }
}
