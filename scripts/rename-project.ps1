#requires -Version 5.1
<#
.SYNOPSIS
  Átnevezi a projektet MINDENHOL (XcodeGen spec, Swift forrás, docs, config).
.EXAMPLE
  ./scripts/rename-project.ps1 -NewName Vitalis
  ./scripts/rename-project.ps1 -NewName Vitalis -NewBundleIdPrefix com.vitalis
.NOTES
  A generált .xcodeproj-t NEM érinti — utána a Mac-en: xcodegen generate
  A repó mappát magát nem nevezi át (fut közben nem lehet) — azt kézzel.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$NewName,
    [string]$NewBundleIdPrefix
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'project.config.json'

if (-not (Test-Path $configPath)) { throw "Nincs project.config.json: $configPath" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$oldName   = [string]$config.projectName
$oldPrefix = [string]$config.bundleIdPrefix
if ([string]::IsNullOrWhiteSpace($NewBundleIdPrefix)) { $NewBundleIdPrefix = $oldPrefix }

if ($NewName -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
    throw "A -NewName legyen érvényes Swift azonosító (betű/szám, betűvel kezdve). Kapott: '$NewName'"
}
if ($NewName -eq $oldName -and $NewBundleIdPrefix -eq $oldPrefix) {
    Write-Host "Nincs változás ($oldName / $oldPrefix)." -ForegroundColor Yellow
    return
}

Write-Host "Átnevezés:  $oldName -> $NewName   |   bundle prefix:  $oldPrefix -> $NewBundleIdPrefix" -ForegroundColor Cyan

function Replace-InFile([string]$path) {
    if (-not (Test-Path $path)) { return }
    $c = Get-Content -LiteralPath $path -Raw
    $new = $c.Replace($oldName, $NewName)
    if ($oldPrefix -ne $NewBundleIdPrefix) { $new = $new.Replace($oldPrefix, $NewBundleIdPrefix) }
    if ($new -ne $c) {
        Set-Content -LiteralPath $path -Value $new -Encoding UTF8 -NoNewline
        Write-Host "  módosítva: $($path.Substring($root.Length + 1))"
    }
}

# 1. az app fő fájlja: előbb tartalom, aztán átnevezés
$appOld = Join-Path $root ("App/Sources/App/{0}App.swift" -f $oldName)
$appNew = Join-Path $root ("App/Sources/App/{0}App.swift" -f $NewName)
Replace-InFile $appOld
if ((Test-Path $appOld) -and ($appOld -ne $appNew)) {
    Move-Item -LiteralPath $appOld -Destination $appNew
    Write-Host "  átnevezve: $($appNew.Substring($root.Length + 1))"
}

# 2. további szöveges fájlok (token-csere)
@(
    'project.yml',
    'README.md',
    'App/Sources/App/Branding.swift',
    'App/Tests/AppSmokeTests.swift'
) | ForEach-Object { Replace-InFile (Join-Path $root $_) }

Get-ChildItem -LiteralPath (Join-Path $root 'docs') -Filter *.md -ErrorAction SilentlyContinue |
    ForEach-Object { Replace-InFile $_.FullName }

# 3. config újraírása
$config.projectName   = $NewName
$config.displayName   = $NewName
$config.bundleIdPrefix = $NewBundleIdPrefix
$config.organizationName = $NewName
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8

Write-Host ""
Write-Host "Kész. Következő:" -ForegroundColor Green
Write-Host "  - (opcionális) nevezd át a repó mappát is: $oldName -> $NewName"
Write-Host "  - Mac-en:  ./scripts/bootstrap-mac.sh    (xcodegen generate + megnyitás)"
