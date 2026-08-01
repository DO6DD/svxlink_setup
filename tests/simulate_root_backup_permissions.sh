#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2015

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
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
expect() { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (expected ${2}, got ${1})"; }

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

nonroot_output="${TEMP_DIR}/nonroot.out"
if env -u SVXLINK_TEST_MODE bash "${ROOT}/svxlink_setup.sh" --show-config >"${nonroot_output}" 2>&1; then
    fail 'production start without root must fail'
else
    pass 'production start without root fails'
fi
expect "$(grep -Fxc 'FEHLER: Root-Rechte erforderlich.' "${nonroot_output}" || true)" 1 'root error is clear'
grep -Fqx '  sudo ./svxlink_setup.sh' "${nonroot_output}" && pass 'root error names sudo invocation' || fail 'root error names sudo invocation'

header=$(show_header)
[[ ${header} == *'Dieses Programm muss als root gestartet werden.'* && ${header} == *'sudo ./svxlink_setup.sh'* ]] && pass 'root hint is visible in header' || fail 'root hint is visible in header'
require_root && pass 'test mode bypasses root requirement' || fail 'test mode bypasses root requirement'

getent() {
    case $2 in
        caller) printf 'caller:x:1000:1000::/home/caller:/bin/bash\n' ;;
        root) printf 'root:x:0:0::/root:/bin/bash\n' ;;
        *) return 2 ;;
    esac
}
SUDO_USER=caller
INSTALL_USER=""
resolve_install_user
expect "${INSTALL_USER}" caller 'SUDO_USER selects installation user'
expect "${INSTALL_HOME}" /home/caller 'SUDO_USER home is resolved via getent'
unset SUDO_USER
INSTALL_USER=""
resolve_install_user
expect "${INSTALL_USER}" root 'direct root login uses root explicitly'
expect "${INSTALL_HOME}" /root 'direct root login home is defined'
unset -f getent

source_directory="${TEMP_DIR}/source-directory"
mkdir -p "${source_directory}/nested"
printf 'backup content\n' >"${source_directory}/nested/file"
chmod 0640 "${source_directory}/nested/file"
backup_directory "${source_directory}"
[[ -d ${source_directory} ]] && pass 'directory backup leaves source in place' || fail 'directory backup leaves source in place'
backup_copy=$(find "${SVXLINK_BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'source-directory.*.bak' -print -quit)
[[ -n ${backup_copy} && -f ${backup_copy}/nested/file ]] && pass 'directory backup contains complete copy' || fail 'directory backup contains complete copy'
expect "$(stat -c '%a' "${backup_copy}/nested/file")" 640 'directory backup preserves file mode'

mkdir -p "${SVXLINK_SOUNDS_DIR}/de_DE/Core" "${SVXLINK_SOUNDS_DIR}/en_US/Core" "${SVXLINK_SOUNDS_DIR}/fr_FR"
printf x >"${SVXLINK_SOUNDS_DIR}/de_DE/Core/a.wav"
printf x >"${SVXLINK_SOUNDS_DIR}/en_US/Core/a.wav"
printf x >"${SVXLINK_SOUNDS_DIR}/fr_FR/untouched.wav"
chmod 0700 "${SVXLINK_SOUNDS_DIR}/de_DE" "${SVXLINK_SOUNDS_DIR}/de_DE/Core"
chmod 0600 "${SVXLINK_SOUNDS_DIR}/de_DE/Core/a.wav"
chmod 0700 "${SVXLINK_SOUNDS_DIR}/en_US" "${SVXLINK_SOUNDS_DIR}/en_US/Core"
chmod 0600 "${SVXLINK_SOUNDS_DIR}/en_US/Core/a.wav"
chmod 0711 "${SVXLINK_SOUNDS_DIR}/fr_FR"
chmod 0600 "${SVXLINK_SOUNDS_DIR}/fr_FR/untouched.wav"
outside="${TEMP_DIR}/outside.wav"
printf outside >"${outside}"
chmod 0600 "${outside}"
ln -s "${outside}" "${SVXLINK_SOUNDS_DIR}/de_DE/external.wav"
normalize_sound_permissions "${SVXLINK_SOUNDS_DIR}/de_DE"
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE")" 755 'German sound directory mode normalized'
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/de_DE/Core/a.wav")" 644 'German sound file mode normalized'
expect "$(stat -c '%a' "${outside}")" 600 'sound symlink target is not dereferenced'
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/fr_FR")" 711 'other language directory remains unchanged'
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/fr_FR/untouched.wav")" 600 'other language file remains unchanged'

printf '%s\n' '[GLOBAL]' 'LOGICS=RepeaterLogic' '[SimplexLogic]' 'DEFAULT_LANG=en_US' '[RepeaterLogic]' 'DEFAULT_LANG=en_US' '[Other]' 'DEFAULT_LANG=keep' >"${SVXLINK_CONFIG}"
activate_sound_language de_DE false
expect "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" de_DE 'German activation follows permission normalization'
expect "$(ini_value "${SVXLINK_CONFIG}" RepeaterLogic DEFAULT_LANG)" de_DE 'German activation updates RepeaterLogic'
activate_sound_language en_US false
expect "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" en_US 'English activation updates SimplexLogic'
expect "$(ini_value "${SVXLINK_CONFIG}" RepeaterLogic DEFAULT_LANG)" en_US 'English activation updates RepeaterLogic'
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US")" 755 'English sound directory mode normalized'
expect "$(stat -c '%a' "${SVXLINK_SOUNDS_DIR}/en_US/Core/a.wav")" 644 'English sound file mode normalized'

SVXLINK_TEST_FAIL_SOUND_PERMISSIONS=true
if activate_sound_language de_DE false >/dev/null 2>&1; then
    fail 'activation must fail when permission normalization fails'
else
    pass 'permission failure prevents activation'
fi
expect "$(ini_value "${SVXLINK_CONFIG}" SimplexLogic DEFAULT_LANG)" en_US 'failed activation leaves configuration unchanged'
unset SVXLINK_TEST_FAIL_SOUND_PERMISSIONS

if rg -nP '^\s*sudo\s+(?!\./svxlink_setup\.sh)' "${ROOT}/svxlink_setup.sh" >/dev/null; then
    fail 'production script must not use internal sudo'
else
    pass 'production script contains no internal sudo commands'
fi

if (( failures == 0 )); then
    printf 'Root, backup and sound permission simulation completed: all tests passed.\n'
else
    printf 'Root, backup and sound permission simulation completed: %d failures.\n' "${failures}" >&2
    exit 1
fi
