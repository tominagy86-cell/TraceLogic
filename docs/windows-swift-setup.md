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
# FONTOS: a --custom-ba CSAK a --add elemek mennek; a --quiet/--norestart-ot a winget
# adja hozzá, ha megismételjük -> a VS installer 87-es hibával elszáll.
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget `
  --accept-package-agreements --accept-source-agreements --custom `
  "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22000"
# (vagy egyszerűbben: VS Installer GUI -> "Desktop development with C++" workload)

# Swift
winget install --id Swift.Toolchain -e --source winget

# runtime DLL fix + VS Code extension
.\scripts\hc.ps1 fix
code --install-extension swiftlang.swift-vscode
```

### 3. Build és teszt – `hc.ps1`

**Új** PowerShell ablak (hogy a PATH frissüljön), a repo gyökeréből:
```powershell
.\scripts\hc.ps1 test      # build + XCTest
.\scripts\hc.ps1 build     # csak build
.\scripts\hc.ps1 clean     # scratch + .build törlése
.\scripts\hc.ps1 fix       # runtime DLL-ek újramásolása (toolchain-frissítés után)
```
Várható: `Test Suite 'All tests' passed` – jelenleg **9 eset** (`SampleGapAnalyzerTests` 6, `MetricTypeTests` 3).

`swift build` / `swift test` közvetlenül **nem működik** ezen a gépen két Windows-os buktató miatt (lásd lent) – ezért van a `hc.ps1` wrapper.

## Windows-os buktatók (a `hc.ps1` megkerüli őket)

### #1 – A fordító csendben elszáll (DLL)
A SwiftPM/llbuild a `swift-frontend.exe` alfolyamatnak **nem adja át** a
`...\Swift\Runtimes\<ver>\usr\bin` PATH-t, így az nem találja a `swiftCore.dll`-t és
**hibaüzenet nélkül** meghal → `swift build` csak annyit ír: `[1/2] Write swift-version...`, majd exit 1.
**Megoldás:** a runtime DLL-eket a `swiftc.exe` mellé másoljuk (`hc.ps1 fix`, ill. a setup script
a végén automatikusan). Windows a saját mappából tölt DLL-t először, így megkerüli a hiányos PATH-t.

### #2 – Szóköz a profil-útvonalban
`C:\Users\Nagy Tamás` – a szóköz miatt a SwiftPM teszt-felderítő kódgenerátora elhasal:
`...all-discovered-tests.swift doesn't exist in file system` (az útvonal elhasad a szóköznél).
**Megoldás:** szóköz-mentes build-könyvtár: `hc.ps1` mindig `--scratch-path C:\sw_build\healthcore`-ral hív.

### Ártalmatlan warning
`unable to create symbolic link at ...\debug (I/O error code: 512)` – a SwiftPM egy kényelmi
`debug` symlinket próbál csinálni; a build enélkül is rendben lefut. Ignorálható.

## Hibaelhárítás

- **`swift` nem található** új ablakban is → jelentkezz ki/be vagy indíts újra (a telepítő a User PATH-t módosítja).
- **`unable to load standard library for target x86_64-unknown-windows-msvc`** → hiányzik az MSVC toolchain. VS Installer → Build Tools → Modify → *„Desktop development with C++"*. Ellenőrzés: „Developer PowerShell for VS 2022" → `where cl`.
- **`swift build` exit 1, semmi hibaüzenet** → a buktató #1; futtasd: `.\scripts\hc.ps1 fix`.
- **`...all-discovered-tests.swift doesn't exist`** → a buktató #2; használd a `hc.ps1`-et (ne a nyers `swift test`-et).
- **VS Installer örökké újraindítást kér** → Fast Startup miatt a „Leállítás" nem valódi reboot. `shutdown /r /t 0 /f` rendszergazdai promptból; ha az sem elég: `Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations`.
- **`error: no such module 'XCTest'`** → frissíts: `winget upgrade Swift.Toolchain`, majd `hc.ps1 fix`.
- Git Bash-ből a `swift` gyakran nem látszik – használd PowerShell-t.

## Editor

VS Code már megvan. A setup script telepíti a „Swift" hivatalos extensiont (`swiftlang.swift-vscode`):
kódkiegészítés, teszt-futtatás a szerkesztőből, debug. Kézzel: `code --install-extension swiftlang.swift-vscode`.
