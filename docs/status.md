# Fejlesztési státusz

*Utolsó frissítés: 2026-09-04, commit `575e65d`.*

Ez a dokumentum azt mondja meg pontosan: **mi kész és igazoltan működik**, **mi kész de nincs
igazolva** (Mac kell hozzá), és **mi nincs még megcsinálva**. A `docs/v0-plan.md` a teljes tervet
írja le; ez itt egy pillanatfelvétel a haladásról.

---

## 1. Kész és igazoltan működik (Windows-on tesztelve)

### Projekt-infrastruktúra
- Repó gyökér: `TraceLogic/`, XcodeGen-alapú (`project.yml`) — az `.xcodeproj` nincs verziózva.
- Átnevezési mechanizmus: `scripts/rename-project.ps1 -NewName <X>` (a végleges név még nincs meg).
- Windows Swift dev-környezet: Swift 6.3.3 + VS Build Tools (MSVC 14.44 + Windows SDK) + `scripts/hc.ps1`
  wrapper, ami megkerüli a két Windows-os SwiftPM-bugot (runtime-DLL PATH, szóköz a profil-útvonalban).
  Dokumentálva: `docs/windows-swift-setup.md`.
- Git: `main` branch, GitHub `tominagy86-cell/TraceLogic` (publikus repó).

### `Packages/HealthCore` — platformfüggetlen logika, **25/25 XCTest zöld**
Parancs: `.\scripts\hc.ps1 test`

| Fájl | Tartalom | Tesztelve |
|---|---|---|
| `MetricType.swift` | 16 metrika enum (szív, légzés, aktivitás, test, alvás) + unit/aggregáció metaadat | ✅ `MetricTypeTests` |
| `MetricSample.swift` | normalizált minta-struct (HealthKit-független) | ✅ (közvetve) |
| `SampleGapAnalyzer.swift` | mintavételi sűrűség elemzése (rések, percentilisek, forrásbontás) | ✅ `SampleGapAnalyzerTests` (6) |
| `DailyStat.swift` + `DailyAggregator.swift` | minták → naptári napi bontás (sum/avg/min/max, üres napok) | ✅ `DailyAggregatorTests` (5) |
| `MetricCatalog.swift` | megjelenítési infó metrikánként (név, egység-jel, sorrend) | ✅ `MetricCatalogTests` (5) |
| `HealthDataSource.swift` | a fő absztrakció: protokoll amire minden épül (auth, lekérdezés) | ✅ (közvetve) |
| `InMemoryHealthDataSource.swift` | fake adatforrás teszthez/previewhoz | ✅ `InMemoryHealthDataSourceTests` (6) |

**Ez a réteg megbízható.** Amit itt leírunk (baseline-logika, aggregálás, gap-analízis), az helyesen
működik, függetlenül attól, hogy a HealthKit-es réteg még nincs kipróbálva.

---

## 2. Kész, de **nincs igazolva** — Mac kell hozzá (szerda, 09.09.)

Az `App/Sources/` alatti kód HealthKit-et és SwiftUI-t használ, amit Windows-on **nem lehet
lefordítani** — tehát ez a kód eddig **soha nem futott át semmilyen fordítón**. Valószínűleg lesznek
benne apró hibák, amiket csak a Mac-en derül ki.

| Fájl | Mit csinál |
|---|---|
| `HealthKit/MetricType+HealthKit.swift` | `MetricType` → `HKQuantityTypeIdentifier` / `HKSampleType` / `HKUnit` leképezés |
| `HealthKit/MetricSample+HealthKit.swift` | `HKQuantitySample` → `MetricSample` (SpO₂ ×100 konverzió, HR motion context) |
| `HealthKit/HealthKitAdapter.swift` | `actor`, a `HealthDataSource` valódi HealthKit-implementációja |
| `Features/Permission/PermissionGateView.swift` | engedélykérő képernyő + `@Observable` modell |
| `Features/Dashboard/DashboardView.swift` + `DashboardModel.swift` | „Legfrissebb értékek" lista |
| `App/RootView.swift` | PermissionGate → Dashboard összekötve |

### Amit szerdán konkrétan tesztelni kell (sorrendben)

1. **`./scripts/bootstrap-mac.sh` lefut hiba nélkül** — xcodegen települ, `.xcodeproj` legenerálódik.
2. **Az App target lefordul.** Ez az első valódi próba — gyanús pontok, ahol hiba várható:
   - `HKQuantityType(_:)` / `HKCategoryType(_:)` inicializáló elérhetősége (iOS 17 vs 18 API-verzió)
   - `HKUnit(from: "ml/kg*min")` — a VO₂max mértékegység string helyessége
   - Swift 6 strict concurrency (`project.yml`-ben bekapcsolva) — a `HealthKitAdapter` actor és a
     `@MainActor @Observable` modellek közti határok
   - `ContentUnavailableView`, `.refreshable`, `@Observable` — mind iOS 17+ API, de sose futottak
3. **Aláírás:** a kolléganő saját (ingyenes) Apple ID-jával, Signing & Capabilities → Team.
4. **Telepítés a te iPhone-odra** kábellel — „Untrusted Developer" kezelése a telefonon.
5. **Az engedélykérő prompt ténylegesen megjelenik-e**, és a teljes 16 metrikás listát kéri-e.
6. **Dashboard valós adattal** — a „Legfrissebb értékek" lista helyes-e, és a „Nincs adat" szekció
   értelmesen kezeli-e azokat a típusokat, amik nálad nincsenek (pl. SpO₂ órafüggő, VO₂max ritka).
7. **Összevetés az Apple Health apppal** ugyanarra az értékre (legalább pulzus + lépés).
8. **Crash-teszt:** ha egy-egy típust megtagadsz, nem száll-e el az app.

Ha bármelyik pontnál hiba van, **ne próbáljátok ott helyben kézzel javítani** — másoljátok ki a
hibaüzenetet, ide behozom, javítom, `git push`, ti `git pull` + újra 1–2. lépés.

---

## 3. Még nincs elkezdve

A `docs/v0-plan.md` szerinti sorrendben:

- **C fázis:** SwiftData perzisztencia (`StoredSample`, `StoredDailyStat`, `MetricStore`),
  `SyncCoordinator` (90 napos backfill), `MetricDetailView` grafikonnal
- **D fázis:** `SleepSessionBuilder` (alvás-szegmensek éjszakákká csoportosítása — HealthCore-ban,
  Windows-on tesztelhető, **ez a legjobb jelölt a következő Windows-os munkára**), edzés-lekérdezés,
  `SleepView`, `WorkoutsView`
- **E fázis:** `DataInspectorView` (a már kész `SampleGapAnalyzer`-re épül), latencia-log
- **F fázis:** inkrementális anchored szinkron, háttér-kézbesítés kísérlet
- **G fázis:** JSON/CSV export, `docs/metric-findings.md` és `docs/test-matrix.md` **kitöltése valós
  adattal** (jelenleg csak üres sablon mindkettő)

---

## Összefoglaló egy mondatban

**A logikai mag (mit jelent egy „nap", hogyan térünk el a baseline-tól, milyen sűrű az adat) készen
van és bizonyítottan helyes. A HealthKit-es „csatlakozás a valósághoz" réteg meg van írva, de első
tesztje szerdán lesz — ott várható egy kör hibajavítás, mielőtt tényleg fut az app a telefonodon.**
