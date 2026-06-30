#Requires -Version 5.1
<#
  release.ps1 - one command to ship a new version. Does the FULL bump+release:
    1. writes the new version into src/lib/Common.ps1 (single source of truth)
    2. rebuilds dist/Sel01Tweaker.ps1
    3. packages release/Sel01-Tweaker.zip (launcher + dist + docs)
    4. commits "release: vX.Y.Z", tags vX.Y.Z, pushes main + tag
    5. creates the GitHub release with the zip + single-file script + notes

  Auth: reuses the GitHub token already stored for `git push` (Credential
  Manager) - no separate login needed.

  Usage:  .\release.ps1 -Version 1.1.0 [-Notes "release\NOTES.md"]
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [string]$Notes = (Join-Path $PSScriptRoot 'release\NOTES.md'),
    [string]$Repo  = 'seltonmt012/Sel01-Tweaker'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$tag  = "v$Version"

function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }

# 1) bump version in the single source of truth
$common = Join-Path $root 'src\lib\Common.ps1'
$txt = [System.IO.File]::ReadAllText($common)
if ($txt -notmatch "Version\s*=\s*'\d+\.\d+\.\d+'") { throw "Could not find Version = '...' in $common" }
$new = [regex]::Replace($txt, "Version\s*=\s*'\d+\.\d+\.\d+'", "Version   = '$Version'", 1)
if ($new -eq $txt) {
    Step "version already $Version (no bump needed)"
} else {
    [System.IO.File]::WriteAllText($common, $new, [System.Text.UTF8Encoding]::new($false))
    Step "version -> $Version"
}

# 2) rebuild
Step 'building dist'
& (Join-Path $root 'build.ps1')

# 3) package zip
Step 'packaging zip'
$stage = Join-Path $env:TEMP "sel01-rel-$Version"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage,(Join-Path $stage 'dist') -Force | Out-Null
Copy-Item (Join-Path $root 'START_Sel01-Tweaker.bat'),(Join-Path $root 'build.bat'),
          (Join-Path $root 'ANLEITUNG.md'),(Join-Path $root 'README.md'),
          (Join-Path $root 'LICENSE'),(Join-Path $root 'NOTICE.md') $stage
Copy-Item (Join-Path $root 'dist\Sel01Tweaker.ps1') (Join-Path $stage 'dist')
$zip = Join-Path $root 'release\Sel01-Tweaker.zip'
New-Item -ItemType Directory -Path (Split-Path $zip) -Force | Out-Null
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force

# 4) commit + tag + push
Step 'commit + tag + push'
git -C $root add -A
git -C $root commit -m "release: $tag" | Out-Null
git -C $root tag -a $tag -m "Sel01-Tweaker $tag"
git -C $root push origin main
git -C $root push origin $tag

# 5) GitHub release (reuse stored credential)
Step 'creating GitHub release'
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = "$env:ProgramFiles\GitHub CLI\gh.exe" }
$cred = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$env:GH_TOKEN = (($cred | Where-Object { $_ -like 'password=*' }) -replace '^password=','').Trim()
$notesArg = if (Test-Path $Notes) { @('--notes-file', $Notes) } else { @('--generate-notes') }
& $gh release create $tag $zip (Join-Path $root 'dist\Sel01Tweaker.ps1') `
    --repo $Repo --title "Sel01-Tweaker $tag" @notesArg

Write-Host "DONE: https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
