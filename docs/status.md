# Fejlesztési státusz

*Utolsó frissítés: 2026-09-04, commit `09c6f6c`.*

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

### `Packages/HealthCore` — platformfüggetlen logika, **42/42 XCTest zöld**
Parancs: `.\scripts\hc.ps1 test`

| Fájl | Tartalom | Tesztelve |
|---|---|---|
| `MetricType.swift` | 16 metrika enum (szív, légzés, aktivitás, test, alvás) + unit/aggregáció metaadat | ✅ `MetricTypeTests` (3) |
| `MetricSample.swift` | normalizált minta-struct (HealthKit-független) | ✅ (közvetve) |
| `SampleGapAnalyzer.swift` | mintavételi sűrűség elemzése (rések, percentilisek, forrásbontás) | ✅ `SampleGapAnalyzerTests` (6) |
| `DailyStat.swift` + `DailyAggregator.swift` | minták → naptári napi bontás (sum/avg/min/max, üres napok) | ✅ `DailyAggregatorTests` (5) |
| `MetricCatalog.swift` | megjelenítési infó metrikánként (név, egység-jel, sorrend) | ✅ `MetricCatalogTests` (5) |
| `HealthDataSource.swift` | a fő absztrakció: protokoll amire minden épül (auth, lekérdezés, alvás, edzés) | ✅ (közvetve) |
| `SleepStage.swift` + `SleepSession.swift` + `SleepSessionBuilder.swift` | szegmensek → éjszakák (dél-dél anchor), több-forrás dedup | ✅ `SleepSessionBuilderTests` (9) |
| `WorkoutSummary.swift` | edzés-összesítő (HealthKit-független) | ✅ (közvetve) |
| `JSONExporter.swift` + `CSVExporter.swift` | JSON/CSV export mintákra, napi statra, alvásra, edzésre | ✅ `ExportTests` (8) |
| `InMemoryHealthDataSource.swift` | fake adatforrás teszthez/previewhoz (mostantól alvást/edzést is tud) | ✅ `InMemoryHealthDataSourceTests` (6) |

**Ez a réteg megbízható.** Amit itt leírunk (baseline-logika, aggregálás, alvás-csoportosítás,
export, gap-analízis), az helyesen működik, függetlenül attól, hogy a HealthKit-es réteg még
nincs kipróbálva.

---

## 2. Kész, de **nincs igazolva** — Mac kell hozzá (szerda, 09.09.)

Az `App/Sources/` alatti kód HealthKit-et és SwiftUI-t használ, amit Windows-on **nem lehet
lefordítani** — tehát ez a kód eddig **soha nem futott át semmilyen fordítón**. Valószínűleg lesznek
benne apró hibák, amiket csak a Mac-en derül ki.

| Fájl | Mit csinál |
|---|---|
| `HealthKit/MetricType+HealthKit.swift` | `MetricType` → `HKQuantityTypeIdentifier` / `HKSampleType` / `HKUnit` leképezés |
| `HealthKit/MetricSample+HealthKit.swift` | `HKQuantitySample` → `MetricSample` (SpO₂ ×100 konverzió, HR motion context) |
| `HealthKit/SleepStage+HealthKit.swift` | `HKCategoryValueSleepAnalysis` → `SleepStage` |
| `HealthKit/HealthKitAdapter.swift` | `actor`, a `HealthDataSource` teljes HealthKit-implementációja (minták, napi stat, alvás, edzés) |
| `Store/StoredModels.swift` + `MetricStore.swift` + `ModelContainerFactory.swift` | SwiftData perzisztencia, `hkUUID`-alapú upsert-dedup |
| `Sync/SyncCoordinator.swift` | `backfill(days:)` (90 nap) + `incrementalSync()` a `HealthDataSource`-ra építve — **még nincs bekötve az app UI-ba** |
| `Features/Permission/PermissionGateView.swift` | engedélykérő képernyő + `@Observable` modell |
| `Features/Dashboard/DashboardView.swift` + `DashboardModel.swift` | „Legfrissebb értékek" lista, toolbarban link az Inspectorhoz |
| `Features/DataInspector/DataInspectorView.swift` + `DataInspectorModel.swift` | metrika + időablak választó, `GapStats` (rések, lefedettség, forrásbontás), nyers minták listája |
| `App/RootView.swift` | PermissionGate → Dashboard összekötve |

**Fontos:** a `MetricStore` / `SyncCoordinator` **meg van írva, de a `RootView`/`App` még nem
hívja** — a Dashboard egyelőre mindig élő HealthKit-lekérdezéssel dolgozik, nincs lokális cache
és nincs 90 napos automata backfill elindítva. Ez a következő Mac-utáni lépés, miután a jelenlegi
réteg lefordul és fut.

### Amit szerdán konkrétan tesztelni kell (sorrendben)

1. **`./scripts/bootstrap-mac.sh` lefut hiba nélkül** — xcodegen települ, `.xcodeproj` legenerálódik.
2. **Az App target lefordul.** Ez az első valódi próba — gyanús pontok, ahol hiba várható:
   - `HKQuantityType(_:)` / `HKCategoryType(_:)` inicializáló elérhetősége (iOS 17 vs 18 API-verzió)
   - `HKUnit(from: "ml/kg*min")` — a VO₂max mértékegység string helyessége
   - Swift 6 strict concurrency (`project.yml`-ben bekapcsolva) — a `HealthKitAdapter` actor és a
     `@MainActor @Observable` modellek közti határok
   - `ContentUnavailableView`, `.refreshable`, `@Observable` — mind iOS 17+ API, de sose futottak
   - `HKCategoryValueSleepAnalysis` switch-exhaustivity a deprecated `.asleep` case-re (jelölve a kódban)
   - `@ModelActor` makró generált `init(modelContainer:)` láthatósága (jelölve a kódban)
   - `workout.statistics(for:)` és a `HKStatistics` opcionális-lánc helyessége
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

## 3. Kész (unverified), és ami tényleg nincs elkezdve

A `docs/v0-plan.md` fázisai szerint — a C/D/E fázis kódja **megvan**, de Mac nélkül nem tudjuk
igazolni, és néhány darab nincs bekötve az app tényleges futásába:

| Fázis | Elem | Állapot |
|---|---|---|
| C | SwiftData perzisztencia (`StoredSample` stb., `MetricStore`) | kód kész, **nincs bekötve** a Dashboardba |
| C | `SyncCoordinator` (90 napos backfill + inkrementális) | kód kész, **nincs elindítva** sehonnan |
| C | `MetricDetailView` (7/28/90 napos grafikon) | ❌ nincs elkezdve |
| D | `SleepSessionBuilder` | ✅ kész, Windows-on tesztelve (HealthCore) |
| D | Edzés-lekérdezés (`HealthKitAdapter.workouts`) | kód kész, nem verifikált |
| D | `SleepView`, `WorkoutsView` (kész UI ezekre) | ❌ nincs elkezdve — a `WorkoutSummary`/`SleepSession` adat megvan, csak nézet nincs rá |
| E | `DataInspectorView` | ✅ megírva, Dashboard toolbarból elérhető, nem verifikált |
| E | Latencia-log (`SyncLogEntry`) | kód kész a `MetricStore`-ban, nincs UI rajta |
| F | Inkrementális szinkron | ✅ megírva **re-query alapon** (nem valódi `HKAnchoredObjectQuery`-anchor — tudatos V0 egyszerűsítés, lásd `SyncCoordinator.swift` fejléc-komment) |
| F | Háttér-kézbesítés (`HKObserverQuery` + `enableBackgroundDelivery`) | ❌ nincs elkezdve |
| G | JSON/CSV export | ✅ kész, Windows-on tesztelve (HealthCore) — **nincs export-gomb** a UI-n |
| G | `docs/metric-findings.md` / `docs/test-matrix.md` valós adattal | ❌ **szándékosan nem töltöttem ki** — lásd lent |

### Miért nincs kitöltve a metric-findings.md / test-matrix.md

Ezek a dokumentumok **valós Apple Watch adatot** és **valós eszközön futó tesztet** igényelnek —
sem az egyik, sem a másik nem áll rendelkezésre Windows-on, kitalált számokkal pedig nem töltöm ki
őket (az egész V0 lényege pont az, hogy ez a két dokumentum *mért*, nem feltételezett adatot
tartalmazzon). Ezek szerdán, a Mac-es session-ben, a `DataInspectorView` és az export alapján
töltendők ki élesben.

---

## Összefoglaló egy mondatban

**A logikai mag (mit jelent egy „nap", hogyan térünk el a baseline-tól, milyen sűrű az adat, hogyan
áll össze egy alvás-éjszaka, hogyan exportálunk) készen van és bizonyítottan helyes — 42/42 teszt
zöld. A HealthKit-es „csatlakozás a valósághoz" réteg (adapter, perzisztencia, szinkron, inspector)
meg van írva, de első tesztje szerdán lesz — ott várható egy kör hibajavítás, mielőtt tényleg fut
az app a telefonodon, és utána tudjuk elkezdeni kitölteni a metric-findings.md-t.**
