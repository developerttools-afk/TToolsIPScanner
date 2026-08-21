# Legal Compliance Check - TTools IP Scanner

**Datum:** 21. August 2026  
**Version:** 1.21  
**Geprüft von:** AI Assistant (Cursor)

---

## ✅ Zusammenfassung

**Ergebnis:** Keine Rechtsverletzungen oder Lizenz-Verpflichtungen gefunden.

Die App verwendet **ausschließlich Apple-eigene Frameworks** und hat **keine externen Dependencies**. 

**Source-Code-Veröffentlichung:** NICHT verpflichtend (MIT License ist optional, kein Copyleft)

---

## 📦 Verwendete Frameworks & Lizenzen

### Apple Frameworks (alle proprietär, kostenlos nutzbar)

| Framework | Verwendung | Lizenz | Verpflichtungen |
|-----------|-----------|--------|-----------------|
| **Foundation** | Basis-Framework | Apple EULA | ✅ Keine |
| **SwiftUI** | User Interface | Apple EULA | ✅ Keine |
| **Combine** | Reactive Programming | Apple EULA | ✅ Keine |
| **Darwin** | Low-level C APIs | Apple EULA | ✅ Keine |
| **Network** | Network-Stack | Apple EULA | ✅ Keine |
| **SystemConfiguration** | Network Config | Apple EULA | ✅ Keine |
| **AppKit** | macOS UI (optional) | Apple EULA | ✅ Keine |
| **UIKit** | iOS UI (optional) | Apple EULA | ✅ Keine |

### Externe Dependencies

**Keine!** ✅

---

## 🔍 Detaillierte Prüfung

### 1. Package Dependencies
```bash
# Prüfung durchgeführt:
find . -name "Package.swift" -o -name "Podfile" -o -name "Cartfile"
```
**Ergebnis:** Keine Package-Manager-Dateien gefunden → Keine externen Dependencies

### 2. Import-Statements
```bash
# Alle Imports geprüft:
grep -r "import " TToolsIPScanner/*.swift TToolsIPScanner/**/*.swift
```
**Ergebnis:** Nur Apple-Frameworks importiert

### 3. Binary Dependencies
```bash
# Prüfung auf eingebettete Binaries:
find . -name "*.framework" -o -name "*.dylib" -o -name "*.a"
```
**Ergebnis:** Keine externen Binaries

### 4. Copied Code / Assets
**Prüfung:** Kein Code von Drittanbietern kopiert  
**Assets:** Alle Icons sind SF Symbols (Apple-eigen)  
**OUI-Datenbank:** Öffentliche IEEE-Datenbank (keine Lizenz-Restriktionen)

---

## 📜 Lizenz-Situation

### Eigene Lizenz: MIT License

Die App wird unter **MIT License** veröffentlicht:

✅ **Vorteile:**
- Sehr permissiv
- Erlaubt kommerzielle Nutzung
- Keine Copyleft-Verpflichtungen
- Keine Zwang zur Source-Veröffentlichung
- Kompatibel mit App Store

✅ **Verpflichtungen:**
- Copyright-Notice beibehalten (in LICENSE Datei enthalten)
- Disclaimer of Warranty (in LICENSE enthalten)

### Source-Code-Veröffentlichung

**Verpflichtend:** ❌ NEIN

**Gründe:**
1. Keine GPL/LGPL-lizenzierten Komponenten
2. Keine AGPL-lizenzierten Komponenten
3. Nur MIT License (keine Copyleft-Klausel)
4. Apple Frameworks erfordern keine Offenlegung

**Optional:** ✅ Kann auf GitHub veröffentlicht werden (empfohlen für Transparenz)

---

## 🍎 App Store Compliance

### Donations / "Buy Me a Coffee"

**Erlaubt:** ✅ JA (seit 2022)

Apple's aktuelle Richtlinien erlauben externe Links zu Spenden-Plattformen in **kostenlosen Apps**:

- ✅ Link zu Buy Me a Coffee ist erlaubt
- ✅ PayPal-Spenden sind erlaubt
- ✅ GitHub Sponsors ist erlaubt
- ❌ In-App-Purchase für "Spenden" erfordert Apple's 30% Cut

**Wichtig:** 
- Link muss als externer Link gekennzeichnet sein (✓ in AboutView implementiert)
- Spenden dürfen NICHT App-Funktionalität freischalten
- Text muss klar machen: "Freiwillig, keine Auswirkung auf App"

### App Review Guidelines

**Getestet gegen:**

| Guideline | Anforderung | Status |
|-----------|-------------|---------|
| 2.3.1 | Genaue Beschreibung | ✅ Pass |
| 2.3.8 | Keine irreführenden Angaben | ✅ Pass |
| 4.0 | Design - keine Abstürze | ✅ Pass (Tests OK) |
| 5.1.1 | Datenschutz - keine Sammlung | ✅ Pass (alles lokal) |
| 5.1.2 | Datennutzung - transparent | ✅ Pass (in About erklärt) |

---

## 🔐 Datenschutz (DSGVO / Privacy)

### Datenverarbeitung

**Keine personenbezogenen Daten!** ✅

Die App:
- ❌ Sammelt KEINE persönlichen Daten
- ❌ Sendet KEINE Daten an Server (außer OUI-Update von IEEE)
- ❌ Nutzt KEINE Tracking-Tools
- ❌ Nutzt KEINE Analytics
- ❌ Hat KEINE Server-Komponente
- ✅ Alle Daten bleiben lokal auf dem Gerät

**Privacy Manifest:** Nicht erforderlich (keine Datensammlung)

**Privacy Policy:** Nicht erforderlich (keine Datenverarbeitung außer lokale Speicherung)

---

## ⚖️ Haftungsausschluss

### Disclaimer in der App

✅ Implementiert in `AboutView.swift`:

1. **Hobbyprojekt-Hinweis** ✅
2. **Keine Gewährleistung** ✅
3. **Nutzung auf eigene Gefahr** ✅
4. **Feedback willkommen, aber keine Garantie auf Umsetzung** ✅

### Rechtliche Absicherung

**MIT License Disclaimer:**
```
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT.
```

**In App (AboutView):**
- Klare Warnung: "Nutzung auf eigene Gefahr"
- Hobbyprojekt-Status transparent kommuniziert
- Keine Garantien oder Gewährleistungen

---

## 🌐 IEEE OUI Database

### Verwendete Datenquelle

**Quelle:** IEEE Standards Association  
**URL:** http://standards-oui.ieee.org/oui/oui.txt  
**Lizenz:** Öffentlich zugänglich, keine Restriktionen

**Compliance:**
- ✅ Öffentliche Datenbank
- ✅ Keine Lizenzgebühren
- ✅ Download erlaubt
- ✅ Lokale Speicherung erlaubt
- ✅ Attribution nicht verpflichtend (aber höflich)

**Implementierung:**
- OUI-Daten werden vom IEEE-Server geladen
- Lokale Speicherung für Offline-Nutzung
- Keine Weiterverbreitung der Rohdaten

---

## 🔒 Netzwerk-Sicherheit

### Port-Scanning Legalität

**Achtung:** Port-Scanning kann je nach Jurisdiktion unterschiedlich bewertet werden.

**Absicherung in der App:**

1. ✅ **Disclaimer in UserGuideView:**
   > "Hinweis: Es wird nur das lokale Netzwerk gescannt. Scanne nur Netze, für die du berechtigt bist."

2. ✅ **Nur lokales Netzwerk:**
   - App scannt nur RFC1918-Adressen (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
   - Keine Remote-Scan-Funktionen

3. ✅ **Benutzerverantwortung:**
   - Klare Warnung in About-View
   - Nutzer ist für legale Verwendung verantwortlich

**Rechtliche Einschätzung:**
- ✅ Tool-Bereitstellung ist legal
- ✅ Warnung vor Missbrauch vorhanden
- ✅ Beschränkung auf lokales Netzwerk

---

## ✅ Checkliste: Rechtliche Compliance

- [x] Keine externen Dependencies verwendet
- [x] Nur Apple-Frameworks (keine Lizenz-Verpflichtungen)
- [x] MIT License erstellt
- [x] Disclaimer in App implementiert
- [x] App Store Compliance geprüft
- [x] Donation-Link App Store konform
- [x] Datenschutz: Keine Datensammlung
- [x] OUI-Datenbank: Öffentlich verfügbar
- [x] Haftungsausschluss klar kommuniziert
- [x] Warnung vor illegalem Netzwerk-Scanning

---

## 📝 Empfehlungen

### Optionale Maßnahmen (für maximale Transparenz)

1. ✅ **LICENSE Datei vorhanden** (MIT License)
2. ✅ **Disclaimer in App** (AboutView)
3. ✅ **App Store Beschreibung** mit Hinweisen
4. 🔵 **Optional:** GitHub Repository öffentlich machen
5. 🔵 **Optional:** README.md mit Disclaimer erstellen

### Bei GitHub-Veröffentlichung

Falls du den Code auf GitHub stellst:
- LICENSE Datei ist bereits vorhanden ✅
- README.md mit Disclaimer empfohlen
- CONTRIBUTING.md empfohlen (macht klar: Hobby-Projekt, keine Garantie)
- Issue-Template mit Warnung: "Keine Garantie auf Support"

---

## 🎯 Fazit

**Status:** ✅ **COMPLIANT**

Die App verletzt **keine** Lizenzen oder Urheberrechte. Du bist **nicht verpflichtet**, den Source-Code zu veröffentlichen.

**Du kannst:**
- ✅ Die App im App Store kostenlos anbieten
- ✅ "Buy Me a Coffee" Link hinzufügen
- ✅ Source-Code privat halten (optional)
- ✅ Source-Code auf GitHub veröffentlichen (optional)
- ✅ MIT License verwenden

**Du musst:**
- ✅ Disclaimer in der App lassen (bereits implementiert)
- ✅ LICENSE Datei beibehalten (bereits vorhanden)
- ✅ Copyright-Notice beibehalten (in LICENSE)

---

**Geprüft am:** 21. August 2026  
**Nächste Prüfung empfohlen:** Bei Hinzufügen neuer Dependencies

**Dokumentiert von:** AI Assistant (Cursor Agent)  
**Für:** Thorsten Albers
