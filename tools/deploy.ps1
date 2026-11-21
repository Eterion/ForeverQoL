[CmdletBinding(SupportsShouldProcess)]
param([string]$AddOnsPath = 'C:\Games\World of Warcraft\_forever_\Interface\AddOns')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = (Resolve-Path -LiteralPath (Join-Path $root 'addon/ForeverQoL')).Path
$parent = (Resolve-Path -LiteralPath $AddOnsPath).Path
$target = [IO.Path]::GetFullPath((Join-Path $parent 'ForeverQoL'))
if ([IO.Path]::GetDirectoryName($target) -ne $parent.TrimEnd('\')) { throw 'Target must be directly inside AddOns.' }
if ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AddOns must not be a linked directory.' }
if (Test-Path -LiteralPath $target) {
    if ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing a linked addon directory.' }
    if (-not (Test-Path -LiteralPath (Join-Path $target 'ForeverQoL.build.json'))) { throw 'Existing folder is not owned by this deploy script.' }
    if (Get-ChildItem -LiteralPath $target -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Refusing linked contents.' }
}
$toc = Get-Content -LiteralPath (Join-Path $source 'ForeverQoL.toc') -Raw
$version = [regex]::Match($toc, '(?m)^## Version:[ \t]*(\d+\.\d+\.\d+)[ \t]*\r?$').Groups[1].Value
if (-not $version) { throw 'Expected stable TOC version.' }
$core = Get-Content -LiteralPath (Join-Path $source 'Core.lua') -Raw
$marker = '(?m)^local developmentBuild = nil(?= --)'
if ($core -notmatch $marker) { throw 'Missing development build marker.' }
$number = 1
$installedCore = Join-Path $target 'Core.lua'
if (Test-Path -LiteralPath $installedCore) {
    $previous = [regex]::Match((Get-Content -LiteralPath $installedCore -Raw), '(?m)^local developmentBuild = "' + [regex]::Escape($version) + '-dev\.(\d+)"')
    if ($previous.Success) { $number += [int]$previous.Groups[1].Value }
}
$build = "$version-dev.$number"
if ($PSCmdlet.ShouldProcess($target, "Deploy ForeverQoL $build")) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $files = @(Get-ChildItem -LiteralPath $source -Recurse -File)
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($source.Length + 1)
        $dest = Join-Path $target $relative
        New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
        if ($relative -eq 'Core.lua') {
            $localCore = $core -replace $marker, ('local developmentBuild = "' + $build + '"')
            [IO.File]::WriteAllText($dest, $localCore, $utf8)
            if ((Get-Content -LiteralPath $dest -Raw) -cne $localCore) { throw 'Core verification failed.' }
        } else {
            Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
            if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $dest).Hash) { throw "Verification failed: $relative" }
        }
    }
    @{ addon = 'ForeverQoL'; version = $version; developmentBuild = $build; fileCount = $files.Count } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target 'ForeverQoL.build.json') -Encoding UTF8
    Write-Output "Deployed and verified ForeverQoL $build ($($files.Count) files) to $target. After /reload, check /fql."
}
