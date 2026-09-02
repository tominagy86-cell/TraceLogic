# TraceLogic – iOS V0 fejlesztési terv

**Dokumentum státusz:** V0 kickoff terv · 2026-09-02
**Projektnév:** `TraceLogic` – **ideiglenes**, a végleges még nincs meg. Átnevezés mindenhol:
`./scripts/rename-project.ps1 -NewName <UjNev>`. A névforrás a `project.config.json`.
**Scope:** *Kizárólag* a saját iPhone-odon, HealthKit adatokból működő technikai proof of concept.
**Nem cél most:** baseline engine, score-ok, AI briefing, backend, más platformok, HealthKit write-back, értesítések, widget, fiókkezelés.

A korábbi koncepció-leírás „Healthy Bullet" munkacímen készült – a termékvízió (personal baseline + health intelligence engine) változatlan, csak a kód/repó neve most `TraceLogic`.

A V0 fő értéke nem egy szép app, hanem **megbízhatóan validált tudás** arról, hogy a saját Apple Watch-od pontosan milyen adatokat, milyen időbeli felbontással, milyen késleltetéssel és milyen forrásból ad. Ez a `docs/metric-findings.md`-ben áll össze – ez a V0 legfontosabb leszállítandója.

---

## 0. Fejlesztési modell és előfeltevések

| Hol | Mit |
|---|---|
| **Windows gép (elsődleges)** | Kód írása. A `Packages/HealthCore` (tiszta Swift, HealthKit nélkül) itt **fordul és tesztelhető** — `swift test`. TDD-vel itt épül a lényegi logika (gap-analízis, aggregálás, alvás-session, baseline). |
| **Kölcsön Apple gép (időnként)** | `xcodegen generate` → build a saját iPhone-ra, HealthKit engedélyek, valós adat validálása, `metric-findings.md` frissítése. |

- **Windows Swift toolchain:** <https://www.swift.org/install/windows/> (a HealthCore csomaghoz).
- **Mac:** Xcode 16.x (macOS Sequoia). `xcodegen` (a `bootstrap-mac.sh` telepíti).
- **Apple ID** elég a saját eszközre telepítéshez (személyes team, 7 napos provisioning). A **HealthKit capability** personal team-mel is megy on-device fejlesztéshez. **Fizetős Apple Developer Program ($99/év)** csak TestFlight / App Store esetén kell. → *Provisioning-nél ellenőrizd.*
- iPhone iOS 17+ és párosított Apple Watch watchOS 10+.
- Az **`.xcodeproj` nincs verziózva** – a `project.yml`-ből generálódik (XcodeGen). Ez teszi olcsóvá az átnevezést és a Windows-os szerkesztést.

---

## 1. Technológiai stack

| Réteg | Választás | Indok |
|---|---|---|
| Nyelv | Swift 6 (strict concurrency) | – |
| UI | SwiftUI | egyszerű, dark mode ingyen, V0-hoz elég |
| Projekt-generálás | **XcodeGen** (`project.yml`) | text-alapú, átnevezhető, `.xcodeproj` nélkül verziózható, Windows-on szerkeszthető |
| Min. deployment target | **iOS 17.0** | SwiftData, `@Observable`, modern Swift Charts; lefedi az összes kellő HealthKit API-t |
| Konkurencia | async/await, **egy `actor`** a `HKHealthStore` köré | HealthKit callback-alapú; az actor sorosít és izolál |
| Perzisztencia | **SwiftData** (`@Model`) | V0/V0.2 méretre elég; a `MetricStore` protokoll mögött később cserélhető GRDB-re |
| Grafikonok | Swift Charts | natív |
| Csomagkezelés | SPM (lokális `HealthCore` package) | – |
| Külső függőségek | **0** a V0-ban (XcodeGen csak build-tool a Mac-en) | – |
| Hálózat | **nincs** | privacy-first: V0-ban egyetlen byte health adat sem hagyja el az eszközt |

**Teszt-abasztrakció:** minden HealthKit hozzáférés egy `HealthDataSource` protokoll mögött → unit tesztben fixture-öket adunk be.

---

## 2. Projektarchitektúra

```
TraceLogic/                              (repó gyökér — minden ide kerül)
├─ project.yml                           XcodeGen spec (app target neve/bundle ID-ja)
├─ project.config.json                   projektnév + bundle prefix (rename script forrása)
├─ scripts/
│  ├─ rename-project.ps1 / .sh
│  ├─ bootstrap-mac.sh   build-mac.sh
├─ docs/
│  ├─ v0-plan.md                         (ez a fájl)
│  ├─ metric-findings.md                 ← V0 fő leszállítandó
│  ├─ test-matrix.md
│  └─ mac-build-workflow.md
├─ App/                                  iOS app target (iOS-specifikus)
│  ├─ Sources/
│  │  ├─ App/            TraceLogicApp, RootView, Branding
│  │  ├─ HealthKit/      HealthKitAdapter (actor, HealthDataSource impl), MetricCatalog+HealthKit
│  │  ├─ Sync/           SyncCoordinator (backfill, anchored sync, observers), SyncLog
│  │  ├─ Store/          SwiftData @Model típusok, MetricStore
│  │  └─ Features/
│  │     ├─ Dashboard/   MetricDetail/  Sleep/  Workouts/  DataInspector/  Debug/
│  ├─ Resources/         (Info.plist ide generálódik)
│  ├─ Support/           (App.entitlements ide generálódik)
│  └─ Tests/
└─ Packages/
   └─ HealthCore/                        tiszta Swift, ZÉRÓ HealthKit import — Windows-on tesztelhető
      ├─ Package.swift
      ├─ Sources/HealthCore/
      │  ├─ MetricType, MetricSample, MetricUnit
      │  ├─ SampleGapAnalyzer            (kész — lásd 7. szakasz)
      │  ├─ DailyAggregator              (jön)
      │  ├─ SleepSessionBuilder          (jön)
      │  └─ Export/ (JSON, CSV)          (jön)
      └─ Tests/HealthCoreTests/
```

**Rétegek / adatfolyam V0-ban:**

```
HKHealthStore
  ↓  HealthKitAdapter (actor)            — nyers HKSample → HealthCore.MetricSample
  ↓  SyncCoordinator                     — backfill / anchored incremental / observer
  ↓  MetricStore (SwiftData)             — dedup hkUUID alapján, napi aggregátumok
  ↓  Feature Model-ek (@Observable)      — a store-ból olvasnak, offline is
  ↓  SwiftUI View-k
```

A `HealthCore` sosem importál HealthKitet – csak sima value type-okat kap. Ez a határ teszi olcsóvá a jövőbeli Health Connect / Garmin adaptert és a Windows-os unit tesztelést.

---

## 3. HealthKit jogosultságok és konfiguráció

### Capability (a `project.yml` már tartalmazza)
- **HealthKit** entitlement
- **Background Delivery** → `com.apple.developer.healthkit.background-delivery` (enélkül az `enableBackgroundDelivery()` hibázik)

### Info.plist (a `project.yml`-ből generálódik)
| Kulcs | Kell? | Megjegyzés |
|---|---|---|
| `NSHealthShareUsageDescription` | **Igen** (olvasás) | szövege a `project.yml`-ben — egy helyen, átnevezés-barát |
| `NSHealthUpdateUsageDescription` | **Nem** – V0 csak olvas | – |

### Kód
```swift
guard HKHealthStore.isHealthDataAvailable() else { /* nem támogatott eszköz */ }
try await healthStore.requestAuthorization(toShare: [], read: MetricCatalog.allReadTypes)
```
- **Egyetlen** jogosultságkérés az onboardingban, a teljes olvasási halmazra (`MetricType.v0ReadSet`).
- **Fontos korlát:** olvasási típusoknál a rendszer **nem árulja el**, engedélyezve van-e vagy megtagadva – üres eredmény = „megtagadva VAGY nincs adat". `authorizationStatus(for:)` olvasásnál nem használható; `getRequestStatusForAuthorization(...)` csak azt mondja meg, kell-e még prompt. Az UI ezt feltételezi minden metrikánál.

---

## 4. HealthKit datatype lista (V0 célhalmaz)

Forrás: ⌚ = Apple Watch, 📱 = iPhone is. Cadence = *tapasztalati* nagyságrend, a V0-ban méréssel pontosítod (`metric-findings.md`).

### Quantity types

| MetricType (HealthCore) | HKQuantityTypeIdentifier | Unit | Forrás | Tapasztalati cadence | Megjegyzés |
|---|---|---|---|---|---|
| heartRate | `.heartRate` | count/min | ⌚ | edzés ~5 s, nyugalom ~5–10 perc (adaptív) | `HKMetadataKeyHeartRateMotionContext` (sedentary/active) |
| restingHeartRate | `.restingHeartRate` | count/min | ⌚ (derivált) | 1/nap | – |
| heartRateVariabilitySDNN | `.heartRateVariabilitySDNN` | ms | ⌚ | szórványos, főleg éjszaka + Breathe; pár/nap | – |
| walkingHeartRateAverage | `.walkingHeartRateAverage` | count/min | ⌚ | ~1/nap | – |
| heartRateRecoveryOneMinute | `.heartRateRecoveryOneMinute` | count/min | ⌚ | **ritka** – megfelelő intenzitású edzés után (iOS 16+) | Health: „Cardio Recovery" |
| oxygenSaturation | `.oxygenSaturation` | % (0–1 tört, ×100) | ⌚ | háttér periodikus + kézi | **elérhetőség modell/régió/OS függő** – 12. szakasz |
| respiratoryRate | `.respiratoryRate` | count/min | ⌚ | alvás közben | – |
| vo2Max | `.vo2Max` | mL/(kg·min) | ⌚ | **ritka** – kültéri séta/futás/túra, GPS+HR | metadata: `HKMetadataKeyVO2MaxTestType` |
| stepCount | `.stepCount` | count | ⌚+📱 | sok/nap, háttér ~óránként | kumulatív |
| distanceWalkingRunning | `.distanceWalkingRunning` | m | ⌚+📱 | mint a lépés | – |
| activeEnergyBurned | `.activeEnergyBurned` | kcal | ⌚ | aktivitás alatt sűrű | Move gyűrű |
| basalEnergyBurned | `.basalEnergyBurned` | kcal | ⌚ | rendszeres | – |
| appleExerciseTime | `.appleExerciseTime` | min | ⌚ | napi | Exercise gyűrű |
| appleStandTime | `.appleStandTime` | min | ⌚ | napi | – |
| bodyMass | `.bodyMass` | kg | manuális / mérleg | szórványos | ha van adat |

### Category type

| MetricType | HKCategoryTypeIdentifier | Értékek | Forrás | Megjegyzés |
|---|---|---|---|---|
| sleepAnalysis | `.sleepAnalysis` | `HKCategoryValueSleepAnalysis`: `.inBed`, `.awake`, `.asleepUnspecified`, `.asleepCore`, `.asleepDeep`, `.asleepREM` | ⌚ (órával aludva, watchOS 9+) / 📱 / 3rd party | `asleepCore/Deep/REM` = iOS 16+; régi `.asleep` deprecated → `.asleepUnspecified`. Egy éjszaka = sok szegmens, több forrásból → dedup kell |

### Workouts

- `HKWorkoutType.workoutType()` → `HKWorkout`, `HKWorkoutActivityType`.
- Időtartam: `workout.duration`. **`HKWorkout.totalEnergyBurned` / `totalDistance` deprecated iOS 18** → `workout.statistics(for:)` / `allStatistics`.
- Per-workout pulzus: `HKStatisticsQuery` a `.heartRate`-re `HKQuery.predicateForObjects(from: workout)` prediká­tummal.

### Series (V0-ban csak feltérképezés)

- `HKHeartbeatSeriesSample` – beat-to-beat, ritka. `HKElectrocardiogram` – csak kézi EKG.

---

## 5. Adatmodell (SwiftData `@Model`, az App rétegben)

```swift
@Model final class StoredSample {
    @Attribute(.unique) var hkUUID: String     // HKObject.uuid.uuidString — dedup kulcs
    var typeRaw: String                        // MetricType.rawValue
    var value: Double                          // HealthCore unitban
    var unitRaw: String
    var start: Date
    var end: Date
    var sourceName: String
    var sourceBundleID: String
    var deviceName: String?
    var motionContext: Int?                    // csak heartRate
    var metadataJSON: String?
}

@Model final class StoredDailyStat {
    var day: Date                              // helyi éjfél
    var typeRaw: String
    var minValue: Double?
    var maxValue: Double?
    var avgValue: Double?
    var sumValue: Double?
    var sampleCount: Int
}

@Model final class StoredWorkout {
    @Attribute(.unique) var hkUUID: String
    var activityRaw: Int
    var start: Date
    var end: Date
    var duration: TimeInterval
    var activeEnergyKcal: Double?
    var distanceMeters: Double?
    var avgHR: Double?
    var maxHR: Double?
    var minHR: Double?
    var sourceName: String
}

@Model final class StoredSleepSession {
    var nightOf: Date                          // "alvás-nap" (dél→dél anchor)
    var inBedStart: Date?
    var inBedEnd: Date?
    var segmentsJSON: String                   // [{stageRaw, start, end, sourceBundleID}]
    var totalAsleep: TimeInterval
    var coreSec: TimeInterval
    var deepSec: TimeInterval
    var remSec: TimeInterval
    var awakeSec: TimeInterval
    var primarySource: String
}

@Model final class SyncState {
    @Attribute(.unique) var typeRaw: String
    var anchorData: Data?                      // HKQueryAnchor archívum
    var lastRunAt: Date?
    var lastSampleEnd: Date?
}

@Model final class SyncLogEntry {
    var typeRaw: String
    var syncedAt: Date
    var newestSampleEnd: Date
    var latencySeconds: Double                 // syncedAt - newestSampleEnd
    var newCount: Int
    var trigger: String                       // "foreground" | "observer" | "backfill"
}
```

`HealthCore` value type-ok (kész / jön): `MetricType`, `MetricUnit`, `MetricSample`, `MotionContext`, `GapStats`; jön: `DailyStat`, `SleepStage`, `SleepSegment`, `SleepSession`.

---

## 6. Lekérdezési stratégia

| Cél | API | Részletek |
|---|---|---|
| **Historikus backfill** (kézi) | `HKAnchoredObjectQuery` típusonként, `predicate` = utolsó 90 nap, `limit: 10_000`, ciklusban | HR akár tízezres → lapozz; a végső anchort `SyncState`-be |
| **Inkrementális szinkron** | `HKAnchoredObjectQuery` a tárolt anchorral, app foreground-kor | `updateHandler` amíg él az app; anchor mentése minden batch után |
| **Napi aggregátumok** | `HKStatisticsCollectionQuery`, `anchorDate` = helyi éjfél, 1 napos intervallum | kumulatív → `.cumulativeSum`; diszkrét → `[.discreteAverage, .discreteMin, .discreteMax]` |
| **Alvás** | `HKSampleQuery` a `.sleepAnalysis`-re → `SleepSessionBuilder` | „alvás-nap" (dél→dél) csoportosítás; több forrás átfedő szegmensei → Apple Watch preferálása, dedup |
| **Edzések** | `HKSampleQuery(sampleType: .workoutType())`; per workout `HKStatisticsQuery` a `.heartRate`-re | energia: `workout.statistics(for:)` (nem a deprecated property) |
| **Observer + háttér** | `HKObserverQuery` (`.heartRate`, `.sleepAnalysis`, `.stepCount`) + `enableBackgroundDelivery(.hourly)` | callbackben anchored szinkron + `completionHandler`. **Megbízhatatlan** – 12. szakasz; V0-ban mérési kísérlet |
| **Forrás-feltérképezés** | `HKSourceQuery` | bundle ID-k tárolása; Inspectorban „csak Apple Watch" szűrő |

---

## 7. Mintavételi gyakoriság ellenőrzése

Ez a V0 magja. **Számokkal** dokumentálni, mit ad *a te órád*.

### `SampleGapAnalyzer` — **kész** (`Packages/HealthCore`, unit-tesztelt, Windows-on fut)
Bemenet: `[MetricSample]` + `DateInterval` ablak. Kimenet `GapStats`:
- minta-szám, lefedett időtartam, **lefedettség %**
- rések: **medián, p10, p90, max**
- minta/óra
- **forrásonkénti** bontás (`countBySource`)

Következő bővítés: motion-context szerinti bontás HR-nél.

### `DataInspectorView` (App)
- választó: metrika + időablak (1/7/28 nap) + forrásszűrő
- `GapStats` + **idővonal-sáv** (Swift Charts) + nyers lista (időbélyeg, érték, forrás, eszköz, hossz, motion context, metadata)
- alvásra: **hypnogram** + fázis-összegek + forrás
- edzésre: HR-minták sűrűsége az edzésen belül

### Késleltetés-mérés
Minden szinkronnál `SyncLogEntry`: `syncedAt - newestSampleEnd`. Pár nap alatt kirajzolódik típusonként a tipikus latencia.

### Leszállítandó: `docs/metric-findings.md` (sablon már megvan)

---

## 8. Minimális UI (V0)

Rendszerkomponensek, nulla dizájn-csiszolás.

1. **PermissionGate** – magyarázó + „Csatlakozás az Apple Health-hez" → `requestAuthorization` → Dashboard.
2. **DashboardView** – `MetricCard` lista: név, legfrissebb érték + unit, relatív időbélyeg, forrás-badge (⌚/📱), 7 napos sparkline. Külön „Nincs adat / nem elérhető" szekció.
3. **MetricDetailView** – 7/28/90 nap kapcsoló; Swift Chart; napi min/átlag/max; nyers minták listája; „Megnyitás a Data Inspectorban".
4. **DataInspectorView** – lásd 7.
5. **SleepView** – tegnap éjszakai hypnogram + fázis-összegek; korábbi alvások.
6. **WorkoutsView** – edzéslista → detail HR-grafikonnal.
7. **DebugView** – `isHealthDataAvailable`, request status, forráslista, DB rekordszámok, utolsó szinkronidők; gombok: Backfill, Inkrementális szinkron, DB törlése, Export JSON/CSV.

---

## 9. Fejlesztési lépések sorrendben

### A – váz  *(részben kész)*
1. ✅ Repó-struktúra, `project.yml` (XcodeGen), `project.config.json`, rename scriptek, `HealthCore` package váz + első tesztek.
2. ⬜ **Windows:** `cd Packages/HealthCore && swift test` — zöld.
3. ⬜ **Mac:** `./scripts/bootstrap-mac.sh` → `xcodegen generate` → üres app fut a saját iPhone-odon (RootView placeholder).

### B – olvasási út
4. `MetricCatalog+HealthKit` (App): `MetricType` ↔ `HKObjectType` leképezés, `allReadTypes`.
5. `HealthDataSource` protokoll (HealthCore) + `HealthKitAdapter` actor (App): `isAvailable`, `requestAuthorization`, `latestSample(for:)`, `samples(for:start:end:)`.
6. `PermissionGate` + `DashboardView` a legfrissebb mintával típusonként. **Ellenőrzés eszközön a Health app ellen.**

### C – történet & aggregátumok
7. `statisticsCollection(...)` az adapterben + `DailyAggregator` (HealthCore, tesztelt) + `MetricDetailView` grafikonnal.
8. Perzisztencia: SwiftData modellek + `MetricStore`; a UI a store-ból olvas; offline újraindítás.
9. `SyncCoordinator.backfill()` – 90 napos pull, lapozva; progressz a Debug képernyőn.

### D – strukturált metrikák
10. `SleepSessionBuilder` (HealthCore, tesztelt) + `SleepView`.
11. Edzés-lekérdezés + per-workout HR + `WorkoutsView`.

### E – inspekció
12. `DataInspectorView` (idővonal + `GapStats` + nyers lista) — a `SampleGapAnalyzer` már kész.
13. `SyncLog` latencia-követés; megjelenítés az Inspectorban.

### F – szinkron & háttér
14. `HKAnchoredObjectQuery` inkrementális + anchor perzisztencia; foreground-kor fut.
15. `HKObserverQuery` + `enableBackgroundDelivery` HR/alvás/lépés-re; minden ébredés logolva; valós cadence mérése pár napon át.

### G – export & keményítés
16. JSON + CSV export share sheettel (`HealthCore/Export`).
17. Üres / hiba / megtagadva állapotok; „tegnap nem volt óra"; unit-eltérések; időzóna.
18. `docs/metric-findings.md` kitöltése valós adatból.

---

## 10. Tesztelési terv

### Unit (HealthCore, HealthKit nélkül, **Windows-on is fut**)
- **`SampleGapAnalyzer`** ✅ – egyenletes; rések; egyetlen minta; üres; átfedő; több forrás; (jön: DST-határ).
- **`SleepSessionBuilder`** – egy tiszta éjszaka; töredezett; több forrás átfedéssel; szundi vs fő alvás; dél–dél határ; csak `asleepUnspecified`.
- **`DailyAggregator`** – bucket-határok; éjfél/időzóna; kumulatív vs diszkrét; üres napok.
- **`MetricType`** ✅ – minden típusnak van unitja; kumulatív/diszkrét besorolás; V0 read set.

### Contract-teszt (App)
- `HealthDataSource` in-memory fake, ami **egyszer rögzített valós HK-payloadokat** játszik vissza (exportáld a saját eszközödről).

### Integráció (eszközön, kézi mátrix – `docs/test-matrix.md`)
- Friss telepítés; részleges/teljes engedély-megtagadás; repülő üzemmód; összevetés a Health appal fix napra; órával/óra nélkül alvás; edzés utáni megjelenés.

### Háttér-kézbesítés
- App háttérben 24–48 óra, ébredési idők logolva, összevetés a `.hourly` elvárással; **valós viselkedés dokumentálva**.

### Szimulátor
- Csak UI-elrendezés + HealthCore tesztek. Adatvalidáció mindig eszközön.

### UI-teszt
- V0-ban nincs automata UI-teszt. Kézi mátrix checklist a repóban, kipipálva.

---

## 11. V0 exit criteria

- [ ] `swift test` zöld a `Packages/HealthCore`-ban (Windows-on is).
- [ ] `xcodegen generate` + build fut a saját iPhone-odon (iOS 17+), párosított Apple Watch-csal.
- [ ] Onboarding a teljes olvasási halmazra kér engedélyt; az app működik, ha bármelyik / az összes típus meg van tagadva (nincs crash, egyértelmű „nincs adat").
- [ ] Minden cél-datatype-ra: vagy él az adat, vagy explicit „nem elérhető ezen az eszközön / OS-en / régióban" jelölés indokkal.
- [ ] A Dashboard legfrissebb értékei kerekítésen belül egyeznek a Health appal: lépés, nyugalmi pulzus, aktív energia, edzésperc, tegnap éjszakai alvás hossza, legutóbbi testsúly.
- [ ] 90 napos backfill lefut és perzisztál; force-quit + repülő üzemmód után a cache-elt történet renderel.
- [ ] Inkrementális anchored szinkron új mintákat ad **nulla duplikátummal** (rekordszám + `hkUUID` egyediség) 3+ futáson át.
- [ ] A Data Inspector **számokkal** jelenti a valós mintavételi cadence-t egy 7 napos ablakra: `heartRate` (nyugalom vs aktív), `heartRateVariabilitySDNN`, `respiratoryRate`, `oxygenSaturation`, alvás-szegmensek.
- [ ] Alvás-session-ök helyesen felépítve 5+ éjszakára (fázis-összegek pár percen belül a Health apphoz képest).
- [ ] Edzéslista egyezik a Health appal az utolsó 90 napra; per-workout átlag/max HR megvan.
- [ ] JSON + CSV export offline elemzésre nyitható fájlokat ad; a séma dokumentálva.
- [ ] **`docs/metric-findings.md` kitöltve** – ez a fő tudás-leszállítandó.
- [ ] A kézi teszt-mátrix végrehajtva és rögzítve.
- [ ] Egyetlen byte health adat sem hagyja el az eszközt – hálózati hívás nincs (Proxyman / hálózat-tiltás ellenőrzés).

**Explicit V0-n kívül:** baseline engine, score-ok, AI briefing, backend, más platformok, HealthKit write-back, értesítések, widget, fiók/auth.

---

## 12. Bizonytalanságok / ellenőrizendő állítások

| # | Állítás | Státusz |
|---|---|---|
| 1 | HealthKit capability free personal team-mel: on-device fejlesztéshez általában megy; disztribúció/TestFlight fizetős programot igényel. | **Ellenőrizd provisioning-nél.** |
| 2 | Háttér-kézbesítés gyakorisága *best-effort*, eszközönként/OS-enként **empirikusan inkonzisztens** (óránkénti plafon vs ~10–15 perc; force-quit után leállhat). Csak fizikai eszközön. | **Megerősítve** (Apple docs + fejlesztői fórumok). V0-ban kísérlet. |
| 3 | `oxygenSaturation` elérhetősége óramodell + régió + OS függő: **US Series 9/10/Ultra 2** csak **iOS 18.6.1 / watchOS 11.6.1** (2025. aug.) óta kapta vissza, a számítás átkerült az iPhone-ra (Health „Respiratory"). Series 6–8/Ultra változatlan. | **Megerősítve.** Ellenőrizd, hogy a te órád termel-e SpO₂-t. |
| 4 | `HKWorkout.totalEnergyBurned` / `totalDistance` **deprecated iOS 18** → `statistics(for:)` / `allStatistics`. | **Megerősítve.** |
| 5 | Részletes alvásfázisok watchOS 9+ és ténylegesen órával aludva; óra nélkül → `asleepUnspecified` vagy semmi. | **Megerősítve** (WWDC22). |
| 6 | `vo2Max`, `heartRateRecoveryOneMinute` természetüknél fogva ritkák – pár napos hiány nem bug. | **Megerősítve.** |
| 7 | SwiftData V0 méretre elég; ha V0.2 felé migrációs/perf fájdalom jön, a `MetricStore` cserélhető GRDB-re. | Tervezési döntés. |
| 8 | Olvasási jogosultság státusza **tervezetten nem lekérdezhető** – „megtagadva" és „nincs adat" nem különböztethető meg. | **Megerősítve.** Az UI ezt feltételezi. |
| 9 | XcodeGen a Mac-en kell (`brew install xcodegen`); a `project.yml` a névforrás az app targethez. | Tervezési döntés. Alternatíva: checked-in `.xcodeproj` (nehezebb átnevezni / Windows-on szerkeszteni). |
| 10 | Swift toolchain Windows-on stabilan fordítja a `HealthCore`-t (Foundation, nincs platform-specifikus API). | **Ellenőrizd** az első `swift test`-tel. |

---

## Források

- [walkingHeartRateAverage – Apple Developer](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/walkingheartrateaverage)
- [heartRateVariabilitySDNN – Apple Developer](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn)
- [heartRateRecoveryOneMinute – Apple Developer](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartraterecoveryoneminute)
- [HKCategoryValueSleepAnalysis – Apple Developer](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
- [What's new in HealthKit – WWDC22](https://developer.apple.com/videos/play/wwdc2022/10005/)
- [sleepAnalysis – Apple Developer](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/sleepanalysis)
- [What's the expected frequency of HealthKit enableBackgroundDelivery – Apple Developer Forums](https://developer.apple.com/forums/thread/790004)
- [Unable to receive HealthKit updates when app is force-quit – Apple Developer Forums](https://developer.apple.com/forums/thread/803365)
- [Abnormal Background Delivery Frequency of HealthKit on Specific watchOS Devices – Apple Developer Forums](https://developer.apple.com/forums/thread/814914)
- [An update on Blood Oxygen for Apple Watch in the U.S. – Apple Newsroom (2025-08-14)](https://www.apple.com/newsroom/2025/08/an-update-on-blood-oxygen-for-apple-watch-in-the-us/)
- [Apple Watch blood-oxygen feature returns in iOS 18.6.1 – Macworld](https://www.macworld.com/article/2878472/the-apple-watch-blood-oxygen-sensor-is-coming-back-to-series-9-10-and-ultra-2-users.html)
- [XcodeGen – project.yml dokumentáció](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md)
- [Swift on Windows – telepítés](https://www.swift.org/install/windows/)
