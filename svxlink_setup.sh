#!/usr/bin/env bash
# SvxLink installation for Debian 12/13 and Raspberry Pi OS based on them.

set -Eeuo pipefail

readonly SCRIPT_NAME=${0##*/}
if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
    svxlink_config_path=${SVXLINK_CONFIG_FILE:-/etc/svxlink/svxlink.conf}
    svxlink_log_path=${LOG_FILE:-/var/log/svxlink}
    svxlink_logrotate_path=${LOGROTATE_FILE:-/etc/logrotate.d/svxlink}
    svxlink_backup_path=${SVXLINK_BACKUP_DIR:-/var/backups/svxlink-setup}
    alsa_state_path=${ALSA_STATE_FILE:-}
else
    svxlink_config_path=/etc/svxlink/svxlink.conf
    svxlink_log_path=/var/log/svxlink
    svxlink_logrotate_path=/etc/logrotate.d/svxlink
    svxlink_backup_path=/var/backups/svxlink-setup
    alsa_state_path=""
fi
readonly SVXLINK_REPOSITORY="https://github.com/sm0svx/svxlink.git"
readonly SVXLINK_USER="svxlink"
readonly SVXLINK_GROUP="svxlink"
readonly SVXLINK_CONFIG="${svxlink_config_path}"
readonly SVXLINK_CONFIG_DIR="/etc/svxlink/svxlink.d"
readonly SVXLINK_EVENTS_DIR="/usr/share/svxlink/events.d"
readonly SVXLINK_EVENTS_LOCAL_DIR="/usr/share/svxlink/events.d/local"
readonly SVXLINK_SOUNDS_DIR="/usr/share/svxlink/sounds"
readonly SVXLINK_LOG="${svxlink_log_path}"
readonly APT_CONFIG="/etc/apt/apt.conf.d/20svxlink-disable-auto-updates"
readonly LOGROTATE_CONFIG="${svxlink_logrotate_path}"
readonly SVXLINK_BACKUP_DIR="${svxlink_backup_path}"

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
    [[ ${EUID} -eq 0 ]] || die "Run the script with sudo: sudo ./${SCRIPT_NAME}"
    [[ -n ${SUDO_USER:-} && ${SUDO_USER} != "root" ]] || die "Run the script through sudo from a regular user account."

    INSTALL_USER=${SUDO_USER}
    INSTALL_HOME=$(getent passwd "${INSTALL_USER}" | cut -d: -f6)
    [[ -n ${INSTALL_HOME} && ${INSTALL_HOME} != "/root" ]] || die "Could not determine the invoking user's home directory."
    SOURCE_DIR="${INSTALL_HOME}/svxlink"
    BUILD_DIR="${SOURCE_DIR}/src/build"
}

backup_file() {
    local file=$1
    [[ -e ${file} ]] || return 0
    install -d -m 0750 "${SVXLINK_BACKUP_DIR}"
    cp -a "${file}" "${SVXLINK_BACKUP_DIR}/$(basename "${file}").$(date +%Y%m%d%H%M%S%N).bak"
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

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
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
    log "  4) ELENATA Wolfson / Fe-Pi Audio"

    while :; do
        read -r -p "Auswahl (0 oder 4): " HARDWARE_PROFILE
        [[ ${HARDWARE_PROFILE} == 0 || ${HARDWARE_PROFILE} == 4 ]] || \
            { log "Ungültige Auswahl. Erlaubt sind 0 und 4."; continue; }
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
    if [[ -d ${SVXLINK_SOUNDS_DIR}/de_DE ]]; then
        set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" "de_DE"
        GERMAN_SOUNDS_AVAILABLE=true
    else
        set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" "en_US"
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
}

main() {
    if [[ ${1:-} == "--check" ]]; then
        run_checks
        return 0
    fi
    [[ $# -eq 0 ]] || die "Usage: sudo ./${SCRIPT_NAME} [--check]"

    require_root
    detect_operating_system
    log "Detected Debian/Raspberry Pi OS ${OS_VERSION}; Raspberry Pi: ${IS_RASPBERRY_PI}."
    prompt_callsign
    choose_hardware_profile
    install_packages
    disable_automatic_updates
    ensure_svxlink_account
    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        configure_elenata_boot
    fi
    build_svxlink
    configure_logging
    configure_base_svxlink
    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        configure_elenata_svxlink
        configure_elenata_alsa
        log "ELENATA boot configuration was prepared. Reboot before putting the station into service."
    fi
    log "Standard RepeaterLogic is active; local extensions stay available in ${SVXLINK_EVENTS_DIR}, ${SVXLINK_EVENTS_LOCAL_DIR} and ${SVXLINK_CONFIG_DIR}."
    log "German sound resources are expected below ${SVXLINK_SOUNDS_DIR}; no unverified source is downloaded."
    enable_svxlink_service
    if ! ${GERMAN_SOUNDS_AVAILABLE}; then
        log "WARN: RepeaterLogic is prepared for de_DE, but German sound files are not installed."
    fi
    if [[ ${HARDWARE_PROFILE} == 0 ]]; then
        log "Base installation completed. Profile 0 does not create a productive audio, PTT or squelch configuration."
    else
        log "Installation completed. Verify the hardware with sudo ./${SCRIPT_NAME} --check before starting operation."
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
