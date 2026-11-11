import SwiftUI

/// In-app manual. All descriptions reflect the implemented data model and
/// synchronization behavior; the guide is available without internet.
struct InformationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introduction
                quickStart
                diaryGuide
                updateGuide
                dailyCategories
                savingGuide
                reminderGuide
                reportsGuide
                pdfGuide
                syncGuide
                encryptionGuide
                devicesGuide
                troubleshootingGuide
            }
            .padding(16)
        }
        .background(TherDiaTheme.canvas)
        .navigationTitle("Information")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introduction: some View {
        SectionCard("Willkommen bei TherDia", subtitle: "Dein persönliches, geschütztes Therapie-Tagebuch") {
            Label("Tagebuch · Berichte · Dropbox · Offline", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundStyle(TherDiaTheme.accent)
            Text("TherDia hilft dir, den Alltag, Medikamente, Therapien und das Wohlbefinden festzuhalten und über längere Zeiträume auszuwerten. Du kannst mehrere iPhones mit derselben verschlüsselten Dropbox-Datenbank verwenden.")
            Text("Diese Anleitung ist direkt in der App gespeichert und auch ohne Internet verfügbar.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var quickStart: some View {
        SectionCard("1 · Die App einmalig einrichten") {
            HelpLine("Dropbox verbinden",
                     "Tippe auf „Dropbox-Anmeldung öffnen“, melde dich im Browser an und übertrage den angezeigten Einmalcode in TherDia.",
                     icon: "externaldrive")
            Divider()
            HelpLine("Datenbank wählen",
                     "Beim ersten Gerät „Neu erstellen“ wählen. Weitere Geräte öffnen die „Bestehende“ Datenbank. Alle Geräte müssen auf denselben Dropbox-Dateipfad zugreifen.",
                     icon: "doc")
            Divider()
            HelpLine("Passphrase festlegen",
                     "Lege eine gemeinsame Passphrase mit mindestens 12 Zeichen fest. Auf weiteren Geräten ist exakt dieselbe Passphrase nötig. Bewahre sie sicher auf: Ohne sie können die Daten nicht wiederhergestellt werden.",
                     icon: "key.fill")
            Divider()
            HelpLine("Medikamente voreinstellen",
                     "Trage deine regelmäßig verwendeten Basis-Medikamente mit Name und Menge ein; du kannst beliebig viele hinzufügen. Notmedikation kann ebenfalls voreingestellt werden.",
                     icon: "pills.fill")
        }
    }

    private var diaryGuide: some View {
        SectionCard("2 · Einen Tag eintragen") {
            HelpLine("Datum auswählen",
                     "Im Tagebuch ist zunächst der heutige Tag ausgewählt. Über das Datum oder „Menü → Zu einem bestimmten Tag springen“ kannst du vergangene Tage öffnen.",
                     icon: "calendar")
            Divider()
            HelpLine("Tagesbefinden",
                     "Bewege den farbigen Schieberegler zwischen Gut (grün), Mittelgut (gelb), Mittelschlecht (orange), Schlecht (rot) und Extrem schlecht (dunkelrot). In den Berichten kennzeichnet ein farbiger Punkt den Tag.",
                     icon: "slider.horizontal.3")
            Divider()
            HelpLine("Änderungen an älteren Tagen",
                     "Du kannst bereits gespeicherte Tage bearbeiten. TherDia zeigt bei vorhandenen Werten einen Vergleich und fragt vor dem Überschreiben nach deiner Zustimmung.",
                     icon: "square.and.pencil")
        }
    }

    private var updateGuide: some View {
        SectionCard("TestFlight · Neue Version erkennen") {
            HelpLine("Türkiser Hinweis im Tagebuch",
                     "Wenn eine neuere, von Apple für interne Tests bereitgestellte TherDia-Version verfügbar ist, erscheint oben links im Tagebuch ein türkisfarbener Hinweis. Nach dem Aktualisieren auf diese Version wird der Hinweis nicht mehr angezeigt.",
                     icon: "arrow.down.circle")
            Divider()
            HelpLine("App aktualisieren",
                     "Öffne Apples TestFlight-App auf dem iPhone, wähle TherDia und tippe auf „Aktualisieren“. Lass die bisherige App installiert, damit nicht synchronisierte lokale Einträge erhalten bleiben.",
                     icon: "arrow.down.app")
            Divider()
            HelpLine("Wann wird geprüft?",
                     "TherDia fragt beim Öffnen beziehungsweise erneuten Aktivieren der App eine über GitHub bereitgestellte Versionsinformation ab. Diese wird regelmäßig mit Apples TestFlight-Status abgeglichen. Ohne Internet oder wenn die Abfrage fehlschlägt, kann der Hinweis fehlen.",
                     icon: "wifi")
            Text("Ein grüner GitHub-Build-Check oder ein erfolgreicher Upload allein bedeutet noch nicht, dass die Version bereits in TestFlight installiert werden kann.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var dailyCategories: some View {
        SectionCard("3 · Alle Tagebuch-Kategorien") {
            HelpLine("Basis-Medikation",
                     "Art und Menge stehen jeweils in einer Zeile. Über „Medikament hinzufügen“ lassen sich weitere Präparate eintragen; die Voreinstellungen sind pro Tag veränderbar.",
                     icon: "pills")
            Divider()
            HelpLine("Notmedikation",
                     "Wähle Ja oder Nein. Bei Ja gibst du Art und Menge ein; die Uhrzeit kann mit einem iOS-Wheel-Picker erfasst werden. Direkt unter der Uhrzeit kannst du angeben, ob Müdigkeit als Folge aufgetreten ist (Ja, Nein oder nicht angegeben). Anschließend lässt sich das Wohlbefinden nach der Medikation mit einem fünfstufigen Regler und einer optionalen Notiz dokumentieren. In der Tagesübersicht erscheint ein blauer Punkt.",
                     icon: "cross.vial.fill")
            Divider()
            HelpLine("Aggressives Verhalten",
                     "Wenn Ja, kannst du „Selbstverletzend“, „Fremdaggressiv“ oder beides auswählen. Für jede ausgewählte Art erscheint ein eigenes Beschreibungsfeld. Ältere Verletzungseinträge bleiben als historische Daten erhalten und werden nicht automatisch umgedeutet.",
                     icon: "exclamationmark.bubble")
            Divider()
            HelpLine("Schule",
                     "Zuerst wird gefragt, ob überhaupt Schule war. Falls ja: Hast du teilgenommen? Bei Teilnahme wählst du Online, Präsenz oder beides und anschließend die Fächer.",
                     icon: "graduationcap")
            Divider()
            HelpLine("Therapie",
                     "Erfasse, ob eine Therapie geplant war, welche Art (KJP oder ASS) und ob du teilgenommen hast.",
                     icon: "person.crop.rectangle")
            Divider()
            HelpLine("Unternehmungen",
                     "Notiere eine Aktivität. Falls sie das Wohlbefinden beeinflusst hat, wähle die Bewertung über den farbigen Schieberegler und ergänze bei Bedarf einen Text.",
                     icon: "figure.walk")
            Divider()
            HelpLine("Begegnungen",
                     "Erfasse Personen außerhalb der Familie mit je einem eigenen Namensfeld. Du kannst später nach Namen filtern. Der Einfluss auf das Wohlbefinden lässt sich ebenfalls per Schieberegler und optionalem Text dokumentieren.",
                     icon: "person.2")
            Divider()
            HelpLine("Bildschirmzeit",
                     "Aktiviere die Erfassung und stelle die tägliche Dauer zwischen 0 und 24 Stunden in Schritten von 30 Minuten ein. „Nicht erfasst“ ist etwas anderes als 0 Stunden.",
                     icon: "iphone")
        }
    }

    private var savingGuide: some View {
        SectionCard("4 · Speichern und offline arbeiten") {
            HelpLine("Tag speichern",
                     "Tippe unten auf „Tag speichern“. Nach erfolgreichem lokalen Speichern zeigt TherDia eine Bestätigung. Der zusätzliche Synchronisationsstatus verrät dir, ob Dropbox schon abgeglichen wurde.",
                     icon: "checkmark.circle.fill")
            Divider()
            HelpLine("Ohne Internet",
                     "Nach der Ersteinrichtung kannst du die bereits lokal geladenen Einträge ansehen und neue Tage bearbeiten. Änderungen werden zunächst verschlüsselt auf dem iPhone gespeichert.",
                     icon: "wifi.slash")
            Divider()
            HelpLine("Lokale Daten",
                     "Die App hält derzeit den gesamten synchronisierten Datenbestand verschlüsselt lokal vor, nicht nur den letzten Monat. Zum erstmaligen Verbinden mit Dropbox ist eine Internetverbindung nötig.",
                     icon: "internaldrive")
        }
    }

    private var reminderGuide: some View {
        SectionCard("5 · Tägliche Erinnerung") {
            HelpLine("Einmal täglich erinnern",
                     "Aktiviere in „Einstellungen → Tägliche Tagebuch-Erinnerung“ den Schalter und wähle die gewünschte Uhrzeit mit dem iOS-Wheel-Picker. Tippe auf „Erinnerungseinstellungen speichern“ und erlaube iOS-Mitteilungen.",
                     icon: "bell")
            Divider()
            HelpLine("Anzeige und Ton",
                     "Du kannst „Nur optisch“, „Nur akustisch“ oder „Optisch und akustisch“ auswählen. Für akustische Hinweise stehen ein Standardton und zwei kurze TherDia-Töne zur Verfügung; die TherDia-Töne kannst du in den Einstellungen probehören. iOS-Mitteilungseinstellungen, Lautlos-Modus und Fokus können die tatsächliche Anzeige und Lautstärke beeinflussen; eine reine Ton-Benachrichtigung lässt sich im Hintergrund nicht in allen iOS-Modi garantieren.",
                     icon: "speaker.wave.2")
            Divider()
            HelpLine("Nur für den aktuellen Tag",
                     "TherDia plant für den Tag eine Erinnerung nur, wenn noch kein entsprechender Eintrag auf dem iPhone bekannt ist. Bei erfolgreichem Speichern werden geplante weitere Erinnerungen für diesen Tag gelöscht. Frühere Tage lösen keine Nachhol-Erinnerung aus.",
                     icon: "calendar.badge.checkmark")
            Divider()
            HelpLine("Schlummern oder für heute beenden",
                     "Ohne ausdrückliche Bestätigung sind für denselben Tag weitere Mitteilungen im 30-Minuten-Abstand geplant. Das Öffnen der App oder Wegwischen beendet die Erinnerungsserie nicht. Beim Antippen der Sperrbildschirm-Benachrichtigung öffnet sich TherDia mit einem eigenen Auswahlfenster: „Jetzt Tagebuch eintragen“, „In 15 Minuten“, „In 30 Minuten“, „In 1 Stunde“ oder „Für heute beenden“. Dieselben Schlummer- und Ende-Aktionen findest du auch beim Aufklappen der iOS-Benachrichtigung. Schließt du das Fenster ohne Auswahl, laufen die automatischen Erinnerungen weiter. Auch nach einem Schlummern wird nur am selben Kalendertag erinnert. Die tatsächliche Auslieferung hängt von iOS und den Mitteilungseinstellungen ab.",
                     icon: "clock")
            Divider()
            HelpLine("Mehrere Geräte und Hintergrundverhalten",
                     "Die Erinnerung wird auf jedem iPhone separat eingerichtet. Hat ein anderes Gerät den Tag gespeichert, erkennt dieses iPhone das erst nach dem Dropbox-Abgleich. iOS prüft die Dropbox-Datei nicht bei jeder Benachrichtigung; dadurch sind unter Umständen noch Hinweise möglich. Die App aktualisiert geplante Erinnerungen beim Start und beim erneuten Verwenden.",
                     icon: "iphone")
        }
    }

    private var reportsGuide: some View {
        SectionCard("6 · Berichte und Auswertungen") {
            HelpLine("Berichtswesen öffnen",
                     "Unten auf „Berichte“ tippen oder im Menü „Berichtswesen und Statistiken“ auswählen.",
                     icon: "chart.pie")
            Divider()
            HelpLine("Zeitraum",
                     "Wähle die letzten 7 oder 30 Tage, 3, 6 oder 12 Monate oder einen eigenen Zeitraum mit Von- und Bis-Datum.",
                     icon: "calendar.badge.clock")
            Divider()
            HelpLine("Filter",
                     "Grenze die Daten nach Tagesbefinden, Notmedikation, Schultag, Unterrichtsteilnahme, Therapie, aggressivem Verhalten und dessen Art, Bildschirmzeit, Unternehmungen, Basis-Medikament oder Begegnungen ein. Jeder Filter zeigt eine kurze Erklärung. Mehrere ausgewählte Filter gelten gleichzeitig; oben werden die Kategorien aller aktiven Filter eingeblendet.",
                     icon: "line.3.horizontal.decrease")
            Divider()
            HelpLine("Statistiken oder Tagesliste",
                     "Wechsle zwischen Diagrammen, Prozentwerten und zeitlichem Verlauf oder der chronologischen Liste. Ausgewertet werden unter anderem Wohlbefinden nach Notmedikation, deren Zeitpunkt und eventuelle Müdigkeit sowie Schule, Begegnungen und Bildschirmzeit. Ein ausdrücklich nicht beantwortetes Feld wird nicht als „Nein“ gedeutet. Die Statistiken beziehen sich auf dokumentierte Tage beziehungsweise auf die jeweils erfassten Angaben – nicht automatisch auf alle Kalendertage.",
                     icon: "chart.bar")
        }
    }

    private var pdfGuide: some View {
        SectionCard("7 · PDF-Berichte erstellen und weitergeben") {
            HelpLine("PDF zusammenstellen",
                     "Öffne „Berichte → PDF zusammenstellen“. Wähle dort separat den Berichtszeitraum und die gewünschten Teile, zum Beispiel Kennzahlen, Kuchen- oder Verlaufsdiagramme, Notmedikation mit Müdigkeit und Wohlbefinden danach, Schule, aggressives Verhalten, Bildschirmzeit oder Tagebucheinträge. Über „Alle auswählen“ oder die einzelnen Schalter bestimmst du den Umfang.",
                     icon: "doc.richtext")
            Divider()
            HelpLine("Patientenname (optional)",
                     "Du kannst einen Namen in die PDF-Kopfzeile aufnehmen. Er wird nicht als Tagebucheintrag in Dropbox gespeichert. Auch das Erstellungsdatum und der Berichtszeitraum stehen im PDF.",
                     icon: "person.text.rectangle")
            Divider()
            HelpLine("Persönliche Angaben steuern",
                     "Entscheide gesondert, ob Namen von Begegnungen sowie Freitexte und Beschreibungen im PDF erscheinen sollen. Die PDF-Zeitraumauswahl ist unabhängig von den Filtern der normalen Berichtsansicht.",
                     icon: "hand.raised")
            Divider()
            HelpLine("Ansehen, speichern, versenden",
                     "Tippe auf „PDF jetzt erstellen“ und danach auf „PDF ansehen“ oder „PDF teilen oder sichern“. Über das iOS-Teilen-Menü kannst du die Datei zum Beispiel in „Dateien“ sichern, per Mail verschicken oder in einer anderen App öffnen.",
                     icon: "square.and.arrow.up")
            Text("Wichtig: Ein erzeugtes PDF ist nicht mit der Tagebuch-Passphrase verschlüsselt. Wer die Datei erhält, kann ihre Inhalte lesen. Teile solche Berichte nur über geeignete, vertrauenswürdige Wege.")
                .font(.footnote)
                .foregroundStyle(TherDiaTheme.ink)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TherDiaTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var syncGuide: some View {
        SectionCard("8 · So funktioniert die Dropbox-Synchronisierung") {
            HelpLine("Wann wird synchronisiert?",
                     "Beim Öffnen nach dem Laden des lokalen Bestands, beim erneuten Aktivieren der App, bei wiederhergestellter Internetverbindung und nach dem Speichern. Unter „Einstellungen“ oder im Menü ist auch „Jetzt synchronisieren“ möglich.",
                     icon: "arrow.triangle.2.circlepath")
            Divider()
            HelpLine("Reihenfolge und Zeitstempel",
                     "Jede gespeicherte Änderung erhält einen Zeitstempel. TherDia gleicht einzelne Felder je Tag ab; unterschiedliche Felder können zusammengeführt werden, ohne einen ganzen Tag zu ersetzen.",
                     icon: "clock")
            Divider()
            HelpLine("Wenn zwei Geräte dasselbe Feld ändern",
                     "Bei unterschiedlichen Werten auf zwei Geräten zeigt TherDia den älteren und den jüngeren Eintrag mit Zeitstempel. Der jüngere ist vorausgewählt, aber du musst die Auswahl bestätigen. Ohne Zustimmung erfolgt keine automatische inhaltliche Überschreibung.",
                     icon: "exclamationmark.shield")
            Divider()
            HelpLine("Gleichzeitiges Speichern",
                     "Dropbox-Dateiversionen werden beim Hochladen berücksichtigt. Hat ein anderes Gerät die Datei zwischenzeitlich geändert, wird der Abgleich erneut versucht, statt dessen Änderungen blind zu überschreiben.",
                     icon: "arrow.left.arrow.right")
            Text("Tipp: Lass die Synchronisation auf einem Gerät abschließen, bevor du denselben Tag auf dem nächsten Gerät bearbeitest.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var encryptionGuide: some View {
        SectionCard("9 · Verschlüsselung einfach erklärt") {
            HelpLine("Verschlüsselte Datenbank",
                     "Bevor TherDia Tagebucheinträge in Dropbox speichert, verschlüsselt die App sie mit AES-256-GCM über Apples CryptoKit. Die lokale Datenbank wird nach demselben Verfahren verschlüsselt. Die Dateien lassen sich ohne die richtige Passphrase nicht sinnvoll lesen.",
                     icon: "lock.shield.fill")
            Divider()
            HelpLine("Passphrase und Schlüssel",
                     "Aus deiner Passphrase wird mit PBKDF2-HMAC-SHA256 und einem zufälligen Salt ein 256-Bit-Schlüssel abgeleitet (450.000 Durchläufe). Das bedeutet: Die eigentliche Verschlüsselung wird nicht allein durch die eingegebene Zeichenfolge durchgeführt.",
                     icon: "key.horizontal")
            Divider()
            HelpLine("Sicher auf dem iPhone",
                     "Passphrase und Dropbox-Zugangstoken liegen im iOS-Schlüsselbund und sind an dieses Gerät gebunden. Der verschlüsselte lokale Cache ist zusätzlich mit dem iOS-Dateischutz gespeichert.",
                     icon: "iphone.gen3.radiowaves.left.and.right")
            Divider()
            HelpLine("Übertragung und Dropbox",
                     "Die Verbindung zu Dropbox erfolgt über HTTPS. In Dropbox liegt die verschlüsselte .enc-Datei, keine direkt lesbare Tagebuchliste. Für die Anmeldung nutzt TherDia einen einmaligen Bestätigungscode, ohne dein Dropbox-Passwort in der App abzufragen.",
                     icon: "externaldrive.badge.person.crop")
            Text("Die Verschlüsselung schützt den Inhalt der Datenbank, nicht automatisch jedes daraus exportierte PDF. Eine verlorene Passphrase kann nicht von TherDia oder Dropbox wiederhergestellt werden.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var devicesGuide: some View {
        SectionCard("10 · Mehrere Geräte einrichten") {
            HelpLine("Gemeinsame Datei verwenden",
                     "Auf dem zweiten Gerät TherDia installieren, mit dem berechtigten Dropbox-Konto verbinden, „Bestehende öffnen“ wählen und denselben Dateipfad und dieselbe Passphrase eingeben. Bei verschiedenen Dropbox-Konten muss der betreffende Ordner freigegeben und erreichbar sein.",
                     icon: "iphone.and.arrow.forward")
            Divider()
            HelpLine("Gleiche App-Version",
                     "Aktualisiere möglichst alle Geräte auf denselben neuen TestFlight-Build, bevor neue Kategorien gemeinsam bearbeitet werden.",
                     icon: "arrow.down.app")
            Divider()
            HelpLine("Voreinstellungen",
                     "Die Voreinstellungen für Medikamente werden pro Gerät im iOS-Schlüsselbund gespeichert. Auch die Erinnerungszeit, Töne und Schlummer-Einstellungen gelten jeweils nur für dieses iPhone. Gespeicherte Tagesangaben selbst gehören zur gemeinsamen Datenbank.",
                     icon: "gearshape")
        }
    }

    private var troubleshootingGuide: some View {
        SectionCard("11 · Häufige Fragen und wichtige Hinweise") {
            HelpLine("Was heißt „Synchronisation ausstehend“?",
                     "Der Eintrag ist lokal gespeichert, aber noch nicht erfolgreich mit Dropbox abgeglichen. Prüfe die Internetverbindung und tippe bei Bedarf auf „Jetzt synchronisieren“.",
                     icon: "questionmark.circle")
            Divider()
            HelpLine("Falscher Dropbox-Pfad oder falsche Passphrase?",
                     "Prüfe auf allen Geräten denselben Dateipfad und exakt dieselbe Passphrase. Eine vorhandene fremde oder falsch entschlüsselte Datei wird aus Sicherheitsgründen nicht stillschweigend überschrieben.",
                     icon: "doc.badge.gearshape")
            Divider()
            HelpLine("Dieses Gerät zurücksetzen",
                     "Unter Einstellungen kannst du die lokale Datenbank und den Zugang dieses Geräts löschen. Nicht synchronisierte lokale Änderungen gehen dabei verloren; die Dropbox-Datei bleibt bestehen. Vorher unbedingt den Synchronisationsstatus prüfen.",
                     icon: "exclamationmark.triangle")
            Divider()
            HelpLine("Medizinischer Hinweis",
                     "TherDia ist ein Dokumentations- und Auswertungstool und ersetzt keine medizinische Beratung, Diagnose oder Behandlung. Bei akuten Notfällen professionelle Hilfe in Anspruch nehmen.",
                     icon: "cross.case")
        }
    }
}

private struct HelpLine: View {
    let title: String
    let detail: String
    let icon: String

    init(_ title: String, _ detail: String, icon: String) {
        self.title = title
        self.detail = detail
        self.icon = icon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(TherDiaTheme.accent)
                .frame(width: 26, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(TherDiaTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(TherDiaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}
