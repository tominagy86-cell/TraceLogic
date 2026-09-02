# Metric Findings — mit ad ténylegesen a saját Apple Watch

> **Ez a V0 fő leszállítandója.** Valós adatból töltsd, a Data Inspector képernyő és az export alapján.
> Eszköz: _(pl. Apple Watch Series X, watchOS X.X)_ · iPhone: _(iOS X.X)_ · Mérési időszak: _____ – _____

## Összefoglaló tábla

| Metrika | Elérhető? | Forrás(ok) | Cadence (medián rés) | Lefedettség | Tipikus latencia | Kvirkek / megjegyzés |
|---|---|---|---|---|---|---|
| heartRate (nyugalom) | | | | | | |
| heartRate (aktív / edzés) | | | | | | |
| restingHeartRate | | | | | | |
| heartRateVariabilitySDNN | | | | | | |
| walkingHeartRateAverage | | | | | | |
| heartRateRecoveryOneMinute | | | | | | ritka – csak edzés után |
| oxygenSaturation | | | | | | modell/régió/OS-függő |
| respiratoryRate | | | | | | főleg alvás közben |
| vo2Max | | | | | | ritka – kültéri kardió |
| stepCount | | | | | | |
| distanceWalkingRunning | | | | | | |
| activeEnergyBurned | | | | | | |
| basalEnergyBurned | | | | | | |
| appleExerciseTime | | | | | | |
| appleStandTime | | | | | | |
| bodyMass | | | | | | manuális / mérleg |
| sleepAnalysis (fázisok) | | | | | | watchOS 9+, órával aludva |

## Részletes jegyzetek metrikánként

### heartRate
- Minta/nap: 
- Nyugalmi medián rés: 
- Edzés alatti rés: 
- Motion context eloszlás (sedentary/active/notSet): 

### heartRateVariabilitySDNN
- Napi mintaszám: 
- Mikor keletkezik (éjszaka / Breathe / egyéb): 

### sleepAnalysis
- Fázisok jönnek-e (core/deep/rem) vagy csak asleepUnspecified: 
- Több forrás? (Watch + iPhone + 3rd party): 
- Eltérés a Health app „alvás összesen"-től: 

### oxygenSaturation
- Termel-e egyáltalán adatot ez az óra/régió/OS: 
- Ha igen: háttér-mintavétel gyakorisága: 

## Következtetések a baseline engine (V0.3) számára
- Mely metrikák elég sűrűek napi baseline-hoz: 
- Melyek csak heti/havi trendre alkalmasak: 
- Hol kell a hiányzó napokat kezelni (imputálás / kihagyás): 
