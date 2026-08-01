# Changelog

## Unreleased

- Projektanforderungen und Testgrundlage dokumentiert.
- Erster Modernisierungsstand für Debian 12/13 und ELENATA Wolfson / Fe-Pi Audio dokumentiert.
- Deutsche RepeaterLogic bewusst auf eine spätere Integrationsphase verschoben; der Basisinstaller bleibt bei der Standard-RepeaterLogic.
- Debian-12/13-Erkennung und ein sauberer read-only-Prüfmodus ergänzt.
- Benutzer- und Rechteverwaltung sowie die Abschaltung automatischer Updates ergänzt.
- Offiziellen SvxLink-Build und RepeaterLogic als aktive Basislogik ergänzt.
- Idempotente Rufzeichenkonfiguration ergänzt.
- Profil 0 für Nicht-Raspberry-Pi-Systeme und ELENATA-Profil 4 für Raspberry Pi ergänzt.
- Logging und Logrotate ergänzt.
- Kontrollierten Umgang mit fehlenden deutschen Sounds ergänzt.
- Debian-13-VM-Basistest erfolgreich durchgeführt.
- Sicherer Profil-4-Funktionssimulationstest `tests/simulate_elenata.sh` hinzugefügt.
- Testpfade sind nur im expliziten Testmodus überschreibbar; ein `BASH_SOURCE`-Guard erlaubt das sichere Einbinden des Produktionsskripts.
- ELENATA-Bootkonfiguration idempotent gestaltet und Sicherungen auf tatsächlichen Änderungsbedarf beschränkt.
- Fehler bei nicht möglichem Boot-Schreibvorgang werden weitergegeben; fehlende Pflichtregler führen zu kontrollierten Fehlern.
- ALSA-State kann im Test in eine temporäre Datei geschrieben werden.
- Vollständige Prüfung der Profil-4-GPIO- und Audio-Konfiguration für einen und zwei Anschlüsse ergänzt.
- Hash- und Metadatenvergleich echter Systemdateien ergänzt.
- Profil-4-Test klar als Simulation ohne Hardwarevalidierung gekennzeichnet.
- Profil-4-Funktionssimulation zusätzlich auf Debian 13 erfolgreich ausgeführt.
- ShellCheck dort mangels installiertem Programm nicht ausgeführt; bereits auf dem Entwicklungsrechner bestanden.
- Interaktives Startmenü und nicht-interaktive Sprachaktionen ergänzt.
- Englischen Standardsatz aus einem versionsfixierten offiziellen SvxLink-Release mit SHA-256-Prüfung ergänzt.
- Anna 16k als geprüftes Repositoryartefakt mit Herkunftsinformation und Prüfsummenmanifest ergänzt; Lizenz- und Weiterverbreitungsfragen bleiben offen.
- Deutsche und englische Sprachinstallation, sichere Archivprüfung mit Materialisierung sicherer interner Links, Konfigurationssicherung und Sprachumschaltung ergänzt.
- Deutsche Sprache wird nach erfolgreicher normaler Installation aktiviert; bei Fehlern bleibt Englisch aktiv.
- Historische Hardwareprofile wiederhergestellt: Profil 1 ICS Pi-Repeater, Profil 2 uSvxCard und Profil 3 WM8960 Audio-HAT.
- Hauptmenü, Installations-/Aktualisierungsuntermenü und Backup-Untermenü ergänzt; alle Profile 0 bis 4 bleiben erreichbar.
- Simulation `tests/simulate_legacy_profiles.sh` für die historischen Profilzweige, Boot- und Moduleinträge, uSvxCard-GPIO sowie externe Treiberquellen ergänzt.
- Die historischen Treiberquellen bleiben zunächst unpinned und bis zur Prüfung auf aktueller Raspberry-Pi-Hardware nicht hardwarevalidiert.
- Produktivstart verbindlich auf Root mit `sudo ./svxlink_setup.sh` festgelegt; Testmodus bleibt rootlos.
- Quell- und Build-Benutzer werden über `SUDO_USER` und `getent` bestimmt; direkter Root-Login ist definiert.
- Verzeichnisbackups kopieren statt den Quellordner zu verschieben; ein separater Helfer bleibt für atomaren Austausch zuständig.
- Deutsche und englische Soundordner werden einzeln auf `svxlink:svxlink`, Verzeichnisse `0755` und reguläre Dateien `0644` normalisiert. Symbolziele werden nicht dereferenziert.
- Parameterloser Programmstart öffnet verbindlich `main_menu`; Systemerkennung und Installation sind erst über Installations-Untermenüpunkt 1 erreichbar.
