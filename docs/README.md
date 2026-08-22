# App Store Support Pages

Diese HTML-Seiten müssen für die App Store Connect Einreichung öffentlich gehostet werden.

## Dateien

- `privacy.html` - Datenschutzerklärung (Privacy Policy) - **Pflicht für App Store**
- `support.html` - Support-Seite mit FAQ - **Pflicht für deutsche Lokalisierung**
- `impressum.html` - Impressum (nicht App Store Pflicht, aber auf Seiten verlinkt)

## Hosting-Optionen

### Option 1: GitHub Pages (empfohlen)

1. GitHub Repository öffentlich machen
2. Repository Settings → Pages
3. Source: Branch `main` oder `cursor/release-v1.21-merged-50e7`, Ordner `/store` oder `/`
4. Nach Deploy (ca. 1-2 Minuten):
   ```
   https://developerttools-afk.github.io/TToolsIPScanner/privacy.html
   https://developerttools-afk.github.io/TToolsIPScanner/support.html
   https://developerttools-afk.github.io/TToolsIPScanner/impressum.html
   ```

### Option 2: Cloudflare Pages

1. Cloudflare Dashboard → Pages → Create Project
2. GitHub Repository verbinden oder Ordner hochladen
3. Build Settings: Keine (statisches HTML)
4. Deploy → Produktions-URL verwenden (nicht Preview!)
5. Beispiel: `https://ttoolsipscanner.pages.dev/privacy.html`

### Option 3: Netlify Drop

1. https://app.netlify.com/drop
2. Ordner `store/` hochziehen
3. Kostenlose *.netlify.app URL
4. Beispiel: `https://ttoolsipscanner.netlify.app/privacy.html`

## URLs in App Store Connect eintragen

Nach dem Hosting die URLs hier notieren und in App Store Connect einfügen:

### Für Copy & Paste

```
DATENSCHUTZ-URL (Privacy Policy URL):
https://____________________/privacy.html

SUPPORT-URL (deutsch + english):
https://____________________/support.html

IMPRESSUM (nicht App Store Pflicht):
https://____________________/impressum.html
```

### Wo eintragen?

1. **Datenschutz-URL:**
   - App Store Connect → TTools IP Scanner → App-Informationen → Datenschutzrichtlinie-URL
   - Auch in iOS-Version → Lokalisierung Deutsch/English prüfen

2. **Support-URL:**
   - App Store Connect → TTools IP Scanner → iOS-Version 1.31 → Deutsch → Support-URL
   - Dasselbe in English und anderen Lokalisierungen

3. **Copyright:**
   - App Store Connect → TTools IP Scanner → iOS-Version 1.31 → Copyright
   - Eintragen: `© 2026 Thorsten Albers`

## Wichtig

- ✅ URLs müssen **https** sein
- ✅ **Produktions-URL** verwenden (keine Preview/Hash-URLs)
- ✅ Im Browser testen **vor** Eintragen in App Store Connect
- ✅ Seiten sind zweisprachig (DE + EN in einer Datei)
- ✅ Kontakt: `developerttools@gmail.com`

## Inhalt prüfen

### Privacy Policy muss enthalten:
- ✅ Welche Daten erfasst werden (keine)
- ✅ Lokales Netzwerk-Permission Erklärung
- ✅ OUI-Update (IEEE, optional, keine Nutzerdaten)
- ✅ Keine Analytics, kein Tracking

### Support Page muss enthalten:
- ✅ Kontakt-E-Mail
- ✅ FAQ
- ✅ Hobbyprojekt-Disclaimer
- ✅ Systemanforderungen
- ✅ Rechtliche Hinweise

### Impressum muss enthalten:
- ✅ Name und Kontakt
- ✅ Haftungsausschluss
- ✅ Urheberrecht (MIT License)
- ✅ Hinweis: Privates, nicht-kommerzielles Projekt

## Nach dem Hosten

1. URLs in Browser testen
2. URLs in `APP_STORE_CONNECT_CHECKLISTE.md` Abschnitt 0 eintragen
3. URLs in App Store Connect einfügen
4. App zur Review einreichen

---

**Hinweis:** Diese Seiten müssen **vor** der Einreichung bei App Store Connect öffentlich erreichbar sein!
