# V0 kézi teszt-mátrix

Minden kölcsön-Mac session-nél végigmenni. Dátum / build: _______

## Jogosultság

- [ ] Friss telepítés → onboarding a teljes olvasási halmazra kér engedélyt
- [ ] Mindent engedélyezve → minden képernyő feltöltődik
- [ ] Részleges engedély (HRV megtagadva) → HRV „nincs adat", nincs crash
- [ ] Minden megtagadva → app nem omlik össze, értelmes üres állapot
- [ ] „Health engedélyek megnyitása" gomb a Beállításokba visz

## Adathelyesség (összevetés a Health appal, fix napra: ______)

- [ ] Lépésszám (≈ pontos): app ____ / Health ____
- [ ] Aktív energia (±): app ____ / Health ____
- [ ] Nyugalmi pulzus (pontos): app ____ / Health ____
- [ ] HR napi átlag (±1–2 bpm): app ____ / Health ____
- [ ] Alvás összes hossz (±pár perc): app ____ / Health ____
- [ ] Tegnap éjszakai fázisok (core/deep/rem): egyeznek? ____
- [ ] Legutóbbi testsúly: app ____ / Health ____

## Történet / perzisztencia

- [ ] 90 napos backfill lefut (idő: ____)
- [ ] Force-quit + repülő üzemmód → cache-elt történet renderel
- [ ] Inkrementális szinkron 3× → nulla duplikátum (rekordszám: ____ / ____ / ____)

## Alvás / edzés

- [ ] Órával aludva 1 éjjel → session helyes
- [ ] Óra nélkül 1 éjjel → nem hamis adat
- [ ] Edzés után pár perccel → megjelenik HR-rel
- [ ] Edzéslista egyezik a Health appal (90 nap)

## Data Inspector

- [ ] heartRate cadence (nyugalom vs aktív) számmal megjelenik
- [ ] HRV SDNN cadence
- [ ] respiratoryRate cadence
- [ ] oxygenSaturation cadence (vagy „nincs adat" indokkal)
- [ ] alvás-szegmensek idővonala

## Háttér / hálózat

- [ ] App 24–48h háttérben → observer ébredések logolva (tényleges gyakoriság: ____)
- [ ] Proxyman/hálózat-tiltás: **nulla** kimenő health adat

## Export

- [ ] JSON export nyitható, séma dokumentált
- [ ] CSV export nyitható
