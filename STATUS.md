# Status

## Implementiert

- SvxLink wird bewusst aus dem offiziellen Upstream-Repository auf `master` gebaut; Buildstatus, Commit, Version, Plattform und Optionen steuern den Build-Skip.
- Die vollständige angeforderte Abhängigkeitssammlung wird installiert. `raspberrypi-kernel-headers` wurde nach einem realen Neuinstallationstest entfernt: Auf dem Zielsystem war kein Kandidat verfügbar und ELENATA benötigt wegen des vorhandenen `fe-pi-audio`-Overlays kein externes Kernelmodul. Debian 13 arm64 stellte `libsigc++-2.0-dev` und `libgcrypt20-dev` direkt bereit; die fehlerhafte Alias-/Kandidatenprüfung wurde durch direkte Installation dieser Namen ersetzt. Der reale Neuinstallationstest wurde dabei abgebrochen und muss vollständig wiederholt werden.
- `-D` schreibt ein geschütztes Debuglog; read-only Aufrufe und Hauptmenü funktionieren ohne Root, schreibende Aktionen verlangen Root erst vor der Änderung.
- ELENATA verwaltet die Bootwerte idempotent, deaktiviert `vc4-kms-v3d`, behält feste GPIOD-Pins bei und richtet bei fehlender Karte `Audio` eine einmalige ALSA-Post-Boot-Konfiguration ein.
- Die vollständigen DB0DAM-950-Mixer-, AVC-, BASS- und Signalwegwerte sind als Pflichtregler implementiert. DB0VL-Pegel sind nur stationsspezifisch und kein Standard.
- Deutsche Sounds werden bei fehlendem `de_DE` aus dem passwortgeschützten Nextcloud-Archiv bezogen; Passwortabfrage, Curl-Konfiguration und Download sind temporär, die Prüfsumme und die Archivwurzel `sounds/de_DE/` werden vor der Installation geprüft. Der reale Download mit Zugangsdaten steht noch aus.

## Statisch auf dem ThinkPad geprüft

- Bash-Syntax, ShellCheck und `git diff --check` wurden für den Stand `66fa22a` erfolgreich ausgeführt.

## Auf dem ThinkPad simuliert

- `simulate_elenata`: 125 erfolgreich, 0 Fehler.
- `simulate_build_progress`: 6 erfolgreich, 0 Fehler.
- `simulate_root_backup_permissions`: 44 erfolgreich, 0 Fehler.
- `simulate_sound_management`: 53 erfolgreich, 0 Fehler.
- `simulate_build_decision`: 15 erfolgreich, 0 Fehler.
- `simulate_legacy_profiles`: 27 erfolgreich, 0 Fehler.

## Real in der Debian-VM auf dem ThinkPad geprüft

- Debian-13-Installation, Profil 0, Update-/Build-Skip, Soundinstallation und Sprachaktivierung wurden bestätigt.
- Die VM ist kein Raspberry-Pi- oder ELENATA-Hardwaretest.

## Real auf Raspberry Pi ohne Zielhardware geprüft

- Auf `we10-test` lief ein vollständiger Neubau im Pfad `/root/svxlink/build`, nachdem Buildordner und Buildstatus für den Test entfernt beziehungsweise gesichert wurden.
- Die reale CMake-Prozentanzeige lief fortlaufend; die Objektkompilierung war im Buildlog sichtbar. Installation, `svxlink --version` (`1.10.1@26.05.1`), erkannte Releaseversion `26.05.1`, Buildstatus, idempotente Bootkonfiguration und `--check` ohne interne Shellfehler wurden bestätigt.
- Es war kein ELENATA-Board vorhanden. Die fehlende Karte `Audio` war daher erwartet; ALSA, Mixer, Audio, GPIO, Squelch und PTT wurden nicht bestätigt.

## Reale ELENATA-/Fe-Pi-Referenz

- Die vollständigen DB0DAM-950-Controlwerte wurden von einer real laufenden Station ausgelesen und sind die Implementierungsreferenz.
- Nicht bestätigt ist noch, dass eine frische Installation mit diesem Installer die Werte auf ELENATA-/Fe-Pi-Hardware vollständig setzt, mit `asactl` speichert und nach dem Neustart wiederherstellt.

## Noch offen

- Frische ELENATA-/Fe-Pi-Installation einschließlich Post-Boot-Unit, `Audio`-Karte, Mixer, Aufnahme, Wiedergabe, SQL, PTT und optionalem zweiten Anschluss.
- Produktiver SvxLink-Betrieb mit Zielhardware.
- Debian-12-VM sowie reale Tests der historischen Profile 1–3 auf aktueller Zielhardware.
- Separate externe deutsche RepeaterLogic: `DEFAULT_LANG=de_DE` aktiviert nur Sprachansagen und integriert keine angepasste Tcl-Logic.
- Reale Prüfung des passwortgeschützten deutschen Nextcloud-Downloads mit gültigen Zugangsdaten, vollständigem Archiv und Hörtest.

## Nächster Test

Eine frische ELENATA-/Fe-Pi-Installation mit dem aktuellen Installer ausführen, neu starten und danach Pending-Datei, Post-Boot-Log, `amixer -c Audio scontents`, `asactl`-Speicherung, Audio, SQL und PTT prüfen.
