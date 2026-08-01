# Changelog

## Unreleased

- Projektanforderungen und Testgrundlage dokumentiert.
- Erster Modernisierungsstand für Debian 12/13 und ELENATA Wolfson / Fe-Pi Audio dokumentiert.
- Deutsche RepeaterLogic bewusst auf eine spätere Integrationsphase verschoben; der Basisinstaller bleibt bei der Standard-RepeaterLogic.
- Debian-12/13-Erkennung und ein sauberer read-only-Prüfmodus ergänzt.
- Benutzer- und Rechteverwaltung sowie die Abschaltung automatischer Updates ergänzt.
- Offiziellen SvxLink-Build und RepeaterLogic als aktive Basislogik ergänzt.
- Idempotente Rufzeichenkonfiguration ergänzt.
- Profil 0 für Nicht-Raspberry-Pi-Systeme und ELENATA-Profil 4 für Raspberry Pi ergänzt.
- Logging und Logrotate ergänzt.
- Kontrollierten Umgang mit fehlenden deutschen Sounds ergänzt.
- Debian-13-VM-Basistest erfolgreich durchgeführt.
- Sicherer Profil-4-Funktionssimulationstest `tests/simulate_elenata.sh` hinzugefügt.
- Testpfade sind nur im expliziten Testmodus überschreibbar; ein `BASH_SOURCE`-Guard erlaubt das sichere Einbinden des Produktionsskripts.
- ELENATA-Bootkonfiguration idempotent gestaltet und Sicherungen auf tatsächlichen Änderungsbedarf beschränkt.
- Fehler bei nicht möglichem Boot-Schreibvorgang werden weitergegeben; fehlende Pflichtregler führen zu kontrollierten Fehlern.
- ALSA-State kann im Test in eine temporäre Datei geschrieben werden.
- Vollständige Prüfung der Profil-4-GPIO- und Audio-Konfiguration für einen und zwei Anschlüsse ergänzt.
- Hash- und Metadatenvergleich echter Systemdateien ergänzt.
- Profil-4-Test klar als Simulation ohne Hardwarevalidierung gekennzeichnet.
