# SvxLink Setup by DF5KX & DO6NP

Für eine deutsche Erklärung siehe weiter unten.

# English

## Purpose

The SvxLink Server is a general purpose voice services system which, when connected to a transceiver, can act as both an advanced repeater system and can also operate on a simplex channel.

## Current setup workflow

Run `sudo ./svxlink_setup.sh` without parameters to open the interactive menu. It provides installation or update, read-only status, backup management, language installation and activation, and a safe configuration summary. The same actions are available through `--help`; non-interactive write actions require `--yes`.

The production program requires root privileges and stops before changing the system when started without root. `sudo ./svxlink_setup.sh` preserves the invoking user from `SUDO_USER` for source and build directories; a direct root login deliberately uses `/root`. The isolated test mode does not require root.

Before a build, the installer installs and verifies required tools including `curl`, `tar`, `bzip2`, checksum, Git and build tools. Status output uses textual status labels; ANSI colors are used only on a terminal and are disabled by `NO_COLOR` and redirected output.

Normal updates use `/var/lib/svxlink-setup/build-state` to compare the source commit, version, platform, compiler and CMake option signature. Matching builds are skipped; forced reinstallations always rebuild. Technical command output is recorded in `/var/log/svxlink-setup/` while the terminal remains concise.

The normal installation installs the official English SvxLink sound release `25.05` and the bundled German Anna 16k archive. The English download uses HTTPS and the fixed SHA-256 `e79e61bec17a24fad093edfb21e7f8ca51af33b9590db954b4789271db2957dd`. German becomes the default language only after its archive has been verified and installed successfully; otherwise English remains active. The Anna archive provenance and checksum are documented in `resources/sounds/de_DE-anna-16k.SOURCE.md`. The project does not claim ownership of its recordings and does not claim that its unresolved licence and redistribution status is free.

Only the selected `de_DE` or `en_US` sound directory is normalized: owner and group `svxlink`, directories `0755`, regular files `0644`. Symbolic-link targets and other local languages are not changed. The same normalization happens before a language is activated.

The SvxLink setup script arose from the requirement to establish a simple solution for the local NordWestLink network in order to provide all repeaters with the same current version of SvxLink. Chris, DF5KX, wrote the first lines of bash code based on an idea of NJ6N. Nils, DO6NP, added some more lines and that's how the storry goes. :-) The small script has meanwhile become a comprehensive setup solution for SvxLink.

## Features

The script offers the following features:

* Installing SvxLink on a Raspberry Pi or Debian “Bookworm”
* Always installing the latest “master” branch
* Setting up various HATs for connecting to repeaters including installation of all required drivers and setup of all needed GPIO ports (RPi only)
* Getting all the content you need right from Git
* Compiling from the most recent Trunks
* Importing SvxLink sound files
* Otimizing various system parameters (Rpi only)
* Messages shown optionally in English or German

## Supported HATs

The following Raspberry Pi HAT's are currently supported:

0. No Raspberry Pi audio profile
1. ICS Pi-Repeater
2. uSvxCard by F5SWB & F8ASB including Seeed VoiceCard
3. WM8960 Audio HAT
4. ELENATA Wolfson / Fe-Pi Audio

Profiles 1 to 3 were restored from the historical installer implementation. Their driver branches are not pinned and need current-hardware validation; the separate ELENATA profile 4 is component-simulated but not hardware-validated.

## Installation

We assume that we are dealing with a freshly installed Raspberry Pi with the current Raspbian / Raspberry Pi OS or Debian 11 “Bookworm” installed.

To run the script, please do the following:

1. First, update the system and download the current version of the script:
```
$ sudo apt-get update 
$ sudo apt-get upgrade
$ sudo apt-get install git
$ git clone https://github.com/do6np/svxlink_setup.git
```

2. Change directory and make the script executable:
```
$ cd svxlink_setup
$ chmod +x svxlink_setup.sh
```

3. Run script:
```
$ sudo ./svxlink_setup.sh
```

Or, if you realy like to write a debug log (development only):
```
$ sudo ./svxlink_setup.sh -D
```

4. Answer all questions and enter credentials.

5. Enjoy!

## Important notes

This script can only be a tool to help you quickly install SvxLink on your computer. It in no way replaces the need to familiarize yourself intensively with the concept and setup of SvxLink. Especially if you plan to run SvxLink as a repeater controller, you should know exactly what you are doing and how everything works together. Tobias, SM0SVX, instructions explain all the components and settings in detail. Help is also available on the [corresponding forum](https://groups.io/g/svxlink).

Please also note that SvxLink is constantly being developed. You should therefore also pay attention to the information in the [changelog](https://github.com/sm0svx/svxlink/blob/master/src/svxlink/ChangeLog).

## Further development

We have to admit, neither of us is a pro in Bash. We just put our kitchen knowledge together and tried to make the best of it. So there are definitely things that need to be improved. Perhaps you have some completely new ideas that we haven't even thought of yet? Feel free to use Git and send us your commits. We are always happy to receive your suggestions!

# German / Deutsch

## Zweck

SvxLink ist ein multifunktionaler Server für den Einsatz im Amateurfunk, mit dem sich sowohl ein erweitertes Relais-System als auch ein Simplex-Node umsetzen lässt. SvxLink wird von Tobias Blomberg, SM0SVX, entwickelt und kostenfrei als Open-Source-Lösung auf Github bereitgestellt.

Dieses Setup-Skript entstand aus dem Wunsch, eine einfache Lösung für das [NordWestLink](https://nordwestlink.net)-Netzwerk zu schaffen, um alle Relais mit der gleichen aktuellen Version von SvxLink auszustatten. Chris, DF5KX, schrieb die ersten Zeilen des Bash-Codes, basierend auf einer Idee von NJ6N. Nils, DO6NP, fügte noch ein paar Zeilen hinzu und ... aus dem kleinen Skript ist inzwischen eine umfassende Setup-Lösung für SvxLink geworden.

## Eigenschaften

Das Skript bietet die folgenden Funktionen:

* Installation von SvxLink auf einem Raspberry Pi oder Debian "Bookworm"
* Installation des jeweils neuesten "Master"-Zweigs
* Einrichten verschiedener HATs für den Anschluss an Repeater, einschließlich der Installation aller benötigten Treiber und der Einrichtung der GPIO-Ports (nur RPi)
* Bezug aller Inhalte direkt von Github
* Kompilieren der aktuellsten Trunks
* Importieren von SvxLink-Sounddateien (Deutsch + Englisch)
* Optimierung verschiedener Systemparameter (nur Rpi)
* Anzeige der Meldungen wahlweise in Englisch oder Deutsch
* Eintragen der wichtigsten Parameter in die SvxLink-Konfigurationsdateien

## Unterstützte HATs

Die folgenden Raspberry-Pi-Profile werden derzeit unterstützt:

0. Kein Raspberry-Pi-Audioprofil
1. ICS Pi-Repeater
2. uSvxCard von F5SWB und F8ASB einschließlich Seeed VoiceCard
3. WM8960 Audio-HAT
4. ELENATA Wolfson / Fe-Pi Audio

Die Profile 1 bis 3 wurden aus der historischen Installer-Implementierung wiederhergestellt. Ihre Treiberzweige sind nicht gepinnt und müssen auf aktueller Zielhardware noch validiert werden; Profil 4 ist separat komponentensimuliert, aber ebenfalls noch nicht hardwarevalidiert.

## Installation

Das Skript geht davon aus, dass wir es mit einem frisch installierten Raspberry Pi oder PC zu tun haben, auf dem das aktuelle Raspbian oder Debian 11 "Bookworm" installiert ist. 

Die read-only Aufrufe `./svxlink_setup.sh --help`, `--check` und `--show-config` sowie das Hauptmenü funktionieren ohne Root. Erst schreibende Aktionen benötigen Root und nennen bei fehlenden Rechten die passende `sudo`-Variante. Bei einem Start über `sudo` werden Quell- und Build-Verzeichnisse über `SUDO_USER` im Home des aufrufenden Benutzers angelegt; ein direkter Root-Login verwendet bewusst `/root`. Der isolierte Testmodus benötigt keine Root-Rechte.

Beim Update wird die SvxLink-Releaseversion normalisiert verglichen. Die in manchen Binärdateien sichtbare interne Kennung `1.10.1` ist nicht die Releaseversion: Aus `1.10.1@26.05.1` wird gezielt `26.05.1` ermittelt. Ist die Releaseversion nicht eindeutig feststellbar, wird aus Sicherheitsgründen neu gebaut.

Ein unveränderter Update-Lauf wurde auf Debian 13 erfolgreich geprüft: CMake, Build und Installation werden übersprungen, während Profil-, Sound- und Sprachprüfungen weiterlaufen. Vor jedem Sounddownload prüft das Skript den vorhandenen Bestand anhand nicht leerer WAV-Dateien. Vollständige deutsche und englische Pakete bleiben erhalten und werden nicht erneut geladen oder entpackt; sichtbare Abschlussmeldungen unterscheiden Build, Skip und Soundfehler.

Für die Sprachordner `de_DE` und `en_US` werden jeweils nur der gewählte Ordner und dessen reguläre Dateien berechtigt: `svxlink:svxlink`, Verzeichnisse `0755`, reguläre Dateien `0644`. Andere Sprachen und Ziele symbolischer Links bleiben unverändert.

Um das Skript auszuführen, gehe bitte wie folgt vor:

1. Aktualisiere Dein System und lade anschließend die aktuelle Version des Skripts herunter:
```
$ sudo apt-get update 
$ sudo apt-get upgrade
$ sudo apt-get install git
$ git clone https://github.com/do6np/svxlink_setup.git
```

2. Wechsle das Verzeichnis und mache das Skript ausführbar:
```
$ cd svxlink_setup
$ chmod +x svxlink_setup.sh
```

3. Führe es aus:
```
$ sudo ./svxlink_setup.sh
```

Oder, falls Du ein Debug-Log schreiben möchtest (benötigen eigentlich nur Entwickler):
```
$ sudo ./svxlink_setup.sh -D
```

4. Beantworte alle Fragen und trage die erforderlichen Daten ein.

5. Fahre mit der Einrichtung von SvxLink fort.

## Wichtige Hinweise

Dieses Skript kann nur ein Hilfswerkzeug sein, um die Basis für SvxLink möglichst schnell auf Deinem Computer einzurichten. Es ersetzt jedoch keinesfalls die Notwendigkeit, Dich intensiv mit dem Konzept sowie der Einrichtung von SvxLink auseinanderzusetzen. Insbesondere dann, wenn Du SvxLink als Relais-Steuerung einsetzen möchtest, solltest Du genau wissen, was Du tust und wie alles funktioniert und miteinander zusammenhängt. Die Anleitungen von Tobias Blomberg, SM0SVX, erklären alle Bestandteile und Einstellungen im Detail. Hilfe gibt es auch im zugehörigen [Forum](https://groups.io/g/svxlink).

Bitte beachte auch, dass SvxLink ständig weiterentwickelt wird. Du solltest daher unbedingt auch die Informationen im [Changelog](https://github.com/sm0svx/svxlink/blob/master/src/svxlink/ChangeLog) beachten. Ehrlicherweise müssen wir allerdings darauf hinweisen, dass zur Beschäftigung mit SvxLink Kenntnisse der englischen Sprache unerlässlich sind, da nur wenige aktuelle Informationen in deutscher Sprache vorliegen und die Entwicklung in einer weltweiten Gemeinschaft stattfindet.

## Weiterentwicklung und Verbesserungen

Wir geben es gern zu, wir sind beide keine Bash-Profis. Wir haben nur unser Amateur(funk)wissen zusammengeworfen und versucht, das Beste daraus zu machen. Daher gibt es bestimmt Dinge, die an diesem Setup noch verbessert werden können. Vielleicht hast Du auch noch ganz neue Ideen, auf die wir bislang gar nicht gekommen sind? Nutze gerne Git und sende uns Deine Commits. Wir freuen uns immer sehr über konstruktive Vorschläge!

# Contact / Kontakt

* **E-Mail:** Nils, <do6np@darc.de>
* **Mastodon:** @DO6NP@social.darc.de
