# TTools IP Scanner

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue.svg" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License">
</p>

Ein schneller, einfacher Netzwerk-Scanner für iOS und macOS. Entwickelt als Hobbyprojekt und kostenlos im App Store verfügbar.

## ✨ Features

- **Blitzschneller Scan**: 254 IPs in ~2 Minuten dank intelligenter Parallelisierung
- **Intelligente Host-Discovery**: Erkennt Geräte auch ohne offene Ports (TCP RST Detection)
- **Port-Scanning**: Custom Ports oder Full Scan Modi
- **MAC-Adresse & Hersteller**: OUI-Datenbank mit IEEE-Update-Funktion
- **DNS-Lookup**: Mit intelligentem Cache für Performance
- **Geräte-Aliase**: Eigene Namen für Geräte vergeben
- **Live-Status**: Echtzeit-Anzeige des Scan-Fortschritts
- **Universal**: Native Apps für iOS und macOS

## 🚀 Performance

**Version 1.31 Optimierungen:**
- **80% schneller**: Von 10+ Minuten auf ~2 Minuten für /24 Netzwerk
- **Intelligente Discovery**: Early Exit bei toten Hosts (0.6s statt 7s)
- **Parallele Scans**: ~50-100 IPs gleichzeitig
- **Optimiertes Timeout**: 0.2s für LAN (typisch <1ms RTT)

## 📱 Installation

Verfügbar im App Store (kostenlos, ohne Werbung, ohne In-App-Käufe):

[🔗 TTools IP Scanner im App Store](#) _(Link folgt nach Veröffentlichung)_

## 🛠️ Technologie

- **Sprache**: Swift 5.9+
- **UI**: SwiftUI
- **Concurrency**: Modern async/await mit TaskGroups
- **Architektur**: MVVM mit Extensions
- **Dependencies**: Keine! Nur Apple-Frameworks

## 🎯 Wie es funktioniert

### Zwei-Phasen-Scan:

**Phase 1: Host Discovery (schnell)**
- Prüft 14 häufige Ports parallel (80, 443, 22, ...)
- Erkennt Hosts per TCP Connect (auch ECONNREFUSED = Host alive!)
- Early Exit: Stoppt bei erstem offenen Port oder nach 3 erfolglosen Versuchen

**Phase 2: Port Scanning (nur gefundene Hosts)**
- Quick Scan: Custom Ports aus Einstellungen
- Full Scan: Custom + Standard-Ports kombiniert
- DNS-Lookup und MAC-Adresse parallel

## ⚠️ Wichtige Hinweise

**Hobbyprojekt**: Privates Projekt, entwickelt für eigene Zwecke und gerne geteilt.

**Keine Gewährleistung**: Nutzung auf eigene Gefahr. Keine Garantie für Funktionalität oder Updates.

**Netzwerk-Berechtigung**: Nur in Netzwerken scannen, für die du berechtigt bist!

**macOS**: App Sandbox ist deaktiviert (erforderlich für Low-Level-Socket-Operationen).

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) Datei.

## 🔗 Links

- **Support**: [https://developerttools-afk.github.io/TToolsIPScanner/support.html](https://developerttools-afk.github.io/TToolsIPScanner/support.html)
- **Datenschutz**: [https://developerttools-afk.github.io/TToolsIPScanner/privacy.html](https://developerttools-afk.github.io/TToolsIPScanner/privacy.html)
- **Buy Me a Coffee**: [https://buymeacoffee.com/developerttools](https://buymeacoffee.com/developerttools) _(freiwillig)_

## 📝 Changelog

### Version 1.31 (Build 2) - August 2026

**Performance-Revolution:**
- ⚡ Scan-Speed um 80% verbessert (2 Min statt 10+ Min)
- 🎯 Host-Discovery findet jetzt auch Geräte ohne offene Ports
- 📊 Live-Status zeigt aktuell gescannte IP
- 🔓 macOS: App Sandbox entfernt für volle Funktionalität
- 🚀 Optimierte Discovery-Strategie mit Early Exit
- 🧹 Buy Me a Coffee Link aus App entfernt (bleibt auf Support-Seite)

### Version 1.30 (Build 11) - August 2026
- Concurrency-Modernisierung (async/await)
- DNS-Cache-System
- Strukturierte Fehlerbehandlung
- Type-Safe Settings Manager
- Test Coverage erhöht auf 60%+

### Version 1.21 (Build 9) - August 2026
- Initial Release mit Basis-Funktionalität

---

© 2024-2026 Thorsten Albers
