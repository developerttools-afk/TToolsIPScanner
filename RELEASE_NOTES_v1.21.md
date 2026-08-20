# TToolsIPScanner v1.21 - Release Notes

## Version 1.21 (Build 9)
**Release Date**: 20. August 2026

### 🎯 Hauptfeatures

#### 1. ⚡ Modernisierte Concurrency (Async/Await)
- Komplette Migration von DispatchQueue zu modernem async/await
- Strukturiertes Task-Management für bessere Cancellation
- TaskGroup für parallele IP- und Port-Scans
- Verbesserte Performance und Stabilität

#### 2. 🚨 Strukturierte Fehlerbehandlung
- Neuer `ScanError` Enum mit type-safe Fehlern
- Severity-Levels (Info, Warning, Error, Critical)
- Detaillierte Fehlermeldungen mit Recovery-Suggestions
- Neue `ErrorMessageView` für bessere UX

#### 3. 🚀 DNS-Cache für Performance
- Actor-basierter Thread-Safe DNS-Cache
- Konfigurierbare Cache-Lifetime (5 Minuten default)
- Cache-Statistiken (Hit/Miss Rate)
- Neues DNS-Cache Settings UI (iOS & macOS)
- Signifikante Performance-Verbesserung bei wiederholten Scans

#### 4. ⚙️ Type-Safe Settings Manager
- Property Wrappers (@UserDefault, @CodableUserDefault, @EnumUserDefault)
- Zentrale Settings-API statt Magic Strings
- Bessere Wartbarkeit und Type-Safety
- Export/Import von Settings für Debugging

#### 5. 🧪 Umfassende Test-Coverage (60-80%)
- 320+ neue Unit- und Integration-Tests
- 100% Coverage für Utilities & Models
- Performance-Tests für kritische Pfade
- Edge-Case-Tests für Robustheit

### 🐛 Bugfixes
- Verbesserte IP-Validierung mit besseren Edge-Case-Checks
- Korrekte Behandlung von Leading Zeros in IP-Adressen
- Robustere Port-Parsing-Logik
- Bessere Fehlerbehandlung bei OUI-Database-Updates

### 📈 Performance-Verbesserungen
- DNS-Lookups sind nun deutlich schneller durch Caching
- Parallele Scan-Operationen durch TaskGroup
- Optimierte Memory-Nutzung durch strukturiertes Task-Management
- Reduzierte Netzwerk-Last durch intelligentes Caching

### 🛠️ Technische Verbesserungen
- Swift 6 Concurrency-ready
- Modern Swift Best Practices
- Verbesserte Code-Qualität durch Tests
- Bessere Separation of Concerns

### 📱 Plattformen
- **iOS**: 18.1+
- **macOS**: 15.1+

### 🔗 GitHub Pull Requests
- [PR #2](https://github.com/developerttools-afk/TToolsIPScanner/pull/2) - Modernisierung Concurrency
- [PR #3](https://github.com/developerttools-afk/TToolsIPScanner/pull/3) - DNS Cache
- [PR #4](https://github.com/developerttools-afk/TToolsIPScanner/pull/4) - Error Handling
- [PR #5](https://github.com/developerttools-afk/TToolsIPScanner/pull/5) - Settings Manager
- [PR #6](https://github.com/developerttools-afk/TToolsIPScanner/pull/6) - Test Coverage

### ⚠️ Breaking Changes
Keine - Alle Änderungen sind abwärtskompatibel.

### 📝 Bekannte Einschränkungen
- Socket-basierte Port-Scans funktionieren weiterhin nur im lokalen Netzwerk
- iOS Local Network Permission muss gewährt werden
- OUI-Database muss manuell aktualisiert werden (über Settings)

### 🙏 Danke
Diese Version enthält umfangreiche Verbesserungen basierend auf einem detaillierten Code Review.
Alle neuen Features sind durch umfassende Tests abgesichert.

---

**Vorherige Version**: 1.20 (Build 8)
