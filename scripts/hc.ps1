#requires -Version 5.1
<#
.SYNOPSIS
  HealthCore (Windows) dev helper — swift build/test a két Windows-os buktató megkerülésével.
.DESCRIPTION
  Buktató #1 (DLL): a SwiftPM/llbuild a fordító-alfolyamatnak nem adja át a
    ...\Swift\Runtimes\<ver>\usr\bin PATH-t, ezért a swift-frontend.exe csendben
    elszáll (STATUS_DLL_NOT_FOUND, semmi hibaüzenet). Megoldás: a runtime DLL-eket
    a swiftc.exe mellé másoljuk (a Windows a saját mappából tölt először).
  Buktató #2 (szóköz): a felhasználói profil útvonalában szóköz van
    ("C:\Users\Nagy Tamás"), és a SwiftPM teszt-felderítő kódgenerátora emiatt
    elhasal ("...all-discovered-tests.swift doesn't exist"). Megoldás: szóköz-mentes
    --scratch-path (C:\sw_build\healthcore).
.EXAMPLE
  .\scripts\hc.ps1 test
  .\scripts\hc.ps1 build
  .\scripts\hc.ps1 fix       # csak a DLL-másolást futtatja (toolchain-frissítés után)
  .\scripts\hc.ps1 clean
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('build', 'test', 'clean', 'fix')]
    [string]$Command = 'test',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

$repo    = Split-Path -Parent $PSScriptRoot
$pkg     = Join-Path $repo 'Packages\HealthCore'
$scratch = 'C:\sw_build\healthcore'   # SZÓKÖZ-MENTES — lásd fent, buktató #2

$swiftRoot = Join-Path $env:LOCALAPPDATA 'Programs\Swift'
$tc = Get-ChildItem (Join-Path $swiftRoot 'Toolchains') -Directory -EA SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
$rt = Get-ChildItem (Join-Path $swiftRoot 'Runtimes')  -Directory -EA SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if (-not $tc -or -not $rt) {
    throw "Swift toolchain/runtimes nem található itt: $swiftRoot  (telepítés: scripts\setup-swift-windows.ps1)"
}
$tcBin = Join-Path $tc.FullName 'usr\bin'
$rtBin = Join-Path $rt.FullName 'usr\bin'
$env:Path = "$rtBin;$tcBin;$env:Path"

function Invoke-DllFix {
    Copy-Item (Join-Path $rtBin '*.dll') $tcBin -Force
    Write-Host "[hc] runtime DLL-ek a toolchain bin-be másolva ($($tc.Name))" -ForegroundColor Green
}

switch ($Command) {
    'fix' {
        Invoke-DllFix
    }
    'clean' {
        cmd /c "rd /s /q `"$scratch`" 2>nul & rd /s /q `"$(Join-Path $pkg '.build')`" 2>nul"
        Write-Host "[hc] tiszta ($scratch + .build törölve)" -ForegroundColor Green
    }
    default {
        if (-not (Test-Path (Join-Path $tcBin 'swiftCore.dll'))) { Invoke-DllFix }
        Push-Location $pkg
        try {
            Write-Host "[hc] swift $Command --scratch-path $scratch $Rest" -ForegroundColor DarkGray
            & swift $Command --scratch-path $scratch @Rest
            exit $LASTEXITCODE
        }
        finally { Pop-Location }
    }
}
