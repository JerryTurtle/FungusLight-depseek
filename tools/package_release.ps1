param(
    [string]$BuildId = "G6-013",
    [string]$ReleaseName = "Release"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source64 = Join-Path $root "deliverables/$BuildId"
$source32 = Join-Path $root "deliverables/$BuildId-32"
$release = Join-Path $root "deliverables/$BuildId-$ReleaseName"
$game = Join-Path $release "Game"
$src = Join-Path $release "Source"
$docs = Join-Path $release "Docs"
$qa = Join-Path $release "QA"
$licenses = Join-Path $release "Licenses"

foreach ($path in @(
    (Join-Path $source64 "FungusLight.exe"), (Join-Path $source64 "FungusLight.pck"),
    (Join-Path $source32 "FungusLight.exe"), (Join-Path $source32 "FungusLight.pck")
)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing release build file: $path" }
}
$project = Get-Content (Join-Path $root "game/project.godot") -Raw -Encoding UTF8
if ($project -match '(?m)^\[autoload\]' -or $project -match 'McpInteractionServer') { throw "Refusing to package an MCP autoload project" }
if ($project -notmatch ('config/version="' + [regex]::Escape($BuildId) + '"')) { throw "project.godot version does not match $BuildId" }
& python (Join-Path $root "tools/check_release_package.py") $BuildId
if ($LASTEXITCODE -ne 0) { throw "PCK audit failed" }

if (Test-Path $release) {
    Get-ChildItem -LiteralPath $release -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Force $release | Out-Null
}
New-Item -ItemType Directory -Force $game,(Join-Path $game "64"),$src,$docs,$qa,$licenses | Out-Null

# Default FungusLight.exe is the 32-bit build: it runs on both 32-bit and
# 64-bit Windows when double-clicked. The launcher prefers 64/ on 64-bit OS.
Copy-Item (Join-Path $source32 "FungusLight.exe") (Join-Path $game "FungusLight.exe")
Copy-Item (Join-Path $source32 "FungusLight.pck") (Join-Path $game "FungusLight.pck")
Copy-Item (Join-Path $source64 "FungusLight.exe") (Join-Path $game "64/FungusLight.exe")
Copy-Item (Join-Path $source64 "FungusLight.pck") (Join-Path $game "64/FungusLight.pck")

function Write-GbkLauncher([string]$sourcePath, [string]$destPath) {
    $text = [IO.File]::ReadAllText($sourcePath, [Text.Encoding]::UTF8)
    $text = $text -replace "`r?`n", "`r`n"
    [IO.File]::WriteAllText($destPath, $text, [Text.Encoding]::GetEncoding(936))
}
$launcherSource = Join-Path $root "docs/g6/release/launchers"
foreach ($name in @("开始游戏.cmd", "兼容模式启动.cmd", "系统检查.cmd")) {
    $sourceLauncher = Join-Path $launcherSource $name
    if (-not (Test-Path -LiteralPath $sourceLauncher)) { throw "Missing launcher template: $sourceLauncher" }
    Write-GbkLauncher $sourceLauncher (Join-Path $game $name)
}

@(
    "《菌灯之下》$BuildId",
    "",
    "本包同时包含 32 位与 64 位 Windows 构建：",
    "  FungusLight.exe        32 位构建（32/64 位 Windows 都可直接双击运行）",
    "  64\FungusLight.exe     64 位构建（仅 64 位 Windows）",
    "",
    "推荐启动方式：双击 开始游戏.cmd",
    "  64 位系统会自动选择 64 位版本；32 位系统会自动选择 32 位版本。",
    "  启动失败时它会自动再尝试一次 ANGLE/D3D11 兼容模式。",
    "",
    "老显卡 / 黑屏 / 闪退：双击 兼容模式启动.cmd（强制 ANGLE/D3D11 渲染）。",
    "仍然无法启动：双击 系统检查.cmd 生成 diagnostic.txt，",
    "并把 startup-log.txt、startup-info.txt 一起反馈。",
    "",
    "FungusLight.exe 与 FungusLight.pck 必须保持同目录；",
    "64\ 目录内的 exe 与 pck 也必须保持同目录。",
    "操作与存档说明见 ../Docs/操作说明.md。",
    "构建哈希见 ../QA/SHA256SUMS.txt。"
) -join "`r`n" | Set-Content -LiteralPath (Join-Path $game "README.txt") -Encoding UTF8

# Source project without the editor cache, MCP dev autoload or personal files.
$sourceGame = Join-Path $src "game"
$null = New-Item -ItemType Directory -Force $sourceGame
$excludeDirs = @(".godot", "autoload", "qa")
$excludeFiles = @("*.tmp", "*.log", "presentation.cfg", "startup-info.txt", "compat_report.json")
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
    "像素字体：assets/fonts/FusionPixel12px-zh_hans.ttf（OFL，见 ../Licenses）。",
    "32 位发布构建使用官方 windows_release_x86_32.exe 模板导出。"
) | Set-Content -Encoding UTF8 (Join-Path $src "README.md")

Copy-Item (Join-Path $root "docs/g6/release/*.md") $docs
Copy-Item (Join-Path $root "docs/g6/release/Godot-MIT.txt") $licenses
Copy-Item (Join-Path $root "docs/g6/release/ASSET-RIGHTS.md") $licenses
Copy-Item (Join-Path $root "LICENSE") $licenses
Copy-Item (Join-Path $root "game/assets/licenses/*") $licenses -Recurse

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
Copy-Item (Join-Path $root "qa/G6-013-approval.md") (Join-Path $qa "G6-013-approval.md")

$hashRows = @(
    @{ path = (Join-Path $game "FungusLight.exe"); name = "FungusLight.exe" },
    @{ path = (Join-Path $game "FungusLight.pck"); name = "FungusLight.pck" },
    @{ path = (Join-Path $game "64/FungusLight.exe"); name = "64/FungusLight.exe" },
    @{ path = (Join-Path $game "64/FungusLight.pck"); name = "64/FungusLight.pck" }
)
$hashLines = foreach ($row in $hashRows) {
    "$((Get-FileHash -LiteralPath $row.path -Algorithm SHA256).Hash)  $($row.name)"
}
$hashLines | Set-Content -Encoding ascii (Join-Path $qa "SHA256SUMS.txt")
@(
    "# 菌灯之下 $BuildId 发布包",
    "",
    "- Game/：可直接运行的 Windows 构建（默认 32 位 + 64/ 64 位）",
    "- Source/：Godot 4.3 工程（无缓存/无 MCP autoload）",
    "- Docs/：操作、验收、已知问题、兼容性说明与素材边界",
    "- QA/：AI 验证证据与哈希",
    "- Licenses/：项目、引擎、字体与素材来源",
    "",
    "首次运行请看 Docs/操作说明.md；老电脑请看 Docs/兼容性说明.md；最终人工验收看 QA/验收说明.md。"
) | Set-Content -Encoding UTF8 (Join-Path $release "README.md")

& python (Join-Path $root "tools/check_release_layout.py") $BuildId "$BuildId-$ReleaseName"
if ($LASTEXITCODE -ne 0) { throw "Release layout audit failed." }
$layoutJson = Join-Path $root "qa/evidence/G6/$BuildId-release-layout.json"
if (Test-Path -LiteralPath $layoutJson) {
    Copy-Item $layoutJson (Join-Path $evidence "$BuildId-release-layout.json") -Force
}

$zip = Join-Path $root "deliverables/FungusLight-$BuildId-Release.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $release "*") -DestinationPath $zip -CompressionLevel Optimal
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash
$deliveryZip = Join-Path $root "资料包/01-游戏安装包/FungusLight-$BuildId-Release.zip"
Start-Sleep -Milliseconds 300
Copy-Item $zip $deliveryZip -Force
$hashRows | ForEach-Object {
    "$((Get-FileHash -LiteralPath $_.path -Algorithm SHA256).Hash)  $($_.name)"
} | Set-Content (Join-Path $root "qa/evidence/G6/$BuildId-final-package.txt") -Encoding UTF8
@(
    "",
    "zip=$zip",
    "zip_sha256=$zipHash",
    "delivery_zip=$deliveryZip",
    "release_dir=$release"
) | Add-Content (Join-Path $root "qa/evidence/G6/$BuildId-final-package.txt") -Encoding UTF8
Write-Output "Release: $release"
Write-Output "Zip: $zip"
Write-Output "Delivery zip: $deliveryZip"
Write-Output "ZipSHA256: $zipHash"
