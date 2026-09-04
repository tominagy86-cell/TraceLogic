# TraceLogic – build útmutató (ha valaki más Mac-jét használjuk)

Ez az útmutató annak szól, aki **kölcsönadja a Mac-jét**, hogy ráépítsük és a fejlesztő
(Nagy Tamás) iPhone-jára telepítsük a `TraceLogic` iOS appot. Nem kell Swift-et tudni hozzá —
minden lépés másolható parancs.

**Amire szükség van:**
- Mac, macOS Sequoia (15) vagy újabb, ~15 GB szabad hely
- Apple ID (a sajátod is jó — ingyenes, nem kell fizetős Developer Program)
- Tamás iPhone-ja + a hozzá tartozó kábel
- kb. 30–45 perc (a Visual Studio-szerű Xcode-telepítés hosszú, de csak egyszer kell)

---

## 1. Xcode telepítése

App Store → keresd meg az **Xcode**-ot → Telepítés (~10 GB, sokáig tart).

Első indításkor fogadd el a licencet, és ha kéri, telepítsd a „Command Line Tools"-t is.

## 2. Homebrew telepítése

Nyisd meg a **Terminal**-t (Launchpad → Terminal), és illeszd be:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Kövesd a végén kiírt utasításokat, ha kéri a PATH beállítását (copy-paste-elhető parancsokat ad).

## 3. A projekt letöltése

```bash
git clone https://github.com/tominagy86-cell/TraceLogic.git
cd TraceLogic
```
(A repó nyilvános, nem kell hozzá GitHub-fiók vagy jelszó.)

## 4. Build előkészítése

```bash
./scripts/bootstrap-mac.sh
```
Ez telepíti az `xcodegen`-t, legenerálja a projektet, lefuttat pár tesztet, és **megnyitja az Xcode-ot**.

## 5. Aláírás beállítása Xcode-ban

Az Xcode bal oldali listájában kattints a legfelső **TraceLogic** projekt-ikonra →
**Signing & Capabilities** fül → a **Team** legördülőnél válaszd a saját Apple ID-dat.

Ha nincs benne a listában: Xcode menü → **Settings… → Accounts → „+"** → jelentkezz be a saját
Apple ID-ddal (ingyenes, nem kell fizetős fiók).

## 6. Az iPhone csatlakoztatása

- Kösd össze Tamás iPhone-ját a Mac-kel a kábellel.
- Az iPhone-on nyomd meg: **„Megbízom ebben a számítógépben"** (ha kéri a jelkódot, azt Tamás tudja).
- Az Xcode ablak tetején, a Play (▶) gomb mellett lévő legördülőben válaszd ki a **csatlakoztatott iPhone-t** (ne szimulátort).

## 7. Build + telepítés

Nyomj **Cmd+R**-t (vagy a ▶ gombot).

Az első build eltarthat pár percig. Ha végzett, az app megpróbál elindulni az iPhone-on, de:

> **„Untrusted Developer" / „Nem megbízható fejlesztő"** üzenet jön az iPhone-on.

Ez ilyenkor normális. Az iPhone-on: **Beállítások → Általános → VPN és eszközkezelés** →
a fejlesztői profilodnál → **„Megbízom"**. Utána nyisd meg újra az appot az iPhone-on (vagy Cmd+R
Xcode-ban).

## 8. Kész

Az app fut az iPhone-on. Mivel ingyenes Apple ID-vel van aláírva, **7 nap után lejár** — utána
újra kell futtatni a Cmd+R-t (Mac-kel), hogy tovább menjen. Ez a fejlesztési fázisban rendben van.

---

## Ha hibát dob a build

Ne próbáld megjavítani — **másold ki a hibaüzenetet** (Xcode jobb oldali panel, piros háromszögek),
és küldd el Tamásnak. A kódot ő (és Claude) fogja javítani, majd `git pull` után újra próbálod
az 4–7. lépéseket.

## Amire NINCS szükséged

- GitHub fiók / jelszó (a repó publikus, csak olvasásra kell)
- Fizetős Apple Developer Program ($99/év) — csak App Store megjelenéshez kellene, futtatáshoz nem
- Swift/Xcode ismeret
