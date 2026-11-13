# Generates vendored Tech Stack strips: one SVG per category per theme,
# with skillicons' baked 44-unit gaps (8.25px at 48px render height) and
# locally-authored icons appended using the same gap.
# Skillicons source: https://github.com/tandpfun/skill-icons (MIT).

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$assets = Join-Path $PSScriptRoot '..\assets'

$categories = @(
    @{ name = 'languages'; icons = 'ts,js,py,php';                       custom = @() }
    @{ name = 'frontend';  icons = 'react,vue,tailwind,htmx,html,css';   custom = @('shadcn', 'daisyui') }
    @{ name = 'backend';   icons = 'nestjs,django,laravel';              custom = @() }
    @{ name = 'data';      icons = 'graphql,apollo,postgres,prisma';     custom = @('swagger') }
    @{ name = 'tools';     icons = 'git,github,vscode';                  custom = @('codex', 'claudecode') }
)

function Get-SkilliconsStrip {
    param([string]$Icons, [string]$Theme)
    $url = "https://skillicons.dev/icons?i=$Icons&theme=$Theme"
    Write-Host "Fetching $url"
    return (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
}

function Add-CustomTiles {
    param([string]$Strip, [string[]]$Custom, [string]$Theme)

    $root = [regex]::Match($Strip, '<svg width="[\d.]+" height="48" viewBox="0 0 (\d+) 256"')
    if (-not $root.Success) { throw 'Unexpected skillicons strip root tag' }
    $width = [int]$root.Groups[1].Value

    $x = $width + 44
    $insert = ''
    foreach ($name in $Custom) {
        $path = Join-Path $assets "icon-$name-$theme.svg"
        $svg = (Get-Content $path -Raw).Trim()
        $insert += "        <g transform=`"translate($x, 0)`">`n          $svg`n        </g>`n"
        $x += 256 + 44
    }
    $newWidth = $width + 300 * $Custom.Count

    # Update the root svg's width and viewBox, then insert tiles before the closing tag.
    $strip = [regex]::Replace($Strip, '<svg width="[\d.]+" height="48" viewBox="0 0 \d+ 256"',
        "<svg width=`"$([string]::Format([cultureinfo]::InvariantCulture, '{0}', $newWidth * 48 / 256))`" height=`"48`" viewBox=`"0 0 $newWidth 256`"",
        'None') # single occurrence at the start
    $idx = $strip.LastIndexOf('</svg>')
    $strip = $strip.Substring(0, $idx) + $insert + $strip.Substring($idx)
    return $strip
}

foreach ($cat in $categories) {
    foreach ($theme in @('dark', 'light')) {
        $strip = Get-SkilliconsStrip -Icons $cat.icons -Theme $theme
        if ($cat.custom.Count -gt 0) {
            $strip = Add-CustomTiles -Strip $strip -Custom $cat.custom -Theme $theme
        }

        # Sanity check: must be parseable XML.
        [xml]$null = $strip

        $out = Join-Path $assets "stack-$($cat.name)-$theme.svg"
        [IO.File]::WriteAllText($out, $strip)
        $kb = '{0:N1}' -f ((Get-Item $out).Length / 1KB)
        Write-Host "Wrote $out ($kb KB)"
    }
}
