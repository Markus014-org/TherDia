# TherDia · verschlüsseltes iOS-Tagebuch

**TherDia** ist ein SwiftUI-Tagebuch für iPhone (ab iOS 17) mit synchronisierter Dropbox-Datei, vollständig verschlüsseltem Offline-Cache, Feldversionsverwaltung und auswertbaren Berichten. Das Projekt kann per **GitHub Actions → TestFlight** veröffentlicht werden. Der Quellcode benötigt keine kostenpflichtigen Swift-Pakete oder eigenen Server.

> **Wichtig:** Der bereitgestellte Quellcode und die Workflows sind eine vollständige Implementierungsvorlage, aber **kein fertig signiertes iOS-Binary**. Für einen tatsächlichen TestFlight-Upload müssen deine eigenen Apple- und Dropbox-Zugänge, das App-Signing und die GitHub-Secrets eingerichtet werden. Auf diesem System konnte kein Xcode-/iPhone-Laufzeittest ausgeführt werden. Vor der Nutzung mit echten Gesundheitsdaten solltest du einen Test mit zwei Geräten und Konfliktfällen durchführen.

## Funktionen
## Neue Tagebuch-Oberfläche

- Orangefarbenes TherDia-App-Icon (wird durch `scripts/generate_icon.py` bei iOS-Builds erzeugt), orange Akzente und ein hell- bis mittelgrauer Hintergrund.
- Beliebig viele Basis-Medikamente in einer Zeile je Medikament mit Bezeichnung und Menge. Das gilt für Ersteinrichtung, Voreinstellungen und Tagebuch.
- Schulfrage in zwei Schritten: zuerst „War Schule?“, danach Unterrichtsteilnahme und Form.
- Fünfstufiger Wohlbefindens-Schieberegler auch für Unternehmungen und Begegnungen.
- Sichtbare Bestätigung nach lokalem Speichern, mit separatem Dropbox-Synchronisationsstatus.
- Eigenes Menü, direkt aufrufbares Berichtswesen und Datumsauswahl.
- Alte Einträge mit genau einem Basis-Medikament bleiben durch rückwärtskompatibles Lesen erhalten. Die neue Begegnungsbewertung liegt in einem eigenen Feld, um Mehrgeräte-Konflikte zu minimieren.
- Bei älteren App-Versionen auf weiteren Geräten möglichst alle Geräte aktualisieren, bevor gemeinsame Tagebuchfelder bearbeitet werden. Zuerst nur mit Testdaten prüfen.


- **Tagebuch** nach Datum (heute oder Vergangenheit), Wohlbefinden in fünf Ampelstufen und blaue Markierung bei Notmedikation.
- **Basis- und Notmedikation** (Art und Menge). Gerätespezifische Voreinstellungen bei Einrichtung bzw. unter Einstellungen; Tageswerte sind änderbar. Für jeden Tagebucheintrag müssen Art und Menge der Basis-Medikation angegeben werden.
- **Verletzungen**, **Schule** (nicht teilgenommen / online / Präsenz / beides, Fachkategorie), **KJP/ASS-Therapie und Teilnahme**, **Unternehmungen mit Einfluss auf Befinden**, **Begegnungen mit einzelnen Namen**.
- **Berichte**: letzte 7 oder 30 Tage, 3/6/12 Monate, eigener Zeitraum; nach Befinden, Notmedikation, Schule, Therapie, Verletzungen, Unternehmungen, Basis-Medikament und Person filtern; anzuzeigende Kategorien auswählen; tagesweise chronologische Datenansicht.
- **Statistiken**: Häufigkeiten, Prozente, Kreisdiagramme für Befinden, Medikamente, Schule, Therapie, Verletzungen, Unternehmungen, Begegnungen; Wohlbefindensverlauf, Durchschnitt, persönliche Kontakte und Verletzungsnotizen.
- **Offline**: Die **gesamte bisher synchronisierte Datenhistorie** wird zusätzlich auf dem Gerät AES-256-GCM-verschlüsselt gespeichert (damit auch die Daten des letzten Monats). Neue Einträge sind ohne Internet möglich.
- **Synchronisation**: beim Start, beim Rückkehren in die App, nach Wiederherstellen der Verbindung und manuell. Das gilt, solange iOS die App ausführt; ein garantierter Upload im vollständig beendeten/Hintergrund-Zustand ist nicht möglich.
- **Mehrgeräte-Konflikte**: pro Datenfeld Zeitstempel, Geräte-ID und eindeutige Änderungs-ID; neuere Einträge haben Vorrang **erst nach** expliziter Bestätigung bei unterschiedlichen Werten. Vor einem Upload prüft die App die Dropbox-Dateirevision, um gleichzeitige Überschreibungen zu erkennen.

## Voraussetzungen

1. **Apple Developer Program** (kostenpflichtige Mitgliedschaft), Zugang zu [App Store Connect](https://appstoreconnect.apple.com/) und einem Apple-Entwicklungsteam.
2. Ein GitHub-Repository mit aktiviertem Actions-Zugriff auf macOS-Runner.
3. Ein Dropbox-Konto und eine einmalig erstellte App im [Dropbox App Console](https://www.dropbox.com/developers/apps).
4. Zum lokalen Öffnen: macOS mit Xcode und [XcodeGen](https://github.com/yonaskolb/XcodeGen). Für den GitHub-Build ist lokal kein Mac erforderlich.

## 1. Dropbox-App anlegen

In der Dropbox App Console eine **Scoped App** erstellen:

- **Zugriffsart „Full Dropbox“** (wichtig für einen frei wählbaren oder mit anderen Dropbox-Konten geteilten Ordner; „App folder“ reicht dafür nicht).
- **Permissions / Scopes:** `files.content.read` und `files.content.write` aktivieren. Falls die Konsole die App zunächst auf Entwicklungskonten begrenzt, weitere Tester erlauben bzw. die notwendige Produktionsfreigabe beantragen.
- In Settings **Allow public clients** aktivieren. Die Anmeldung nutzt **OAuth 2.0 PKCE/S256** mit `token_access_type=offline` und Refresh-Token, **ohne App Secret**.
- Unter **App key** den **App Key (client_id)** kopieren. Dieser ist *öffentlich*, kein geheimes App Secret.

**Besonderheit Dropbox:** Dropbox akzeptiert für `redirect_uri` nur HTTPS bzw. localhost. Deshalb verwendet die App einen von Dropbox unterstützten **PKCE-Code-Flow ohne Redirect-URI**: Dropbox im Browser öffnen, Einmalcode kopieren, in TherDia einfügen. Die App speichert den Refresh-Token gerätegebunden im iOS-Schlüsselbund. Jeder Nutzer verbindet sein eigenes Gerät einmalig. Die Passphrase wird nicht an Dropbox übertragen.

### Gemeinsamer Ordner für mehrere Konten

Werden mehrere Geräte **mit demselben Dropbox-Konto** verbunden, reicht z. B. `/TherDia/therdia.enc`.

Nutzen mehrere Menschen **je ein eigenes Dropbox-Konto**, erstelle den Dropbox-Ordner zunächst im Dropbox-Webinterface, gib ihn **mit Bearbeitungsrechten** frei und stelle sicher, dass er bei allen Mitgliedern unter demselben API-Pfad eingehängt ist (z. B. `/TherDia-Gemeinsam/therdia.enc`). Dann den **identischen Dateipfad und dieselbe Passphrase** in allen TherDia-Installationen verwenden. Die Datei ist für berechtigte Dropbox-Mitglieder direkt sichtbar, wegen der Verschlüsselung aber nicht im Klartext lesbar.

> Achtung: Die **Passphrase nicht vergessen oder ohne sichere Übergabe an alle Geräte wechseln**. Es gibt keinen Passwort-Reset und keinen Server, der sie wiederherstellen könnte.

## 2. App in Apple Developer und App Store Connect einrichten

1. In **Certificates, Identifiers & Profiles** eine eindeutige **App ID / Bundle ID** anlegen, z. B. `de.beispiel.therdia`. Die ID muss später exakt dem Wert `BUNDLE_ID` entsprechen.
2. In **App Store Connect → Apps** eine App „TherDia“ (Plattform iOS, gleiche Bundle ID) anlegen.
3. Ein **Apple Distribution**-Zertifikat mit zugehörigem **privaten Schlüssel** erstellen und als **passwortgeschützte `.p12`** exportieren.
4. Ein **App Store Connect / App Store Distribution Provisioning Profile** für diese Bundle ID und dieses Zertifikat erzeugen und als `.mobileprovision` herunterladen. **Kein Development-/Ad-Hoc-Profil** verwenden.
5. In App Store Connect unter **Users and Access → Integrations → App Store Connect API** einen **Team API Key** mit geeigneten Rechten für TestFlight erstellen. **Key ID**, **Issuer ID** und die nur einmal herunterladbare **`.p8`** aufbewahren.
6. **Export-Compliance:** TherDia implementiert AES-256-GCM (CryptoKit) und PBKDF2. Prüfe und beantworte die Verschlüsselungs-/Exportfragen in App Store Connect zutreffend. Im Projekt ist bewusst **keine pauschale Befreiung** durch `ITSAppUsesNonExemptEncryption=NO` eingetragen.

Weitere Angaben (Testinformationen, Tester, Datenschutzangaben) müssen in App Store Connect je nach interner/externer TestFlight-Nutzung ergänzt werden. **Externe Tester** können eine Beta-App-Review benötigen; interne Tester lassen sich in App Store Connect hinzufügen.

## 3. Dateien zu GitHub hochladen und Konfiguration hinterlegen

Das **gesamte Verzeichnis** (einschließlich `.github/`) ins Root deines privaten Repositories legen, z. B.:

```text
TherDia/
├── .github/workflows/check.yml       # simulatorfähiger Kompilierungscheck bei Push/PR
├── .github/workflows/testflight.yml  # signieren, IPA erzeugen, TestFlight-Upload
├── TherDia/                           # SwiftUI-App inkl. Assets
├── TherDiaTests/                      # Tests für Merge-Logik und Verschlüsselung
├── fastlane/Fastfile                  # Upload zu TestFlight
├── Gemfile
├── project.yml                        # XcodeGen-Konfiguration
└── README.md
```

In GitHub unter **Settings → Secrets and variables → Actions** folgende Einträge anlegen:

| Art | Name | Inhalt |
|---|---|---|
| **Variable** | `BUNDLE_ID` | Deine exakte Apple Bundle ID, z. B. `de.beispiel.therdia` |
| **Variable** | `DROPBOX_APP_KEY` | Public Dropbox App Key (nicht App Secret) |
| **Secret** | `APPLE_TEAM_ID` | Apple Team ID (meist 10 Zeichen) |
| **Secret** | `APPLE_CERTIFICATE_P12_BASE64` | Base64 **der vollständigen** `.p12`-Datei |
| **Secret** | `APPLE_CERTIFICATE_PASSWORD` | Exportpasswort der `.p12` |
| **Secret** | `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 **der vollständigen** `.mobileprovision`-Datei |
| **Secret** | `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| **Secret** | `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| **Secret** | `APPSTORE_PRIVATE_KEY_BASE64` | Base64 **der vollständigen** `.p8`-Datei |

Auf macOS erzeugst du die drei Base64-Werte so (die Ergebnisse jeweils **ohne Zeilenumbrüche** als GitHub Secret speichern):

```bash
base64 -i AppleDistribution.p12 | tr -d '\n'
base64 -i TherDia_AppStore.mobileprovision | tr -d '\n'
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

**Keine Zertifikate, privaten Schlüssel, Passphrasen oder OAuth-Refresh-Tokens committen!** GitHub-Secrets schützen die Werte beim Build. Die Dropbox-App-Key-Variable wird absichtlich in die App-Info.plist eingebettet, da ein OAuth Public Client seine Client-ID kennen muss.

## 4. GitHub Actions starten und auf iPhone installieren

1. Unter **GitHub → Actions → „TherDia → TestFlight“ → Run workflow** den manuellen Release starten (Branch `main`). Die Workflowdatei wird nicht automatisch bei jedem Push veröffentlichen.
2. Der Runner generiert per **XcodeGen** das Projekt, importiert das Signierungszertifikat in einen temporären Keychain, installiert das Provisioning Profile, erstellt ein signiertes **iOS-Archiv**, exportiert die **IPA** und lädt sie über **fastlane/pilot** mit dem App Store Connect API Key zu **TestFlight** hoch.
3. Nach der Verarbeitung in **App Store Connect → TestFlight** den Build für interne Tester freigeben (ggf. noch Angaben zu Verschlüsselung/Test hinzufügen).
4. Auf dem iPhone die **Apple TestFlight** App installieren, Einladung für TherDia annehmen, den Build installieren.
5. Beim ersten Start in TherDia Dropbox verbinden, Medikamenten-Voreinstellungen eintragen; **auf Gerät 1 „Neu erstellen“**, auf weiteren Geräten **„Bestehende öffnen“** wählen, dabei denselben Dateipfad und dieselbe Passphrase eingeben.

Wird ein neues Archiv veröffentlicht, verwendet der Workflow die **GitHub Run Number** als aufsteigende Build-Nummer. Die Bundle ID ist konfigurierbar, der Name bleibt **TherDia**.

## 5. Lokal mit Xcode starten (optional)

```bash
brew install xcodegen
cd TherDia
xcodegen generate
open TherDia.xcodeproj
```

Für einen plattformunabhängigen Smoke-Test der Merge-Logik (Swift-Compiler erforderlich): `./scripts/smoke_core.sh`.

In Xcode unter **Signing & Capabilities** dein Team auswählen, die Bundle ID anpassen und unter den **Build Settings** die benutzerdefinierte Variable `DROPBOX_APP_KEY` auf den Public App Key setzen. Ohne diesen Wert lässt sich die App zwar im Simulator kompilieren, aber nicht mit Dropbox anmelden. Tests laufen auf einem iOS-17+-Simulator (`TherDiaTests`).

## Speichermodell und Konfliktregeln

- Der Dropbox-Datenträger ist **eine einzige Datei**, z. B. `/TherDia/therdia.enc`, mit einem versionierten JSON-Container. Der Container enthält nur zufälligen Salt und AES-GCM-Chiffrat; sämtliche Tagesdaten, Namen und Medikationsangaben sind verschlüsselt.
- Die Passphrase wird mit **PBKDF2-HMAC-SHA256 (450.000 Durchläufe, zufälliger Salt je Schreibvorgang)** in einen AES-256-Schlüssel abgeleitet. **Keine Passphrase wird in Dropbox gespeichert.** Durch zufälligen Salt und Nonce unterscheiden sich zwei Verschlüsselungen desselben Inhalts.
- Der lokale Cache wird in **Application Support** mit **iOS Complete File Protection** gespeichert, von iCloud-Dateibackups ausgeschlossen und genauso verschlüsselt. Die Passphrase und Dropbox-Refresh-Tokens liegen unter **WhenUnlockedThisDeviceOnly** im iOS-Keychain.
- Jeder Tagesdatensatz enthält acht **einzeln versionierte Felder** (die Fragen nach Verletzungen, Schule usw. speichern jeweils Unterfelder zusammen), jeweils mit UTC-Zeitstempel (Millisekunden), Geräte-ID und Änderungs-ID.
- Beim **manuellen Ändern** eines gespeicherten Feldes zeigt die App vorher die bisherige und die neue Angabe und fordert eine explizite Bestätigung.
- Beim **Synchronisieren** werden disjunkte Felder ohne Konflikt zusammengeführt. Liegen für dasselbe Feld zwei unterschiedliche Werte vor, zeigt die App **alt und neu** an; sie schlägt den zeitlich jüngeren vor. Erst nach Bestätigung schreibt sie den Gewinner. Das Ablehnen des neueren Werts wird als **neue, genehmigte Korrektur** versioniert.
- Dropbox-Uploads verwenden entweder **`mode=add` ohne Autorename** (nur beim Neuanlegen) oder **`mode=update` mit exakt bekannter `rev`** (optimistische Nebenläufigkeitskontrolle). Bei einem Revisionkonflikt erfolgt erneutes Lesen/Mergen; es gibt **kein ungeprüftes `overwrite`**.
- Im Konfliktfall, bei einem falschen Passwort, bei API-Fehlern und beim Fehlen einer erwarteten Dropbox-Datei findet **kein automatischer ersetzender Upload** statt.

### Grenzen / vor produktiver Verwendung testen

- **Uhrzeit:** Das „jünger gewinnt“-Modell stützt sich auf die **Systemuhren der Geräte**. Sind diese stark unterschiedlich eingestellt, kann die Reihenfolge falsch sein. Auf allen iPhones „Datum & Uhrzeit automatisch einstellen“ aktivieren.
- **Feldgranularität:** „Schule“ oder „Medikation“ sind jeweils ein Feld. Wenn zwei Geräte *verschiedene Unterangaben desselben Bereichs* ändern, wird der **gesamte Bereich** als Konflikt präsentiert.
- **Gemeinsamer Dropbox-Dateipfad:** Shared-Folder-Pfade sind je nach Konto und Mount-Konfiguration unterschiedlich. Vor dem realen Mehrgerätebetrieb mit zwei Testgeräten prüfen. Der Scope „Full Dropbox“ gibt der App relativ weitreichenden Zugriff auf das Benutzerkonto; sicherere granulare Freigaben würden zusätzliche Architektur benötigen.
- **Offline**: Die App speichert Änderungen zuverlässig beim Speichern lokal. Die Synchronisation findet statt, sobald die App wieder läuft und Netzwerk verfügbar ist; iOS garantiert keine Ausführung einer beendeten App genau im Moment des Netzwechsels.
- **Kein echtes Backup-Management:** Dropbox bietet ggf. Dateiversionen; TherDia selbst besitzt keinen Versions-Export, keinen Passphrase-Wiederherstellungsdienst und keine serverseitige Wiederherstellung. Für wichtige Einträge vor Einsatz eine separate, sichere Backup-Strategie festlegen.
- **Dateigröße:** Die vollständige Historie wird derzeit bei einem Upload als eine verschlüsselte Datei übertragen. Für einige Dutzend/Jahre täglicher Kurztexte ist das praktikabel; für sehr große Datenmengen wäre eine differenzielle Datenbank nötig.
- **Medizinische Nutzung:** TherDia unterstützt Dokumentation und Auswertung, nicht Diagnose, medizinische Entscheidungen oder Notfallversorgung. Vor einem Einsatz mit Gesundheitsdaten oder Daten Minderjähriger sind Datenschutz, Einwilligungen, Zugriffskontrolle und die Dropbox-Auftragsbedingungen eigenständig zu prüfen.
- **Technischer Teststand:** Das Repository enthält Swift-Quellcode und Tests, wurde aber hier **nicht** mit Apples Xcode kompiliert oder mit einem echten Dropbox-Konto end-to-end getestet. Der Actions-Check dient der ersten tatsächlichen Xcode-Verifikation nach dem Hochladen.

## Technische Quellen

- [Dropbox: OAuth PKCE / Offline Access](https://docs.dropboxapi.com/riviera/docs/get-started/authorization)
- [Dropbox: Dateien mit Revisionsschutz hochladen](https://docs.dropboxapi.com/dropbox-api/api-reference/user-endpoints/files/upload)
- [fastlane: TestFlight / pilot](https://docs.fastlane.tools/actions/pilot/)
- [Apple: Export-Compliance für Verschlüsselung](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)


## Erweiterungen: Notmedikation, Verhalten, Bildschirmzeit und PDF (November 2026)

- **Notmedikation:** Optionale Uhrzeit der Einnahme in 24-Stunden-Darstellung; alte Einträge ohne Zeit bleiben gültig.
- **Aggressives Verhalten:** Getrennte Schalter für selbstverletzendes und fremdaggressives Verhalten. Bei gleichzeitigem Auftreten können beide Beschreibungsfelder ausgefüllt werden. Die ursprünglichen Verletzungseinträge bleiben als historische Kategorie erhalten und werden niemals stillschweigend umklassifiziert.
- **Bildschirmzeit:** Neue letzte Tagebuchkategorie; optional 0 bis 24 Stunden in halbstündigen Schritten. Nicht erfasste Tage sind kein Nullwert.
- **Berichte:** Aktive Filter zeigen ihre Kategorie; hinzugekommen sind gezielte Filter für Art des aggressiven Verhaltens und Bildschirmzeit sowie entsprechende Auswertungen.
- **PDF:** Unter Berichte → PDF zusammenstellen kann unabhängig vom bisherigen Bildschirmfilter ein Zeitraum gewählt werden. Frei auswählbare Module enthalten Kennzahlen, Verlauf, Kuchendiagramme, Bildschirmzeit-Diagramm, Medikamenten- und Tageslisten. Optionaler Patientenname steht nur im PDF; Personennamen und Freitextnotizen lassen sich separat ein- oder ausschließen. Vorschau per PDFKit, Speichern/Mail/andere Apps über die iOS-Teilen-Funktion.
- **Datenschutz:** Ein exportiertes PDF ist **nicht verschlüsselt**, enthält unter Umständen sehr sensible Gesundheitsdaten und wird zur Weitergabe vorübergehend im iOS-Temporärverzeichnis abgelegt. Nur an vertrauenswürdige Empfänger teilen; nicht unnötig in ungeschützten Cloud-Ordnern aufbewahren.
- **Mehrere Geräte:** Alle Geräte sollten auf denselben aktuellen TherDia-Build aktualisiert werden, bevor neue Felder auf anderen Geräten bearbeitet werden. Bei der Weiterentwicklung mit Testdaten beginnen.

