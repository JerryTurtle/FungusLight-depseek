param([string]$BuildId = 'G0-001')
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$EnginePath = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
$ProjectPath = Join-Path $ProjectRoot 'game'
$EvidenceStage = if ($BuildId -match '^(G[0-6])') { $Matches[1].ToUpper() } else { 'G0' }
$EvidenceDir = Join-Path $ProjectRoot "qa/evidence/$EvidenceStage"
New-Item -ItemType Directory -Force $EvidenceDir | Out-Null
$OutputDir = Join-Path $ProjectRoot "deliverables/$BuildId"
New-Item -ItemType Directory -Force $OutputDir | Out-Null
$ImportOutput = & $EnginePath --headless --path $ProjectPath --editor --import --quit 2>&1
$ImportOutput | Set-Content (Join-Path $EvidenceDir "$BuildId-import.log")
if ($LASTEXITCODE -ne 0 -or ($ImportOutput -match 'SCRIPT ERROR|Parse Error|ERROR:')) { throw 'Import failed; inspect log.' }
$ExportOutput = & $EnginePath --headless --path $ProjectPath --export-release 'Windows Desktop' (Join-Path $OutputDir 'FungusLight.exe') 2>&1
$ExportOutput | Set-Content (Join-Path $EvidenceDir "$BuildId-export.log")
if ($LASTEXITCODE -ne 0 -or ($ExportOutput -match 'SCRIPT ERROR|Parse Error|ERROR:')) { throw 'Export failed; inspect log.' }
Copy-Item -LiteralPath (Join-Path $ProjectPath 'assets/licenses') -Destination $OutputDir -Recurse -Force
if ($BuildId -like 'G3-*') {
    '@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe" -- --campaign' | Set-Content -Encoding ascii (Join-Path $OutputDir 'Play-Prologue.cmd')
    '@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe" -- --enemy-arena' | Set-Content -Encoding ascii (Join-Path $OutputDir 'Enemy-Arena.cmd')
}
Get-FileHash (Join-Path $OutputDir 'FungusLight.exe'),(Join-Path $OutputDir 'FungusLight.pck') | Format-List | Out-File (Join-Path $EvidenceDir "$BuildId-hashes.txt")
Write-Output "Built $OutputDir"
