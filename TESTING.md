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
