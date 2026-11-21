param([string]$LuaPath = $env:FOREVERQOL_LUA)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'test.ps1') -LuaPath $LuaPath
$addon = Join-Path $root 'addon/ForeverQoL'
$toc = Get-Content -LiteralPath (Join-Path $addon 'ForeverQoL.toc') -Raw
$version = [regex]::Match($toc, '(?m)^## Version:[ \t]*(\d+\.\d+\.\d+)[ \t]*\r?$').Groups[1].Value
$interface = [regex]::Match($toc, '(?m)^## Interface:[ \t]*(\d+)[ \t]*\r?$').Groups[1].Value
if (-not $version -or -not $interface) { throw 'Invalid version or interface.' }
$out = Join-Path $root "dist/v$version"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$filename = "ForeverQoL-$version.zip"
$zip = Join-Path $out $filename
Compress-Archive -LiteralPath $addon -DestinationPath $zip -Force
@{ releases = @(@{ filename = $filename; version = $version; nolib = $false; metadata = @(@{ flavor = 'camelot'; interface = [int]$interface }) }) } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'release.json') -Encoding UTF8
Get-Item -LiteralPath $zip, (Join-Path $out 'release.json')
