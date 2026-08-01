#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2155

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
export SVXLINK_TEST_MODE=true
export SVXLINK_CONFIG_FILE="${TEMP_DIR}/svxlink.conf"
export SVXLINK_SOUNDS_DIR="${TEMP_DIR}/sounds"
export SVXLINK_BACKUP_DIR="${TEMP_DIR}/backups"

failures=0
cleanup() { rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf 'PASS: %s\n' "$*"; }
expect_file() { [[ -f $1 ]] && pass "$2" || fail "$2"; }
expect_value() { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (expected $2, got $1)"; }

make_archive() {
    local root_name=$1 archive=$2 source
    source="${TEMP_DIR}/${root_name}"
    mkdir -p "${source}/Core" "${source}/Default"
    : >"${source}/Core/online.wav"
    : >"${source}/Default/0.wav"
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

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

require_root() { :; }
snapshot_production_paths before

printf '%s\n' '[GLOBAL]' 'LOGICS=RepeaterLogic' '[SimplexLogic]' 'DEFAULT_LANG=en_US' '[RepeaterLogic]' 'DEFAULT_LANG=en_US' '[Other]' 'DEFAULT_LANG=keep' >"${SVXLINK_CONFIG}"

expect_value "$(sha256sum "${ROOT}/resources/sounds/de_DE-anna-16k.tar.bz2" | awk '{print $1}')" "${GERMAN_SOUND_SHA256}" 'bundled Anna archive checksum'
expect_value "$(wc -c <"${ROOT}/resources/sounds/de_DE-anna-16k.tar.bz2")" 18677572 'bundled Anna archive size'
tar -tjf "${ROOT}/resources/sounds/de_DE-anna-16k.tar.bz2" >"${TEMP_DIR}/anna-list.txt"
grep -Fqx "${GERMAN_SOUND_ROOT}/" "${TEMP_DIR}/anna-list.txt" && pass 'bundled Anna archive root' || fail 'bundled Anna archive root'
sound_archive_is_safe "${ROOT}/resources/sounds/de_DE-anna-16k.tar.bz2" "${GERMAN_SOUND_ROOT}" && pass 'bundled Anna archive safety' || fail 'bundled Anna archive safety'

make_archive "${GERMAN_SOUND_ROOT}" "${TEMP_DIR}/german.tar.bz2"
export GERMAN_SOUND_ARCHIVE="${TEMP_DIR}/german.tar.bz2"
export GERMAN_SOUND_SHA256_OVERRIDE=$(sha256sum "${GERMAN_SOUND_ARCHIVE}" | awk '{print $1}')
install_german_sounds
expect_file "${SVXLINK_SOUNDS_DIR}/de_DE/Core/online.wav" 'German installation from mock archive'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE")" 755 'German sound directory permissions'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE/Core/online.wav")" 644 'German sound file permissions'
german_hash=$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')
install_german_sounds
expect_value "$(find "${SVXLINK_SOUNDS_DIR}/de_DE" -type f -exec sha256sum {} + | sha256sum | awk '{print $1}')" "${german_hash}" 'German installation idempotent'

rm -rf "${SVXLINK_SOUNDS_DIR}/de_DE"
export GERMAN_SOUND_SHA256_OVERRIDE=deadbeef
if install_german_sounds >/dev/null 2>&1; then fail 'wrong German checksum must fail'; else pass 'wrong German checksum rejected'; fi
[[ ! -e ${SVXLINK_SOUNDS_DIR}/de_DE ]] && pass 'wrong checksum leaves target unchanged' || fail 'wrong checksum leaves target unchanged'
export GERMAN_SOUND_SHA256_OVERRIDE=$(sha256sum "${GERMAN_SOUND_ARCHIVE}" | awk '{print $1}')

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
before_local=$(sha256sum "${SVXLINK_SOUNDS_DIR}/de_DE/local.wav" | awk '{print $1}')
install_german_sounds
assert_unchanged "${before_local}" "${SVXLINK_SOUNDS_DIR}/de_DE/local.wav" 'existing German files are preserved'
rm -rf "${SVXLINK_SOUNDS_DIR}/de_DE"

make_archive "${ENGLISH_SOUND_ROOT}" "${TEMP_DIR}/english.tar.bz2"
export ENGLISH_SOUND_ARCHIVE="${TEMP_DIR}/english.tar.bz2"
export ENGLISH_SOUND_SHA256_OVERRIDE=$(sha256sum "${ENGLISH_SOUND_ARCHIVE}" | awk '{print $1}')
install_english_sounds
expect_file "${SVXLINK_SOUNDS_DIR}/en_US/Core/online.wav" 'English installation from mock archive'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US")" 755 'English sound directory permissions'
expect_value "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US/Core/online.wav")" 644 'English sound file permissions'

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
snapshot_production_paths after
assert_production_paths_unchanged

if (( failures == 0 )); then
    printf 'Sound management simulation completed: all tests passed.\n'
else
    printf 'Sound management simulation completed: %d failures.\n' "${failures}" >&2
    exit 1
fi
