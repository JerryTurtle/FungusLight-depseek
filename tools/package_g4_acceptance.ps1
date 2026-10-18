param([string]$BuildId = "G4-001")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "deliverables/$BuildId"
$output = Join-Path $root "deliverables/$BuildId-Acceptance"
$docs = Join-Path $root "docs/g4/acceptance"
$evidence = Join-Path $root "qa/evidence/G4"
if (-not (Test-Path (Join-Path $source "FungusLight.exe"))) { throw "Missing $BuildId build" }
if (Test-Path $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item (Join-Path $source "FungusLight.exe") $output
Copy-Item (Join-Path $source "FungusLight.pck") $output
Copy-Item (Join-Path $source "licenses") $output -Recurse
Copy-Item (Join-Path $docs "G4-Acceptance.md") $output
Copy-Item (Join-Path $docs "G4-Checklist.md") $output
$cmds = @{
  "G4-Acceptance.cmd" = @('@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe" -- --campaign')
  "G2-Review.cmd" = @('@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe"')
  "Enemy-Arena.cmd" = @('@echo off', 'cd /d "%~dp0"', 'start "" "%~dp0FungusLight.exe" -- --enemy-arena')
}
foreach ($name in $cmds.Keys) { $cmds[$name] | Set-Content -Encoding ascii (Join-Path $output $name) }
$ev = Join-Path $output "evidence"
New-Item -ItemType Directory -Path $ev -Force | Out-Null
foreach ($name in @("$BuildId-progress.md","$BuildId-route-matrix.json","$BuildId-hashes.txt","G4-001-boss.png","G4-001-boss-phase.png","G4-001-branch.png","G4-001-ending.png","G4-001-court.png","G4-001-rootbridge.png")) {
  $path = Join-Path $evidence $name
  if (Test-Path $path) { Copy-Item $path $ev }
}
$hashLines = Get-FileHash (Join-Path $output "FungusLight.exe"),(Join-Path $output "FungusLight.pck") -Algorithm SHA256 | ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" }
$hashLines | Set-Content -Encoding ascii (Join-Path $output "SHA256SUMS.txt")
$zip = "$output.zip"
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $output "*") -DestinationPath $zip -CompressionLevel Optimal
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash
Write-Output "Package: $output"
Write-Output "Zip: $zip"
Write-Output "ZipSHA256: $zipHash"
