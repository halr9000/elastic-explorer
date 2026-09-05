$ErrorActionPreference = 'Stop'
$gamePath = Join-Path $PSScriptRoot 'builds/ElasticExplorer.exe'
if (Test-Path -LiteralPath $gamePath) {
    Start-Process -FilePath $gamePath -WorkingDirectory $PSScriptRoot
} else {
    $godotCommand = Get-Command godot -ErrorAction Stop
    Start-Process -FilePath $godotCommand.Source -ArgumentList @('--path', ('"' + $PSScriptRoot + '"')) -WorkingDirectory $PSScriptRoot
}
