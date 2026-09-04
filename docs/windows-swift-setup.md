# Swift setup – Windows

Cél: a `Packages/HealthCore` csomag (tiszta Swift, HealthKit nélkül) fordítása és tesztelése ezen a gépen.
Az iOS app-héjhoz továbbra is a kölcsön Mac kell.

Gép: Windows 11, x64. Swift stable: **6.3.3** (winget). Forrás: <https://www.swift.org/install/windows/winget/>

## Fontos: VS Code ≠ Visual Studio

A gépen van **VS Code** (1.130) – az **csak szerkesztő**, jó is marad (Swift extensionnel).
De a Swift a Windows-on az **MSVC C++ toolchaint és a Windows SDK-t** használja fordításhoz/linkeléshez,
amit a VS Code **nem** tartalmaz. Ezért kell a **Visual Studio Build Tools** (a teljes VS IDE-t nem kell,
mert szerkesztőnek marad a VS Code).

## Mit telepítünk

| Csomag | Miért | Méret / idő |
|---|---|---|
| Developer Mode | SwiftPM szimbolikus linkekhez kell | azonnal |
| **VS Build Tools 2022** + `VC.Tools.x86.x64` + `Windows11SDK.22000` | MSVC fordító/linker + Windows SDK (C++ headerek) | ~4–6 GB, 10–30 perc |
| `Swift.Toolchain` (winget) | maga a Swift fordító + SwiftPM | ~1 GB |
| VS Code „Swift" extension | kódkiegészítés, teszt-futtatás, debug a meglévő VS Code-ban | pár MB |

> Ha mégis kell a teljes Visual Studio IDE: `-UseVisualStudioCommunity` kapcsoló a scriptnek,
> vagy kézzel a `Microsoft.VisualStudio.2022.Community` ID ugyanazokkal a `--add` komponensekkel.

## Lépések

### 1. Automatán (ajánlott)

**Rendszergazda** PowerShell-ből:
```powershell
cd "C:\Users\Nagy Tamás\TraceLogic"
powershell -ExecutionPolicy Bypass -File .\scripts\setup-swift-windows.ps1
```
Ha már van megfelelő VS: `... setup-swift-windows.ps1 -SkipVisualStudio`

### 2. Kézzel (ha a script nem tetszik)

```powershell
# Developer Mode (rendszergazda)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v AllowDevelopmentWithoutDevLicense /d 1

# VS Build Tools 2022 + komponensek
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --force --custom `
  "--add Microsoft.VisualStudio.Component.Windows11SDK.22000 --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --quiet --norestart" --source winget

# Swift
winget install --id Swift.Toolchain -e --source winget

# VS Code Swift extension
code --install-extension swiftlang.swift-vscode
```

### 3. Ellenőrzés

**Új** PowerShell ablak (hogy a PATH frissüljön), majd:
```powershell
swift --version
cd "C:\Users\Nagy Tamás\TraceLogic\Packages\HealthCore"
swift test
```
Várható: `Test Suite 'All tests' passed` – jelenleg 3 teszt-osztály, ~12 eset (`SampleGapAnalyzerTests`, `MetricTypeTests`).

## Hibaelhárítás

- **`swift` nem található** új ablakban is → jelentkezz ki/be vagy indíts újra (a telepítő módosítja a rendszer-PATH-t).
- **`swift build` linker/headers hiba** (`cannot open ... ucrt` / `MSVCRT`) → a VS komponensek hiányoznak vagy más SDK-verzió van. Nyisd a Visual Studio Installert → Modify → tedd be a *„MSVC v143 – VS 2022 C++ x64/x86 build tools"* és a *„Windows 11 SDK"* elemet.
- **`error: no such module 'XCTest'`** → a Windows Swift toolchain tartalmazza az XCTest-et; ha mégsem, frissíts a legújabb stable-re (`winget upgrade Swift.Toolchain`).
- Git Bash-ből a `swift` lehet, hogy nem látszik akkor sem, ha PowerShell-ből igen – használd PowerShell-t a `swift` parancsokhoz.

## Editor

VS Code már megvan. A setup script telepíti a „Swift" hivatalos extensiont (`swiftlang.swift-vscode`):
kódkiegészítés, teszt-futtatás a szerkesztőből, debug. Kézzel: `code --install-extension swiftlang.swift-vscode`.
