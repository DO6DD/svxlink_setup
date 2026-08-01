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

## Erster Modernisierungsstand

- Unterstützt werden Debian 12, Debian 13 sowie darauf basierende Raspberry-Pi-OS-Versionen.
- ELENATA Wolfson / Fe-Pi Audio ist das einzige angebotene Raspberry-Pi-Hardwareprofil; TL5 wird nicht unterstützt.
- Das Script benötigt `sudo`, erkennt das aufrufende Benutzerkonto über `SUDO_USER` und legt SvxLink-Quellen nicht unter `/root` ab.
- Der Prüfmodus `--check` meldet System-, Dienst-, Log-, Audio- und Update-Status. Hardwareergebnisse bleiben bis zum echten Test nicht hardwarevalidiert.
- Nicht-Raspberry-Pi-Systeme erhalten automatisch Profil 0; Profil 0 erzeugt keine produktive Audio-, PTT- oder Squelch-Konfiguration.
- RepeaterLogic ist die aktive Basislogik.
- Ohne fertig konfigurierte Hardware wird der Dienst nicht automatisch produktiv gestartet.

## Deutsche Sounds und RepeaterLogic

- Deutsche Sounds sind allgemeine Sprachressourcen der Standardinstallation. Quelle, Lizenz, Verzeichnisstruktur und Aktualisierbarkeit müssen vor einer automatischen Installation geprüft sein.
- Die deutsche RepeaterLogic ist eine spätere, getrennte Erweiterung. Die Standard-RepeaterLogic von SvxLink bleibt bis dahin aktiv.
- Spätere Phase: `svxlink_repeaterlogic_de` gegen die installierte SvxLink-Version und Tcl-Kompatibilität prüfen, `repeater.conf` prüfen und anpassen sowie die deutsche Logic versionieren.
- Die Erweiterung wird optional, standardmäßig empfohlen und darf bestehende Betreiberkonfigurationen niemals ungefragt überschreiben.
- Der Basisinstaller verwendet die zentrale Pfaddefinition für `events.d`, `events.d/local` und `svxlink.d`; er löscht oder sperrt keine lokalen Tcl-Dateien und überschreibt keine bestehende `repeater.conf`.

## Geprüfter Sound-Stand

- Das alte Script klonte `dl1hrc/svxlink-sounds-de_DE-petra`, verlinkte dessen Verzeichnis als `de_DE` und lud zusätzlich `de_DE-anna-16k.tar.bz2` von `server42.net`.
- Das Petra-Repository ist erreichbar, weist jedoch auf Nutzungsbeschränkungen für die zugrundeliegende Stimme hin. Es wird deshalb nicht automatisch installiert.
- Für `de_DE-anna-16k` ist derzeit keine aktuelle, verlässlich lizenzierte Quelle bestätigt. Es wird nicht blind heruntergeladen.
- Ein späterer Installer benötigt einen vollständigen Sprachsatz unter `/usr/share/svxlink/sounds/de_DE`, entweder als Verzeichnis oder als Symlink auf einen vollständigen Sprachsatz. Verzeichnisse müssen für `svxlink` lesbar und durchsuchbar sein; bei lokaler Installation werden Eigentümer `svxlink:svxlink`, Dateien `0644` und Verzeichnisse `0755` verwendet.
- Eine spätere Soundinstallation muss vorhandene deutsche Sounds erkennen oder sichern, nur bei fehlender beziehungsweise veralteter geprüfter Quelle laden und einen unvollständigen Satz als Fehler melden.
- Solange `/usr/share/svxlink/sounds/de_DE` fehlt, bleibt die aktive RepeaterLogic auf `en_US`, damit sie mit vorhandenen Standardsounds funktionsfähig bleibt. Das Script meldet die vorbereitete, aber noch nicht aktivierte deutsche Sprache als Warnung.
