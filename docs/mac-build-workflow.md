# Kölcsön Apple gép – munkafolyamat

A kódot Windows-on írjuk. Amikor van hozzáférés Apple géphez, ott ellenőrzünk / buildelünk a saját iPhone-ra.

## Egyszeri beállítás a Mac-en

1. **Xcode 16.x** az App Store-ból (macOS Sequoia kell). Első indításkor: `xcodebuild -runFirstLaunch`.
2. **Homebrew**: <https://brew.sh>
3. A repó másolása a Mac-re (git clone, vagy USB/hálózat).
4. A repó gyökerében:
   ```bash
   ./scripts/bootstrap-mac.sh
   ```
   Ez telepíti az `xcodegen`-t, legenerálja a `<Név>.xcodeproj`-t, lefuttatja a HealthCore teszteket és megnyitja az Xcode-ot.
5. Xcode → a target **Signing & Capabilities** fülén válaszd ki a **Team**-et.
   Személyes Apple ID („Personal Team") is elég a saját eszközre telepítéshez.
   A **HealthKit** és **Background Delivery** capability már a `project.yml`-ből jön.

## Minden alkalommal

```bash
git pull                       # legfrissebb kód Windows-ról
./scripts/build-mac.sh sim     # build + teszt szimulátoron (gyors ellenőrzés)
# vagy
./scripts/build-mac.sh device  # build a csatlakoztatott iPhone-ra
```

Majd Xcode-ban: válaszd ki a saját iPhone-t a futtatási célként, **Cmd+R**.

## Fontos korlátok

- **HealthKit valós adat csak fizikai eszközön** van értelmesen. A szimulátorban alig van adat, és a háttér-kézbesítés nem működik → minden adat-validáció a saját iPhone-on.
- A személyes team-mel aláírt build **7 nap** után lejár – újra kell telepíteni. Ez a V0-hoz elég.
- Az `.xcodeproj` gitignore-olt. Soha ne kézzel szerkeszd; mindig `xcodegen generate`.
- Ha a `project.yml` vagy egy forrásmappa változott Windows-on: `xcodegen generate` újra (a `build-mac.sh` ezt megteszi).

## Amit a Mac-en rögzítünk

Minden alkalommal, amikor valós eszközön futtatunk, frissítjük:
- `docs/metric-findings.md` – mit ad ténylegesen az óra (cadence, latencia, kvirkek)
- `docs/test-matrix.md` – kézi tesztek kipipálása
