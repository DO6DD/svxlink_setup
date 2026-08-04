#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2155

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT
# shellcheck disable=SC1091
source "${ROOT}/tests/test_output.sh"
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
export SVXLINK_TEST_MODE=true
export SVXLINK_CONFIG_FILE="${TEMP_DIR}/svxlink.conf"
export SVXLINK_SOUNDS_DIR="${TEMP_DIR}/sounds"
export SVXLINK_BACKUP_DIR="${TEMP_DIR}/backups"
export SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/logs"
export SVXLINK_DEBUG_LOG_DIR="${TEMP_DIR}/debug"

failures=0
successes=0
cleanup() { rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT
fail() { test_line '[FEHLER]' "$*" >&2; failures=$((failures + 1)); }
pass() { test_line '[ OK ]' "$*"; successes=$((successes + 1)); }
expect_file() { [[ -f $1 ]] && pass "$2" || fail "$2"; }
expect_value() { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (expected $2, got $1)"; }

make_archive() {
    local root_name=$1 archive=$2 source
    source="${TEMP_DIR}/${root_name}"
    mkdir -p "${source}/Core" "${source}/Default"
    printf x >"${source}/Core/online.wav"
    printf x >"${source}/Default/0.wav"
    tar -cjf "${archive}" -C "${TEMP_DIR}" "${root_name}"
    rm -rf "${source}"
}

make_unsafe_archive() {
    local kind=$1 archive=$2 source="${TEMP_DIR}/unsafe"
    mkdir -p "${source}"
    : >"${source}/bad.wav"
    case ${kind} in
        traversal) tar -cjf "${archive}" --transform='s#^#../#' -C "${TEMP_DIR}" unsafe ;;
        absolute) tar -cjf "${archive}" --transform='s#^#/unsafe/#' -C "${TEMP_DIR}" unsafe ;;
        link) ln -s target "${source}/link.wav"; tar -cjf "${archive}" -C "${TEMP_DIR}" unsafe ;;
    esac
    rm -rf "${source}"
}

assert_unchanged() {
    local before=$1 target=$2 label=$3
    expect_value "$(sha256sum "${target}" | awk '{print $1}')" "${before}" "${label}"
}

snapshot_production_paths() {
    local phase=$1 path output
    for path in /etc/svxlink/svxlink.conf /usr/share/svxlink/sounds /var/backups/svxlink-setup; do
        output="${TEMP_DIR}/${phase}-${path//\//_}"
        if [[ -d ${path} ]]; then
            find "${path}" -printf '%y|%p|%s|%m|%u|%g|%T@\n' 2>/dev/null | sort | sha256sum >"${output}"
        elif [[ -f ${path} ]]; then
            sha256sum "${path}" >"${output}"
            stat -c '%F|%a|%u|%g|%s|%Y' "${path}" >>"${output}"
        else
            printf absent >"${output}"
        fi
    done
}

assert_production_paths_unchanged() {
    local path before after
    for path in /etc/svxlink/svxlink.conf /usr/share/svxlink/sounds /var/backups/svxlink-setup; do
        before="${TEMP_DIR}/before-${path//\//_}"
        after="${TEMP_DIR}/after-${path//\//_}"
        cmp -s "${before}" "${after}" && pass "unchanged ${path}" || fail "changed ${path}"
    done
}

enable_german_curl_mock() {
    # shellcheck disable=SC2317
    curl() {
        local argument config_file='' output_file='' head=false
        while (($#)); do
            argument=$1
            case ${argument} in
                --config) config_file=$2; shift 2 ;;
                --head) head=true; shift ;;
                -o|--output) output_file=$2; shift 2 ;;
                *) shift ;;
            esac
        done
        if ${head}; then printf '%s' "$(stat -c %s "${GERMAN_SOUND_TEST_ARCHIVE}")"; return 0; fi
        printf 'curl\n' >>"${TEMP_DIR}/german-curl-calls"
        printf '%s\n' "${config_file}" >"${TEMP_DIR}/german-curl-config-path"
        printf '%s\n' "${output_file}" >"${TEMP_DIR}/german-curl-output-path"
        stat -c '%a' "${config_file}" >"${TEMP_DIR}/german-curl-config-mode"
        cp "${config_file}" "${TEMP_DIR}/german-curl-config-capture"
        if [[ ${GERMAN_SOUND_TEST_MODE:-success} == unauthorized ]]; then
            printf 'curl: (22) The requested URL returned error: 401\n' >&2
            return 22
        fi
        cp "${GERMAN_SOUND_TEST_ARCHIVE}" "${output_file}"
    }
}

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR
test_line '[TEST]' 'Soundverwaltungs-Simulation'

mkdir -p "${TEMP_DIR}/real-layout/sounds/de_DE/Core" "${TEMP_DIR}/real-layout/sounds/en_US"
printf x >"${TEMP_DIR}/real-layout/sounds/de_DE/Core/online.wav"
printf x >"${TEMP_DIR}/real-layout/sounds/en_US/unexpected.wav"
tar -cjf "${TEMP_DIR}/real-layout.tar.bz2" --no-recursion -C "${TEMP_DIR}/real-layout" sounds sounds/de_DE sounds/de_DE/Core
sound_archive_is_safe "${TEMP_DIR}/real-layout.tar.bz2" sounds/de_DE && pass 'archive accepts required parent directories of sounds/de_DE' || fail 'archive must accept required parent directories'
mkdir -p "${TEMP_DIR}/special-names/sounds/de_DE"
printf x >"${TEMP_DIR}/special-names/sounds/de_DE/Verkehr Info #9.wav"
printf x >"${TEMP_DIR}/special-names/sounds/de_DE/mehrere   Leerzeichen.wav"
printf x >"${TEMP_DIR}/special-names/sounds/de_DE/Tab$(printf '\t')Name.wav"
printf x >"${TEMP_DIR}/special-names/sounds/de_DE/Grüße.wav"
tar -cjf "${TEMP_DIR}/special-names.tar.bz2" -C "${TEMP_DIR}/special-names" sounds
sound_archive_is_safe "${TEMP_DIR}/special-names.tar.bz2" sounds/de_DE && pass 'archive accepts spaces, #, tabs, and Unicode in valid member names' || fail 'valid special member names must be retained exactly'
mkdir -p "${TEMP_DIR}/root-file/sounds/de_DE"
printf x >"${TEMP_DIR}/root-file/sounds/de_DE/online.wav"
printf x >"${TEMP_DIR}/root-file/#9.wav"
tar -cjf "${TEMP_DIR}/root-file.tar.bz2" -C "${TEMP_DIR}/root-file" sounds '#9.wav'
if sound_archive_is_safe "${TEMP_DIR}/root-file.tar.bz2" sounds/de_DE; then fail 'root #9.wav must be rejected'; else pass 'archive rejects genuine root #9.wav'; fi
tar -cjf "${TEMP_DIR}/sibling-layout.tar.bz2" -C "${TEMP_DIR}/real-layout" sounds
if sound_archive_is_safe "${TEMP_DIR}/sibling-layout.tar.bz2" sounds/de_DE; then fail 'archive sibling path must be rejected'; else pass 'archive rejects sounds/en_US sibling path'; fi
mkdir -p "${TEMP_DIR}/escaping-link/sounds/de_DE/Core"
printf x >"${TEMP_DIR}/escaping-link/sounds/de_DE/Core/online.wav"
ln -s ../../outside.wav "${TEMP_DIR}/escaping-link/sounds/de_DE/escape.wav"
tar -cjf "${TEMP_DIR}/escaping-link.tar.bz2" -C "${TEMP_DIR}/escaping-link" sounds
if sound_archive_is_safe "${TEMP_DIR}/escaping-link.tar.bz2" sounds/de_DE; then fail 'archive link escaping expected root must be rejected'; else pass 'archive rejects symbolic link escaping expected root'; fi
mkdir -p "${TEMP_DIR}/english-links/en_US-heather-16k/Core" "${TEMP_DIR}/english-links/en_US-heather-16k/EchoLink" "${TEMP_DIR}/english-links/en_US-heather-16k/Links with spaces"
printf x >"${TEMP_DIR}/english-links/en_US-heather-16k/Core/repeater.wav"
printf x >"${TEMP_DIR}/english-links/en_US-heather-16k/Core/Datei #9.wav"
ln -s ../Core/repeater.wav "${TEMP_DIR}/english-links/en_US-heather-16k/EchoLink/repeater.wav"
ln -s ../EchoLink/repeater.wav "${TEMP_DIR}/english-links/en_US-heather-16k/Links with spaces/verschachtelt #9.wav"
ln -s '../Core/Datei #9.wav' "${TEMP_DIR}/english-links/en_US-heather-16k/EchoLink/Link mit Leerzeichen #.wav"
ln "${TEMP_DIR}/english-links/en_US-heather-16k/Core/repeater.wav" "${TEMP_DIR}/english-links/en_US-heather-16k/EchoLink/repeater-hard.wav"
tar -cjf "${TEMP_DIR}/english-links.tar.bz2" -C "${TEMP_DIR}/english-links" en_US-heather-16k
sound_archive_is_safe "${TEMP_DIR}/english-links.tar.bz2" en_US-heather-16k && pass 'English archive accepts internal relative, nested, special-name, and hard links' || fail 'internal English archive links must be accepted'
mkdir -p "${TEMP_DIR}/absolute-link/en_US-heather-16k"
ln -s /etc/passwd "${TEMP_DIR}/absolute-link/en_US-heather-16k/absolute.wav"
tar -cjf "${TEMP_DIR}/absolute-link.tar.bz2" -C "${TEMP_DIR}/absolute-link" en_US-heather-16k
if sound_archive_is_safe "${TEMP_DIR}/absolute-link.tar.bz2" en_US-heather-16k; then fail 'absolute symbolic link must be rejected'; else pass 'archive rejects absolute symbolic link'; fi
mkdir -p "${TEMP_DIR}/outside-link/en_US-heather-16k/EchoLink"
ln -s ../../outside.wav "${TEMP_DIR}/outside-link/en_US-heather-16k/EchoLink/outside.wav"
tar -cjf "${TEMP_DIR}/outside-link.tar.bz2" -C "${TEMP_DIR}/outside-link" en_US-heather-16k
if sound_archive_is_safe "${TEMP_DIR}/outside-link.tar.bz2" en_US-heather-16k; then fail 'escaping symbolic link must be rejected'; else pass 'archive rejects escaping symbolic link'; fi
mkdir -p "${TEMP_DIR}/outside-hardlink/en_US-heather-16k/EchoLink"
printf x >"${TEMP_DIR}/outside-hardlink/outside.wav"
ln "${TEMP_DIR}/outside-hardlink/outside.wav" "${TEMP_DIR}/outside-hardlink/en_US-heather-16k/EchoLink/outside-hard.wav"
tar -cjf "${TEMP_DIR}/outside-hardlink.tar.bz2" -C "${TEMP_DIR}/outside-hardlink" en_US-heather-16k outside.wav
if sound_archive_is_safe "${TEMP_DIR}/outside-hardlink.tar.bz2" en_US-heather-16k; then fail 'outside hard link must be rejected'; else pass 'archive rejects hard link outside expected root'; fi
archive_hardlink_target_is_safe 'en_US-heather-16k/Core/repeater.wav' en_US-heather-16k && pass 'hard link target within expected root is accepted' || fail 'internal hard link target must be accepted'
if archive_hardlink_target_is_safe outside.wav en_US-heather-16k; then fail 'hard link target outside expected root must be rejected'; else pass 'hard link target outside expected root is rejected'; fi

require_root() { :; }
snapshot_production_paths before

printf '%s\n' '[GLOBAL]' 'LOGICS=RepeaterLogic' '[SimplexLogic]' 'DEFAULT_LANG=en_US' '[RepeaterLogic]' 'DEFAULT_LANG=en_US' '[Other]' 'DEFAULT_LANG=keep' >"${SVXLINK_CONFIG}"

make_archive "${GERMAN_SOUND_ROOT}" "${TEMP_DIR}/german-download.tar.bz2"
export GERMAN_SOUND_TEST_ARCHIVE="${TEMP_DIR}/german-download.tar.bz2"
export GERMAN_SOUND_TEST_PASSWORD='sound-test-password'
export GERMAN_SOUND_SHA256_OVERRIDE=$(sha256sum "${GERMAN_SOUND_TEST_ARCHIVE}" | awk '{print $1}')
enable_german_curl_mock
GERMAN_SOUND_TEST_MODE=success
DEBUG_MODE=true
start_debug_log
if install_german_sounds >"${TEMP_DIR}/german-success.out" 2>&1; then
    pass 'authenticated German download succeeds'
else
    fail "authenticated German download failed: $(<"${TEMP_DIR}/german-success.out")"
fi
set +x
expect_file "${SVXLINK_SOUNDS_DIR}/de_DE/Core/online.wav" 'authenticated German download installs sounds/de_DE'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE")" 755 'German sound directory permissions'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE/Core/online.wav")" 644 'German sound file permissions'
grep -Fqx "${GERMAN_SOUND_ROOT}/" < <(tar -tjf "${GERMAN_SOUND_TEST_ARCHIVE}") && pass 'German archive root is sounds/de_DE' || fail 'German archive root must be sounds/de_DE'
grep -Fqx 'user = "xYa3dWLK9NtAer4:sound-test-password"' "${TEMP_DIR}/german-curl-config-capture" && pass 'German download uses authenticated curl configuration' || fail 'German download must use authenticated curl configuration'
expect_value "$(cat "${TEMP_DIR}/german-curl-config-mode")" 600 'temporary curl configuration mode'
expect_value "$(basename "$(cat "${TEMP_DIR}/german-curl-output-path")")" svxlink-sounds-de_DE-nextcloud.tar.bz2 'German download uses fixed local archive name'
[[ ! -e $(cat "${TEMP_DIR}/german-curl-config-path") && ! -e $(cat "${TEMP_DIR}/german-curl-output-path") ]] && pass 'German temporary credentials and download removed after success' || fail 'German temporary credentials and download must be removed after success'
if grep -Fq "${GERMAN_SOUND_TEST_PASSWORD}" "${TEMP_DIR}/german-success.out" "${DEBUG_LOG_FILE}"; then fail 'German password must not appear in output or debug log'; else pass 'German password is absent from output and debug log'; fi
german_hash=$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')
german_curl_calls=$(wc -l <"${TEMP_DIR}/german-curl-calls")
install_german_sounds
expect_value "$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')" "${german_hash}" 'German installation idempotent'
expect_value "$(wc -l <"${TEMP_DIR}/german-curl-calls")" "${german_curl_calls}" 'existing German sounds do not download again'

rm -rf "${SVXLINK_SOUNDS_DIR}/de_DE"
export GERMAN_SOUND_SHA256_OVERRIDE=deadbeef
if install_german_sounds >/dev/null 2>&1; then fail 'wrong German checksum must fail'; else pass 'wrong German checksum rejected'; fi
[[ ! -e ${SVXLINK_SOUNDS_DIR}/de_DE ]] && pass 'wrong checksum leaves target unchanged' || fail 'wrong checksum leaves target unchanged'
[[ ! -e $(cat "${TEMP_DIR}/german-curl-config-path") && ! -e $(cat "${TEMP_DIR}/german-curl-output-path") ]] && pass 'German temporary credentials and download removed after checksum failure' || fail 'German temporary files must be removed after checksum failure'
export GERMAN_SOUND_SHA256_OVERRIDE=$(sha256sum "${GERMAN_SOUND_TEST_ARCHIVE}" | awk '{print $1}')

mkdir -p "${SVXLINK_SOUNDS_DIR}/de_DE"
printf previous >"${SVXLINK_SOUNDS_DIR}/de_DE/previous.txt"
german_previous_hash=$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')
GERMAN_SOUND_TEST_MODE=unauthorized
german_curl_calls=$(wc -l <"${TEMP_DIR}/german-curl-calls")
if install_german_sounds >"${TEMP_DIR}/german-401.out" 2>&1; then fail 'HTTP 401 must fail German download'; else pass 'HTTP 401 rejects German download'; fi
expect_value "$(( $(wc -l <"${TEMP_DIR}/german-curl-calls") - german_curl_calls ))" 3 'HTTP 401 uses exactly three password attempts'
grep -Fq 'Bei HTTP 401 bitte Passwort und Zugriffsrechte prüfen.' "${TEMP_DIR}/german-401.out" && pass 'HTTP 401 emits clear German authentication error' || fail 'HTTP 401 must emit clear German authentication error'
expect_value "$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')" "${german_previous_hash}" 'HTTP 401 leaves existing German sounds unchanged'
[[ ! -e $(cat "${TEMP_DIR}/german-curl-config-path") && ! -e $(cat "${TEMP_DIR}/german-curl-output-path") ]] && pass 'German temporary credentials and download removed after HTTP 401' || fail 'German temporary files must be removed after HTTP 401'
rm -rf "${SVXLINK_SOUNDS_DIR}/de_DE"
GERMAN_SOUND_TEST_MODE=success

for kind in traversal absolute link; do
    make_unsafe_archive "${kind}" "${TEMP_DIR}/${kind}.tar.bz2"
    if install_sound_archive "${TEMP_DIR}/${kind}.tar.bz2" "$(sha256sum "${TEMP_DIR}/${kind}.tar.bz2" | awk '{print $1}')" unsafe de_DE false >/dev/null 2>&1; then
        fail "${kind} archive must fail"
    else
        pass "${kind} archive rejected"
    fi
done

mkdir -p "${SVXLINK_SOUNDS_DIR}/de_DE"
: >"${SVXLINK_SOUNDS_DIR}/de_DE/local.wav"
install_german_sounds
expect_file "${SVXLINK_SOUNDS_DIR}/de_DE/Core/online.wav" 'empty German directory is replaced from authenticated download'
rm -rf "${SVXLINK_SOUNDS_DIR}/de_DE"

make_archive "${ENGLISH_SOUND_ROOT}" "${TEMP_DIR}/english.tar.bz2"
export ENGLISH_SOUND_ARCHIVE="${TEMP_DIR}/english.tar.bz2"
export ENGLISH_SOUND_SHA256_OVERRIDE=$(sha256sum "${ENGLISH_SOUND_ARCHIVE}" | awk '{print $1}')
install_english_sounds
expect_file "${SVXLINK_SOUNDS_DIR}/en_US/Core/online.wav" 'English installation from mock archive'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US")" 755 'English sound directory permissions'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US/Core/online.wav")" 644 'English sound file permissions'

english_hash=$(find "${SVXLINK_SOUNDS_DIR}/en_US" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')
# shellcheck disable=SC2317
curl() { printf 'CURL_CALLED\n'; return 1; }
install_english_sounds >"${TEMP_DIR}/english-present.out"
unset -f curl
enable_german_curl_mock
expect_value "$(find "${SVXLINK_SOUNDS_DIR}/en_US" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')" "${english_hash}" 'existing English sounds are not extracted again'
grep -Fq 'Download wird übersprungen.' "${TEMP_DIR}/english-present.out" && pass 'existing English sounds prevent download' || fail 'existing English sounds must prevent download'
grep -Fq 'CURL_CALLED' "${TEMP_DIR}/english-present.out" && fail 'existing English sounds must not call curl' || pass 'existing English sounds do not call curl'

rm -rf "${SVXLINK_SOUNDS_DIR}/en_US"
export SVXLINK_TEST_MISSING_COMMANDS=curl
if install_english_sounds >"${TEMP_DIR}/missing-curl.out" 2>&1; then fail 'missing curl must fail cleanly'; else pass 'missing curl is rejected before download'; fi
grep -Fq 'Erforderliches Programm fehlt: curl' "${TEMP_DIR}/missing-curl.out" && pass 'missing curl names dependency' || fail 'missing curl names dependency'
grep -Fq 'curl: Kommando nicht gefunden' "${TEMP_DIR}/missing-curl.out" && fail 'missing curl has no raw shell error' || pass 'missing curl has no raw shell error'
export SVXLINK_TEST_MISSING_COMMANDS=tar
if install_german_sounds >"${TEMP_DIR}/missing-tar.out" 2>&1; then fail 'missing tar must fail cleanly'; else pass 'missing tar is rejected before archive handling'; fi
grep -Fq 'Erforderliches Programm fehlt: tar' "${TEMP_DIR}/missing-tar.out" && pass 'missing tar names dependency' || fail 'missing tar names dependency'
export SVXLINK_TEST_MISSING_COMMANDS=bzip2
if install_german_sounds >"${TEMP_DIR}/missing-bzip2.out" 2>&1; then fail 'missing bzip2 must fail cleanly'; else pass 'missing bzip2 is rejected before archive handling'; fi
grep -Fq 'Erforderliches Programm fehlt: bzip2' "${TEMP_DIR}/missing-bzip2.out" && pass 'missing bzip2 names dependency' || fail 'missing bzip2 names dependency'
unset SVXLINK_TEST_MISSING_COMMANDS
install_english_sounds

if activate_sound_language de_DE false >/dev/null 2>&1; then fail 'missing German language must not activate'; else pass 'missing German language leaves configuration unchanged'; fi
expect_value "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" en_US 'Simplex remains English when German missing'
install_german_sounds
activate_sound_language de_DE false
expect_value "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" de_DE 'Simplex language activation'
expect_value "$(ini_value "${SVXLINK_CONFIG}" RepeaterLogic DEFAULT_LANG)" de_DE 'Repeater language activation'
expect_value "$(ini_value "${SVXLINK_CONFIG}" Other DEFAULT_LANG)" keep 'unrelated section preserved'
find "${SVXLINK_BACKUP_DIR}" -type f -print -quit | grep -q . && pass 'configuration backup created' || fail 'configuration backup created'
config_hash=$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')
activate_sound_language de_DE false
expect_value "$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')" "${config_hash}" 'language activation idempotent'
activate_sound_language en_US false
expect_value "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" en_US 'English can be activated'
expect_value "$(ini_value "${SVXLINK_CONFIG}" RepeaterLogic DEFAULT_LANG)" en_US 'English activated for RepeaterLogic'

menu_output=$(printf '9\n' | main)
[[ ${menu_output} == *'SVXLINK SETUP'* && ${menu_output} == *'DF5KX'* && ${menu_output} == *'DO6DD'* ]] && pass 'menu header is shown without hanging' || fail 'menu header is shown without hanging'
for item in '1) Installieren / aktualisieren' '2) Systemstand anzeigen' '3) Backup erstellen / wiederherstellen' '4) Deutsche Sounds installieren' '5) Englische Sounds installieren' '6) Deutsch aktivieren' '7) Englisch aktivieren' '8) Konfiguration anzeigen' '9) Beenden'; do
    [[ ${menu_output} == *"${item}"* ]] || fail "menu item missing: ${item}"
done
install_menu_output=$(printf '3\n' | install_menu)
[[ ${install_menu_output} == *'INSTALLIEREN / AKTUALISIEREN'* && ${install_menu_output} == *'1) Automatisch installieren oder aktualisieren'* && ${install_menu_output} == *'2) Erzwungene Neuinstallation'* ]] && pass 'installation submenu is reachable' || fail 'installation submenu is reachable'
backup_menu_output=$(printf '4\n' | backup_menu)
[[ ${backup_menu_output} == *'BACKUP'* && ${backup_menu_output} == *'1) Neues Backup erstellen'* && ${backup_menu_output} == *'2) Vorhandenes Backup wiederherstellen'* ]] && pass 'backup submenu is reachable' || fail 'backup submenu is reachable'
help_output=$(main --help)
[[ ${help_output} == *'--install-german-sounds'* ]] && pass 'CLI help includes sound actions' || fail 'CLI help includes sound actions'
ACTION_YES=true
summary_output=$(confirm_installation Update)
[[ ${summary_output} == *'Deutsche Sounds:    werden geprüft'* && ${summary_output} == *'Englische Sounds:   werden geprüft'* && ${summary_output} == *'Deutsch wird geprüft und bei Bedarf aktiviert'* ]] && pass 'installation summary describes sound checks neutrally' || fail 'installation summary must describe sound checks neutrally'
snapshot_production_paths after
assert_production_paths_unchanged

printf '\n============================================================\nTESTERGEBNIS\n============================================================\nErfolgreich: %d\nWarnungen:   0\nFehler:      %d\n' "${successes}" "${failures}"
if (( failures == 0 )); then
    printf 'Ergebnis:    ERFOLGREICH\n============================================================\n'
else
    printf 'Ergebnis:    FEHLGESCHLAGEN\n============================================================\n' >&2
    exit 1
fi
