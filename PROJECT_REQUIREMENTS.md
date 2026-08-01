# Projektanforderungen

## Zweck und Plattformen

- Das Projekt bleibt ein einzelnes, einfach zu bedienendes Installationsscript.
- Ziel ist die schnelle Installation einer neuen Raspberry-Pi-SD-Karte für SvxLink mit angeschlossener ELENATA-Hardware.
- Unterstützt werden aktuelle Raspberry-Pi-OS-Versionen sowie Debian-Versionen, soweit die jeweilige Hardware dies zulässt.
- ELENATA ist das wichtigste Hardwareprofil.
- Die ELENATA-Konfiguration richtet sich nach der Anleitung des Entwicklers und nach bereits funktionierenden Referenzsystemen.

## Benutzer und Pakete

- SvxLink läuft als Benutzer und Gruppe `svxlink`.
- Der Benutzer `svxlink` erhält nur die für Audio, GPIO und serielle Schnittstellen benötigten Rechte.
- Automatische Systemupdates werden deaktiviert.
- Das Installationsscript führt kein automatisches `apt upgrade` oder `apt dist-upgrade` durch.
- Erforderliche Pakete dürfen gezielt mit `apt` installiert werden.

## Protokollierung

- Die aktive SvxLink-Logdatei ist `/var/log/svxlink`.
- Logrotate läuft täglich und behält 14 Rotationen.
- Es werden `compress`, `delaycompress`, `missingok`, `notifempty` und `copytruncate` verwendet.
- SvxLink darf nach der Rotation nicht in eine gelöschte Datei weiterschreiben.

## Betrieb und Stabilität

- System- und Bootkonfigurationen werden vor Änderungen gesichert.
- Änderungen müssen wiederholbar und idempotent sein.
- Es dürfen keine doppelten Einträge in `config.txt`, `fstab`, `modules` oder Logrotate-Dateien entstehen.
- Das System soll monatelang unbeaufsichtigt stabil laufen können.
- Der Branch `main` bleibt stabil.
- Nicht getestete Hardwarefunktionen werden klar als nicht hardwarevalidiert gekennzeichnet.
