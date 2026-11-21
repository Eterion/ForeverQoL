param([string]$Upstream = (Join-Path $PSScriptRoot '../work/QuestieDB'))
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = (Resolve-Path -LiteralPath $Upstream).Path
$revision = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'upstream-revision.txt') -Raw).Trim()
if ((git -C $source rev-parse HEAD).Trim() -ne $revision) { throw 'QuestieDB revision does not match pin.' }
if (git -C $source status --porcelain --untracked-files=no) { throw 'QuestieDB tracked sources must be clean.' }
$lua = Join-Path $source 'tools/lua-binary/lua.exe'
if ((Get-FileHash -LiteralPath $lua -Algorithm SHA256).Hash -ine '1e2911d6e9e29c2a0bd14a7e5477c4c42e433a3d13a5d82ff7a414d9782a7f0e') { throw 'Unexpected Lua runtime hash.' }
$out = Join-Path $root 'work/quest-item-profiles'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$script = Join-Path $PSScriptRoot 'export-quest-items.lua'
$profiles = @()
$classes = [ordered]@{WARRIOR=1; PALADIN=2; HUNTER=3; ROGUE=4; PRIEST=5; SHAMAN=7; MAGE=8; WARLOCK=9; DRUID=11}
Push-Location $source
try {
    foreach ($faction in @('Alliance', 'Horde')) {
        foreach ($class in $classes.GetEnumerator()) {
            $path = Join-Path $out "$faction-$($class.Key).lua"
            & $lua $script profile $path $revision $class.Key $class.Value $faction
            if ($LASTEXITCODE -ne 0) { throw "Quest item export failed: $faction $($class.Key)" }
            $profiles += $path
        }
    }
    & $lua $script merge (Join-Path $root 'addon/ForeverQoL/QuestItemData.lua') $revision @profiles
    if ($LASTEXITCODE -ne 0) { throw 'Quest item merge failed.' }
} finally { Pop-Location }
$licenses = Join-Path $root 'addon/ForeverQoL/Licenses'
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'LICENSE.md') -Destination (Join-Path $licenses 'QuestieDB-LICENSE.md') -Force
Copy-Item -LiteralPath (Join-Path $source 'PROVENANCE.md') -Destination (Join-Path $licenses 'QuestieDB-PROVENANCE.md') -Force
Copy-Item -LiteralPath (Join-Path $source 'gpl-3.0.md') -Destination (Join-Path $licenses 'GPL-3.0.md') -Force
