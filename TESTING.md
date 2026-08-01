# Testplan

## VM-validiert

- Test auf Debian 12 VM.
- Test auf Debian 13 VM.
- Prüfung der Paketinstallation.
- Prüfung des SvxLink-Builds.
- Prüfung des Benutzers und der Gruppe `svxlink`.
- Prüfung des systemd-Dienstes.
- Prüfung der Logdatei `/var/log/svxlink`.
- Prüfung von Logrotate mit `copytruncate`.
- Prüfung mit `lsof +L1` auf offene gelöschte Dateien.
- Prüfung deaktivierter automatischer Updates.
- Zweiter Installationslauf zur Kontrolle der Wiederholbarkeit.
- Simulierter ELENATA-Test mit Testdateien für Bootkonfiguration.

## Hardwarevalidiert

- Späterer echter Raspberry-Pi-Test.
- Echter ELENATA-Test für Audioaufnahme, Audiowiedergabe, PTT und Squelch.

Hardwarefunktionen gelten erst nach erfolgreichem Test auf der jeweiligen Zielhardware als hardwarevalidiert.

## Modernisierungsstand

- `bash -n svxlink_setup.sh` und ShellCheck vor jeder Ausführung prüfen.
- `sudo ./svxlink_setup.sh --check` auf Debian 12 und Debian 13 ausführen.
- Auf Raspberry Pi die Erkennung von `/boot/config.txt` und `/boot/firmware/config.txt` getrennt prüfen.
- Den ELENATA-Test erst nach Neustart mit vorhandener ALSA-Karte `Audio` durchführen.
- Prüfen, dass die Bootkonfiguration keine doppelten Einträge enthält und vorhandene UART-Einstellungen unverändert bleiben.
- Prüfen, dass ein zweiter Installationslauf keine doppelten Konfigurations- oder Logrotate-Einträge erzeugt.
- Späterer Logic-Test in einer VM.
- SvxLink-Start mit externer deutscher Logic prüfen.
- Auf Tcl-Fehler, Kennung, Uhrzeit, Rogerbeep und Sprachdateien prüfen.
- Update-Test ohne Überschreiben einer angepassten `repeater.conf`.
- Prüfen, dass ein vollständiger deutscher Sprachsatz unter `sounds/de_DE` lesbar ist und keine unvollständige Installation als Erfolg gilt.
