param([string]$LuaPath = $env:FOREVERQOL_LUA)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $LuaPath) {
    $command = Get-Command lua -ErrorAction SilentlyContinue
    if ($command) { $LuaPath = $command.Source }
    else { $LuaPath = Join-Path $root '../QuestsStarts/work/QuestieDB/tools/lua-binary/lua.exe' }
}
if (-not (Test-Path -LiteralPath $LuaPath)) { throw 'Supply Lua 5.1+ using -LuaPath or FOREVERQOL_LUA.' }
& $LuaPath (Join-Path $root 'tests/run.lua') $root
if ($LASTEXITCODE -ne 0) { throw 'ForeverQoL regression tests failed.' }
& $LuaPath (Join-Path $root 'tests/quest-items.lua') $root
if ($LASTEXITCODE -ne 0) { throw 'Quest-item regression tests failed.' }
$addon = Join-Path $root 'addon/ForeverQoL'
foreach ($file in Get-ChildItem -LiteralPath $addon -Filter '*.lua') {
    $env:FOREVERQOL_PARSE_FILE = $file.FullName
    & $LuaPath -e 'assert(loadfile(os.getenv([[FOREVERQOL_PARSE_FILE]])))'
    if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $($file.Name)" }
}
Remove-Item Env:FOREVERQOL_PARSE_FILE
foreach ($line in Get-Content -LiteralPath (Join-Path $addon 'ForeverQoL.toc')) {
    if ($line.Trim() -and -not $line.StartsWith('#') -and -not (Test-Path -LiteralPath (Join-Path $addon $line))) { throw "Missing TOC entry: $line" }
}
if ((Get-Content -LiteralPath (Join-Path $addon 'Core.lua') -Raw) -notmatch '(?m)^local developmentBuild = nil --') { throw 'Source must not contain a development build identifier.' }
Write-Output 'Shipped Lua syntax, TOC entries, and release build marker passed.'
