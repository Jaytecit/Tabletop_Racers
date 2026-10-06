param(
    [Parameter(Mandatory=$true)][string]$Candidate,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [int]$MaxSeconds=90,
    [switch]$WaitAndCheck
)
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$candidateInput = if ([IO.Path]::IsPathRooted($Candidate)) { $Candidate } else { Join-Path $projectPath $Candidate }
$candidatePath = (Resolve-Path -LiteralPath $candidateInput).Path
$evidenceRoot = (Resolve-Path -LiteralPath (Join-Path $projectPath 'tests/baselines/content')).Path
if (-not $candidatePath.StartsWith($evidenceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Candidate must be inside tests/baselines/content'
}
$result = Get-Content -LiteralPath (Join-Path $candidatePath 'result.json') -Raw | ConvertFrom-Json
if (-not $result.passed) { throw 'Candidate source gates have not passed' }
$evidenceInput = if ([IO.Path]::IsPathRooted($Evidence)) { $Evidence } else { Join-Path $projectPath $Evidence }
$evidencePath = [IO.Path]::GetFullPath($evidenceInput)
if (-not $evidencePath.StartsWith($evidenceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Rendered evidence must be inside tests/baselines/content'
}
if (Test-Path -LiteralPath $evidencePath) { throw 'Use a new evidence folder to preserve prior results' }
New-Item -ItemType Directory -Path $evidencePath | Out-Null
$enginePath = 'C:/Users/jayte/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/SummerEngine/current/Summer.exe'
$testProcess = Start-Process -FilePath $enginePath -ArgumentList @(
    '--path', ('"'+$projectPath+'"'), '--disable-crash-handler',
    '--summer-verify', 'res://tests/probes/road_candidate_verification.gd',
    '--summer-verify-out', ('"'+$evidencePath+'"'), '--summer-verify-max', $MaxSeconds.ToString(),
    '--', '--road-candidate', ('"'+$candidatePath+'"')
) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $evidencePath 'stdout.log') -RedirectStandardError (Join-Path $evidencePath 'stderr.log') -PassThru
$testProcess.Id | Set-Content -LiteralPath (Join-Path $evidencePath 'pid.txt')
Write-Output $testProcess.Id
# Caller reads results.json and verifies this exact test PID has exited.
if ($WaitAndCheck) {
    $forced = -not $testProcess.WaitForExit(($MaxSeconds+45)*1000)
    if ($forced) { $testProcess.Kill(); $testProcess.WaitForExit() }
    if (-not $testProcess.HasExited) { throw 'Owned candidate test has not exited' }
    "PID $($testProcess.Id) exited. Exit code: $($testProcess.ExitCode). Forced watchdog stop: $forced. UTC: $([DateTime]::UtcNow.ToString('o'))" | Set-Content -LiteralPath (Join-Path $evidencePath 'process-exit.txt')
    $testResult = Get-Content -LiteralPath (Join-Path $evidencePath 'results.json') -Raw | ConvertFrom-Json
    $shutdownErrors = @(Select-String -LiteralPath (Join-Path $evidencePath 'stderr.log') -Pattern '^(ERROR:|SCRIPT ERROR:|WARNING:.*(?:leak|resources? still))')
    $passed = -not $forced -and $testProcess.ExitCode -eq 0 -and $testResult.finished -and $testResult.reports.passed -and -not $testResult.reports._timeout -and $testResult.errors_seen.Count -eq 0 -and $testResult.frame_warnings.Count -eq 0 -and $shutdownErrors.Count -eq 0
    [pscustomobject]@{Evidence=$Evidence; Passed=$passed; Seconds=$testResult.duration_ms/1000; Failures=$testResult.reports.failures; Errors=$testResult.errors_seen} | ConvertTo-Json -Depth 4 -Compress
    if (-not $passed) { throw "Candidate verification failed: $evidencePath" }
}
