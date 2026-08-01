# Status

- Aktueller Branch: `project-documentation`
- Aktueller Stand: Debian-13-VM-Basistest bestanden.
- Letzter bekannter getesteter Commit: `17fd665`

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
- Der reale Debian-13-VM-Updatepfad erkannte Rufzeichen und Profil 0 korrekt und baute SvxLink 26.05.1 erneut. Er brach danach wegen der fehlenden `curl`-Abhängigkeit ab; ein Wiederholungstest nach der Korrektur steht aus.
- Der getestete VM-Lauf erzeugte bei unverändertem Quellstand noch einen vollständigen Neuaufbau. Die neue Build-Skip-Logik mit persistentem Buildstatus ist simuliert geprüft; ein erneuter VM-Test steht aus.
- Die Ursache dieses Neuaufbaus ist eingegrenzt: `svxlink --version` meldete die interne Kennung `1.10.1`, während die Binärdatei `1.10.1@26.05.1` enthält. Der Parser ermittelt nun gezielt die Releaseversion `26.05.1`; der erneute unveränderte VM-Skip-Test steht weiterhin aus.

## Offen

- Debian-12-VM-Test.
- Raspberry Pi mit ELENATA-Profil 4 einschließlich Audio, GPIO und produktivem Dienststart.
- Aktuelle Raspberry-Pi-OS- und Debian-13-Hardwaretests für ICS Pi-Repeater, uSvxCard und WM8960 Audio-HAT.
- Echtes Installations- und Hörtest-Ergebnis für die eingebetteten deutschen und offiziellen englischen Sounds.
- Erneuter Debian-13-VM-Update- und Soundtest nach Aufnahme von `curl`, `tar` und `bzip2` in die Grundabhängigkeiten.
- Erneuter realer Debian-13-VM-Lauf, der den Build-Skip nach der Parserkorrektur bestätigt.
- Externe deutsche RepeaterLogic.

## Grenzen der Profil-4-Simulation

- Der Test ist kein vollständiger Installationslauf.
- Nicht aufgerufene Mocks im aktuellen Komponententest: `aplay`, `arecord`, `systemctl`, `usermod` und `getent`.
- Nicht hardwarevalidiert: echter Raspberry Pi, ELENATA Wolfson / Fe-Pi Audio, `dtoverlay=fe-pi-audio` auf echter Hardware, reale ALSA-Karte `Audio`, reale Mixercontrols, Aufnahme und Wiedergabe, GPIO PTT und Squelch, zweiter physischer Anschluss, produktiver Dienststart, deutsche Sounds und externe deutsche RepeaterLogic.

## Nächster Schritt

Raspberry Pi mit einem der fünf Hardwareprofile auf aktueller Zielhardware testen; ELENATA-Profil 4 bleibt prioritär.
