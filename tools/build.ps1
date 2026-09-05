param([string]$Godot = "", [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $godotCommand = Get-Command godot -ErrorAction Stop
    $godotLink = Get-Item -LiteralPath $godotCommand.Source
    $enginePath = if ($godotLink.Target) { [string]$godotLink.Target } else { $godotCommand.Source }
    $consolePath = $enginePath -replace '\.exe$', '_console.exe'
    $Godot = if (Test-Path -LiteralPath $consolePath) { $consolePath } else { $enginePath }
}
if (-not $SkipTests) { & (Join-Path $PSScriptRoot 'test.ps1') -Godot $Godot }
$outputDirectory = Join-Path $projectRoot 'builds'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$outputPath = Join-Path $outputDirectory 'ElasticExplorer.exe'
$output = & $Godot --headless --path $projectRoot --export-release 'Windows Desktop' $outputPath 2>&1
$engineExitCode = $LASTEXITCODE
$text = $output | Out-String
Write-Output $text
if ($engineExitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:)') { throw 'Windows export failed.' }
$artifact = Get-Item -LiteralPath $outputPath
$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
$revision = git -C $projectRoot rev-parse --short HEAD
$manifest = [ordered]@{
    file = $artifact.Name
    bytes = $artifact.Length
    sha256 = $hash.Hash
    revision = $revision
    engine = (& $Godot --version | Out-String).Trim()
    builtUtc = [DateTime]::UtcNow.ToString('o')
    dirty = [bool](git -C $projectRoot status --porcelain)
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'build-info.json')
Write-Output "Built $outputPath"
