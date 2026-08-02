# Status

- Aktueller Branch: `project-documentation`
- Der CMake-Live-Fortschritt ist isoliert simuliert; ein realer Raspberry-Pi-Neubau steht noch aus.
- Pi-Test ohne ELENATA-Board bestätigte Installation und Bootwerte; Fe-Pi-Audio, ALSA, Mixer und GPIO bleiben ohne Board nicht hardwarevalidiert.
- Die vollständigen DB0DAM-950-Mixer-, AVC-, BASS- und Signalwegwerte sind als Konfigurationsreferenz hinterlegt; ihr Verhalten auf echter ELENATA-Hardware ist noch nicht durch diesen Projektstand validiert.
- Aktueller Stand: realer Debian-13-VM-Update-Skip einschließlich Sound- und Sprachprüfung bestätigt.
- Letzter real bestätigter Stand: `cb555b8`

## Fertig

- Debian-13-VM-Basisinstallation einschließlich wiederholtem Installationslauf.
- Read-only-Prüfmodus, Logging, Logrotate und RepeaterLogic-Basiskonfiguration.
- `tests/simulate_elenata.sh` prüft Profil 4 als Funktionssimulation ohne Root und ausschließlich mit temporären Dateien aus `mktemp -d`.
- Hash- und Metadatenvergleich bestätigte unveränderte überwachte Dateien unter `/boot` und `/etc`.
- Bootkonfiguration, SvxLink-Konfiguration, GPIO-Zuordnung, ALSA-Aufrufe, Idempotenz und definierte Fehlerfälle sind simuliert geprüft.
- Profil-4-Funktionssimulation zusätzlich direkt in der Debian-13-VM `svxlink-test` ohne `sudo` erfolgreich ausgeführt; alle Testfälle meldeten `PASS`.
- ShellCheck war in der Debian-13-VM nicht installiert und wurde dort nicht ausgeführt; auf dem Entwicklungsrechner wurde ShellCheck erfolgreich ausgeführt.
- Interaktives Startmenü sowie sichere Sprachverwaltung für Deutsch und Englisch sind per isolierter Simulation geprüft.
- Der deutsche Anna-16k-Sprachsatz ist als geprüftes Archiv eingebettet; seine Lizenz- und Weiterverbreitungsfrage bleibt offen und wird nicht als Freigabe dargestellt.
- Die historischen Profile 1 (ICS Pi-Repeater), 2 (uSvxCard) und 3 (WM8960 Audio-HAT) sind wieder im Installer auswählbar. `tests/simulate_legacy_profiles.sh` prüft ihre Konfigurationspfade ohne Root und ohne Downloads.
- Der Produktivstart verlangt Root über `sudo ./svxlink_setup.sh`; `SVXLINK_TEST_MODE=true` bleibt ohne Root nutzbar.
- Die Rechteverwaltung für deutsche und englische Sounds normalisiert ausschließlich `de_DE` beziehungsweise `en_US` auf `svxlink:svxlink`, Verzeichnisse `0755` und reguläre Dateien `0644`.
- Real auf Debian 13 bestätigt: Update mit Rufzeichen `DM0DOS`, SvxLink `26.05.1`, gültigem persistenten Buildstatus, unverändertem Git-Commit und Profil 0.
- Der Versionsparser verarbeitet `1.10.1@26.05.1` als Releaseversion `26.05.1`; Buildstatus und Quellstand wurden akzeptiert.
- Der unveränderte Update-Lauf übersprang CMake, Kompilierung und Installation. Profil-, Sound- und Sprachprüfung liefen weiter.
- `de_DE` und `en_US` wurden als vorhanden erkannt; es erfolgten weder Neuinstallation noch en_US-Download oder erneutes Entpacken. Rechte und Besitzerprüfung blieb idempotent.
- Deutsch blieb für `SimplexLogic` und `RepeaterLogic` aktiv; SvxLink wurde nicht automatisch gestartet.
- Die deutschen Abschlussmeldungen für Build-Skip und Profil 0 sowie die Rückkehr zum Hauptmenü wurden real bestätigt.

## Offen

- Debian-12-VM-Test.
- Raspberry Pi mit ELENATA-Profil 4 einschließlich Audio, GPIO und produktivem Dienststart.
- Aktuelle Raspberry-Pi-OS- und Debian-13-Hardwaretests für ICS Pi-Repeater, uSvxCard und WM8960 Audio-HAT.
- Echtes Installations- und Hörtest-Ergebnis für die eingebetteten deutschen und offiziellen englischen Sounds.
- Externe deutsche RepeaterLogic.

## Grenzen der Profil-4-Simulation

- Der Test ist kein vollständiger Installationslauf.
- Nicht aufgerufene Mocks im aktuellen Komponententest: `aplay`, `arecord`, `systemctl`, `usermod` und `getent`.
- Nicht hardwarevalidiert: echter Raspberry Pi, ICS Pi-Repeater, uSvxCard, WM8960 Audio-HAT, ELENATA Wolfson / Fe-Pi Audio, Raspberry-Pi-Bootkonfiguration, reale Treiberinstallation der Profile 1–4, ALSA-Karte `Audio`, Mixercontrols, Aufnahme und Wiedergabe, GPIO PTT und Squelch, zweiter physischer Anschluss und produktiver Dienststart.

## Nächster Schritt

Raspberry Pi mit einem der fünf Hardwareprofile auf aktueller Zielhardware testen; ELENATA-Profil 4 bleibt prioritär.
