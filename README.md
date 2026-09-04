# TraceLogic

> **A név ideiglenes.** A végleges még nincs meg. Átnevezés mindenhol egy paranccsal:
> `./scripts/rename-project.ps1 -NewName <UjNev>` (Windows) vagy `./scripts/rename-project.sh <UjNev>` (Mac).
> Az egyetlen „névforrás" a [`project.config.json`](project.config.json).

iPhone-first személyes egészség-intelligencia réteg az Apple HealthKit adatai fölött.
Nem aktivitás-dashboard: **személyes baseline**-t épít, és azt mutatja meg, a mai állapot hogyan
tér el a felhasználó *saját* szokásos értékeitől (HRV, nyugalmi pulzus, alvás, terhelés) —
magyarázható score-okkal és reggeli összefoglalóval.

Jelenlegi fázis: **V0 – HealthKit Reader** (technikai proof of concept a saját iPhone-on).
Részletes terv: [`docs/v0-plan.md`](docs/v0-plan.md).

## Fejlesztési modell

| Hol | Mit |
|---|---|
| **Windows gép (elsődleges)** | Kód írása. A `Packages/HealthCore` (tiszta Swift, HealthKit nélkül) itt **fordul és tesztelhető**. |
| **Kölcsön Apple gép (időnként)** | `xcodegen generate` → build a saját iPhone-ra, HealthKit-hitelesítés, valós adat validálása. |

Az `.xcodeproj`-t **nem verziózzuk** — a [`project.yml`](project.yml)-ből generálódik (XcodeGen).
Így az átnevezés és a platformfüggetlen szerkesztés is egyszerű.

## Repó felépítés

```
TraceLogic/
├─ project.yml              XcodeGen spec (név/bundle ID egyetlen forrása az app targethez)
├─ project.config.json      projektnév + bundle prefix (a rename script ezt olvassa/írja)
├─ scripts/
│  ├─ rename-project.ps1 / .sh   átnevezés mindenhol
│  ├─ bootstrap-mac.sh           kölcsön Mac: xcodegen + megnyitás
│  └─ build-mac.sh               kölcsön Mac: build/teszt
├─ docs/
│  ├─ v0-plan.md            részletes V0 fejlesztési terv
│  ├─ metric-findings.md    ← a V0 fő leszállítandója (valós mérésekből töltöd)
│  ├─ test-matrix.md        kézi tesztlista
│  └─ mac-build-workflow.md kölcsön-Mac munkafolyamat
├─ App/                     iOS app target (Swift/SwiftUI + HealthKit)
│  ├─ Sources/App/
│  └─ Tests/
└─ Packages/HealthCore/     platformfüggetlen logika (Windows-on is tesztelhető)
```

## Windows – gyors start

1. Swift + VS Build Tools telepítése: `scripts/setup-swift-windows.ps1` (rendszergazdaként) — részletek: [`docs/windows-swift-setup.md`](docs/windows-swift-setup.md)
2. Build + teszt: **`.\scripts\hc.ps1 test`** (a nyers `swift test` itt nem megy — a `hc.ps1` kezeli a Windows-os buktatókat: runtime-DLL PATH és a szóközös profil-útvonal)

## Mac – gyors start

```bash
./scripts/bootstrap-mac.sh
```

## Átnevezés

```powershell
./scripts/rename-project.ps1 -NewName Vitalis -NewBundleIdPrefix com.vitalis
```

Ezután (Mac-en) `xcodegen generate`. A repó mappát magát kézzel nevezd át.
