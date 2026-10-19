param(
    [string]$BuildId = 'G6-013',
    [ValidateSet('release','qa')]
    [string]$Mode = 'release'
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$EnginePath = 'C:/Software/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
$ProjectPath = Join-Path $ProjectRoot 'game'
$EvidenceStage = if ($BuildId -match '^(G[0-6])') { $Matches[1].ToUpper() } else { 'G6' }
$EvidenceDir = Join-Path $ProjectRoot "qa/evidence/$EvidenceStage"
$Template32 = Join-Path $env:APPDATA 'Godot/export_templates/4.3.stable/windows_release_x86_32.exe'

if (-not (Test-Path -LiteralPath $EnginePath)) { throw "Godot executable missing: $EnginePath" }
New-Item -ItemType Directory -Force $EvidenceDir | Out-Null

$projectText = Get-Content (Join-Path $ProjectPath 'project.godot') -Raw -Encoding UTF8
if ($projectText -match '(?m)^\[autoload\]' -or $projectText -match 'McpInteractionServer') {
    throw 'Preflight: project.godot contains an MCP/dev autoload. Remove it before export.'
}
if ($projectText -notmatch ('config/version="' + [regex]::Escape($BuildId) + '"')) {
    throw "Preflight: project.godot version does not match $BuildId"
}

$ImportOutput = & $EnginePath --headless --path $ProjectPath --editor --import --quit 2>&1
$ImportOutput | Set-Content (Join-Path $EvidenceDir "$BuildId-import.log") -Encoding UTF8
if ($LASTEXITCODE -ne 0 -or ($ImportOutput -match 'SCRIPT ERROR|Parse Error|ERROR:')) { throw 'Import failed; inspect log.' }

function Export-OnePreset([string]$Preset, [string]$OutDir, [switch]$DebugExport) {
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $outputExe = Join-Path $OutDir 'FungusLight.exe'
    $flag = if ($DebugExport) { '--export-debug' } else { '--export-release' }
    $safePreset = $Preset -replace '[^A-Za-z0-9]+','-'
    $log = Join-Path $EvidenceDir "$BuildId-$safePreset-export.log"
    $output = & $EnginePath --headless --path $ProjectPath $flag $Preset $outputExe 2>&1
    $output | Set-Content $log -Encoding UTF8
    if ($LASTEXITCODE -ne 0 -or ($output -match 'SCRIPT ERROR|Parse Error|ERROR:')) {
        throw "Export failed for preset '$Preset'; inspect $log"
    }
    if (-not (Test-Path -LiteralPath $outputExe)) { throw "Export did not create $outputExe" }
    $pck = [IO.Path]::ChangeExtension($outputExe, '.pck')
    if (-not (Test-Path -LiteralPath $pck)) { throw "Export did not create $pck" }
    return @{ exe = $outputExe; pck = $pck }
}

if ($Mode -eq 'release') {
    if (-not (Test-Path -LiteralPath $Template32)) {
        throw "Missing 32-bit export template: $Template32. Install the official Godot 4.3 export templates (windows_release_x86_32.exe) first."
    }
    $x64 = Export-OnePreset 'Windows Release' (Join-Path $ProjectRoot "deliverables/$BuildId")
    $x32 = Export-OnePreset 'Windows Release 32' (Join-Path $ProjectRoot "deliverables/$BuildId-32")
    @(
        "build=$BuildId",
        "x64_exe=$($x64.exe)",
        "x64_pck=$($x64.pck)",
        "x86_32_exe=$($x32.exe)",
        "x86_32_pck=$($x32.pck)"
    ) | Set-Content (Join-Path $EvidenceDir "$BuildId-release-builds.txt") -Encoding UTF8
    Get-FileHash $x64.exe, $x64.pck, $x32.exe, $x32.pck -Algorithm SHA256 |
        Format-List | Out-File (Join-Path $EvidenceDir "$BuildId-release-hashes.txt") -Encoding UTF8
    & python (Join-Path $ProjectRoot 'tools/check_release_package.py') $BuildId
    if ($LASTEXITCODE -ne 0) { throw 'Release PCK audit failed.' }
    Write-Output "Built x64:  $($x64.exe)"
    Write-Output "Built x86:  $($x32.exe)"
} else {
    $qa64 = Export-OnePreset 'Windows QA' (Join-Path $ProjectRoot "deliverables/$BuildId-QA") -DebugExport
    $qa32 = Export-OnePreset 'Windows QA 32' (Join-Path $ProjectRoot "deliverables/$BuildId-QA32") -DebugExport
    Write-Output "Built QA x64: $($qa64.exe)"
    Write-Output "Built QA x86: $($qa32.exe)"
}
