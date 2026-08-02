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
- Der normale Updatepfad erkannte Rufzeichen `DM0DOS` und Profil 0 korrekt und behielt die Konfiguration.

#### Reproduzierter unveränderter Update-Skip

Voraussetzungen: Debian-13-VM, bereits installiertes SvxLink `26.05.1`, gültiger Buildstatus unter `/var/lib/svxlink-setup/build-state`, unveränderter SvxLink-Quellcommit, vorhandene nicht leere `de_DE`- und `en_US`-Soundpakete sowie Profil 0.

1. `sudo ./svxlink_setup.sh` starten.
2. Im Hauptmenü Punkt 1 und im Installationsmenü erneut Punkt 1 wählen.
3. Update bestätigen und die Ausgabe prüfen.

Erwartet und real bestätigt: unveränderter Quellstand und Releaseversion `26.05.1`; akzeptierter Buildstatus; kein CMake, kein Build und kein `make install`; vorhandenes `de_DE` und `en_US` ohne Neuinstallation, Download oder Entpacken; Deutsch für `SimplexLogic` und `RepeaterLogic`; kein automatischer Dienststart sowie Rückkehr zum Hauptmenü. Die Abschlussmeldung benennt dabei ausdrücklich den Build-Skip.

### Gefundene und behobene Fehler

- Rohe `runuser`-, `id`-, `grep`- und `logrotate`-Fehler im Prüfmodus unterdrückt.
- Abbruch durch `false && usermod` auf Nicht-Raspberry-Pi-Systemen behoben.
- Kommentarlos übersprungenes Hardwareprofil auf Nicht-Pi-Systemen durch explizites Profil 0 ersetzt.
- Ursprünglich aktive `SimplexLogic` durch `RepeaterLogic` als Basislogik ersetzt.
- Rufzeichen nicht mehr nur in `SimplexLogic` gesetzt.
- Ungefilterte Logrotate-Debugausgabe unterdrückt.

## Simuliert validiert

- Die ELENATA-Simulation prüft die vom Hauptskript selbst erzeugte einmalige Post-Boot-ALSA-Unit, das Hilfsskript, Pending und sichere Modi. SvxLink wird dabei nicht gestartet.

- Idempotente ELENATA-Bootkonfiguration.
- ELENATA-Bootwerte werden im wirksamen `[all]` ergänzt, abweichende und doppelte verwaltete Werte werden ersetzt; `[cm4]` und `[cm5]` bleiben bytegleich erhalten.
- `-D`, `-D --check` und der Debug-Menüstart werden isoliert geprüft. Debuglogs werden nur in temporären Testpfaden erzeugt; der Normalmodus aktiviert kein Shell-Tracing.
- Erhalt fremder und kommentierter Bootzeilen.
- Rx-/Tx-Sektionsbearbeitung ohne doppelte oder falsch zugeordnete SQL-/PTT-Werte.
- Account-Setup für Raspberry Pi und Nicht-Raspberry-Pi.
- Nicht-Pi-Profil 0.

### `tests/simulate_sound_management.sh`

- Prüft Menüanzeige ohne Blockierung sowie die nicht-interaktiven CLI-Hinweise.
- Prüft das eingebettete Anna-16k-Archiv auf feste SHA-256 und Archivwurzel `de_DE-anna-16k/`.
- Installiert deutsche und englische Testarchive ausschließlich in temporäre Testpfade; kein Root und keine Netzwerkverbindung sind erforderlich.
- Prüft falsche Prüfsumme, Traversal, absolute Archivpfade und unsichere symbolische Links als kontrollierte Fehler; sichere interne Links des Anna-Archivs werden materialisiert.
- Prüft idempotente Soundprüfung, fehlende oder leere deutsche Verzeichnisse, Sicherung der SvxLink-Konfiguration und sektionsgenaue Sprachumschaltung für `SimplexLogic` und `RepeaterLogic`.
- Prüft, dass ein fehlendes `de_DE` die Konfiguration nicht ändert und dass andere Sektionen unverändert bleiben.
- Prüft keine Vollständigkeit, Audioheader oder Modulabdeckung deutscher Sounds, entsprechend der vorgesehenen Aktivierungslogik.
- Die feste englische Quelle ist Release `25.05` von `sm0svx/svxlink-sounds-en_US-heather`, Archiv `svxlink-sounds-en_US-heather-16k-25.05.tar.bz2`, SHA-256 `e79e61bec17a24fad093edfb21e7f8ca51af33b9590db954b4789271db2957dd` und Archivwurzel `en_US-heather-16k/`.
- Prüft kontrollierte Fehler bei fehlendem `curl`, `tar` und `bzip2`, ohne einen rohen `command not found`-Fehler zu erzeugen, sowie dass vorhandenes `en_US` weder curl noch erneutes Entpacken auslöst.

### `tests/simulate_root_backup_permissions.sh`

- Prüft den Produktivstart ohne Root: Exitcode ungleich 0 sowie den Hinweis `sudo ./svxlink_setup.sh`.
- Prüft Root-Hinweis im Header und die Root-Ausnahme im expliziten Testmodus.
- Prüft die Ermittlung von `SUDO_USER` und dessen Home über `getent`; ein direkter Root-Login verwendet definiert `root` und `/root`.
- Prüft, dass das Produktionsskript keine internen `sudo`-Befehle enthält.
- Prüft, dass `backup_directory` eine Metadaten erhaltende Kopie erzeugt und den Quellordner nicht entfernt.
- Prüft die Rechte für `de_DE` und `en_US`: Verzeichnisse `0755`, reguläre Dateien `0644`; andere Sprachordner und ein Symbolziel außerhalb des Sprachordners bleiben unverändert.
- Prüft, dass die Sprachaktivierung Rechte vor `DEFAULT_LANG` normalisiert und bei einem Rechtefehler keine Konfiguration verändert.
- Prüft den parameterlosen Start: Hauptmenü ohne Rufzeichen-, Profil-, Paket- oder Installationsaufruf; Menüpunkt 1 öffnet nur das Untermenü und erst dessen Punkt 1 startet den Installationspfad.
- Prüft, dass `--check` gezielt ohne Menü ausgeführt wird.
- Prüft den festen Headerrahmen sowie ANSI-freie Ausgabe mit `NO_COLOR`.

### `tests/simulate_build_decision.sh`

- Prüft fehlenden Buildstatus, passenden Buildstatus, geänderten Git-Commit, geänderte Buildoptionen und Force-Modus.
- Prüft atomar geschriebenen Buildstatus mit Modus `0644` sowie zeilenweises Einlesen ohne `source`-Ausführung.
- Prüft kombinierte Versionskennung, normalisierten Vergleich und dass beim passenden Status keine Build-Kommandos aufgerufen werden; der entsprechende Debian-13-VM-Lauf ist real bestätigt.

### `tests/simulate_legacy_profiles.sh`

- Zweck: Funktionssimulation der wiederhergestellten historischen Raspberry-Pi-Profile 1 bis 3 ohne Root, Netzwerkzugriff oder echte Systemänderungen.
- Prüft die Zuordnung: Profil 1 ICS Pi-Repeater, Profil 2 uSvxCard und Profil 3 WM8960 Audio-HAT. Profil 0 und die separate ELENATA-Simulation für Profil 4 bleiben davon unberührt.
- ICS: prüft `i2c-tools`, `i2c-dev`, die Deaktivierung von `snd-bcm2835` sowie die historischen Bootwerte `dtparam=audio=off`, `dtparam=i2c_arm=on`, `dtoverlay=fe-pi-audio`, `dtoverlay=i2s-mmap`, `dtoverlay=mcp23017,addr=0x20,gpiopin=12`, `dtoverlay=mcp3008:spi0-0-present,spi0-0-speed=3600000` und `enable_uart=1`.
- uSvxCard: prüft `blacklist snd_bcm2835`, die historischen Anpassungen in `snd-card.conf`, den gemockten Aufruf der Quelle `https://github.com/respeaker/seeed-voicecard.git` und `/etc/svxlink/gpio.conf` mit PTT GPIO17, Squelch GPIO23 und Taster GPIO24.
- WM8960: prüft den gemockten Aufruf der historischen Quelle `https://github.com/waveshare/WM8960-Audio-HAT`.
- Prüft wiederholte Läufe ohne doppelte Konfigurationseinträge, die Trennung der Profile und SHA-256-/Metadatenvergleiche relevanter echter Dateien vor und nach dem Test.
- Der Test mockt Paket- und Treiberinstallation. Er validiert weder Kernelmodule noch Treiberinstaller, Audio, GPIO oder Bootoverlays auf echter Hardware.

### `tests/simulate_elenata.sh`

- Zweck: sichere Funktionssimulation der Profil-4-Komponenten ohne Root. Der Test ist kein vollständiger Root-Installationslauf und keine Hardwarevalidierung.
- Testlauf in Debian 13 VM `svxlink-test` auf Commit `8781d0b`: ohne `sudo` ausgeführt, alle Testfälle bestanden und die überwachten echten Dateien blieben unverändert.
- ShellCheck wurde in dieser Debian-13-VM nicht durchgeführt, da das Programm nicht installiert war. ShellCheck wurde separat auf dem Entwicklungsrechner erfolgreich ausgeführt.
- Hardwarevalidierung bleibt offen.
- Der Test arbeitet ausschließlich in einem mit `mktemp -d` erzeugten Verzeichnis und entfernt dieses per `trap`.
- Produktionspfade sind nur mit `SVXLINK_TEST_MODE=true` überschreibbar. Ohne Testmodus gelten die festen Produktionspfade.
- Die Raspberry-Pi-Simulation ist nur mit `SVXLINK_TEST_MODE=true` und `SVXLINK_TEST_RASPBERRY_PI=true` aktiv.
- Das Produktionsskript wird über einen `BASH_SOURCE`-Guard sicher eingebunden; seine direkte Ausführung bleibt unverändert.

#### Bootkonfiguration

- Prüft die vollständigen `[all]`-Werte `dtparam=i2c0=on`, `dtparam=i2c1=on`, `dtparam=audio=off`, `dtoverlay=fe-pi-audio`, `dtoverlay=disable-bt`, `enable_uart=1`, `arm_boost=1`, `arm_64bit=1`, `gpu_mem=256`, `hdmi_force_hotplug=1`, `hdmi_group=2` und `hdmi_mode=16`.
- Fremde aktive und kommentierte Zeilen bleiben erhalten.
- `[cm4]` und `[cm5]` einschließlich ihrer abweichenden Werte bleiben unverändert; der verwaltete Marker ist ein gültiger Kommentar.
- Der zweite Lauf ist byte-identisch und erzeugt keine zweite Sicherung ohne Änderungsbedarf.
- Eine nicht beschreibbare temporäre Bootdatei erzeugt einen kontrollierten Fehler.

#### Profil-4-Konfiguration

| Abschnitt | Werte |
| --- | --- |
| `Rx1` | `AUDIO_DEV=alsa:hw:CARD=Audio,DEV=0`, `AUDIO_CHANNEL=0`, `SQL_DET=GPIOD`, `SQL_GPIOD_CHIP=gpiochip0`, `SQL_GPIOD_LINE=26` |
| `Tx1` | `AUDIO_DEV=alsa:hw:CARD=Audio,DEV=0`, `AUDIO_CHANNEL=0`, `PTT_TYPE=GPIOD`, `PTT_GPIOD_CHIP=gpiochip0`, `PTT_GPIOD_LINE=13` |
| `Rx2` | `AUDIO_DEV=alsa:hw:CARD=Audio,DEV=0`, `AUDIO_CHANNEL=1`, `SQL_DET=GPIOD`, `SQL_GPIOD_CHIP=gpiochip0`, `SQL_GPIOD_LINE=6` |
| `Tx2` | `AUDIO_DEV=alsa:hw:CARD=Audio,DEV=0`, `AUDIO_CHANNEL=1`, `PTT_TYPE=GPIOD`, `PTT_GPIOD_CHIP=gpiochip0`, `PTT_GPIOD_LINE=5` |

- Prüft `GLOBAL/LOGICS=RepeaterLogic` und `CALLSIGN` in `RepeaterLogic`.
- Prüft keine PTT-Schlüssel in `Rx1` und `Rx2`, keine SQL-Schlüssel in `Tx1` und `Tx2` sowie keine doppelten Schlüssel in `GLOBAL`, `RepeaterLogic`, `Rx1`, `Tx1`, `Rx2` und `Tx2`.
- Der erste und zweite Anschluss sind jeweils idempotent.

#### ALSA-Simulation

- Simuliert die Karte `Audio` und prüft die Verwendung der über `audio_card_number` ermittelten Kartennummer `2`.
- Prüft vollständig: `amixer -c Audio sset "Capture Mux" LINE_IN`, `amixer -c Audio sset Capture 6,6 unmute`, `amixer -c Audio sset Capture 8,5 unmute`, `amixer -c Audio sset "Capture Attenuate Switch (-6dB)" on`, `amixer -c Audio sset PCM 166,166`, `amixer -c Audio sset Lineout 21,21 unmute`, `amixer -c Audio sset AVC off`, `amixer -c Audio sset "AVC Hard Limiter" off` und `amixer -c Audio sset Mic 0`.
- Prüft `asactl store -f <temporäre-state-datei> 2` sowie das Anlegen der temporären ALSA-State-Datei.

#### Fehler- und Sicherheitsfälle

- Prüft fehlende Karte `Audio`, fehlenden Pflichtregler, fehlenden optionalen Regler, ungültigen Capture-Wert, nicht beschreibbare temporäre Bootdatei und fehlende `RepeaterLogic`-Sektion.
- Vor und nach dem Test werden SHA-256, Dateityp, Modus, UID, GID, Größe und Änderungszeit von `/boot/config.txt`, `/boot/firmware/config.txt`, `/etc/svxlink/svxlink.conf`, `/etc/default/svxlink` und `/etc/logrotate.d/svxlink` verglichen.
- Mock-Aufrufe werden protokolliert. Im aktuellen Komponententest werden `amixer`, `asactl`, `chown`, `chmod` und `logrotate` aufgerufen; `aplay`, `arecord`, `systemctl`, `usermod` und `getent` werden nicht aufgerufen und gelten daher nicht als getestet.

#### Validierung

```bash
bash -n svxlink_setup.sh
bash -n tests/simulate_elenata.sh
shellcheck -x tests/simulate_root_backup_permissions.sh
shellcheck -x svxlink_setup.sh tests/simulate_elenata.sh
git diff --check
tests/simulate_elenata.sh
tests/simulate_root_backup_permissions.sh
```

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
- Echter Installations- und Hörtest des eingebetteten Anna-16k-Satzes sowie des offiziellen englischen Satzes.
- Externe deutsche RepeaterLogic.
- Echte Hardwaretests für ICS Pi-Repeater, uSvxCard und WM8960 Audio-HAT auf aktueller Raspberry-Pi-OS-/Debian-13-Basis.

Hardwarefunktionen gelten bis zum erfolgreichen Test auf der jeweiligen Zielhardware als nicht hardwarevalidiert.
