# Teststand

## Erfolgreich validiert

### Debian 13 VM

- `--check` läuft vor der Installation sauber und verändert nichts.
- Ein frischer Vorinstallationszustand wird mit `MISSING` und `SKIP` ohne rohe stderr-Fehler gemeldet.
- Paketinstallation erfolgreich.
- SvxLink 26.05.1 aus dem offiziellen Repository erfolgreich gebaut und nach `/usr` installiert.
- Benutzer und Gruppe `svxlink` angelegt; die Gruppen `audio`, `dialout` und `plugdev` sind korrekt gesetzt.
- Automatische APT-Updates deaktiviert; `apt-daily.timer` und `apt-daily-upgrade.timer` sind maskiert.
- `/etc/apt/apt.conf.d/20svxlink-disable-auto-updates` korrekt geschrieben.
- `/var/log/svxlink` angelegt.
- Logrotate verwendet täglich `rotate 14`, `compress`, `delaycompress`, `missingok`, `notifempty`, `copytruncate` und `su svxlink svxlink`.
- systemd-Service installiert und aktiviert.
- Der Dienst bleibt bei Profil 0 ohne Hardware bewusst inactive.
- Zweiter Installationslauf erfolgreich und idempotent.
- Aktive Logik ist `RepeaterLogic`.
- `CALLSIGN` wurde in `RepeaterLogic` und `SimplexLogic` korrekt gesetzt.
- `DEFAULT_LANG` bleibt `en_US`, solange `sounds/de_DE` fehlt.
- `--check` nach der Installation vollständig erfolgreich.
- `lsof` zeigt keine offene gelöschte SvxLink-Logdatei.

### Gefundene und behobene Fehler

- Rohe `runuser`-, `id`-, `grep`- und `logrotate`-Fehler im Prüfmodus unterdrückt.
- Abbruch durch `false && usermod` auf Nicht-Raspberry-Pi-Systemen behoben.
- Kommentarlos übersprungenes Hardwareprofil auf Nicht-Pi-Systemen durch explizites Profil 0 ersetzt.
- Ursprünglich aktive `SimplexLogic` durch `RepeaterLogic` als Basislogik ersetzt.
- Rufzeichen nicht mehr nur in `SimplexLogic` gesetzt.
- Ungefilterte Logrotate-Debugausgabe unterdrückt.

## Simuliert validiert

- Idempotente ELENATA-Bootkonfiguration.
- Erhalt fremder und kommentierter Bootzeilen.
- Rx-/Tx-Sektionsbearbeitung ohne doppelte oder falsch zugeordnete SQL-/PTT-Werte.
- Account-Setup für Raspberry Pi und Nicht-Raspberry-Pi.
- Nicht-Pi-Profil 0.

## Noch offen

- Echter Debian-12-VM-Test.
- Echter Raspberry-Pi-Test.
- Echter ELENATA-Test nach Neustart.
- ALSA-Karte `Audio`.
- Aufnahme und Wiedergabe als Benutzer `svxlink`.
- Mixerwerte.
- GPIO PTT und Squelch.
- Zweiter Anschluss.
- Produktiver Dienststart.
- Deutsche Sounds.
- Externe deutsche RepeaterLogic.

Hardwarefunktionen gelten bis zum erfolgreichen Test auf der jeweiligen Zielhardware als nicht hardwarevalidiert.
