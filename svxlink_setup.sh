#!/usr/bin/env bash
# SvxLink installation for Debian 12/13 and Raspberry Pi OS based on them.
# Basierend auf:
# https://github.com/do6np/svxlink_setup
#
# Ursprüngliche Autoren:
# DF5KX und DO6NP
#
# Weiterentwicklung und Anpassung:
# DO6DD

set -Eeuo pipefail

readonly SCRIPT_NAME=${0##*/}
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
    svxlink_config_path=${SVXLINK_CONFIG_FILE:-/etc/svxlink/svxlink.conf}
    svxlink_log_path=${LOG_FILE:-/var/log/svxlink}
    svxlink_logrotate_path=${LOGROTATE_FILE:-/etc/logrotate.d/svxlink}
    svxlink_backup_path=${SVXLINK_BACKUP_DIR:-/var/backups/svxlink-setup}
    svxlink_sounds_path=${SVXLINK_SOUNDS_DIR:-/usr/share/svxlink/sounds}
    modules_file_path=${MODULES_FILE:-/etc/modules}
    modprobe_file_path=${SND_CARD_CONFIG_FILE:-/lib/modprobe.d/snd-card.conf}
    raspi_blacklist_path=${RASPI_BLACKLIST_FILE:-/etc/modprobe.d/raspi-blacklist.conf}
    gpio_config_path=${GPIO_CONFIG_FILE:-/etc/svxlink/gpio.conf}
    driver_source_path=${DRIVER_SOURCE_DIR:-}
    alsa_state_path=${ALSA_STATE_FILE:-}
else
    svxlink_config_path=/etc/svxlink/svxlink.conf
    svxlink_log_path=/var/log/svxlink
    svxlink_logrotate_path=/etc/logrotate.d/svxlink
    svxlink_backup_path=/var/backups/svxlink-setup
    svxlink_sounds_path=/usr/share/svxlink/sounds
    modules_file_path=/etc/modules
    modprobe_file_path=/lib/modprobe.d/snd-card.conf
    raspi_blacklist_path=/etc/modprobe.d/raspi-blacklist.conf
    gpio_config_path=/etc/svxlink/gpio.conf
    driver_source_path=""
    alsa_state_path=""
fi
readonly SVXLINK_REPOSITORY="https://github.com/sm0svx/svxlink.git"
readonly SVXLINK_USER="svxlink"
readonly SVXLINK_GROUP="svxlink"
readonly SVXLINK_CONFIG="${svxlink_config_path}"
# shellcheck disable=SC2034
readonly SVXLINK_CONFIG_DIR="/etc/svxlink/svxlink.d"
# shellcheck disable=SC2034
readonly SVXLINK_EVENTS_DIR="/usr/share/svxlink/events.d"
# shellcheck disable=SC2034
readonly SVXLINK_EVENTS_LOCAL_DIR="/usr/share/svxlink/events.d/local"
readonly SVXLINK_SOUNDS_DIR="${svxlink_sounds_path}"
readonly SVXLINK_LOG="${svxlink_log_path}"
readonly APT_CONFIG="/etc/apt/apt.conf.d/20svxlink-disable-auto-updates"
readonly LOGROTATE_CONFIG="${svxlink_logrotate_path}"
readonly SVXLINK_BACKUP_DIR="${svxlink_backup_path}"
readonly MODULES_FILE="${modules_file_path}"
readonly SND_CARD_CONFIG_FILE="${modprobe_file_path}"
readonly RASPI_BLACKLIST_FILE="${raspi_blacklist_path}"
readonly GPIO_CONFIG_FILE="${gpio_config_path}"
readonly GERMAN_SOUND_ARCHIVE_DEFAULT="${SCRIPT_DIR}/resources/sounds/de_DE-anna-16k.tar.bz2"
readonly GERMAN_SOUND_SHA256="ec35d15ee3ddb012558c56626f408359db6108c701b2f27c9c3d89309ad78415"
readonly GERMAN_SOUND_ROOT="de_DE-anna-16k"
# SvxLink 26.05.1 has no matching sound release. 25.05 is the latest official
# release from the SvxLink project and is verified by the fixed SHA-256 below.
readonly ENGLISH_SOUND_URL="https://github.com/sm0svx/svxlink-sounds-en_US-heather/releases/download/25.05/svxlink-sounds-en_US-heather-16k-25.05.tar.bz2"
readonly ENGLISH_SOUND_SHA256="e79e61bec17a24fad093edfb21e7f8ca51af33b9590db954b4789271db2957dd"
readonly ENGLISH_SOUND_ROOT="en_US-heather-16k"

INSTALL_USER=""
INSTALL_HOME=""
SOURCE_DIR=""
BUILD_DIR=""
BOOT_CONFIG=""
OS_VERSION=""
IS_RASPBERRY_PI=false
HARDWARE_PROFILE=0
SECOND_CONNECTOR=false
CALLSIGN=""
CAPTURE_LEFT=6
CAPTURE_RIGHT=6
GERMAN_SOUNDS_AVAILABLE=false
ALSA_STATE_FILE=${alsa_state_path}
ACTION_YES=false
CALLSIGN_PROVIDED=false
HARDWARE_PROFILE_PROVIDED=false

show_header() {
    cat <<'EOF'
+---------------------------------------------------------------+
|                         SVXLINK SETUP                          |
| Debian / Raspberry Pi OS                                      |
|                                                               |
| Basierend auf svxlink_setup von DF5KX & DO6NP                |
| Weiterentwickelt und angepasst von DO6DD                     |
+---------------------------------------------------------------+
Dieses Programm muss als root gestartet werden.

Aufruf:
  sudo ./svxlink_setup.sh
EOF
}

log() {
    printf '%s: %s\n' "${SCRIPT_NAME}" "$*"
}

die() {
    log "ERROR: $*"
    exit 1
}

on_error() {
    local exit_code=$?
    log "ERROR: command failed at line ${BASH_LINENO[0]} (exit ${exit_code})"
    exit "${exit_code}"
}
trap on_error ERR

require_root() {
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        return 0
    fi
    if [[ ${EUID} -ne 0 ]]; then
        printf '%s\n' 'FEHLER: Root-Rechte erforderlich.' >&2
        printf '\n' >&2
        printf '%s\n' 'Bitte starte das Programm mit:' >&2
        printf '\n' >&2
        printf '%s\n' "  sudo ./${SCRIPT_NAME}" >&2
        exit 1
    fi
    [[ -n ${INSTALL_USER} ]] && return 0
    resolve_install_user
}

resolve_install_user() {
    INSTALL_USER=${SUDO_USER:-root}
    INSTALL_HOME=$(getent passwd "${INSTALL_USER}" | cut -d: -f6)
    [[ -n ${INSTALL_HOME} ]] || die "Could not determine the home directory for ${INSTALL_USER}."
    if [[ ${INSTALL_USER} == root ]]; then
        log "Direkter Root-Start: Quell- und Arbeitsverzeichnisse werden unter ${INSTALL_HOME} verwendet."
    fi
    SOURCE_DIR="${INSTALL_HOME}/svxlink"
    BUILD_DIR="${SOURCE_DIR}/src/build"
    return 0
}

backup_file() {
    local file=$1
    [[ -e ${file} ]] || return 0
    install -d -m 0750 "${SVXLINK_BACKUP_DIR}"
    cp -a "${file}" "${SVXLINK_BACKUP_DIR}/$(basename "${file}").$(date +%Y%m%d%H%M%S%N).bak"
}

backup_directory() {
    local directory=$1
    [[ -d ${directory} ]] || return 0
    install -d -m 0750 "${SVXLINK_BACKUP_DIR}"
    cp -a "${directory}" "${SVXLINK_BACKUP_DIR}/$(basename "${directory}").$(date +%Y%m%d%H%M%S%N).bak"
}

move_directory_to_backup() {
    local directory=$1
    [[ -d ${directory} ]] || return 0
    install -d -m 0750 "${SVXLINK_BACKUP_DIR}"
    mv "${directory}" "${SVXLINK_BACKUP_DIR}/$(basename "${directory}").$(date +%Y%m%d%H%M%S%N).bak"
}

ensure_file_line() {
    local file=$1 line=$2
    [[ -f ${file} ]] || install -m 0644 /dev/null "${file}"
    grep -Fqx "${line}" "${file}" && return 0
    backup_file "${file}"
    printf '%s\n' "${line}" >>"${file}"
}

disable_module_line() {
    local file=$1 module=$2 temporary
    [[ -f ${file} ]] || return 0
    temporary=$(mktemp)
    awk -v module="${module}" '
        $0 == module { if (!written) print "#" module; written=1; next }
        $0 == "#" module { if (!written) print; written=1; next }
        { print }
        END { if (!written) print "#" module }
    ' "${file}" >"${temporary}"
    cmp -s "${file}" "${temporary}" || { backup_file "${file}"; install -m 0644 "${temporary}" "${file}"; }
    rm -f "${temporary}"
}

run_as_install_user() {
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        "$@"
    else
        runuser -u "${INSTALL_USER}" -- "$@"
    fi
}

driver_source_directory() {
    local name=$1
    if [[ -n ${driver_source_path} ]]; then
        printf '%s/%s\n' "${driver_source_path}" "${name}"
    else
        printf '%s/hardware/%s\n' "${SOURCE_DIR}" "${name}"
    fi
}

install_historical_driver() {
    local name=$1 repository=$2 directory
    directory=$(driver_source_directory "${name}")
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        install -d -m 0755 "$(dirname "${directory}")"
    else
        install -d -m 0755 -o "${INSTALL_USER}" -g "$(id -gn "${INSTALL_USER}")" "$(dirname "${directory}")"
    fi
    if [[ -d ${directory}/.git ]]; then
        run_as_install_user git -C "${directory}" fetch --prune origin
        run_as_install_user git -C "${directory}" pull --ff-only
    elif [[ -e ${directory} ]]; then
        die "Driver directory exists but is not a Git repository: ${directory}"
    else
        run_as_install_user git clone "${repository}" "${directory}"
    fi
    [[ -x ${directory}/install.sh ]] || die "Historical driver installer is missing: ${directory}/install.sh"
    "${directory}/install.sh" || die "Historical driver installation failed: ${name}"
}

configure_ics_pi_repeater() {
    local line backup_needed=false
    local -a boot_lines=(
        'dtparam=audio=off'
        'dtparam=i2c_arm=on'
        'dtoverlay=fe-pi-audio'
        'dtoverlay=i2s-mmap'
        'dtoverlay=mcp23017,addr=0x20,gpiopin=12'
        'dtoverlay=mcp3008:spi0-0-present,spi0-0-speed=3600000'
        'enable_uart=1'
    )
    ${IS_RASPBERRY_PI} || die "ICS Pi-Repeater is only supported on a Raspberry Pi."
    install_packages_for_profile i2c-tools
    for line in "${boot_lines[@]}"; do
        if ! boot_line_needs_update "${line}"; then
            backup_needed=true
            break
        fi
    done
    ${backup_needed} && backup_file "${BOOT_CONFIG}"
    for line in "${boot_lines[@]}"; do
        ensure_boot_line "${line}"
    done
    disable_module_line "${MODULES_FILE}" snd-bcm2835
    ensure_file_line "${MODULES_FILE}" i2c-dev
}

configure_usvxcard() {
    local temporary
    ${IS_RASPBERRY_PI} || die "uSvxCard is only supported on a Raspberry Pi."
    ensure_file_line "${RASPI_BLACKLIST_FILE}" 'blacklist snd_bcm2835'
    [[ -f ${SND_CARD_CONFIG_FILE} ]] || install -m 0644 /dev/null "${SND_CARD_CONFIG_FILE}"
    temporary=$(mktemp)
    awk '
        $0 == "options snd_usb_audio index=0" { print "#" $0; next }
        $0 == "options snd slots=snd_usb_audio,snd-bcm2835" { print "#" $0; next }
        { print }
    ' "${SND_CARD_CONFIG_FILE}" >"${temporary}"
    if ! cmp -s "${SND_CARD_CONFIG_FILE}" "${temporary}"; then
        backup_file "${SND_CARD_CONFIG_FILE}"
        install -m 0644 "${temporary}" "${SND_CARD_CONFIG_FILE}"
    fi
    rm -f "${temporary}"
    install_historical_driver seeed-voicecard https://github.com/respeaker/seeed-voicecard.git
    install -d -m 0755 "$(dirname "${GPIO_CONFIG_FILE}")"
    temporary=$(mktemp)
    cat >"${temporary}" <<'EOF'
GPIO_PATH=/sys/class/gpio
GPIO_IN_HIGH="gpio23 gpio24"
GPIO_IN_LOW=""
GPIO_OUT_HIGH="gpio17"
GPIO_OUT_LOW=""
GPIO_USER="svxlink"
GPIO_GROUP="svxlink"
GPIO_MODE="0664"
EOF
    if [[ ! -f ${GPIO_CONFIG_FILE} ]] || ! cmp -s "${GPIO_CONFIG_FILE}" "${temporary}"; then
        backup_file "${GPIO_CONFIG_FILE}"
        install -m 0644 "${temporary}" "${GPIO_CONFIG_FILE}"
    fi
    rm -f "${temporary}"
}

configure_wm8960() {
    ${IS_RASPBERRY_PI} || die "WM8960 Audio-HAT is only supported on a Raspberry Pi."
    install_historical_driver WM8960-Audio-HAT https://github.com/waveshare/WM8960-Audio-HAT
}

configure_hardware_profile() {
    case ${HARDWARE_PROFILE} in
        0) return 0 ;;
        1) configure_ics_pi_repeater ;;
        2) configure_usvxcard ;;
        3) configure_wm8960 ;;
        4) configure_elenata_boot; configure_elenata_svxlink; configure_elenata_alsa ;;
        *) die "Unsupported hardware profile: ${HARDWARE_PROFILE}" ;;
    esac
}

sound_directory_has_wav() {
    local directory=$1
    [[ -d ${directory} ]] && find "${directory}" -type f -name '*.wav' -print -quit 2>/dev/null | grep -q .
}

sound_wav_count() {
    local directory=$1
    [[ -d ${directory} ]] || { printf '0\n'; return 0; }
    find "${directory}" -type f -name '*.wav' -printf '.' 2>/dev/null | wc -c
}

sound_archive_is_safe() {
    local archive=$1 expected_root=$2 entry type listing link_target
    tar -tjf "${archive}" >/dev/null 2>&1 || { log "Sound archive cannot be listed: ${archive}"; return 1; }

    while IFS= read -r entry; do
        [[ ${entry} == "${expected_root}/"* || ${entry} == "${expected_root}" ]] || {
            log "Sound archive contains an unexpected path: ${entry}"; return 1;
        }
        [[ ${entry} != /* && ${entry} != *'../'* && ${entry} != '..' ]] || {
            log "Sound archive contains an unsafe path: ${entry}"; return 1;
        }
        [[ ${entry} != *'/.svn/'* && ${entry} != */.svn && ${entry} != *.tcl ]] || {
            log "Sound archive contains a forbidden entry: ${entry}"; return 1;
        }
    done < <(tar -tjf "${archive}")

    while IFS= read -r listing; do
        type=${listing:0:1}
        if [[ ${type} == l ]]; then
            link_target=${listing##* -> }
            [[ ${link_target} != /* ]] || {
                log "Sound archive contains an unsafe symbolic link: ${listing}"; return 1;
            }
            continue
        fi
        [[ ${type} == '-' || ${type} == 'd' ]] || {
            log "Sound archive contains an unsupported entry type: ${listing}"; return 1;
        }
    done < <(tar -tvjf "${archive}")
    return 0
}

materialize_sound_links() {
    local directory=$1 link resolved replacement
    while IFS= read -r -d '' link; do
        resolved=$(readlink -f -- "${link}") || { log "Broken sound link: ${link}"; return 1; }
        [[ ${resolved} == "${directory}/"* && -f ${resolved} ]] || {
            log "Sound link escapes the extracted archive: ${link}"; return 1;
        }
        replacement="${link}.svxlink-materialized"
        cp --dereference --preserve=mode -- "${link}" "${replacement}" || return 1
        mv -f -- "${replacement}" "${link}" || return 1
    done < <(find "${directory}" -type l -print0)
}

normalize_sound_permissions() {
    local directory=$1
    [[ -d ${directory} ]] || { log "Sound directory is missing: ${directory}"; return 1; }
    if [[ ${SVXLINK_TEST_MODE:-false} == true && ${SVXLINK_TEST_FAIL_SOUND_PERMISSIONS:-false} == true ]]; then
        log "Sound permission normalization failed in test mode."
        return 1
    fi
    if [[ ${SVXLINK_TEST_MODE:-false} != true ]]; then
        chown -hR "${SVXLINK_USER}:${SVXLINK_GROUP}" "${directory}" || {
            log "Could not set ownership for sound directory: ${directory}"
            return 1
        }
    fi
    find "${directory}" -type d -exec chmod 0755 {} + || {
        log "Could not set directory permissions for: ${directory}"
        return 1
    }
    find "${directory}" -type f -exec chmod 0644 {} + || {
        log "Could not set file permissions for: ${directory}"
        return 1
    }
    return 0
}

install_sound_archive() (
    local archive=$1 expected_sha=$2 expected_root=$3 language=$4 replace_existing=${5:-false}
    local actual_sha temporary staged target
    target="${SVXLINK_SOUNDS_DIR}/${language}"
    [[ -f ${archive} ]] || { log "Sound archive is missing: ${archive}"; return 1; }
    actual_sha=$(sha256sum "${archive}" | awk '{print $1}')
    [[ ${actual_sha} == "${expected_sha}" ]] || {
        log "Sound archive checksum verification failed: ${archive}"; return 1;
    }
    sound_archive_is_safe "${archive}" "${expected_root}" || return 1

    if sound_directory_has_wav "${target}"; then
        log "Sound directory already exists and contains WAV files: ${target}"
        return 0
    fi
    if [[ -e ${target} && ${replace_existing} != true ]]; then
        log "Sound directory exists but is not a usable managed sound set: ${target}"
        return 1
    fi

    temporary=$(mktemp -d)
    trap 'rm -rf "${temporary}"' EXIT
    if ! tar -xjf "${archive}" -C "${temporary}" --no-same-owner --no-same-permissions; then
        log "Sound archive extraction failed: ${archive}"
        return 1
    fi
    staged="${temporary}/${expected_root}"
    if ! sound_directory_has_wav "${staged}"; then
        log "Sound archive does not contain any WAV files: ${archive}"
        return 1
    fi
    materialize_sound_links "${staged}" || return 1
    normalize_sound_permissions "${staged}" || return 1
    install -d -m 0755 "${SVXLINK_SOUNDS_DIR}"
    if [[ -e ${target} ]]; then
        move_directory_to_backup "${target}" || return 1
    fi
    mv "${staged}" "${target}"
    log "Sound directory installed: ${target}"
    return 0
)

install_german_sounds() {
    local replace_existing=${1:-false}
    local archive=${GERMAN_SOUND_ARCHIVE_DEFAULT}
    local expected_sha=${GERMAN_SOUND_SHA256}
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        archive=${GERMAN_SOUND_ARCHIVE:-${GERMAN_SOUND_ARCHIVE_DEFAULT}}
        expected_sha=${GERMAN_SOUND_SHA256_OVERRIDE:-${GERMAN_SOUND_SHA256}}
    fi
    install_sound_archive "${archive}" "${expected_sha}" "${GERMAN_SOUND_ROOT}" de_DE "${replace_existing}"
}

install_english_sounds() (
    local replace_existing=${1:-false}
    local temporary archive expected_sha=${ENGLISH_SOUND_SHA256}
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        expected_sha=${ENGLISH_SOUND_SHA256_OVERRIDE:-${ENGLISH_SOUND_SHA256}}
    fi
    if [[ ${SVXLINK_TEST_MODE:-false} == true && -n ${ENGLISH_SOUND_ARCHIVE:-} ]]; then
        install_sound_archive "${ENGLISH_SOUND_ARCHIVE}" "${expected_sha}" "${ENGLISH_SOUND_ROOT}" en_US "${replace_existing}"
        return $?
    fi
    temporary=$(mktemp -d)
    trap 'rm -rf "${temporary}"' EXIT
    archive="${temporary}/svxlink-sounds-en_US-heather-16k-25.05.tar.bz2"
    if ! curl -fL --proto '=https' --tlsv1.2 --retry 2 --connect-timeout 20 -o "${archive}" "${ENGLISH_SOUND_URL}"; then
        log "English sound download failed."
        return 1
    fi
    if ! install_sound_archive "${archive}" "${expected_sha}" "${ENGLISH_SOUND_ROOT}" en_US "${replace_existing}"; then
        return 1
    fi
    return 0
)

activate_sound_language() {
    local language=$1
    local interactive=${2:-false}
    local target="${SVXLINK_SOUNDS_DIR}/${language}"
    [[ -f ${SVXLINK_CONFIG} ]] || { log "SvxLink configuration not found: ${SVXLINK_CONFIG}"; return 1; }
    if ! grep -Fqx '[SimplexLogic]' "${SVXLINK_CONFIG}" || ! grep -Fqx '[RepeaterLogic]' "${SVXLINK_CONFIG}"; then
        log "SimplexLogic and RepeaterLogic sections are required for language activation."
        return 1
    fi
    if ! sound_directory_has_wav "${target}"; then
        log "No usable ${language} sound directory was found: ${target}"
        return 1
    fi
    if ! normalize_sound_permissions "${target}"; then
        log "${language} was not activated because sound permissions could not be normalized."
        return 1
    fi
    if ${interactive}; then
        read -r -p "${language} jetzt aktivieren? [j/N]: " answer
        [[ ${answer} == j || ${answer} == J ]] || { log "Keine Konfiguration geändert."; return 0; }
    fi
    backup_file "${SVXLINK_CONFIG}"
    set_ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" "${language}"
    set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" "${language}"
    log "${language} was activated for SimplexLogic and RepeaterLogic. SvxLink was not started."
    return 0
}

detect_operating_system() {
    if [[ ${SVXLINK_TEST_MODE:-false} == true && ${SVXLINK_TEST_RASPBERRY_PI:-false} == true ]]; then
        IS_RASPBERRY_PI=true
        BOOT_CONFIG=${BOOT_CONFIG_FILE:?BOOT_CONFIG_FILE is required in test mode}
        return 0
    fi
    [[ -r /etc/os-release ]] || die "Missing /etc/os-release."
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_VERSION=${VERSION_ID:-}

    case ${ID:-} in
        debian|raspbian) ;;
        *) die "Unsupported operating system: ${PRETTY_NAME:-unknown}. Only Debian 12/13 and Raspberry Pi OS are supported." ;;
    esac
    [[ ${OS_VERSION} == "12" || ${OS_VERSION} == "13" ]] || \
        die "Unsupported Debian version: ${OS_VERSION:-unknown}. Only Debian 12 and 13 are supported."

    if [[ -r /proc/device-tree/model ]] && tr -d '\0' </proc/device-tree/model | grep -qi 'raspberry pi'; then
        IS_RASPBERRY_PI=true
    elif [[ ${ID:-} == "raspbian" ]]; then
        IS_RASPBERRY_PI=true
    fi

    if ${IS_RASPBERRY_PI}; then
        if [[ -f /boot/firmware/config.txt ]]; then
            BOOT_CONFIG=/boot/firmware/config.txt
        elif [[ -f /boot/config.txt ]]; then
            BOOT_CONFIG=/boot/config.txt
        else
            die "Raspberry Pi detected but neither /boot/firmware/config.txt nor /boot/config.txt exists."
        fi
    fi
}

disable_automatic_updates() {
    local unit
    local -a units=(apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service)

    for unit in "${units[@]}"; do
        systemctl disable --now "${unit}" 2>/dev/null || true
        systemctl mask "${unit}" 2>/dev/null || true
    done

    if dpkg-query -W -f='${db:Status-Status}' unattended-upgrades 2>/dev/null | grep -qx installed; then
        systemctl disable --now unattended-upgrades.service 2>/dev/null || true
        systemctl mask unattended-upgrades.service 2>/dev/null || true
    fi

    backup_file "${APT_CONFIG}"
    install -m 0644 /dev/stdin "${APT_CONFIG}" <<'EOF'
APT::Periodic::Enable "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
}

install_packages() {
    local -a packages=(
        ca-certificates cmake g++ git libasound2-dev libcurl4-openssl-dev
        libgcrypt-dev libgpiod-dev libgsm1-dev libjsoncpp-dev libogg-dev
        libopus-dev libopusenc-dev libpopt-dev libsigc++-2.0-dev libsndfile1-dev
        libspeex-dev libspeexdsp-dev libssl-dev libvorbis-dev logrotate make
        tcl-dev alsa-utils lsof
    )

    if ${IS_RASPBERRY_PI}; then
        packages+=(gpiod)
    fi
    if [[ ${HARDWARE_PROFILE} == 1 ]]; then
        packages+=(i2c-tools)
    fi

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

install_packages_for_profile() {
    local package=$1
    if ! dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null | grep -qx installed; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}"
    fi
}

ensure_svxlink_account() {
    local group
    for group in audio dialout plugdev; do
        getent group "${group}" >/dev/null || log "Optional system group is unavailable: ${group}"
    done
    if ${IS_RASPBERRY_PI}; then
        getent group gpio >/dev/null || die "Raspberry Pi group gpio is unavailable."
    fi

    getent group "${SVXLINK_GROUP}" >/dev/null || groupadd --system "${SVXLINK_GROUP}"
    id -u "${SVXLINK_USER}" >/dev/null 2>&1 || \
        useradd --system --gid "${SVXLINK_GROUP}" --home-dir /nonexistent --shell /usr/sbin/nologin --comment "SvxLink daemon" "${SVXLINK_USER}"

    for group in audio dialout plugdev; do
        getent group "${group}" >/dev/null && usermod -a -G "${group}" "${SVXLINK_USER}"
    done
    if ${IS_RASPBERRY_PI}; then
        usermod -a -G gpio "${SVXLINK_USER}"
    fi
    return 0
}

prompt_callsign() {
    while :; do
        read -r -p "Rufzeichen, Relais- oder Knotenname: " CALLSIGN
        CALLSIGN=${CALLSIGN^^}
        [[ ${CALLSIGN} =~ ^[A-Z0-9][A-Z0-9_-]{2,15}$ ]] && return 0
        log "Ungültige Eingabe. Erlaubt sind 3 bis 16 Großbuchstaben, Ziffern, Bindestrich und Unterstrich."
    done
}

choose_hardware_profile() {
    if ! ${IS_RASPBERRY_PI}; then
        HARDWARE_PROFILE=0
        log "Kein Raspberry Pi erkannt."
        log "Hardwareprofil automatisch auf 0 gesetzt:"
        log "Kein Raspberry-Pi-Audioprofil."
        return 0
    fi

    log "Hardwareprofil auswählen:"
    log "  0) Kein Raspberry-Pi-Audioprofil"
    log "  1) ICS Pi-Repeater"
    log "  2) uSvxCard"
    log "  3) WM8960 Audio-HAT"
    log "  4) ELENATA Wolfson / Fe-Pi Audio"

    while :; do
        read -r -p "Auswahl (0 bis 4): " HARDWARE_PROFILE
        [[ ${HARDWARE_PROFILE} =~ ^[0-4]$ ]] || \
            { log "Ungültige Auswahl. Erlaubt sind 0 bis 4."; continue; }
        break
    done

    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        while :; do
            read -r -p "Zweiten Anschluss vorbereiten (j/n): " answer
            case ${answer,,} in
                j|ja|y|yes) SECOND_CONNECTOR=true; break ;;
                n|nein|no) break ;;
                *) log "Bitte j oder n eingeben." ;;
            esac
        done
        CAPTURE_LEFT=$(prompt_level "Capture-Pegel links" 6)
        CAPTURE_RIGHT=$(prompt_level "Capture-Pegel rechts" 6)
    fi
    return 0
}

detected_hardware_profile() {
    if ! ${IS_RASPBERRY_PI}; then
        printf '0\n'
    elif [[ -f ${BOOT_CONFIG} ]] && grep -Fqx 'dtoverlay=mcp23017,addr=0x20,gpiopin=12' "${BOOT_CONFIG}"; then
        printf '1\n'
    elif [[ -f ${RASPI_BLACKLIST_FILE} ]] && grep -Fqx 'blacklist snd_bcm2835' "${RASPI_BLACKLIST_FILE}"; then
        printf '2\n'
    elif [[ -d $(driver_source_directory WM8960-Audio-HAT) ]]; then
        printf '3\n'
    elif elenata_profile_configured; then
        printf '4\n'
    else
        printf '0\n'
    fi
}

hardware_profile_name() {
    case $1 in
        0) printf '%s\n' 'Kein Raspberry-Pi-Audioprofil' ;;
        1) printf '%s\n' 'ICS Pi-Repeater' ;;
        2) printf '%s\n' 'uSvxCard' ;;
        3) printf '%s\n' 'WM8960 Audio-HAT' ;;
        4) printf '%s\n' 'ELENATA Wolfson / Fe-Pi Audio' ;;
        *) printf '%s\n' 'unbekannt' ;;
    esac
}

prompt_level() {
    local label=$1
    local default=$2
    local value
    while :; do
        read -r -p "${label} (0-15, Standard ${default}): " value
        value=${value:-${default}}
        [[ ${value} =~ ^([0-9]|1[0-5])$ ]] && { printf '%s\n' "${value}"; return 0; }
        log "Ungültiger Pegel. Erlaubt ist 0 bis 15."
    done
}

ensure_boot_line() {
    local line=$1
    local key
    local active_pattern
    local temporary
    local active_count

    case ${line} in
        dtparam=*)
            key="dtparam=${line#dtparam=}"
            key=${key%=*}
            active_pattern="^[[:space:]]*${key//./\\.}="
            ;;
        dtoverlay=*)
            key="dtoverlay=${line#dtoverlay=}"
            active_pattern="^[[:space:]]*${key//./\\.}([[:space:]]*$|,)"
            ;;
        *=*)
            key=${line%%=*}
            active_pattern="^[[:space:]]*${key//./\\.}="
            ;;
        *) die "Unsupported boot setting: ${line}" ;;
    esac
    active_count=$(grep -cE "${active_pattern}" "${BOOT_CONFIG}" || true)
    if [[ ${active_count} == 1 ]] && grep -qE "^[[:space:]]*${line//./\\.}[[:space:]]*$" "${BOOT_CONFIG}"; then
        return 0
    fi
    temporary=$(mktemp)
    if (( active_count > 0 )); then
        awk -v pattern="${active_pattern}" -v line="${line}" '
            $0 ~ pattern {
                if (!written) print line
                written=1
                next
            }
            { print }
        ' "${BOOT_CONFIG}" >"${temporary}"
        install -m 0644 "${temporary}" "${BOOT_CONFIG}" || { rm -f "${temporary}"; return 1; }
        rm -f "${temporary}" || return 1
    else
        printf '\n%s\n' "${line}" >>"${BOOT_CONFIG}" || return 1
    fi
}

boot_line_needs_update() {
    local line=$1
    local key active_pattern active_count

    case ${line} in
        dtparam=*)
            key="dtparam=${line#dtparam=}"
            key=${key%=*}
            active_pattern="^[[:space:]]*${key//./\\.}="
            ;;
        dtoverlay=*)
            key="dtoverlay=${line#dtoverlay=}"
            active_pattern="^[[:space:]]*${key//./\\.}([[:space:]]*$|,)"
            ;;
        *=*)
            key=${line%%=*}
            active_pattern="^[[:space:]]*${key//./\\.}="
            ;;
        *) die "Unsupported boot setting: ${line}" ;;
    esac
    active_count=$(grep -cE "${active_pattern}" "${BOOT_CONFIG}" || true)
    [[ ${active_count} == 1 ]] && grep -qE "^[[:space:]]*${line//./\\.}[[:space:]]*$" "${BOOT_CONFIG}"
}

configure_elenata_boot() {
    local line
    local -a required_lines=(
        "dtparam=i2c0=on"
        "dtparam=i2c1=on"
        "dtparam=audio=off"
        "dtoverlay=fe-pi-audio"
        "dtoverlay=disable-bt"
    )

    ${IS_RASPBERRY_PI} || die "ELENATA is only supported on a Raspberry Pi."
    for line in "${required_lines[@]}"; do
        if ! boot_line_needs_update "${line}"; then
            backup_file "${BOOT_CONFIG}"
            break
        fi
    done
    for line in "${required_lines[@]}"; do
        ensure_boot_line "${line}" || return 1
    done
    return 0
}

amixer_control_exists() {
    amixer -c Audio scontrols 2>/dev/null | grep -Fq "'${1}'"
}

set_optional_amixer_control() {
    local control=$1
    local value=$2
    if amixer_control_exists "${control}"; then
        amixer -c Audio sset "${control}" "${value}" || \
            log "Could not set optional ALSA control: ${control}"
    else
        log "Optional ALSA control is unavailable: ${control}"
    fi
}

set_required_amixer_control() {
    local control=$1
    shift
    if ! amixer_control_exists "${control}"; then
        log "Required ALSA control is unavailable: ${control}"
        return 1
    fi
    if ! amixer -c Audio sset "${control}" "$@"; then
        log "Could not set required ALSA control: ${control}"
        return 1
    fi
    log "ALSA control configured: ${control}"
}

audio_card_number() {
    awk '/^[[:space:]]*[0-9]+[[:space:]]+\[Audio\]/{gsub(/^[[:space:]]+/, "", $0); print $1; exit}' /proc/asound/cards 2>/dev/null || true
}

audio_card_available() {
    [[ -n $(audio_card_number) ]]
}

configure_elenata_alsa() {
    local card_number
    if ! audio_card_available; then
        log "ALSA card Audio is not available yet; ALSA values will be applied after reboot by rerunning the script."
        return 0
    fi
    card_number=$(audio_card_number)

    set_required_amixer_control "Capture Mux" "LINE_IN" || return 1
    set_required_amixer_control "Capture" "${CAPTURE_LEFT},${CAPTURE_RIGHT}" unmute || return 1
    set_required_amixer_control "PCM" "166,166" || return 1
    set_required_amixer_control "Lineout" "21,21" unmute || return 1
    set_optional_amixer_control "Capture Attenuate Switch (-6dB)" on
    set_optional_amixer_control "AVC" off
    set_optional_amixer_control "AVC Hard Limiter" off
    set_optional_amixer_control "Mic" 0
    if [[ -n ${ALSA_STATE_FILE} ]]; then
        asactl store -f "${ALSA_STATE_FILE}" "${card_number}" || die "Could not store ALSA state for card ${card_number}."
    else
        asactl store "${card_number}" || die "Could not store ALSA state for card ${card_number}."
    fi
}

set_ini_value() {
    local file=$1 section=$2 key=$3 value=$4 temporary
    temporary=$(mktemp)
    awk -v section="${section}" -v key="${key}" -v value="${value}" '
        BEGIN { in_section=0; written=0 }
        $0 == "[" section "]" { in_section=1 }
        /^\[/ && $0 != "[" section "]" {
            if (in_section && !written) print key "=" value
            in_section=0
        }
        in_section && $0 ~ "^" key "=" {
            if (!written) print key "=" value
            written=1
            next
        }
        { print }
        END {
            if (in_section && !written) print key "=" value
        }
    ' "${file}" >"${temporary}"
    install -m 0644 "${temporary}" "${file}"
    rm -f "${temporary}"
}

remove_ini_key() {
    local file=$1 section=$2 key=$3 temporary
    temporary=$(mktemp)
    awk -v section="${section}" -v key="${key}" '
        $0 == "[" section "]" { in_section=1 }
        /^\[/ && $0 != "[" section "]" { in_section=0 }
        in_section && $0 ~ "^" key "=" { next }
        { print }
    ' "${file}" >"${temporary}"
    install -m 0644 "${temporary}" "${file}"
    rm -f "${temporary}"
}

configure_elenata_svxlink() {
    [[ -f ${SVXLINK_CONFIG} ]] || { log "SvxLink configuration not found: ${SVXLINK_CONFIG}"; return 0; }
    if ! grep -Fqx '[Rx1]' "${SVXLINK_CONFIG}" || ! grep -Fqx '[Tx1]' "${SVXLINK_CONFIG}"; then
        log "Sections [Rx1] and [Tx1] are both required; ELENATA values were not inserted."
        return 0
    fi
    backup_file "${SVXLINK_CONFIG}"
    remove_ini_key "${SVXLINK_CONFIG}" "Rx1" "PTT_TYPE"
    remove_ini_key "${SVXLINK_CONFIG}" "Rx1" "PTT_GPIOD_CHIP"
    remove_ini_key "${SVXLINK_CONFIG}" "Rx1" "PTT_GPIOD_LINE"
    remove_ini_key "${SVXLINK_CONFIG}" "Tx1" "SQL_DET"
    remove_ini_key "${SVXLINK_CONFIG}" "Tx1" "SQL_GPIOD_CHIP"
    remove_ini_key "${SVXLINK_CONFIG}" "Tx1" "SQL_GPIOD_LINE"
    set_ini_value "${SVXLINK_CONFIG}" "Rx1" "AUDIO_DEV" "alsa:hw:CARD=Audio,DEV=0"
    set_ini_value "${SVXLINK_CONFIG}" "Rx1" "AUDIO_CHANNEL" "0"
    set_ini_value "${SVXLINK_CONFIG}" "Rx1" "SQL_DET" "GPIOD"
    set_ini_value "${SVXLINK_CONFIG}" "Rx1" "SQL_GPIOD_CHIP" "gpiochip0"
    set_ini_value "${SVXLINK_CONFIG}" "Rx1" "SQL_GPIOD_LINE" "26"
    set_ini_value "${SVXLINK_CONFIG}" "Tx1" "AUDIO_DEV" "alsa:hw:CARD=Audio,DEV=0"
    set_ini_value "${SVXLINK_CONFIG}" "Tx1" "AUDIO_CHANNEL" "0"
    set_ini_value "${SVXLINK_CONFIG}" "Tx1" "PTT_TYPE" "GPIOD"
    set_ini_value "${SVXLINK_CONFIG}" "Tx1" "PTT_GPIOD_CHIP" "gpiochip0"
    set_ini_value "${SVXLINK_CONFIG}" "Tx1" "PTT_GPIOD_LINE" "13"

    if ${SECOND_CONNECTOR}; then
        if grep -Fqx '[Rx2]' "${SVXLINK_CONFIG}" && grep -Fqx '[Tx2]' "${SVXLINK_CONFIG}"; then
            remove_ini_key "${SVXLINK_CONFIG}" "Rx2" "PTT_TYPE"
            remove_ini_key "${SVXLINK_CONFIG}" "Rx2" "PTT_GPIOD_CHIP"
            remove_ini_key "${SVXLINK_CONFIG}" "Rx2" "PTT_GPIOD_LINE"
            remove_ini_key "${SVXLINK_CONFIG}" "Tx2" "SQL_DET"
            remove_ini_key "${SVXLINK_CONFIG}" "Tx2" "SQL_GPIOD_CHIP"
            remove_ini_key "${SVXLINK_CONFIG}" "Tx2" "SQL_GPIOD_LINE"
            set_ini_value "${SVXLINK_CONFIG}" "Rx2" "AUDIO_DEV" "alsa:hw:CARD=Audio,DEV=0"
            set_ini_value "${SVXLINK_CONFIG}" "Rx2" "AUDIO_CHANNEL" "1"
            set_ini_value "${SVXLINK_CONFIG}" "Rx2" "SQL_DET" "GPIOD"
            set_ini_value "${SVXLINK_CONFIG}" "Rx2" "SQL_GPIOD_CHIP" "gpiochip0"
            set_ini_value "${SVXLINK_CONFIG}" "Rx2" "SQL_GPIOD_LINE" "6"
            set_ini_value "${SVXLINK_CONFIG}" "Tx2" "AUDIO_DEV" "alsa:hw:CARD=Audio,DEV=0"
            set_ini_value "${SVXLINK_CONFIG}" "Tx2" "AUDIO_CHANNEL" "1"
            set_ini_value "${SVXLINK_CONFIG}" "Tx2" "PTT_TYPE" "GPIOD"
            set_ini_value "${SVXLINK_CONFIG}" "Tx2" "PTT_GPIOD_CHIP" "gpiochip0"
            set_ini_value "${SVXLINK_CONFIG}" "Tx2" "PTT_GPIOD_LINE" "5"
        else
            log "Second connector requested but sections [Rx2] and [Tx2] are both required."
        fi
    fi
}

ini_value() {
    local file=$1 section=$2 key=$3
    awk -v section="${section}" -v key="${key}" '
        $0 == "[" section "]" { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $0 ~ "^" key "=" { print substr($0, length(key) + 2); exit }
    ' "${file}"
}

section_contains_placeholder() {
    local file=$1 section=$2
    awk -v section="${section}" '
        $0 == "[" section "]" { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && ($0 ~ /MYCALL|example\.org|Change this key now/) { found=1 }
        END { exit !found }
    ' "${file}"
}

validate_base_svxlink_configuration() {
    [[ $(ini_value "${SVXLINK_CONFIG}" "GLOBAL" "LOGICS") == "RepeaterLogic" ]] || \
        die "SvxLink configuration validation failed: LOGICS must be RepeaterLogic."
    grep -Fqx '[RepeaterLogic]' "${SVXLINK_CONFIG}" || \
        die "SvxLink configuration validation failed: [RepeaterLogic] is missing."
    [[ $(ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "CALLSIGN") == "${CALLSIGN}" ]] || \
        die "SvxLink configuration validation failed: RepeaterLogic CALLSIGN does not match the input."
    if section_contains_placeholder "${SVXLINK_CONFIG}" "GLOBAL" || \
        section_contains_placeholder "${SVXLINK_CONFIG}" "RepeaterLogic"; then
        die "SvxLink configuration validation failed: active configuration contains a placeholder."
    fi
}

configure_base_svxlink() {
    [[ -f ${SVXLINK_CONFIG} ]] || die "SvxLink configuration not found: ${SVXLINK_CONFIG}"
    grep -Fqx '[GLOBAL]' "${SVXLINK_CONFIG}" || die "SvxLink configuration is missing [GLOBAL]."
    grep -Fqx '[RepeaterLogic]' "${SVXLINK_CONFIG}" || die "SvxLink configuration is missing [RepeaterLogic]."

    backup_file "${SVXLINK_CONFIG}"
    set_ini_value "${SVXLINK_CONFIG}" "GLOBAL" "LOGICS" "RepeaterLogic"
    set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "CALLSIGN" "${CALLSIGN}"
    if grep -Fqx '[SimplexLogic]' "${SVXLINK_CONFIG}"; then
        set_ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "CALLSIGN" "${CALLSIGN}"
    fi
    set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" "en_US"
    if grep -Fqx '[SimplexLogic]' "${SVXLINK_CONFIG}"; then
        set_ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" "en_US"
    fi
    validate_base_svxlink_configuration
}

build_svxlink() {
    if [[ -d ${SOURCE_DIR}/.git ]]; then
        runuser -u "${INSTALL_USER}" -- git -C "${SOURCE_DIR}" fetch --prune origin
        runuser -u "${INSTALL_USER}" -- git -C "${SOURCE_DIR}" pull --ff-only
    elif [[ -e ${SOURCE_DIR} ]]; then
        die "Source directory exists but is not a SvxLink Git repository: ${SOURCE_DIR}"
    else
        runuser -u "${INSTALL_USER}" -- git clone "${SVXLINK_REPOSITORY}" "${SOURCE_DIR}"
    fi

    BUILD_DIR=$(runuser -u "${INSTALL_USER}" -- mktemp -d "${SOURCE_DIR}/.svxlink-build.XXXXXX")
    runuser -u "${INSTALL_USER}" -- cmake -S "${SOURCE_DIR}/src" -B "${BUILD_DIR}" \
        -DUSE_QT=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DSYSCONF_INSTALL_DIR=/etc \
        -DLOCAL_STATE_DIR=/var \
        -DWITH_SYSTEMD=ON
    runuser -u "${INSTALL_USER}" -- cmake --build "${BUILD_DIR}" --parallel "$(nproc)"
    cmake --install "${BUILD_DIR}"
    ldconfig
}

configure_logging() {
    local output
    touch "${SVXLINK_LOG}"
    chown "${SVXLINK_USER}:${SVXLINK_GROUP}" "${SVXLINK_LOG}"
    chmod 0644 "${SVXLINK_LOG}"
    backup_file "${LOGROTATE_CONFIG}"
    install -m 0644 /dev/stdin "${LOGROTATE_CONFIG}" <<'EOF'
/var/log/svxlink {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    su svxlink svxlink
}
EOF
    if ! output=$(logrotate -d "${LOGROTATE_CONFIG}" 2>&1); then
        log "ERROR: Logrotate configuration validation failed."
        printf '%s\n' "${output}" | sed -n '1,3p' | while IFS= read -r line; do
            log "ERROR: logrotate: ${line}"
        done
        return 1
    fi
}

enable_svxlink_service() {
    systemctl daemon-reload
    systemctl cat svxlink.service >/dev/null 2>&1 || die "SvxLink systemd service was not installed."
    systemctl enable svxlink.service
}

check_item() {
    local label=$1
    shift
    if "$@"; then
        log "OK: ${label}"
    else
        log "MISSING: ${label}"
    fi
}

automatic_updates_disabled() {
    local unit state
    local -a units=(apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service)

    [[ -f ${APT_CONFIG} ]] || return 1
    grep -Fqx 'APT::Periodic::Enable "0";' "${APT_CONFIG}" >/dev/null 2>&1 || return 1
    for unit in "${units[@]}"; do
        state=$(systemctl is-enabled "${unit}" 2>/dev/null || true)
        [[ ${state} != "enabled" ]] || return 1
    done
    if dpkg-query -W -f='${db:Status-Status}' unattended-upgrades 2>/dev/null | grep -qx installed; then
        state=$(systemctl is-enabled unattended-upgrades.service 2>/dev/null || true)
        [[ ${state} != "enabled" ]] || return 1
    fi
}

elenata_profile_configured() {
    ${IS_RASPBERRY_PI} && [[ -f ${BOOT_CONFIG} ]] && \
        grep -Fqx 'dtoverlay=fe-pi-audio' "${BOOT_CONFIG}" >/dev/null 2>&1
}

check_logrotate_configuration() {
    local output
    [[ -f ${LOGROTATE_CONFIG} ]] || { log "MISSING: Logrotate configuration"; return; }
    if output=$(logrotate -d "${LOGROTATE_CONFIG}" 2>&1); then
        log "OK: Logrotate configuration"
    else
        log "WARN: Logrotate configuration validation failed"
        printf '%s\n' "${output}" | sed -n '1,3p' | while IFS= read -r line; do
            log "WARN: logrotate: ${line}"
        done
    fi
}

check_svxlink_user() {
    getent passwd "${SVXLINK_USER}" >/dev/null 2>&1
}

check_svxlink_audio_access() {
    local tool=$1
    runuser -u "${SVXLINK_USER}" -- "${tool}" -l >/dev/null 2>&1
}

run_checks() {
    require_root
    detect_operating_system
    log "Operating system: Debian/Raspberry Pi OS ${OS_VERSION}"
    log "Raspberry Pi detected: ${IS_RASPBERRY_PI}"
    if ${IS_RASPBERRY_PI}; then
        log "Boot configuration: ${BOOT_CONFIG}"
        check_item "Fe-Pi Audio boot overlay" grep -Fqx "dtoverlay=fe-pi-audio" "${BOOT_CONFIG}"
    fi
    if ! ${IS_RASPBERRY_PI}; then
        log "SKIP: ELENATA ALSA card check (not a Raspberry Pi)"
    elif elenata_profile_configured; then
        check_item "ELENATA ALSA card Audio" audio_card_available
    else
        log "INFO: ALSA card Audio not present; ELENATA profile not configured"
    fi
    if check_svxlink_user; then
        log "OK: SvxLink user"
        check_item "aplay as svxlink" check_svxlink_audio_access aplay
        check_item "arecord as svxlink" check_svxlink_audio_access arecord
    else
        log "MISSING: SvxLink user"
        log "SKIP: aplay as svxlink (user missing)"
        log "SKIP: arecord as svxlink (user missing)"
    fi
    check_item "SvxLink binary" bash -c 'command -v svxlink >/dev/null 2>&1'
    check_item "SvxLink service" systemctl is-enabled --quiet svxlink.service 2>/dev/null
    check_item "SvxLink log file" test -f "${SVXLINK_LOG}"
    check_logrotate_configuration
    if [[ -f ${APT_CONFIG} ]]; then
        check_item "Automatic APT updates disabled" automatic_updates_disabled
    else
        log "MISSING: Automatic APT updates disabled"
    fi
    log "Free space: $(df -h / | awk 'NR == 2 {print $4}')"
    if command -v lsof >/dev/null 2>&1; then
        if lsof +L1 2>/dev/null | grep -Eq 'svxlink.*(/var/log/svxlink).*\(deleted\)'; then
            log "MISSING: SvxLink has an open deleted log file."
        else
            log "OK: No open deleted SvxLink log file found."
        fi
    else
        log "MISSING: lsof is not installed."
    fi
    check_sound_status
}

check_sound_status() {
    local language simplex_language repeater_language
    for language in en_US de_DE; do
        if sound_directory_has_wav "${SVXLINK_SOUNDS_DIR}/${language}"; then
            log "OK: ${language} sound directory ($(sound_wav_count "${SVXLINK_SOUNDS_DIR}/${language}") WAV files)"
        else
            log "MISSING: ${language} sound directory"
        fi
    done
    [[ -f ${SVXLINK_CONFIG} ]] || return 0
    simplex_language=$(ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" || true)
    repeater_language=$(ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" || true)
    log "SimplexLogic DEFAULT_LANG: ${simplex_language:-missing}"
    log "RepeaterLogic DEFAULT_LANG: ${repeater_language:-missing}"
    [[ ${simplex_language} == "${repeater_language}" ]] || log "WARN: SimplexLogic and RepeaterLogic use different languages."
    for language in "${simplex_language}" "${repeater_language}"; do
        [[ -z ${language} ]] || sound_directory_has_wav "${SVXLINK_SOUNDS_DIR}/${language}" || \
            log "WARN: Active language ${language} has no usable sound directory."
    done
}

show_configuration() {
    local simplex_language repeater_language
    log "Hardware profile: ${HARDWARE_PROFILE}"
    [[ -f ${SVXLINK_CONFIG} ]] || { log "SvxLink configuration not found: ${SVXLINK_CONFIG}"; return 0; }
    log "Active LOGICS: $(ini_value "${SVXLINK_CONFIG}" "GLOBAL" "LOGICS" || true)"
    simplex_language=$(ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" || true)
    repeater_language=$(ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" || true)
    log "SimplexLogic DEFAULT_LANG: ${simplex_language:-missing}"
    log "RepeaterLogic DEFAULT_LANG: ${repeater_language:-missing}"
    log "Sound directory: ${SVXLINK_SOUNDS_DIR}"
    for language in en_US de_DE; do
        if sound_directory_has_wav "${SVXLINK_SOUNDS_DIR}/${language}"; then
            log "${language}: available ($(sound_wav_count "${SVXLINK_SOUNDS_DIR}/${language}") WAV files)"
        else
            log "${language}: missing"
        fi
    done
}

install_sound_interactively() {
    local language=$1 target replace_existing=false answer
    target="${SVXLINK_SOUNDS_DIR}/${language}"
    if [[ -e ${target} ]] && ! sound_directory_has_wav "${target}"; then
        read -r -p "${target} exists but is unusable. Backup and replace it? [j/N]: " answer
        [[ ${answer} == j || ${answer} == J ]] || { log "Keine Sounddateien geändert."; return 0; }
        replace_existing=true
    fi
    if [[ ${language} == de_DE ]]; then
        install_german_sounds "${replace_existing}"
    else
        install_english_sounds "${replace_existing}"
    fi
}

show_german_activation_information() {
    cat <<EOF
Die deutsche Sprache verwendet den mit diesem Projekt
bereitgestellten Sprachsatz "Anna 16k".

Zielordner:

  ${SVXLINK_SOUNDS_DIR}/de_DE

Der Inhalt wird bei manueller Aktivierung nicht auf
Vollständigkeit einzelner Ansagen geprüft.
EOF
}

confirm_installation() {
    local action=$1 answer
    cat <<EOF
Aktion:             ${action}
Rufzeichen:         ${CALLSIGN}
Board:              $(hardware_profile_name "${HARDWARE_PROFILE}")
Deutsche Sounds:    werden installiert
Englische Sounds:   werden installiert
Standardsprache:    Deutsch nach erfolgreicher Installation
EOF
    if ${ACTION_YES}; then
        return 0
    fi
    read -r -p "Installation jetzt starten? [j/N]: " answer
    [[ ${answer} == j || ${answer} == J ]]
}

run_installation() {
    local mode=${1:-automatic} existing_profile existing_callsign
    require_root
    detect_operating_system
    log "Detected Debian/Raspberry Pi OS ${OS_VERSION}; Raspberry Pi: ${IS_RASPBERRY_PI}."
    existing_callsign=""
    [[ -f ${SVXLINK_CONFIG} ]] && existing_callsign=$(ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "CALLSIGN" || true)
    if ${CALLSIGN_PROVIDED}; then
        :
    elif [[ ${mode} == automatic && ${existing_callsign} =~ ^[A-Z0-9][A-Z0-9_-]{2,15}$ ]]; then
        CALLSIGN=${existing_callsign}
        log "Vorhandenes Rufzeichen wird beibehalten: ${CALLSIGN}"
    elif ${ACTION_YES}; then
        die "--install --yes without an existing CALLSIGN requires --callsign=<name>."
    else
        prompt_callsign
    fi
    existing_profile=$(detected_hardware_profile)
    if ${HARDWARE_PROFILE_PROVIDED}; then
        :
    elif [[ ${mode} == automatic && -n ${existing_callsign} ]]; then
        HARDWARE_PROFILE=${existing_profile}
        log "Erkanntes Hardwareprofil wird beibehalten: $(hardware_profile_name "${HARDWARE_PROFILE}")"
    else
        choose_hardware_profile
    fi
    if ! confirm_installation "$([[ -n ${existing_callsign} ]] && printf 'Update' || printf 'Neuinstallation')"; then
        log "Installation abgebrochen."
        return 0
    fi
    install_packages
    disable_automatic_updates
    ensure_svxlink_account
    build_svxlink
    configure_logging
    configure_base_svxlink
    install_english_sounds || die "English sound installation failed; the installation is incomplete."
    if install_german_sounds; then
        GERMAN_SOUNDS_AVAILABLE=true
        activate_sound_language de_DE false || die "German sound installation succeeded but language activation failed."
    else
        log "WARN: German sound installation failed. English remains active."
    fi
    configure_hardware_profile
    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        log "ELENATA boot configuration was prepared. Reboot before putting the station into service."
    fi
    log "SvxLink was installed or updated."
    log "English sound files are installed or already present."
    if ${GERMAN_SOUNDS_AVAILABLE}; then
        log "German sound files are installed and German is active."
    else
        log "German installation failed; English remains active."
    fi
    log "SvxLink was not started automatically."
    enable_svxlink_service
    if [[ ${HARDWARE_PROFILE} == 0 ]]; then
        log "Base installation completed. Profile 0 does not create a productive audio, PTT or squelch configuration."
    else
        log "Installation completed. Verify the hardware with sudo ./${SCRIPT_NAME} --check before starting operation."
    fi
}

show_menu() {
    cat <<'EOF'
1) Installieren / aktualisieren
2) Systemstand anzeigen
3) Backup erstellen / wiederherstellen
4) Deutsche Sounds installieren
5) Englische Sounds installieren
6) Deutsch aktivieren
7) Englisch aktivieren
8) Konfiguration anzeigen
9) Beenden
EOF
}

create_full_backup() {
    local destination timestamp path
    local -a paths
    timestamp=$(date +%Y%m%d%H%M%S)
    destination="${SVXLINK_BACKUP_DIR}/${timestamp}"
    install -d -m 0750 "${destination}"
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        paths=("${SVXLINK_CONFIG}" "${LOGROTATE_CONFIG}" "${SVXLINK_SOUNDS_DIR}/de_DE" "${SVXLINK_SOUNDS_DIR}/en_US")
    else
        paths=(/etc/svxlink /etc/default/svxlink /etc/systemd/system/svxlink.service.d "${LOGROTATE_CONFIG}" "${SVXLINK_EVENTS_LOCAL_DIR}" "${SVXLINK_SOUNDS_DIR}/de_DE" "${SVXLINK_SOUNDS_DIR}/en_US")
    fi
    for path in "${paths[@]}"; do
        [[ -e ${path} ]] || continue
        cp -a --parents "${path}" "${destination}"
    done
    log "Backup created: ${destination}"
}

list_backups() {
    [[ -d ${SVXLINK_BACKUP_DIR} ]] || { log "No backups found."; return 0; }
    find "${SVXLINK_BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

backup_menu() {
    local choice answer selected
    while :; do
        cat <<'EOF'
============================================================
BACKUP
============================================================

1) Neues Backup erstellen
2) Vorhandenes Backup wiederherstellen
3) Vorhandene Backups anzeigen
4) Zurück
EOF
        read -r -p "Auswahl: " choice
        case ${choice} in
            1) create_full_backup ;;
            2)
                if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
                    log "WARN: Backup restore is disabled in test mode."
                    continue
                fi
                list_backups
                read -r -p "Backupname zur Wiederherstellung: " selected
                [[ -d ${SVXLINK_BACKUP_DIR}/${selected} ]] || { log "Backup nicht gefunden."; continue; }
                read -r -p "Aktuelle Installation wird vorher gesichert und vorhandene Dateien ersetzt. Fortfahren? [j/N]: " answer
                [[ ${answer} == j || ${answer} == J ]] || { log "Keine Wiederherstellung durchgeführt."; continue; }
                create_full_backup
                cp -a "${SVXLINK_BACKUP_DIR}/${selected}/." /
                log "Backup restored. SvxLink was not started."
                ;;
            3) list_backups ;;
            4) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
    done
}

install_menu() {
    local choice answer
    while :; do
        cat <<'EOF'
============================================================
INSTALLIEREN / AKTUALISIEREN
============================================================

1) Automatisch installieren oder aktualisieren
2) Erzwungene Neuinstallation
3) Zurück
EOF
        read -r -p "Auswahl: " choice
        case ${choice} in
            1) run_installation automatic ;;
            2)
                cat <<'EOF'
Dieser Modus ist für beschädigte oder unvollständige Installationen vorgesehen.

Vorher wird automatisch ein vollständiges Backup erstellt.

Neu aufgebaut werden SvxLink-Quellcode, Build-Verzeichnis, Programme,
Bibliotheken, systemd-Dateien, Standardressourcen und beide Sprachsätze.
Konfiguration, lokale Events, systemd-Overrides und Soundanpassungen werden
gesichert und nicht ungefragt gelöscht.
EOF
                read -r -p "Erzwungene Neuinstallation starten? [j/N]: " answer
                [[ ${answer} == j || ${answer} == J ]] || { log "Abgebrochen."; continue; }
                create_full_backup
                run_installation force
                ;;
            3) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
    done
}

run_menu() {
    local choice
    require_root
    while :; do
        show_header
        show_menu
        read -r -p "Auswahl: " choice
        case ${choice} in
            1) install_menu ;;
            2) run_checks; read -r -p "ENTER zum Hauptmenü ..." _ ;;
            3) backup_menu ;;
            4) install_sound_interactively de_DE || log "German sound installation failed." ;;
            5) install_sound_interactively en_US || log "English sound installation failed." ;;
            6) show_german_activation_information; activate_sound_language de_DE true || log "German was not activated." ;;
            7) activate_sound_language en_US true || log "English was not activated." ;;
            8) show_configuration ;;
            9) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
        printf '\n'
    done
}

show_help() {
    cat <<EOF
Usage: sudo ./${SCRIPT_NAME} [--menu|--install|--check|--install-german-sounds|--install-english-sounds|--activate-german-sounds|--activate-english-sounds|--show-config] [--callsign=<name>] [--profile=0..4] [--yes]

Without an action parameter, the interactive menu is shown. Writing non-interactive actions require --yes.
EOF
}

main() {
    local action=--menu argument
    for argument in "$@"; do
        case ${argument} in
            --yes) ACTION_YES=true ;;
            --callsign=*)
                CALLSIGN=${argument#--callsign=}
                CALLSIGN=${CALLSIGN^^}
                [[ ${CALLSIGN} =~ ^[A-Z0-9][A-Z0-9_-]{2,15}$ ]] || die "Invalid --callsign value."
                CALLSIGN_PROVIDED=true
                ;;
            --profile=*)
                HARDWARE_PROFILE=${argument#--profile=}
                [[ ${HARDWARE_PROFILE} =~ ^[0-4]$ ]] || die "Invalid --profile value."
                HARDWARE_PROFILE_PROVIDED=true
                ;;
            --menu|--install|--check|--install-german-sounds|--install-english-sounds|--activate-german-sounds|--activate-english-sounds|--show-config|--help)
                [[ ${action} == --menu ]] || die "Only one action parameter is allowed."
                action=${argument}
                ;;
            *) die "Unknown parameter: ${argument}. Use --help." ;;
        esac
    done
    [[ ${action} != --help ]] || { show_help; return 0; }
    require_root
    case ${action} in
        --menu) run_menu ;;
        --check) run_checks ;;
        --show-config) show_configuration ;;
        --install|--install-german-sounds|--install-english-sounds|--activate-german-sounds|--activate-english-sounds)
            ${ACTION_YES} || die "Non-interactive write actions require --yes."
            case ${action} in
                --install) run_installation automatic ;;
                --install-german-sounds) install_german_sounds ;;
                --install-english-sounds) install_english_sounds ;;
                --activate-german-sounds) activate_sound_language de_DE false ;;
                --activate-english-sounds) activate_sound_language en_US false ;;
            esac
            ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
