# Status

- Aktueller Branch: `project-documentation`
- Aktueller Stand: Debian-13-VM-Basistest bestanden.
- Letzter bekannter getesteter Commit: `8781d0b`

## Fertig

- Debian-13-VM-Basisinstallation einschließlich wiederholtem Installationslauf.
- Read-only-Prüfmodus, Logging, Logrotate und RepeaterLogic-Basiskonfiguration.
- `tests/simulate_elenata.sh` prüft Profil 4 als Funktionssimulation ohne Root und ausschließlich mit temporären Dateien aus `mktemp -d`.
- Hash- und Metadatenvergleich bestätigte unveränderte überwachte Dateien unter `/boot` und `/etc`.
- Bootkonfiguration, SvxLink-Konfiguration, GPIO-Zuordnung, ALSA-Aufrufe, Idempotenz und definierte Fehlerfälle sind simuliert geprüft.
- Profil-4-Funktionssimulation zusätzlich direkt in der Debian-13-VM `svxlink-test` ohne `sudo` erfolgreich ausgeführt; alle Testfälle meldeten `PASS`.
- ShellCheck war in der Debian-13-VM nicht installiert und wurde dort nicht ausgeführt; auf dem Entwicklungsrechner wurde ShellCheck erfolgreich ausgeführt.

## Offen

- Debian-12-VM-Test.
- Raspberry Pi mit ELENATA-Profil 4 einschließlich Audio, GPIO und produktivem Dienststart.
- Deutsche Sounds und externe deutsche RepeaterLogic.

## Grenzen der Profil-4-Simulation

- Der Test ist kein vollständiger Installationslauf.
- Nicht aufgerufene Mocks im aktuellen Komponententest: `aplay`, `arecord`, `systemctl`, `usermod` und `getent`.
- Nicht hardwarevalidiert: echter Raspberry Pi, ELENATA Wolfson / Fe-Pi Audio, `dtoverlay=fe-pi-audio` auf echter Hardware, reale ALSA-Karte `Audio`, reale Mixercontrols, Aufnahme und Wiedergabe, GPIO PTT und Squelch, zweiter physischer Anschluss, produktiver Dienststart, deutsche Sounds und externe deutsche RepeaterLogic.

## Nächster Schritt

Raspberry Pi mit ELENATA-Profil 4 testen.
