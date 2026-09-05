param([string]$Godot = "", [switch]$SkipTests, [ValidateSet('Windows', 'SteamDeck', 'Web')][string]$Target = 'Windows')
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
if ($Target -eq 'SteamDeck') { $outputDirectory = Join-Path $outputDirectory 'linux' }
if ($Target -eq 'Web') { $outputDirectory = Join-Path $outputDirectory 'web' }
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$outputPath = Join-Path $outputDirectory 'ElasticExplorer.exe'
$preset = 'Windows Desktop'
$sourceHash = python (Join-Path $PSScriptRoot 'source_identity.py')
if ($LASTEXITCODE -ne 0) { throw 'Source identity failed.' }
if ($Target -eq 'SteamDeck') { $preset = 'Steam Deck'; $outputPath = Join-Path $outputDirectory 'elastic_explorer.x86_64' }
if ($Target -eq 'Web') { $preset = 'Web'; $outputPath = Join-Path $outputDirectory 'index.html' }
$output = & $Godot --headless --path $projectRoot --export-release $preset $outputPath 2>&1
$engineExitCode = $LASTEXITCODE
$text = $output | Out-String
Write-Output $text
if ($engineExitCode -ne 0 -or $text -match '(?m)^(SCRIPT ERROR:|ERROR:)') { throw "$Target export failed." }
$artifact = Get-Item -LiteralPath $outputPath
$sourceAfter = python (Join-Path $PSScriptRoot 'source_identity.py')
if ($LASTEXITCODE -ne 0 -or $sourceHash -ne $sourceAfter) { throw 'Source changed during export. Rebuild before deploying.' }
$hash = Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
$revision = git -C $projectRoot rev-parse --short HEAD
$manifest = [ordered]@{
    file = $artifact.Name
    bytes = $artifact.Length
    sha256 = $hash.Hash
    source_sha256 = $sourceHash
    revision = $revision
    engine = (& $Godot --version | Out-String).Trim()
    builtUtc = [DateTime]::UtcNow.ToString('o')
    dirty = [bool](git -C $projectRoot status --porcelain)
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory 'build-info.json')
Write-Output "Built $outputPath"
