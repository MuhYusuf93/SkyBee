# Isolate the omitted rendering with the final scroll helper. Restore only our
# C32 UI block in finally; no device calls and no other user source is replaced.
$ErrorActionPreference='Stop'
$taskSource=Join-Path (Resolve-Path '.').Path 'lib/features/backup/presentation/backup_settings_screen.dart'
$taskBytes=[IO.File]::ReadAllBytes($taskSource)
$taskText=[Text.Encoding]::UTF8.GetString($taskBytes)
$taskSha=(Get-FileHash -LiteralPath $taskSource).Hash
$taskStart=$taskText.IndexOf('                            if (s.automaticFailureMessage')
$taskEnd=$taskText.IndexOf('                            if (s.policy?.email != null)',$taskStart)
if($taskStart -lt 0 -or $taskEnd -le $taskStart){throw 'C32 block ambiguous; no source change.'}
try {
 [IO.File]::WriteAllText($taskSource,$taskText.Remove($taskStart,$taskEnd-$taskStart),[Text.UTF8Encoding]::new($false))
 & 'C:\Users\ACER\dev\flutter\bin\flutter.bat' test test/m5_settings_ui_test.dart --plain-name 'Drive persisted automatic failure' --reporter expanded *> docs/evidence/m5-20261018/c32-status-repro-final-helper.log
 $taskTestExit=$LASTEXITCODE
 if($taskTestExit -eq 0 -or -not (Select-String -LiteralPath docs/evidence/m5-20261018/c32-status-repro-final-helper.log -SimpleMatch 'Persisted worker failure must survive route load')){throw 'Expected omitted-rendering failure not proven.'}
} finally {
 [IO.File]::WriteAllBytes($taskSource,$taskBytes)
 if((Get-FileHash -LiteralPath $taskSource).Hash -ne $taskSha){throw 'Final C32 screen not restored byte-identically.'}
}
Get-Content docs/evidence/m5-20261018/c32-status-repro-final-helper.log -Tail 8
Write-Output 'Final-helper omitted-rendering repro preserved; final C32 source byte-identically restored.'
