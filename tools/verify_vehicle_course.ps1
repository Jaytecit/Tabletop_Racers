param(
    [Parameter(Mandatory=$true)][string]$Course,
    [Parameter(Mandatory=$true)][string]$Evidence,
    [string[]]$Vehicles=@('buggy','monster_truck','racing_car','drift_car','speedboat'),
    [ValidateRange(1,9)][int]$Laps=3,
    [int]$MaxSeconds=300,
    [string]$Probe='res://tests/probes/race_quality_ai_verification.gd'
)
# One course, sequential disposable rendered children. Stop on first failed case.
$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$savedEnvironment = @{}
$variables = @('TABLETOP_VERIFY_COURSE','TABLETOP_VERIFY_CLASS','TABLETOP_VERIFY_LAPS','TABLETOP_EXPECT_CAR_HASH','TABLETOP_EXPECT_TRACK_HASH')
foreach ($variable in $variables) { $savedEnvironment[$variable] = [Environment]::GetEnvironmentVariable($variable,'Process') }
try {
    $env:TABLETOP_VERIFY_COURSE = $Course
    $env:TABLETOP_VERIFY_LAPS = $Laps.ToString()
    foreach ($vehicleId in $Vehicles) {
        if ($vehicleId -notin @('buggy','monster_truck','racing_car','drift_car','speedboat')) { throw "Unknown vehicle $vehicleId" }
        $caseEvidence = Join-Path $Evidence $vehicleId
        $casePath = Join-Path $projectPath $caseEvidence
        if (Test-Path -LiteralPath $casePath) { throw "Evidence already exists: $casePath" }
        $env:TABLETOP_VERIFY_CLASS = $vehicleId
        $env:TABLETOP_EXPECT_CAR_HASH = (Get-FileHash -LiteralPath (Join-Path $projectPath 'scripts/vehicles/arcade_car.gd') -Algorithm SHA256).Hash.ToLower()
        $env:TABLETOP_EXPECT_TRACK_HASH = (Get-FileHash -LiteralPath (Join-Path $projectPath 'showcase_track.gd') -Algorithm SHA256).Hash.ToLower()
        $timer = [Diagnostics.Stopwatch]::StartNew()
        # The common runner owns the exact Process handle through exit and
        # checks post-shutdown stderr, which the in-game report cannot include.
        try {
            & (Join-Path $PSScriptRoot 'run_tabletop_verification.ps1') -Probe $Probe -Evidence $caseEvidence -MaxSeconds $MaxSeconds -WaitAndCheck | Out-Null
        } catch { throw "Verification child failed for $vehicleId : $_" }
        $resultFile = Join-Path $casePath 'results.json'
        if (-not (Test-Path -LiteralPath $resultFile)) { throw "No results for $vehicleId" }
        $result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
        $passed = $result.finished -and $result.reports.passed -and -not $result.reports._timeout -and $result.errors_seen.Count -eq 0 -and $result.frame_warnings.Count -eq 0
        Write-Output ([pscustomobject]@{course=$Course;vehicle=$vehicleId;passed=$passed;seconds=[math]::Round($timer.Elapsed.TotalSeconds,2);cars=$result.reports.cars} | ConvertTo-Json -Depth 4 -Compress)
        if (-not $passed) { throw "Verification failed: $casePath" }
    }
} finally {
    foreach ($variable in $variables) { [Environment]::SetEnvironmentVariable($variable,$savedEnvironment[$variable],'Process') }
}
