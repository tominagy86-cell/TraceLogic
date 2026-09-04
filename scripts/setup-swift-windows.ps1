#requires -Version 5.1
<#
.SYNOPSIS
  Swift toolchain telepítése Windows-ra (a HealthCore csomag fordításához/teszteléséhez).
.DESCRIPTION
  1) Developer Mode bekapcsolása
  2) Visual Studio Build Tools 2022 + MSVC C++ toolchain + Windows SDK
     (VS Code NEM elég ehhez – az csak szerkesztő.)
  3) Swift.Toolchain (winget)
  4) (opcionális) VS Code "Swift" extension
  RENDSZERGAZDAKÉNT futtatandó PowerShell-ből.
.NOTES
  Forrás: https://www.swift.org/install/windows/winget/
#>
[CmdletBinding()]
param(
    [switch]$SkipVisualStudio,
    [switch]$UseVisualStudioCommunity,
    [switch]$SkipSwift,
    [switch]$SkipVSCodeExtension
)

$ErrorActionPreference = 'Stop'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}
function Invoke-Winget {
    param([string[]]$WingetArgs, [int[]]$OkExit = @(0))
    Write-Host "  winget $($WingetArgs -join ' ')" -ForegroundColor DarkGray
    & winget @WingetArgs
    if ($OkExit -notcontains $LASTEXITCODE) {
        throw "winget kilépési kód: $LASTEXITCODE"
    }
}

if (-not (Test-Admin)) {
    Write-Warning "Nem rendszergazdaként futsz. Indítsd újra a PowerShell-t 'Futtatás rendszergazdaként'-ként."
    return
}

# --- 1. Developer Mode ---
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
$cur = (Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($cur -eq 1) {
    Write-Host "[OK] Developer Mode mar be van kapcsolva." -ForegroundColor Green
} else {
    New-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Host "[OK] Developer Mode bekapcsolva." -ForegroundColor Green
}

# --- 2. Visual Studio Build Tools (vagy Community) + komponensek ---
# FONTOS: a --custom-ba CSAK a --add elemek mennek. A --quiet/--norestart-ot a winget
# maga adja hozza; ha megegyszer beleirjuk, a VS installer 87-es koddal elhasal.
if (-not $SkipVisualStudio) {
    $vsId = if ($UseVisualStudioCommunity) { 'Microsoft.VisualStudio.2022.Community' } else { 'Microsoft.VisualStudio.2022.BuildTools' }
    $components = @(
        '--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
        '--add Microsoft.VisualStudio.Component.Windows11SDK.22000'
    ) -join ' '
    Write-Host "`n[*] $vsId + MSVC + Windows SDK telepitese (hosszu lehet, ~10-30 perc)..." -ForegroundColor Cyan
    Invoke-Winget @(
        'install','--id',$vsId,'-e','--source','winget',
        '--accept-package-agreements','--accept-source-agreements',
        '--custom',$components
    ) -OkExit @(0)
    Write-Host "[OK] $vsId kesz." -ForegroundColor Green
} else {
    Write-Host "[skip] Visual Studio" -ForegroundColor Yellow
}

# --- 3. Swift toolchain ---
if (-not $SkipSwift) {
    Write-Host "`n[*] Swift.Toolchain telepitese..." -ForegroundColor Cyan
    Invoke-Winget @(
        'install','--id','Swift.Toolchain','-e','--source','winget',
        '--accept-package-agreements','--accept-source-agreements'
    ) -OkExit @(0, -1978335189)   # -1978335189 = "mar telepitve / nincs frissites"
    Write-Host "[OK] Swift telepitve." -ForegroundColor Green
} else {
    Write-Host "[skip] Swift" -ForegroundColor Yellow
}

# --- 4. VS Code Swift extension ---
if (-not $SkipVSCodeExtension -and (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "`n[*] VS Code 'Swift' extension..." -ForegroundColor Cyan
    try { & code --install-extension swiftlang.swift-vscode --force } catch { Write-Warning "VS Code extension: $_" }
}

Write-Host @"

============================================================
KESZ. Most:
  1) Zard be EZT az ablakot, nyiss egy UJ PowerShell-t (nem rendszergazda kell).
  2) swift --version
  3) cd "$PSScriptRoot\..\Packages\HealthCore"
     swift test
Ha a 'swift' nem talalhato: jelentkezz ki/be, vagy indits ujra.
============================================================
"@ -ForegroundColor Green
