param(
    [string]$BuildId = 'G6-002',
    [ValidateSet('release','qa')]
    [string]$Mode = 'release'
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$EnginePath = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
$ProjectPath = Join-Path $ProjectRoot 'game'
$Preset = if ($Mode -eq 'release') { 'Windows Release' } else { 'Windows QA' }
$Suffix = if ($Mode -eq 'release') { '' } else { '-QA' }
$OutputDir = Join-Path $ProjectRoot "deliverables/$BuildId$Suffix"
$EvidenceStage = if ($BuildId -match '^(G[0-6])') { $Matches[1].ToUpper() } else { 'G6' }
$EvidenceDir = Join-Path $ProjectRoot "qa/evidence/$EvidenceStage"
New-Item -ItemType Directory -Force $OutputDir,$EvidenceDir | Out-Null

$projectText = Get-Content (Join-Path $ProjectPath 'project.godot') -Raw -Encoding UTF8
if ($projectText -match '(?m)^\[autoload\]' -or $projectText -match 'McpInteractionServer') {
    throw 'Preflight: project.godot contains an MCP/dev autoload. Remove it before export.'
}
if ($projectText -notmatch ('config/version="' + [regex]::Escape($BuildId) + '"')) {
    throw "Preflight: project.godot version does not match $BuildId"
}

$ImportOutput = & $EnginePath --headless --path $ProjectPath --editor --import --quit 2>&1
$ImportOutput | Set-Content (Join-Path $EvidenceDir "$BuildId$Suffix-import.log")
if ($LASTEXITCODE -ne 0 -or ($ImportOutput -match 'SCRIPT ERROR|Parse Error|ERROR:')) { throw 'Import failed; inspect log.' }

$ExportFlag = if ($Mode -eq 'release') { '--export-release' } else { '--export-debug' }
$ExportOutput = & $EnginePath --headless --path $ProjectPath $ExportFlag $Preset (Join-Path $OutputDir 'FungusLight.exe') 2>&1
$ExportOutput | Set-Content (Join-Path $EvidenceDir "$BuildId$Suffix-export.log")
if ($LASTEXITCODE -ne 0 -or ($ExportOutput -match 'SCRIPT ERROR|Parse Error|ERROR:')) { throw 'Export failed; inspect log.' }

Copy-Item -LiteralPath (Join-Path $ProjectPath 'assets/licenses') -Destination $OutputDir -Recurse -Force
if ($Mode -eq 'release') {
    '@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe"' |
        Set-Content -Encoding ascii (Join-Path $OutputDir 'Start-Game.cmd')
}
Get-FileHash (Join-Path $OutputDir 'FungusLight.exe'),(Join-Path $OutputDir 'FungusLight.pck') |
    Format-List | Out-File (Join-Path $EvidenceDir "$BuildId$Suffix-hashes.txt")
if ($Mode -eq 'release') {
    & python (Join-Path $ProjectRoot 'tools/check_release_package.py') $BuildId
    if ($LASTEXITCODE -ne 0) { throw 'Release PCK audit failed.' }
}
Write-Output "Built $OutputDir ($Mode)"
