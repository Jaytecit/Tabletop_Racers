param(
    [Parameter(Mandatory=$true)][string]$Evidence,
    [string]$Course='mount_rainier',
    [switch]$Release,
    [string]$Probe='res://tests/probes/loading_responsiveness_verification.gd'
)
$ErrorActionPreference = 'Stop'
# Owns only the disposable child it starts. Samples OS memory because release
# builds do not expose the engine's MEMORY_STATIC monitor.
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$evidencePath = [IO.Path]::GetFullPath((Join-Path $projectPath $Evidence))
if (Test-Path -LiteralPath (Join-Path $evidencePath 'stdout.log')) { throw "Evidence already exists: $evidencePath" }
New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
$enginePath = 'C:/Users/jayte/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/SummerEngine/current/Summer.exe'
$previousCourse = $env:TABLETOP_VERIFY_COURSE
$previousOutput = $env:TABLETOP_VERIFY_OUTPUT
$previousProbe = $env:TABLETOP_VERIFY_RESPONSIVENESS
try {
    $env:TABLETOP_VERIFY_COURSE = $Course
    $env:TABLETOP_VERIFY_OUTPUT = $evidencePath
    $env:TABLETOP_VERIFY_RESPONSIVENESS = '1'
    if ($Release) {
        if ($Probe -ne 'res://tests/probes/loading_responsiveness_verification.gd') { throw 'Custom probes require a development measurement' }
        $executable = Join-Path $projectPath 'builds/loading/tabletop-loading.exe'
        $arguments = @('--disable-crash-handler','--audio-driver','Dummy','--position','-32000,-32000','--resolution','1200x800')
    } else {
        $executable = $enginePath
        $arguments = @('--path', ('"'+$projectPath+'"'), '--disable-crash-handler', '--summer-verify', $Probe, '--summer-verify-out', ('"'+$evidencePath+'"'), '--summer-verify-max', '120')
    }
    $testProcess = Start-Process -FilePath $executable -ArgumentList $arguments -WorkingDirectory $projectPath -WindowStyle Hidden -RedirectStandardOutput (Join-Path $evidencePath 'stdout.log') -RedirectStandardError (Join-Path $evidencePath 'stderr.log') -PassThru
} finally {
    $env:TABLETOP_VERIFY_COURSE = $previousCourse
    $env:TABLETOP_VERIFY_OUTPUT = $previousOutput
    $env:TABLETOP_VERIFY_RESPONSIVENESS = $previousProbe
}
$testProcess.Id | Set-Content (Join-Path $evidencePath 'pid.txt')
$samples = [Collections.Generic.List[object]]::new()
$elapsed = [Diagnostics.Stopwatch]::StartNew()
$peakWorkingSet = 0L
while (-not $testProcess.WaitForExit(100)) {
    $testProcess.Refresh()
    if ($testProcess.HasExited) { break }
    $peakWorkingSet = [Math]::Max($peakWorkingSet, $testProcess.PeakWorkingSet64)
    $samples.Add(@{elapsed_ms=$elapsed.ElapsedMilliseconds; working_set_bytes=$testProcess.WorkingSet64; private_bytes=$testProcess.PrivateMemorySize64})
    if ($elapsed.Elapsed.TotalSeconds -gt 150) {
        # This Process object is the exact child created above, never an editor.
        $testProcess.Kill()
        $testProcess.WaitForExit()
        break
    }
}
@{pid=$testProcess.Id; peak_working_set_bytes=$peakWorkingSet; samples=$samples; exit_code=$testProcess.ExitCode} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidencePath 'process-memory.json')
"PID $($testProcess.Id) verified exited; code $($testProcess.ExitCode)." | Set-Content (Join-Path $evidencePath 'process-exit.txt')
$result = Get-Content -LiteralPath (Join-Path $evidencePath 'results.json') -Raw | ConvertFrom-Json
$shutdownErrors = @(Select-String -LiteralPath (Join-Path $evidencePath 'stderr.log') -Pattern '^(ERROR:|SCRIPT ERROR:|WARNING:.*(?:leak|resources? still))')
if ($testProcess.ExitCode -ne 0 -or -not $result.finished -or -not $result.reports.passed -or $result.reports._timeout -or $result.errors_seen.Count -gt 0 -or $result.frame_warnings.Count -gt 0 -or $shutdownErrors.Count -gt 0 -or $result.reports.samples.Count -ne 5) { throw 'Loading benchmark failed; preserve evidence.' }
$budget = @{first_selection_ms=6000; warm_selection_ms=2000; max_process_gap_ms=250; peak_working_set_mib=1024}
$violations = [Collections.Generic.List[string]]::new()
for ($index=0; $index -lt $result.reports.samples.Count; $index++) {
    $sample = $result.reports.samples[$index]
    $limit = if ($index -eq 0) { $budget.first_selection_ms } else { $budget.warm_selection_ms }
    if ($sample.visible_ms -gt $limit) { $violations.Add("Selection $index exceeded $limit ms") }
    if ($sample.max_process_gap_ms -gt $budget.max_process_gap_ms) { $violations.Add("Selection $index exceeded process-gap budget") }
}
if ($peakWorkingSet/1MB -gt $budget.peak_working_set_mib) { $violations.Add('Peak working set exceeded budget') }
@{budget=$budget; violations=$violations; passed=($violations.Count -eq 0)} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $evidencePath 'budget.json')
if ($violations.Count -gt 0) { throw ($violations -join '; ') }
Write-Output "PASS: $Evidence; peak working set $([Math]::Round($peakWorkingSet/1MB,1)) MiB"
