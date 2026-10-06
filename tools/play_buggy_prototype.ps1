$projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$enginePath = 'C:/Users/jayte/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/SummerEngine/current/Summer.exe'
$logPath = Join-Path $projectPath ('tests/evidence/buggy-manual-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $logPath -Force | Out-Null
# The user explicitly requested this visible, interactive prototype window.
$game = Start-Process -FilePath $enginePath -ArgumentList @('--path',('"'+$projectPath+'"'),'--script','res://tools/play_buggy_prototype.gd','--','--skip-opening') -WindowStyle Normal -RedirectStandardOutput (Join-Path $logPath 'stdout.log') -RedirectStandardError (Join-Path $logPath 'stderr.log') -PassThru
$game.Id | Set-Content (Join-Path $logPath 'pid.txt')
[pscustomobject]@{Pid=$game.Id;Logs=$logPath}
