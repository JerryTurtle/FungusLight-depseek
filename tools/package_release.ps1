param([string]$BuildId = "G6-008", [string]$ReleaseName = "Release")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "deliverables/$BuildId"
$release = Join-Path $root "deliverables/$ReleaseName"
$game = Join-Path $release "Game"
$src = Join-Path $release "Source"
$docs = Join-Path $release "Docs"
$qa = Join-Path $release "QA"
$licenses = Join-Path $release "Licenses"

if (-not (Test-Path (Join-Path $source "FungusLight.exe"))) { throw "Missing release build $BuildId" }
if (-not (Test-Path (Join-Path $source "FungusLight.pck"))) { throw "Missing release PCK $BuildId" }
$project = Get-Content (Join-Path $root "game/project.godot") -Raw -Encoding UTF8
if ($project -match '(?m)^\[autoload\]' -or $project -match 'McpInteractionServer') { throw "Refusing to package an MCP autoload project" }
if ($project -notmatch ('config/version="' + [regex]::Escape($BuildId) + '"')) { throw "project.godot version does not match $BuildId" }
& python (Join-Path $root "tools/check_release_package.py") $BuildId
if ($LASTEXITCODE -ne 0) { throw "PCK audit failed" }

if (Test-Path $release) {
  # Keep the Release directory itself (host ACL may deny deleting it) and
  # replace its contents for this build.
  Get-ChildItem -LiteralPath $release -Force | Remove-Item -Recurse -Force
} else {
  New-Item -ItemType Directory -Force $release | Out-Null
}
New-Item -ItemType Directory -Force $game,$src,$docs,$qa,$licenses | Out-Null
Copy-Item (Join-Path $source "FungusLight.exe") $game
Copy-Item (Join-Path $source "FungusLight.pck") $game
Copy-Item (Join-Path $root "docs/g6/release/*.md") $docs
Copy-Item (Join-Path $root "docs/g6/release/Godot-MIT.txt") $licenses
Copy-Item (Join-Path $root "docs/g6/release/ASSET-RIGHTS.md") $licenses
Copy-Item (Join-Path $root "LICENSE") $licenses
Copy-Item (Join-Path $root "game/assets/licenses/*") $licenses -Recurse

# Source project without the editor cache, MCP dev autoload or personal files.
$sourceGame = Join-Path $src "game"
$null = New-Item -ItemType Directory -Force $sourceGame
$excludeDirs = @(".godot", "autoload", "qa")
$excludeFiles = @("*.tmp", "*.log")
& robocopy (Join-Path $root "game") $sourceGame /E /XD @excludeDirs /XF @excludeFiles /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy source failed: $LASTEXITCODE" }
Copy-Item (Join-Path $root "tools/gen_props.py") (Join-Path $src "gen_props.py")
Copy-Item (Join-Path $root "tools/generate_sfx.py") (Join-Path $src "generate_sfx.py")
Copy-Item (Join-Path $root "tools/gen_hud_assets.py") (Join-Path $src "gen_hud_assets.py")
@(
  "# 《菌灯之下》$BuildId 源工程",
  "",
  "打开方式：用 Godot 4.3 stable 导入本目录的 game/project.godot。",
  "发布运行文件在 ../Game/；本目录不含 .godot 缓存、MCP 开发 autoload 或个人存档。",
  "像素字体：assets/fonts/FusionPixel12px-zh_hans.ttf（OFL，见 ../Licenses）。"
) | Set-Content -Encoding utf8 (Join-Path $src "README.md")

$evidence = Join-Path $qa "evidence"
New-Item -ItemType Directory -Force $evidence | Out-Null
Get-ChildItem (Join-Path $root "qa/evidence/G6") -File | Copy-Item -Destination $evidence
foreach ($name in @("G4-009-title.png","G4-009-flame.png","G4-009-light.png","G4-009-light-linger.png","G4-009-lightroom.png","G4-009-room-n1-07.png","G4-009-room-n2-08.png","G4-009-route-matrix.json")) {
  $path = Join-Path $root "qa/evidence/G4/$name"
  if (Test-Path $path) { Copy-Item $path $evidence }
}
Copy-Item (Join-Path $root "docs/g6/release/验收说明.md") (Join-Path $qa "验收说明.md")
Copy-Item (Join-Path $root "qa/G6-approval.md") (Join-Path $qa "G6-approval.md")
Copy-Item (Join-Path $root "qa/G4-approval.md") (Join-Path $qa "G4-approval.md")

@'
@echo off
cd /d "%~dp0"
start "" "%~dp0FungusLight.exe"
'@ | Set-Content -Encoding ascii (Join-Path $game "开始游戏.cmd")
@(
  "《菌灯之下》$BuildId",
  "",
  "双击 FungusLight.exe 或 开始游戏.cmd。",
  "FungusLight.exe 与 FungusLight.pck 必须保持同目录。",
  "操作与存档说明见 ../Docs/操作说明.md。",
  "构建哈希见 ../QA/SHA256SUMS.txt。"
) | Set-Content -Encoding utf8 (Join-Path $game "README.txt")

$hashLines = Get-FileHash (Join-Path $game "FungusLight.exe"),(Join-Path $game "FungusLight.pck") -Algorithm SHA256 |
  ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" }
$hashLines | Set-Content -Encoding ascii (Join-Path $qa "SHA256SUMS.txt")
@(
  "# 菌灯之下 $BuildId 发布包",
  "",
  "- Game/：可直接运行的 Windows 构建",
  "- Source/：Godot 4.3 工程（无缓存/无 MCP autoload）",
  "- Docs/：操作、验收、已知问题、素材边界",
  "- QA/：AI 验证证据与哈希",
  "- Licenses/：项目、引擎、字体与素材来源",
  "",
  "首次运行请看 Docs/操作说明.md；最终人工验收看 QA/验收说明.md。"
) | Set-Content -Encoding utf8 (Join-Path $release "README.md")

$zip = Join-Path $root "deliverables/FungusLight-$BuildId-Release.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $release "*") -DestinationPath $zip -CompressionLevel Optimal
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash
Write-Output "Release: $release"
Write-Output "Zip: $zip"
Write-Output "ZipSHA256: $zipHash"
