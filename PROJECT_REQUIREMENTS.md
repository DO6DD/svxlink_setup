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
- `curl`, `tar`, `bzip2`, `sha256sum`, Git- und Build-Werkzeuge gehören zu den vor dem Build geprüften Grundabhängigkeiten. Fehlende Werkzeuge müssen kontrolliert gemeldet werden.
- Ein erfolgreicher SvxLink-Build speichert atomar `/var/lib/svxlink-setup/build-state`. Der normale Updatepfad überspringt den Build nur bei passendem Commit, Version, Plattform, Compiler und Buildoptionssignatur; Force baut immer neu.

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
- Raspberry-Pi-Hardwareprofile sind: Profil 0 ohne spezielles Interface, Profil 1 ICS Pi-Repeater, Profil 2 uSvxCard, Profil 3 WM8960 Audio-HAT und Profil 4 ELENATA Wolfson / Fe-Pi Audio. TL5 wird nicht unterstützt.
- `--help`, `--check`, `--show-config` und das Hauptmenü sind read-only ohne Root verfügbar. Schreibende Aktionen verlangen erst unmittelbar vor der Änderung Root und nennen dann die passende `sudo ./svxlink_setup.sh`-Variante; im Testmodus ist ebenfalls kein Root erforderlich.
- Für den Build-Skip wird ausschließlich eine normalisierte SvxLink-Releaseversion verglichen. Die interne Kennung `1.10.1` ist keine Releaseversion; aus `1.10.1@26.05.1` wird gezielt `26.05.1` ermittelt. Nicht eindeutige Erkennung bedeutet sicherer Neuaufbau.
- Der unveränderte Build-Skip ist real auf Debian 13 bestätigt; CMake, Kompilierung und Installation werden dabei nicht aufgerufen, während Profil-, Sound- und Sprachprüfungen weiterlaufen.
- Vollständige Soundpakete werden anhand nicht leerer regulärer WAV-Dateien vor jedem Download geprüft und weder heruntergeladen noch entpackt. Abschlussmeldungen unterscheiden tatsächlichen Build, Skip und Sound-Teilfehler; sichtbare Benutzertexte sind deutsch.
- Für Quellcode und Build-Verzeichnisse wird `SUDO_USER` mit dem über `getent` ermittelten Home-Verzeichnis verwendet. Ein direkter Root-Login verwendet ausdrücklich `/root`.
- Der Prüfmodus `--check` meldet System-, Dienst-, Log-, Audio- und Update-Status. Hardwareergebnisse bleiben bis zum echten Test nicht hardwarevalidiert.
- Nicht-Raspberry-Pi-Systeme erhalten automatisch Profil 0; Profil 0 erzeugt keine produktive Audio-, PTT- oder Squelch-Konfiguration.
- RepeaterLogic ist die aktive Basislogik.
- Ohne fertig konfigurierte Hardware wird der Dienst nicht automatisch produktiv gestartet.
- Das interaktive Hauptmenü strukturiert Installation, Status, Backups, Sprachverwaltung und Konfigurationsanzeige, ohne die vorhandenen Profilpfade zu ersetzen.
- Ein erzwungener Neuaufbau sichert Konfiguration, lokale Events, systemd-Overrides und Sounds vor dem Neuaufbau; lokale Anpassungen werden nicht ungefragt gelöscht.

## Testbarkeit und Hardwareprofile

- Hardwareprofile müssen ohne echte Hardware soweit möglich über isolierte Funktionstests prüfbar sein.
- Testpfade dürfen Produktionspfade nur bei explizitem `SVXLINK_TEST_MODE=true` überschreiben; ohne Testmodus gelten feste Produktionspfade.
- Simulierte Raspberry-Pi-Erkennung darf nur durch klar begrenzte Testvariablen aktiviert werden.
- Simulationstests dürfen kein Root benötigen und keine echten Dateien unter `/boot`, `/etc`, `/usr` oder `/var` verändern.
- Vor und nach dem Test müssen relevante echte Dateien auf Inhalt und Metadaten geprüft werden.
- Idempotenz muss für Boot- und SvxLink-Konfiguration geprüft werden.
- Mock-Aufrufe müssen protokolliert und relevante Aufrufe inhaltlich geprüft werden. Nicht aufgerufene Mocks dürfen nicht als getestete Funktion behauptet werden.
- Simulation und Hardwarevalidierung müssen in Status und Testdokumentation klar getrennt werden. Ein bestandener Simulationstest darf niemals als Hardwarefreigabe bezeichnet werden.
- Die historischen Profile 1 bis 3 verwenden weiterhin die Quellen `respeaker/seeed-voicecard` und `waveshare/WM8960-Audio-HAT`, soweit die jeweilige Treiberinstallation erforderlich ist. Sie bleiben bis zum Test auf aktueller Zielhardware nicht hardwarevalidiert.

## Deutsche Sounds und RepeaterLogic

- Der Installer stellt Englisch und Deutsch als Sprachressourcen bereit. Englisch wird aus dem offiziellen Release `25.05` von `sm0svx/svxlink-sounds-en_US-heather` mit fester SHA-256 `e79e61bec17a24fad093edfb21e7f8ca51af33b9590db954b4789271db2957dd` installiert.
- Der deutsche Sprachsatz Anna 16k liegt als geprüftes Archiv im Repository unter `resources/sounds/`. Herkunft, Größe und SHA-256 sind dokumentiert; Lizenz- und Weiterverbreitungsfragen bleiben ausdrücklich offen.
- Archive werden vor dem Entpacken auf Prüfsumme, erwartete Wurzel, Traversal, unsichere Links und Sonderdateien geprüft und nur temporär entpackt. Sichere interne relative Links werden nach der Prüfung in reguläre Dateien materialisiert.
- Nach erfolgreicher normaler Installation ist `de_DE` die Standardsprache für `SimplexLogic` und `RepeaterLogic`; bei fehlgeschlagener deutscher Installation bleibt funktionsfähiges `en_US` aktiv.
- Die Sprachaktivierung verlangt nur einen vorhandenen Ordner mit mindestens einer WAV-Datei. Eine Vollständigkeits-, Modul- oder Audioformatprüfung des installierten deutschen Bestands findet bewusst nicht statt.
- Vor einer Konfigurationsänderung wird gesichert; vorhandene Sprachordner werden nicht still überschrieben und SvxLink wird durch Sprachaktionen nicht gestartet.
- Die deutsche RepeaterLogic ist eine spätere, getrennte Erweiterung. Die Standard-RepeaterLogic von SvxLink bleibt bis dahin aktiv.
- Spätere Phase: `svxlink_repeaterlogic_de` gegen die installierte SvxLink-Version und Tcl-Kompatibilität prüfen, `repeater.conf` prüfen und anpassen sowie die deutsche Logic versionieren.
- Die Erweiterung wird optional, standardmäßig empfohlen und darf bestehende Betreiberkonfigurationen niemals ungefragt überschreiben.
- Der Basisinstaller verwendet die zentrale Pfaddefinition für `events.d`, `events.d/local` und `svxlink.d`; er löscht oder sperrt keine lokalen Tcl-Dateien und überschreibt keine bestehende `repeater.conf`.

## Geprüfter Sound-Stand

- Das alte Script klonte `dl1hrc/svxlink-sounds-de_DE-petra`, verlinkte dessen Verzeichnis als `de_DE` und lud zusätzlich `de_DE-anna-16k.tar.bz2` von `server42.net`.
- Das Petra-Repository wird nicht automatisch installiert, weil es auf Nutzungsbeschränkungen hinweist.
- Das eingebettete Anna-Archiv ersetzt den historischen Laufzeitdownload von `server42.net`; die URL bleibt ausschließlich als Herkunftsnachweis erhalten.
- Die Installation nutzt `/usr/share/svxlink/sounds/de_DE` und `/usr/share/svxlink/sounds/en_US`. Jeweils nur der gewählte Sprachordner wird rekursiv auf `svxlink:svxlink`, Verzeichnisse auf `0755` und reguläre Dateien auf `0644` normalisiert; Symbolziele werden nicht dereferenziert.
- Status- und Testausgaben verwenden textuelle Statuszeilen. ANSI-Farben werden nur bei Terminalausgabe verwendet; `NO_COLOR` und Umleitungen bleiben ANSI-frei.
- Produktive Befehlsausgaben werden pro Lauf unter `/var/log/svxlink-setup/install-<Zeitstempel>.log` protokolliert; das Terminal zeigt Phasen und bei Fehlern einen Logauszug.
