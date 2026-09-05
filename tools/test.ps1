param([string]$Godot = "")
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $godotCommand = Get-Command godot -ErrorAction Stop
    $godotLink = Get-Item -LiteralPath $godotCommand.Source
    $enginePath = if ($godotLink.Target) { [string]$godotLink.Target } else { $godotCommand.Source }
    $consolePath = $enginePath -replace '\.exe$', '_console.exe'
    $Godot = if (Test-Path -LiteralPath $consolePath) { $consolePath } else { $enginePath }
}
$resultsPath = Join-Path $projectRoot 'test-results'
New-Item -ItemType Directory -Force -Path $resultsPath | Out-Null
foreach ($check in @(
    @{ Name = 'import'; Arguments = @('--headless', '--path', $projectRoot, '--editor', '--import') },
    @{ Name = 'tests'; Arguments = @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_tests.gd') }
)) {
    $output = & $Godot @($check.Arguments) 2>&1
    $engineExitCode = $LASTEXITCODE
    $text = $output | Out-String
    Set-Content -LiteralPath (Join-Path $resultsPath ($check.Name + '.log')) -Value $text
    Write-Output $text
    if ($engineExitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:|FAIL:)' -or $text -match 'instances were leaked') {
        throw "Godot $($check.Name) failed. See test-results/$($check.Name).log."
    }
}
