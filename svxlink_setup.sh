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
    build_state_path=${SVXLINK_BUILD_STATE_FILE:-/var/lib/svxlink-setup/build-state}
    install_log_dir_path=${SVXLINK_INSTALL_LOG_DIR:-/tmp/svxlink-setup-test/logs}
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
    build_state_path=/var/lib/svxlink-setup/build-state
    install_log_dir_path=/var/log/svxlink-setup
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
readonly BUILD_STATE_FILE="${build_state_path}"
readonly INSTALL_LOG_DIR="${install_log_dir_path}"
if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
    elenata_alsa_unit_path=${ELENATA_ALSA_UNIT_FILE:-/tmp/svxlink-setup-test/systemd/svxlink-setup-elenata-alsa.service}
    elenata_alsa_helper_path=${ELENATA_ALSA_HELPER_FILE:-/tmp/svxlink-setup-test/lib/elenata-alsa-postboot.sh}
    elenata_alsa_pending_path=${ELENATA_ALSA_PENDING_FILE:-/tmp/svxlink-setup-test/state/elenata-alsa.pending}
    elenata_alsa_config_path=${ELENATA_ALSA_CONFIG_FILE:-/tmp/svxlink-setup-test/etc/elenata-alsa.conf}
    elenata_alsa_postboot_log_path=${ELENATA_ALSA_POSTBOOT_LOG_FILE:-/tmp/svxlink-setup-test/logs/elenata-alsa-postboot.log}
else
    elenata_alsa_unit_path=/etc/systemd/system/svxlink-setup-elenata-alsa.service
    elenata_alsa_helper_path=/usr/local/lib/svxlink-setup/elenata-alsa-postboot.sh
    elenata_alsa_pending_path=/var/lib/svxlink-setup/elenata-alsa.pending
    elenata_alsa_config_path=/etc/svxlink-setup/elenata-alsa.conf
    elenata_alsa_postboot_log_path=/var/log/svxlink-setup/elenata-alsa-postboot.log
fi
readonly ELENATA_ALSA_UNIT_FILE="${elenata_alsa_unit_path}"
readonly ELENATA_ALSA_HELPER_FILE="${elenata_alsa_helper_path}"
readonly ELENATA_ALSA_PENDING_FILE="${elenata_alsa_pending_path}"
readonly ELENATA_ALSA_CONFIG_FILE="${elenata_alsa_config_path}"
readonly ELENATA_ALSA_POSTBOOT_LOG_FILE="${elenata_alsa_postboot_log_path}"
readonly GERMAN_SOUND_URL="https://cloud.stockreiter.eu/public.php/dav/files/xYa3dWLK9NtAer4/"
readonly GERMAN_SOUND_AUTH_USER="xYa3dWLK9NtAer4"
readonly GERMAN_SOUND_SHA256="bc30601196bd493b672525e5999252f5d7f4da36a783fadbd0c4d3589838d9c4"
readonly GERMAN_SOUND_ROOT="sounds/de_DE"
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
OS_ID=""
OS_SUPPORTED=true
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
INSTALL_LOG_FILE=""
DEBUG_LOG_FILE=""
DEBUG_MODE=false
DEBUG_FD=""
DEBUG_STDOUT_FD=""
DEBUG_STDERR_FD=""
TERMINAL_FD=""
ORIGINAL_OUTPUT_IS_TTY=false
ACTIVITY_PID=""
ACTIVE_COMMAND_PID=""
BUILD_PERFORMED=false
ELENATA_ALSA_CARD_AVAILABLE=false
SVXLINK_SERVICE_WAS_PRESENT=false
SVXLINK_SERVICE_WAS_ENABLED=false
SVXLINK_SERVICE_WAS_ACTIVE=false
CMAKE_OPTIONS=(
    -DUSE_QT=OFF
    -DCMAKE_INSTALL_PREFIX=/usr
    -DSYSCONF_INSTALL_DIR=/etc
    -DLOCAL_STATE_DIR=/var
    -DWITH_SYSTEMD=ON
)

if [[ -t 1 || ${SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT:-false} == true ]]; then
    ORIGINAL_OUTPUT_IS_TTY=true
    exec {TERMINAL_FD}>&1
fi

terminal_is_interactive() {
    ${ORIGINAL_OUTPUT_IS_TTY} && [[ ${TERM:-dumb} != dumb ]]
}

output_uses_color() {
    terminal_is_interactive && [[ -z ${NO_COLOR:-} ]]
}

terminal_printf() {
    # shellcheck disable=SC2059
    if [[ -n ${TERMINAL_FD} ]]; then
        printf "$@" >&${TERMINAL_FD}
    else
        printf "$@"
    fi
}

print_colored() {
    local color=$1 label=$2 message=$3 prefix='' reset=''
    if output_uses_color; then
        case ${color} in
            green) prefix='\033[32m' ;;
            yellow) prefix='\033[33m' ;;
            red) prefix='\033[31m' ;;
            cyan) prefix='\033[36m' ;;
        esac
        reset='\033[0m'
    fi
    terminal_printf '%b[%s]%b %s\n' "${prefix}" "${label}" "${reset}" "${message}"
}

print_info() { print_colored cyan 'INFO' "$*"; }
print_success() { print_colored green ' OK ' "$*"; }
print_warning() { print_colored yellow 'WARN' "$*"; }
print_error() { print_colored red 'FEHLER' "$*" >&2; }
print_skip() { print_colored '' '  - ' "$*"; }
print_section() { printf '\n============================================================\n%s\n============================================================\n' "$*"; }

print_prompt() {
    local text=$1 prefix='' reset=''
    if output_uses_color; then prefix='\033[1;35m'; reset='\033[0m'; fi
    if [[ -n ${TERMINAL_FD} ]]; then
        terminal_printf '%b%s%b' "${prefix}" "${text}" "${reset}"
    else
        printf '%b%s%b' "${prefix}" "${text}" "${reset}" >&2
    fi
}

prompt_value() {
    local variable=$1 text=$2
    local -n result=${variable}
    print_prompt "${text}"
    IFS= read -r result
}

prompt_secret() {
    # shellcheck disable=SC2034
    local variable=$1 text=$2 trace_was_enabled=false
    local -n result=${variable}
    [[ $- == *x* ]] && { trace_was_enabled=true; set +x; }
    print_prompt "${text}"
    # shellcheck disable=SC2034
    if IFS= read -r -s result; then terminal_printf '\n'; else terminal_printf '\n'; [[ ${trace_was_enabled} != true ]] || set -x; return 1; fi
    [[ ${trace_was_enabled} != true ]] || set -x
}

show_header() {
    local width=63 text='SVXLINK SETUP' padding_left padding_right
    padding_left=$(( (width - ${#text}) / 2 ))
    padding_right=$(( width - ${#text} - padding_left ))
    printf '+%*s+\n' "${width}" '' | tr ' ' '-'
    printf '|%*s%s%*s|\n' "${padding_left}" '' "${text}" "${padding_right}" ''
    printf '|%-*s|\n' "${width}" 'Debian / Raspberry Pi OS'
    printf '|%-*s|\n' "${width}" ''
    printf '|%-*s|\n' "${width}" 'Basierend auf svxlink_setup von DF5KX & DO6NP'
    printf '|%-*s|\n' "${width}" 'Weiterentwickelt und angepasst von DO6DD'
    printf '+%*s+\n' "${width}" '' | tr ' ' '-'
}

log() {
    print_info "$*"
}

die() {
    print_error "$*"
    exit 1
}

require_command() {
    local program=$1
    if [[ ${SVXLINK_TEST_MODE:-false} == true && ",${SVXLINK_TEST_MISSING_COMMANDS:-}," == *",${program},"* ]]; then
        print_error "Erforderliches Programm fehlt: ${program}. Bitte prüfe die Paketinstallation."
        return 1
    fi
    if ! command -v "${program}" >/dev/null 2>&1; then
        print_error "Erforderliches Programm fehlt: ${program}. Bitte prüfe die Paketinstallation."
        return 1
    fi
    return 0
}

require_base_tools() {
    local program
    for program in curl tar bzip2 sha256sum git cmake make g++; do
        require_command "${program}" || return 1
    done
}

on_error() {
    local exit_code=$?
    set +x
    [[ -z ${ACTIVE_COMMAND_PID} ]] || kill "${ACTIVE_COMMAND_PID}" 2>/dev/null || true
    stop_activity_indicator
    log "ERROR: command failed at line ${BASH_LINENO[0]} (exit ${exit_code})"
    exit "${exit_code}"
}
trap on_error ERR


start_debug_log() {
    local timestamp debug_log_dir
    ${DEBUG_MODE} || return 0
    [[ -n ${DEBUG_LOG_FILE} ]] && return 0

    debug_log_dir=${SVXLINK_DEBUG_LOG_DIR:-${INSTALL_LOG_DIR}}
    install -d -m 0755 "${debug_log_dir}"
    timestamp=$(date +%Y%m%d%H%M%S%N)
    DEBUG_LOG_FILE="${debug_log_dir}/debug-${timestamp}.log"
    : >"${DEBUG_LOG_FILE}"
    chmod 0600 "${DEBUG_LOG_FILE}"
    if [[ ${SVXLINK_TEST_MODE:-false} != true ]]; then chown root:root "${DEBUG_LOG_FILE}"; fi

    # The script does not accept credentials, passwords, or private keys. Keep
    # tracing opt-in nevertheless, because xtrace records command arguments.
    exec {DEBUG_FD}>>"${DEBUG_LOG_FILE}"
    exec {DEBUG_STDOUT_FD}>&1 {DEBUG_STDERR_FD}>&2
    exec > >(tee -a "${DEBUG_LOG_FILE}" >&${DEBUG_STDOUT_FD}) \
        2> >(tee -a "${DEBUG_LOG_FILE}" >&${DEBUG_STDERR_FD})
    BASH_XTRACEFD=${DEBUG_FD}
    PS4='+ ${BASH_SOURCE[0]:-main}:${LINENO}:${FUNCNAME[0]:-main}: exit=${?}: '
    export BASH_XTRACEFD PS4
    set -x
    print_info "Debuglog: ${DEBUG_LOG_FILE}"
}

append_install_output_to_debug_log() {
    local offset=$1
    ${DEBUG_MODE} || return 0
    tail -c "+$((offset + 1))" "${INSTALL_LOG_FILE}" >>"${DEBUG_LOG_FILE}" 2>&1 || true
}

print_root_required_error() {
    local action=${1:-}
    local invocation="sudo ./${SCRIPT_NAME}"
    [[ -z ${action} || ${action} == --menu ]] || invocation+=" ${action}"
    print_error 'Root-Rechte erforderlich.'
    printf '\nBitte starte diese Aktion mit:\n\n  %s\n' "${invocation}" >&2
}

require_root_for_action() {
    local action=${1:-}
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        return 0
    fi
    if [[ ${EUID} -ne 0 ]]; then
        print_root_required_error "${action}"
        return 1
    fi
    [[ -n ${INSTALL_USER} ]] && return 0
    resolve_install_user
}

# Compatibility helper for existing function tests.
require_root() { require_root_for_action; }

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
        4)
            configure_elenata_boot
            configure_elenata_svxlink
            configure_elenata_alsa
            if ${ELENATA_ALSA_CARD_AVAILABLE}; then
                clear_elenata_alsa_postboot
            else
                install_elenata_alsa_postboot
                print_info 'ELENATA-Audio wird nach dem nächsten Neustart automatisch konfiguriert. Ein erneuter manueller Setup-Lauf ist dafür nicht erforderlich.'
            fi
            ;;
        *) die "Unsupported hardware profile: ${HARDWARE_PROFILE}" ;;
    esac
}

sound_directory_has_wav() {
    local directory=$1
    [[ -d ${directory} ]] && find "${directory}" -type f -name '*.wav' -size +0c -print -quit 2>/dev/null | grep -q .
}

sound_wav_count() {
    local directory=$1
    [[ -d ${directory} ]] || { printf '0\n'; return 0; }
    find "${directory}" -type f -name '*.wav' -printf '.' 2>/dev/null | wc -c
}

normalize_archive_path() {
    local path=$1 component joined last_index
    local -a components normalized
    [[ ${path} != /* ]] || return 1
    IFS=/ read -r -a components <<<"${path}"
    for component in "${components[@]}"; do
        case ${component} in
            ''|.) ;;
            ..)
                ((${#normalized[@]} > 0)) || return 1
                last_index=$((${#normalized[@]} - 1))
                unset "normalized[${last_index}]"
                ;;
            *) normalized+=("${component}") ;;
        esac
    done
    ((${#normalized[@]} > 0)) || return 1
    joined=$(IFS=/; printf '%s' "${normalized[*]}")
    printf '%s\n' "${joined}"
}

archive_path_is_within_root() {
    local path=$1 root=$2
    [[ ${path} == "${root}" || ${path} == "${root}/"* ]]
}

archive_link_target_is_safe() {
    local entry=$1 target=$2 expected_root=$3 base resolved
    [[ ${target} != /* ]] || return 1
    base=${entry%/*}
    [[ ${base} != "${entry}" ]] || base=''
    resolved=$(normalize_archive_path "${base:+${base}/}${target}") || return 1
    archive_path_is_within_root "${resolved}" "${expected_root}"
}

archive_hardlink_target_is_safe() {
    local target=$1 expected_root=$2 resolved
    [[ ${target} != /* ]] || return 1
    resolved=$(normalize_archive_path "${target}") || return 1
    archive_path_is_within_root "${resolved}" "${expected_root}"
}

sound_archive_is_safe() {
    local archive=$1 expected_root=$2 entry type listing link_target separator link_suffix parent listing_file required_parent=false
    local -a listings
    listing_file=$(mktemp) || return 1
    # shellcheck disable=SC2016
    if ! run_logged 'Soundarchiv wird geprüft' bash -c 'LC_ALL=C tar --numeric-owner --full-time --quoting-style=literal -tvjf "$1" >"$2"' _ "${archive}" "${listing_file}"; then
        rm -f -- "${listing_file}"
        log "Soundarchiv kann nicht gelesen werden: ${archive}"
        return 1
    fi

    mapfile -t listings <"${listing_file}"
    rm -f -- "${listing_file}"
    for listing in "${listings[@]}"; do
        # GNU tar emits fixed metadata followed by one literal space and the
        # member name.  Capture the remaining text verbatim: member names may
        # themselves contain spaces, tabs, '#', or Unicode characters.
        if [[ ${listing} =~ ^(.{10})\ [0-9]+/[0-9]+[[:space:]]+[0-9]+\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?\ (.*)$ ]]; then
            type=${BASH_REMATCH[1]:0:1}
            entry=${BASH_REMATCH[3]}
        else
            log "Soundarchiv enthält eine nicht lesbare Tar-Auflistung: ${listing}"
            return 1
        fi
        if [[ ${type} == l || ${type} == h ]]; then
            if [[ ${type} == l ]]; then
                link_target=${entry##*' -> '}
                separator=' -> '
            else
                link_target=${entry##*' link to '}
                separator=' link to '
            fi
            link_suffix="${separator}${link_target}"
            [[ ${entry} == *"${link_suffix}" ]] || {
                log "Soundarchiv enthält einen nicht lesbaren Link: ${listing}"; return 1;
            }
            entry=${entry:0:${#entry}-${#link_suffix}}
        fi
        required_parent=false
        parent=${expected_root}
        while [[ ${parent} == */* ]]; do
            parent=${parent%/*}
            if [[ ${entry} == "${parent}" || ${entry} == "${parent}/" ]]; then
                required_parent=true
                break
            fi
        done
        ${required_parent} || [[ ${entry} == "${expected_root}/"* || ${entry} == "${expected_root}" || ${entry} == "${expected_root}/" ]] || {
            log "Soundarchiv enthält einen unerwarteten Pfad: ${entry}"; return 1;
        }
        [[ ${entry} != /* && ${entry} != *'../'* && ${entry} != '..' ]] || {
            log "Soundarchiv enthält einen unsicheren Pfad: ${entry}"; return 1;
        }
        [[ ${entry} != *'/.git/'* && ${entry} != */.git && ${entry} != *'/.svn/'* && ${entry} != */.svn && ${entry} != *.svn-base && ${entry} != *.tcl ]] || {
            log "Soundarchiv enthält einen unzulässigen Eintrag: ${entry}"; return 1;
        }
        if ${required_parent}; then
            [[ ${type} == d ]] || {
                log "Soundarchiv enthält einen nicht unterstützten Vorfahrentyp: ${listing}"; return 1;
            }
            continue
        fi
        if [[ ${type} == l ]]; then
            archive_link_target_is_safe "${entry}" "${link_target}" "${expected_root}" || {
                log "Soundarchiv enthält einen unsicheren symbolischen Link: ${listing}"; return 1;
            }
            continue
        fi
        if [[ ${type} == h ]]; then
            archive_hardlink_target_is_safe "${link_target}" "${expected_root}" || {
                log "Soundarchiv enthält einen unsicheren harten Link: ${listing}"; return 1;
            }
            continue
        fi
        [[ ${type} == '-' || ${type} == 'd' ]] || {
            log "Soundarchiv enthält einen nicht unterstützten Eintragstyp: ${listing}"; return 1;
        }
    done
    return 0
}

materialize_sound_links() {
    local directory=$1 link resolved replacement
    while IFS= read -r -d '' link; do
        resolved=$(readlink -f -- "${link}") || { log "Broken sound link: ${link}"; return 1; }
        [[ ${resolved} == "${directory}/"* && -f ${resolved} ]] || {
            log "Soundlink verweist außerhalb des entpackten Archivs: ${link}"; return 1;
        }
        replacement="${link}.svxlink-materialized"
        cp --dereference --preserve=mode -- "${link}" "${replacement}" || return 1
        mv -f -- "${replacement}" "${link}" || return 1
    done < <(find "${directory}" -type l -print0)
}

normalize_sound_permissions() {
    local directory=$1
    [[ -d ${directory} ]] || { log "Soundverzeichnis fehlt: ${directory}"; return 1; }
    if [[ ${SVXLINK_TEST_MODE:-false} == true && ${SVXLINK_TEST_FAIL_SOUND_PERMISSIONS:-false} == true ]]; then
        log "Sound permission normalization failed in test mode."
        return 1
    fi
    if [[ ${SVXLINK_TEST_MODE:-false} != true ]]; then
        find "${directory}" \( -type d -o -type f \) \( ! -user "${SVXLINK_USER}" -o ! -group "${SVXLINK_GROUP}" \) -exec chown "${SVXLINK_USER}:${SVXLINK_GROUP}" {} + || {
            log "Besitzer des Soundverzeichnisses konnten nicht gesetzt werden: ${directory}"
            return 1
        }
    fi
    find "${directory}" -type d ! -perm 0755 -exec chmod 0755 {} + || {
        log "Verzeichnisrechte konnten nicht gesetzt werden: ${directory}"
        return 1
    }
    find "${directory}" -type f ! -perm 0644 -exec chmod 0644 {} + || {
        log "Dateirechte konnten nicht gesetzt werden: ${directory}"
        return 1
    }
    return 0
}

sound_package_already_present() {
    local language=$1 label=$2 target
    target="${SVXLINK_SOUNDS_DIR}/${language}"
    sound_directory_has_wav "${target}" || return 1
    normalize_sound_permissions "${target}" || return 1
    print_success "${label} Sounds sind bereits vorhanden."
    [[ ${language} != en_US ]] || print_info 'Download wird übersprungen.'
    return 0
}

install_sound_archive() (
    local archive=$1 expected_sha=$2 expected_root=$3 language=$4 replace_existing=${5:-false}
    local actual_sha temporary staged target
    target="${SVXLINK_SOUNDS_DIR}/${language}"
    if sound_package_already_present "${language}" "$([[ ${language} == de_DE ]] && printf Deutsche || printf Englische)"; then
        return 0
    fi
    require_command tar || return 1
    require_command bzip2 || return 1
    require_command sha256sum || return 1
    [[ -f ${archive} ]] || { log "Soundarchiv fehlt: ${archive}"; return 1; }
    actual_sha=$(sha256sum "${archive}" | awk '{print $1}')
    [[ ${actual_sha} == "${expected_sha}" ]] || {
        log "Prüfsummenprüfung des Soundarchivs fehlgeschlagen: ${archive}"; return 1;
    }
    sound_archive_is_safe "${archive}" "${expected_root}" || return 1

    if [[ -e ${target} && ${replace_existing} != true ]]; then
        log "Soundverzeichnis ist vorhanden, enthält aber keine nutzbaren WAV-Dateien: ${target}"
        return 1
    fi

    temporary=$(mktemp -d)
    trap 'rm -rf "${temporary}"' EXIT
    # shellcheck disable=SC2016
    if ! run_logged "$([[ ${language} == de_DE ]] && printf 'Deutsche Sounds werden entpackt' || printf 'Englische Sounds werden entpackt')" bash -c 'tar -xjf "$1" -C "$2" --no-same-owner --no-same-permissions' _ "${archive}" "${temporary}"; then
        log "Entpacken des Soundarchivs fehlgeschlagen: ${archive}"
        return 1
    fi
    staged="${temporary}/${expected_root}"
    if ! sound_directory_has_wav "${staged}"; then
        log "Soundarchiv enthält keine WAV-Dateien: ${archive}"
        return 1
    fi
    materialize_sound_links "${staged}" || return 1
    normalize_sound_permissions "${staged}" || return 1
    install -d -m 0755 "${SVXLINK_SOUNDS_DIR}"
    if [[ -e ${target} ]]; then
        move_directory_to_backup "${target}" || return 1
    fi
    mv "${staged}" "${target}"
    print_success "Soundverzeichnis wurde installiert: ${target}"
    return 0
)

write_german_sound_curl_config() {
    local config_file=$1 password='' escaped_password trace_was_enabled=false
    [[ $- == *x* ]] && { trace_was_enabled=true; set +x; }

    if [[ ${SVXLINK_TEST_MODE:-false} == true && -n ${GERMAN_SOUND_TEST_PASSWORD:-} ]]; then
        password=${GERMAN_SOUND_TEST_PASSWORD}
    else
        if [[ ! -t 0 ]]; then
            print_error 'Das Passwort für die deutschen Sounds kann nur interaktiv abgefragt werden.'
            if ${trace_was_enabled}; then set -x; fi
            return 1
        fi
        if ! prompt_secret password 'Passwort für die deutschen Sounds: '; then
            print_error 'Passwort für die deutschen Sounds konnte nicht gelesen werden.'
            if ${trace_was_enabled}; then set -x; fi
            return 1
        fi
    fi
    if [[ -z ${password} ]]; then
        print_error 'Für den Download der deutschen Sounds ist ein Passwort erforderlich.'
        if ${trace_was_enabled}; then set -x; fi
        return 1
    fi

    escaped_password=${password//\\/\\\\}
    escaped_password=${escaped_password//\"/\\\"}
    (umask 077; printf 'user = "%s:%s"\n' "${GERMAN_SOUND_AUTH_USER}" "${escaped_password}" >"${config_file}")
    chmod 0600 "${config_file}"
    unset password escaped_password
    if ${trace_was_enabled}; then set -x; fi
}

install_german_sounds() (
    local replace_existing=${1:-false} target temporary archive curl_config expected_sha=${GERMAN_SOUND_SHA256} attempt
    target="${SVXLINK_SOUNDS_DIR}/de_DE"
    sound_package_already_present de_DE Deutsche && return 0
    [[ ! -e ${target} || ${replace_existing} == true ]] || replace_existing=true
    require_command curl || return 1
    if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
        expected_sha=${GERMAN_SOUND_SHA256_OVERRIDE:-${GERMAN_SOUND_SHA256}}
    fi
    temporary=$(mktemp -d)
    trap 'rm -rf "${temporary}"' EXIT
    archive="${temporary}/svxlink-sounds-de_DE-nextcloud.tar.bz2"
    curl_config="${temporary}/curl.conf"
    for attempt in 1 2 3; do
        write_german_sound_curl_config "${curl_config}" || return 1
        if download_logged 'Deutsche Sounds' "${archive}" --config "${curl_config}" --fail --location --silent --show-error --proto '=https' --tlsv1.2 --retry 2 --connect-timeout 20 "${GERMAN_SOUND_URL}"; then
            break
        fi
        rm -f -- "${archive}" "${curl_config}"
        if (( attempt < 3 )); then
            print_warning "Passwort nicht akzeptiert oder Download fehlgeschlagen. Noch $((3 - attempt)) Versuche."
        else
            print_warning 'Download der deutschen Sounds fehlgeschlagen. Bei HTTP 401 bitte Passwort und Zugriffsrechte prüfen.'
            print_warning 'Deutsche Sounds wurden nicht installiert. Sie können später im Hauptmenü nachgeladen werden.'
            return 1
        fi
    done
    install_sound_archive "${archive}" "${expected_sha}" "${GERMAN_SOUND_ROOT}" de_DE "${replace_existing}"
)

install_english_sounds() (
    local replace_existing=${1:-false} target
    local temporary archive expected_sha=${ENGLISH_SOUND_SHA256}
    sound_package_already_present en_US Englische && return 0
    target="${SVXLINK_SOUNDS_DIR}/en_US"
    [[ ! -e ${target} || ${replace_existing} == true ]] || replace_existing=true
    require_command curl || return 1
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
    if ! download_logged 'Englische Sounds' "${archive}" --fail --location --silent --show-error --proto '=https' --tlsv1.2 --retry 2 --connect-timeout 20 "${ENGLISH_SOUND_URL}"; then
        log 'Download der englischen Sounds fehlgeschlagen.'
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
    [[ -f ${SVXLINK_CONFIG} ]] || { log "SvxLink-Konfiguration nicht gefunden: ${SVXLINK_CONFIG}"; return 1; }
    if ! grep -Fqx '[SimplexLogic]' "${SVXLINK_CONFIG}" || ! grep -Fqx '[RepeaterLogic]' "${SVXLINK_CONFIG}"; then
        log 'Für die Sprachaktivierung sind die Abschnitte SimplexLogic und RepeaterLogic erforderlich.'
        return 1
    fi
    if ! sound_directory_has_wav "${target}"; then
        log "Kein nutzbares ${language}-Soundverzeichnis gefunden: ${target}"
        return 1
    fi
    if ! normalize_sound_permissions "${target}"; then
        log "${language} wurde nicht aktiviert, weil die Soundrechte nicht normalisiert werden konnten."
        return 1
    fi
    if ${interactive}; then
        prompt_value answer "${language} jetzt aktivieren? [j/N]: "
        [[ ${answer} == j || ${answer} == J ]] || { log "Keine Konfiguration geändert."; return 0; }
    fi
    backup_file "${SVXLINK_CONFIG}"
    set_ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" "${language}"
    set_ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" "${language}"
    if [[ ${language} == de_DE ]]; then
        print_success 'Deutsch ist für SimplexLogic und RepeaterLogic aktiviert.'
    else
        print_success 'Englisch ist für SimplexLogic und RepeaterLogic aktiviert.'
    fi
    print_info 'SvxLink wurde nicht gestartet.'
    return 0
}

detect_operating_system() {
    local allow_unsupported=${1:-false}
    if [[ ${SVXLINK_TEST_MODE:-false} == true && ${SVXLINK_TEST_RASPBERRY_PI:-false} == true ]]; then
        IS_RASPBERRY_PI=true
        BOOT_CONFIG=${BOOT_CONFIG_FILE:?BOOT_CONFIG_FILE is required in test mode}
        return 0
    fi
    if [[ ${SVXLINK_TEST_MODE:-false} == true && -n ${SVXLINK_TEST_OS_VERSION:-} ]]; then
        OS_VERSION=${SVXLINK_TEST_OS_VERSION}
        OS_ID=${SVXLINK_TEST_OS_ID:-debian}
        IS_RASPBERRY_PI=false
        return 0
    fi
    [[ -r /etc/os-release ]] || die "Missing /etc/os-release."
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_VERSION=${VERSION_ID:-}
    OS_ID=${ID:-}

    OS_SUPPORTED=true
    case ${ID:-} in
        debian|raspbian) ;;
        *)
            OS_SUPPORTED=false
            ${allow_unsupported} || die "Unsupported operating system: ${PRETTY_NAME:-unknown}. Only Debian 12/13 and Raspberry Pi OS are supported."
            ;;
    esac
    if [[ ${OS_VERSION} != "12" && ${OS_VERSION} != "13" ]]; then
        OS_SUPPORTED=false
        ${allow_unsupported} || die "Unsupported Debian version: ${OS_VERSION:-unknown}. Only Debian 12 and 13 are supported."
    fi

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
        alsa-utils build-essential bzip2 ca-certificates cmake curl dnsutils doxygen g++ gcc git
        gpiod graphviz groff gzip i2c-tools libasound2-dev libcurl4-openssl-dev libgcrypt20-dev
        libgpiod-dev libgsm1-dev libi2c-dev libjsoncpp-dev libogg-dev libopus-dev libopusenc-dev
        libpopt-dev librtlsdr-dev libsigc++-2.0-dev libsndfile1-dev libspeex-dev libspeexdsp-dev
        libssl-dev libvorbis-dev logrotate lsof make mc rtl-sdr tar tcl-dev vorbis-tools
    )

    run_logged 'Paketquellen werden aktualisiert' apt-get update || return 1
    run_logged 'Grundabhängigkeiten werden installiert' env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

install_packages_for_profile() {
    local package=$1
    if ! dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null | grep -qx installed; then
        run_logged "Zusatzpaket ${package} wird installiert" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${package}"
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
        prompt_value CALLSIGN 'Rufzeichen, Relais- oder Knotenname: '
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
        prompt_value HARDWARE_PROFILE 'Auswahl (0 bis 4): '
        [[ ${HARDWARE_PROFILE} =~ ^[0-4]$ ]] || \
            { log "Ungültige Auswahl. Erlaubt sind 0 bis 4."; continue; }
        break
    done

    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        while :; do
            prompt_value answer 'Zweiten Anschluss vorbereiten (j/n): '
            case ${answer,,} in
                j|ja|y|yes) SECOND_CONNECTOR=true; break ;;
                n|nein|no) break ;;
                *) log "Bitte j oder n eingeben." ;;
            esac
        done
        CAPTURE_LEFT=6
        CAPTURE_RIGHT=6
        log 'ELENATA-Capture-Pegel werden automatisch auf links 6 und rechts 6 gesetzt.'
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
        prompt_value value "${label} (0-15, Standard ${default}): "
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
    local temporary desired_lines
    local -a required_lines=(
        "dtparam=i2c0=on"
        "dtparam=i2c1=on"
        "dtparam=audio=off"
        "dtoverlay=fe-pi-audio"
        "dtoverlay=disable-bt"
        "enable_uart=1"
        "arm_boost=1"
        "arm_64bit=1"
        "gpu_mem=256"
        "hdmi_force_hotplug=1"
        "hdmi_group=2"
        "hdmi_mode=16"
    )

    ${IS_RASPBERRY_PI} || die "ELENATA is only supported on a Raspberry Pi."
    # Do not bypass a deliberately read-only boot configuration when invoked as root.
    (( 8#$(stat -c '%a' "${BOOT_CONFIG}") & 0222 )) || return 1
    desired_lines=$(printf '%s\n' "${required_lines[@]}")
    temporary=$(mktemp)
    awk -v desired="${desired_lines}" '
        function managed_key(line, value) {
            if (line ~ /^dtparam=/) {
                value = substr(line, length("dtparam=") + 1)
                sub(/=.*/, "", value)
                return "dtparam=" value
            }
            if (line ~ /^dtoverlay=/) {
                value = substr(line, length("dtoverlay=") + 1)
                sub(/,.*/, "", value)
                return "dtoverlay=" value
            }
            if (line ~ /^[^#][^=]*=/) {
                value = line
                sub(/=.*/, "", value)
                return value
            }
            return ""
        }
        BEGIN {
            count = split(desired, lines, "\n")
            for (i = 1; i <= count; i++) {
                if (lines[i] != "") wanted[managed_key(lines[i])] = 1
            }
            section = ""
        }
        /^\[[^]]+\][[:space:]]*$/ {
            section = substr($0, 2, length($0) - 2)
            if (section == "all" && !written_all) {
                print
                print "# Inserted by SVXLINK Setup Script"
                for (i = 1; i <= count; i++) if (lines[i] != "") print lines[i]
                written_all = 1
                next
            }
            print
            next
        }
        /^[[:space:]]*dtoverlay=vc4-kms-v3d(,.*)?[[:space:]]*$/ {
            print "# " $0 " # disabled for ELENATA Fe-Pi Audio"
            next
        }
        section == "all" {
            if ($0 == "# Inserted by SVXLINK Setup Script") next
            if (managed_key($0) in wanted) next
            print
            next
        }
        section == "" && (managed_key($0) in wanted) { next }
        { print }
        END {
            if (!written_all) {
                if (NR > 0) print ""
                print "[all]"
                print "# Inserted by SVXLINK Setup Script"
                for (i = 1; i <= count; i++) if (lines[i] != "") print lines[i]
            }
        }
    ' "${BOOT_CONFIG}" >"${temporary}"
    if ! cmp -s "${BOOT_CONFIG}" "${temporary}"; then
        backup_file "${BOOT_CONFIG}"
        install -m 0644 "${temporary}" "${BOOT_CONFIG}" || { rm -f "${temporary}"; return 1; }
    fi
    rm -f "${temporary}"
    return 0
}

install_elenata_alsa_runtime() {
    local temporary unit_temporary config_temporary changed=false directory
    for directory in "$(dirname "${ELENATA_ALSA_HELPER_FILE}")" "$(dirname "${ELENATA_ALSA_CONFIG_FILE}")" "$(dirname "${ELENATA_ALSA_PENDING_FILE}")" "$(dirname "${ELENATA_ALSA_POSTBOOT_LOG_FILE}")" "$(dirname "${ELENATA_ALSA_UNIT_FILE}")"; do
        install -d -m 0755 "${directory}"
    done
    temporary=$(mktemp)
    cat >"${temporary}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
note() { if [[ -n ${ELENATA_ALSA_LOG_FILE:-} ]]; then printf '%s %s\n' "$(date -Is)" "$1" >>"${ELENATA_ALSA_LOG_FILE}"; elif declare -F log >/dev/null; then log "$1"; else printf '%s\n' "$1"; fi; }
card_number() { if declare -F audio_card_number >/dev/null; then audio_card_number; else awk '/^[[:space:]]*[0-9]+[[:space:]]+\[Audio\]/{gsub(/^[[:space:]]+/, "", $0); print $1; exit}' /proc/asound/cards 2>/dev/null || true; fi; }
control_exists() { local controls; controls=$(amixer -c Audio scontrols 2>/dev/null) || return 1; grep -Fq "'$1'" <<<"${controls}"; }
required() { local control=$1; shift; control_exists "${control}" || { note "Required ALSA control is unavailable: ${control}"; return 1; }; amixer -c Audio sset "${control}" "$@" || { note "Could not set required ALSA control: ${control}"; return 1; }; note "ALSA control configured: ${control}"; }
optional() { local control=$1 value=$2; if control_exists "${control}"; then amixer -c Audio sset "${control}" "${value}" || note "Could not set optional ALSA control: ${control}"; else note "Optional ALSA control is unavailable: ${control}"; fi; }
apply() { local card; command -v amixer >/dev/null 2>&1 || { note 'Required command is unavailable: amixer'; return 1; }; command -v asactl >/dev/null 2>&1 || { note 'Required command is unavailable: asactl'; return 1; }; card=$(card_number); [[ -n ${card} ]] || return 2; required Headphone 120,120 unmute && required 'Headphone Mux' LINE_IN && required 'Headphone Playback ZC' on && required PCM 165,165 && required Lineout 21,21 unmute && required Mic 0 && required Capture "${CAPTURE_LEFT:-6},${CAPTURE_RIGHT:-6}" unmute && required 'Capture Attenuate Switch (-6dB)' on && required 'Capture Mux' LINE_IN && required 'Capture ZC' on && required AVC off && required 'AVC Hard Limiter' off && required 'AVC Integrator Response' 0 && required 'AVC Max Gain' 0 && required 'AVC Threshold' 0 && required 'BASS 0' 0 && required 'BASS 1' 0 && required 'BASS 2' 0 && required 'BASS 3' 0 && required 'BASS 4' 0 && required 'DAP MIX Mux' ADC && required 'DAP Main channel' 0 && required 'DAP Mix channel' 0 && required 'DAP Mux' ADC && required 'Digital Input Mux' I2S || return 1; if [[ -n ${ALSA_STATE_FILE:-} ]]; then asactl store -f "${ALSA_STATE_FILE}" "${card}"; else asactl store "${card}"; fi || { note "Could not store ALSA state for card ${card}"; return 1; }; note "ALSA state stored for card ${card}"; }
[[ ${ELENATA_ALSA_LIBRARY:-false} == true ]] && return 0
install -d -m 0755 "$(dirname "${ELENATA_ALSA_LOG_FILE}")"; : >"${ELENATA_ALSA_LOG_FILE}"; chmod 0600 "${ELENATA_ALSA_LOG_FILE}"; chown root:root "${ELENATA_ALSA_LOG_FILE}" 2>/dev/null || true
timeout_seconds=${ELENATA_ALSA_TIMEOUT_SECONDS:-90}
poll_interval=${ELENATA_ALSA_POLL_INTERVAL_SECONDS:-2}
[[ ${timeout_seconds} =~ ^[1-9][0-9]*$ && ${poll_interval} =~ ^[1-9][0-9]*$ ]] || { note 'RESULT: failure; invalid post-boot timeout configuration.'; exit 1; }
note "Post-boot ELENATA ALSA configuration started; timeout ${timeout_seconds}s."
deadline=$((SECONDS + timeout_seconds))
attempt=0
card=''
while :; do
    attempt=$((attempt + 1))
    card=$(card_number)
    [[ -n ${card} ]] && break
    remaining=$((deadline - SECONDS))
    (( remaining > 0 )) || break
    (( remaining < poll_interval )) && sleep "${remaining}" || sleep "${poll_interval}"
done
note "ALSA card scan after ${attempt} attempt(s): ${card:-Audio not found}"
[[ -n ${card} ]] || { note 'RESULT: failure; Audio did not appear before timeout.'; exit 1; }
apply || { note 'RESULT: failure; ALSA configuration was not completed.'; exit 1; }
rm -f -- "${ELENATA_ALSA_PENDING_FILE}" || { note 'RESULT: failure; pending marker could not be removed.'; exit 1; }
note 'RESULT: success; pending marker removed.'
EOF
    if [[ ! -f ${ELENATA_ALSA_HELPER_FILE} ]] || ! cmp -s "${temporary}" "${ELENATA_ALSA_HELPER_FILE}"; then install -m 0755 "${temporary}" "${ELENATA_ALSA_HELPER_FILE}"; fi
    rm -f "${temporary}"
    config_temporary=$(mktemp)
    printf 'CAPTURE_LEFT=%q\nCAPTURE_RIGHT=%q\n' "${CAPTURE_LEFT}" "${CAPTURE_RIGHT}" >"${config_temporary}"
    if [[ ! -f ${ELENATA_ALSA_CONFIG_FILE} ]] || ! cmp -s "${config_temporary}" "${ELENATA_ALSA_CONFIG_FILE}"; then install -m 0600 "${config_temporary}" "${ELENATA_ALSA_CONFIG_FILE}"; fi
    rm -f "${config_temporary}"
    unit_temporary=$(mktemp)
    cat >"${unit_temporary}" <<EOF
[Unit]
Description=Apply pending ELENATA ALSA setup after boot
After=local-fs.target sound.target
Wants=sound.target
ConditionPathExists=${ELENATA_ALSA_PENDING_FILE}

[Service]
Type=oneshot
Environment=ELENATA_ALSA_LOG_FILE=${ELENATA_ALSA_POSTBOOT_LOG_FILE}
Environment=ELENATA_ALSA_PENDING_FILE=${ELENATA_ALSA_PENDING_FILE}
EnvironmentFile=${ELENATA_ALSA_CONFIG_FILE}
ExecStart=${ELENATA_ALSA_HELPER_FILE}
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF
    if [[ ! -f ${ELENATA_ALSA_UNIT_FILE} ]] || ! cmp -s "${unit_temporary}" "${ELENATA_ALSA_UNIT_FILE}"; then
        install -m 0644 "${unit_temporary}" "${ELENATA_ALSA_UNIT_FILE}"
        changed=true
    fi
    rm -f "${unit_temporary}"
    if ${changed}; then run_logged 'Systemd-Konfiguration wird neu geladen' systemctl daemon-reload || return 1; fi
}

install_elenata_alsa_postboot() {
    install_elenata_alsa_runtime
    install -m 0600 /dev/null "${ELENATA_ALSA_PENDING_FILE}"
    run_logged 'ELENATA-Postboot-Dienst wird aktiviert' systemctl enable svxlink-setup-elenata-alsa.service
}

clear_elenata_alsa_postboot() {
    rm -f -- "${ELENATA_ALSA_PENDING_FILE}"
    systemctl disable svxlink-setup-elenata-alsa.service 2>/dev/null || true
}

audio_card_number() {
    awk '/^[[:space:]]*[0-9]+[[:space:]]+\[Audio\]/{gsub(/^[[:space:]]+/, "", $0); print $1; exit}' /proc/asound/cards 2>/dev/null || true
}

audio_card_available() {
    [[ -n $(audio_card_number) ]]
}

configure_elenata_alsa() {
    local card_number
    ELENATA_ALSA_CARD_AVAILABLE=false
    card_number=$(audio_card_number || true)
    if [[ -z ${card_number} ]]; then
        log 'ALSA card Audio is not available yet.'
        return 0
    fi
    install_elenata_alsa_runtime
    # shellcheck disable=SC1090
    ELENATA_ALSA_LIBRARY=true source "${ELENATA_ALSA_HELPER_FILE}"
    apply || return 1
    ELENATA_ALSA_CARD_AVAILABLE=true
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

start_install_log() {
    local timestamp
    [[ -n ${INSTALL_LOG_FILE} ]] && return 0
    install -d -m 0755 "${INSTALL_LOG_DIR}"
    timestamp=$(date +%Y%m%d%H%M%S)
    INSTALL_LOG_FILE="${INSTALL_LOG_DIR}/install-${timestamp}.log"
    : >"${INSTALL_LOG_FILE}"
    chmod 0644 "${INSTALL_LOG_FILE}"
    if [[ ${SVXLINK_TEST_MODE:-false} != true ]]; then chown root:root "${INSTALL_LOG_FILE}"; fi
}

activity_indicator_enabled() {
    terminal_is_interactive || [[ ${SVXLINK_TEST_FORCE_ACTIVITY:-false} == true ]]
}

start_activity_indicator() {
    local label=$1 command_pid=$2 kind='WORK'
    activity_indicator_enabled || return 0
    [[ ${label,,} == *herunter* ]] && kind='DOWNLOAD'
    terminal_printf '\r[%s] | %s' "${kind}" "${label}"
    (
        local frame=0
        local -a frames=('|' '/' '-' "\\")
        while kill -0 "${command_pid}" 2>/dev/null; do
            terminal_printf '\r[%s] %s %s' "${kind}" "${frames[frame]}" "${label}"
            frame=$(( (frame + 1) % ${#frames[@]} ))
            sleep 0.1
        done
    ) &
    ACTIVITY_PID=$!
}

stop_activity_indicator() {
    [[ -n ${ACTIVITY_PID} ]] || return 0
    kill "${ACTIVITY_PID}" 2>/dev/null || true
    wait "${ACTIVITY_PID}" 2>/dev/null || true
    ACTIVITY_PID=""
    activity_indicator_enabled && terminal_printf '\r\033[K'
}

start_download_progress() {
    local label=$1 command_pid=$2 target=$3 total=$4
    activity_indicator_enabled || return 0
    terminal_printf '\r[DOWNLOAD] %s:   0 %%' "${label}"
    ( local size percent; while kill -0 "${command_pid}" 2>/dev/null; do size=$(stat -c %s "${target}" 2>/dev/null || printf 0); percent=$(( size * 100 / total )); (( percent <= 100 )) || percent=100; terminal_printf '\r[DOWNLOAD] %s: %3d %%' "${label}" "${percent}"; sleep 0.1; done ) &
    ACTIVITY_PID=$!
}

download_logged() {
    local label=$1 target=$2 total=0 headers='' command_pid status
    shift 2
    start_install_log || return 1
    print_info "${label} werden heruntergeladen ..."
    if headers=$(mktemp); then
        # A HEAD request transfers no archive body.  Its failure is optional: do
        # not pollute the installation log and fall back to the activity spinner.
        if curl "$@" --head --output /dev/null --silent --show-error --location --dump-header "${headers}" >/dev/null 2>&1; then
            total=$(awk 'tolower($1) == "content-length:" { value=$2 } END { gsub(/\r/, "", value); print value }' "${headers}")
        fi
        rm -f -- "${headers}"
    fi
    [[ ${total} =~ ^[1-9][0-9]*$ ]] || total=0
    curl "$@" --output "${target}" >>"${INSTALL_LOG_FILE}" 2>&1 & command_pid=$!
    ACTIVE_COMMAND_PID=${command_pid}
    if (( total > 0 )); then start_download_progress "${label}" "${command_pid}" "${target}" "${total}"; else start_activity_indicator "${label} werden heruntergeladen" "${command_pid}"; fi
    if wait "${command_pid}"; then status=0; else status=$?; fi
    ACTIVE_COMMAND_PID=""; stop_activity_indicator
    if (( status == 0 )); then print_success "${label} wurden heruntergeladen"; else print_error "${label} konnten nicht heruntergeladen werden."; fi
    return "${status}"
}

on_signal() {
    local exit_code=$1
    set +x
    [[ -z ${ACTIVE_COMMAND_PID} ]] || kill "${ACTIVE_COMMAND_PID}" 2>/dev/null || true
    stop_activity_indicator
    exit "${exit_code}"
}
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

run_logged() {
    local label=$1 offset status command_pid
    shift
    start_install_log || return 1
    print_info "${label} ..."
    offset=$(wc -c <"${INSTALL_LOG_FILE}")
    "$@" >>"${INSTALL_LOG_FILE}" 2>&1 &
    command_pid=$!
    ACTIVE_COMMAND_PID=${command_pid}
    start_activity_indicator "${label}" "${command_pid}"
    if wait "${command_pid}"; then status=0; else status=$?; fi
    ACTIVE_COMMAND_PID=""
    stop_activity_indicator
    append_install_output_to_debug_log "${offset}"
    if (( status == 0 )); then
        print_success "${label}"
        return 0
    fi
    print_error "${label} fehlgeschlagen."
    printf 'Letzte Protokollzeilen:\n'
    tail -n 30 "${INSTALL_LOG_FILE}" || true
    printf 'Vollständiges Protokoll: %s\n' "${INSTALL_LOG_FILE}"
    return "${status}"
}

run_build_logged() {
    local label=$1 offset status line
    shift
    start_install_log || return 1
    print_info "${label} ..."
    offset=$(wc -c <"${INSTALL_LOG_FILE}")
    if "$@" 2>&1 | tee -a "${INSTALL_LOG_FILE}" | while IFS= read -r line; do
        if { terminal_is_interactive || [[ ${SVXLINK_TEST_FORCE_BUILD_PROGRESS:-false} == true ]]; } && [[ ${line} =~ \[[[:space:]]*([0-9]+)%\] ]]; then
            terminal_printf '\r[BUILD] %3d %%' "${BASH_REMATCH[1]}"
        fi
    done; then
        status=0
    else
        status=${PIPESTATUS[0]}
    fi
    append_install_output_to_debug_log "${offset}"
    if terminal_is_interactive || [[ ${SVXLINK_TEST_FORCE_BUILD_PROGRESS:-false} == true ]]; then terminal_printf '\n'; fi
    if (( status == 0 )); then
        print_success "${label}"
        return 0
    fi
    print_error "${label} fehlgeschlagen."
    printf 'Letzte Protokollzeilen:\n'
    tail -n 30 "${INSTALL_LOG_FILE}" || true
    printf 'Vollständiges Protokoll: %s\n' "${INSTALL_LOG_FILE}"
    return "${status}"
}

build_options_hash() {
    {
        printf 'BUILD_TYPE=Release\n'
        printf 'ARCH=%s\n' "$(uname -m)"
        printf 'COMPILER=%s\n' "$(g++ --version | head -n 1)"
        printf '%s\n' "${CMAKE_OPTIONS[@]}"
    } | sha256sum | awk '{print $1}'
}

source_commit() { git -C "${SOURCE_DIR}" rev-parse HEAD; }

# Print precisely one normalized release version, or nothing when the input is
# ambiguous.  In particular, never select an arbitrary embedded SemVer value.
normalize_svxlink_release_version() {
    local line candidate='' found='' labelled_found='' combined_found='' version_re='[0-9]+\.[0-9]+\.[0-9]+'
    while IFS= read -r line || [[ -n ${line} ]]; do
        line=${line//$'\r'/}
        line=$(printf '%s' "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # SvxLink embeds component@release, for example 1.10.1@26.05.1.
        if [[ ${line} =~ @(${version_re})([^0-9.]|$) ]]; then
            candidate=${BASH_REMATCH[1]}
            if [[ -z ${combined_found} ]]; then combined_found=${candidate}; elif [[ ${combined_found} != "${candidate}" ]]; then return 1; fi
            continue
        elif [[ ${line} =~ ^(SvxLink[[:space:]]+v?|[Vv]ersion:[[:space:]]*|v)(${version_re})$ ]]; then
            candidate=${BASH_REMATCH[2]}
            if [[ -z ${labelled_found} ]]; then labelled_found=${candidate}; elif [[ ${labelled_found} != "${candidate}" ]]; then return 1; fi
            continue
        elif [[ ${line} =~ ^${version_re}$ ]]; then
            candidate=${line}
        else
            continue
        fi
        if [[ -z ${found} ]]; then found=${candidate}; elif [[ ${found} != "${candidate}" ]]; then return 1; fi
    done
    [[ -z ${combined_found} ]] || { printf '%s\n' "${combined_found}"; return 0; }
    [[ -z ${labelled_found} ]] || { printf '%s\n' "${labelled_found}"; return 0; }
    [[ ${found} =~ ^${version_re}$ ]] || return 1
    printf '%s\n' "${found}"
}

source_version() {
    local raw
    raw=$(git -C "${SOURCE_DIR}" describe --tags --exact-match 2>/dev/null || git -C "${SOURCE_DIR}" describe --tags --always)
    normalize_svxlink_release_version <<<"${raw}" || printf '%s\n' "${raw#v}"
}

installed_svxlink_version() {
    local output version binary
    output=$(svxlink --version 2>/dev/null || true)
    # A combined component@release token is authoritative, whether emitted by
    # the program or discovered as a controlled binary fallback.
    if [[ ${output} == *'@'* ]]; then
        version=$(normalize_svxlink_release_version <<<"${output}" || true)
        [[ -n ${version} ]] && { printf '%s\n' "${version}"; return 0; }
    fi
    binary=$(command -v svxlink 2>/dev/null || true)
    if [[ -n ${binary} && -r ${binary} ]] && strings "${binary}" 2>/dev/null | grep -Eq '@[0-9]+\.[0-9]+\.[0-9]+'; then
        version=$(strings "${binary}" 2>/dev/null | normalize_svxlink_release_version || true)
        [[ -n ${version} ]] && { printf '%s\n' "${version}"; return 0; }
    fi
    # Only now accept an unambiguous official program output.
    normalize_svxlink_release_version <<<"${output}"
}

read_build_state() {
    local line key value
    BUILD_STATE_COMMIT=""; BUILD_STATE_VERSION=""; BUILD_STATE_ARCH=""; BUILD_STATE_OS_ID=""; BUILD_STATE_OS_VERSION=""; BUILD_STATE_OPTIONS=""; BUILD_STATE_COMPILER=""; BUILD_STATE_VALID=false
    [[ -f ${BUILD_STATE_FILE} ]] || return 0
    while IFS= read -r line || [[ -n ${line} ]]; do
        [[ ${line} == *=* ]] || continue
        key=${line%%=*}; value=${line#*=}
        case ${key} in
            STATE_VERSION) [[ ${value} == 1 ]] || return 0 ;;
            SVXLINK_GIT_COMMIT) BUILD_STATE_COMMIT=${value} ;;
            SVXLINK_VERSION) BUILD_STATE_VERSION=${value} ;;
            ARCH) BUILD_STATE_ARCH=${value} ;;
            OS_ID) BUILD_STATE_OS_ID=${value} ;;
            OS_VERSION_ID) BUILD_STATE_OS_VERSION=${value} ;;
            COMPILER) BUILD_STATE_COMPILER=${value} ;;
            CMAKE_OPTIONS_HASH) BUILD_STATE_OPTIONS=${value} ;;
        esac
    done <"${BUILD_STATE_FILE}"
    [[ -n ${BUILD_STATE_COMMIT} && -n ${BUILD_STATE_VERSION} && -n ${BUILD_STATE_ARCH} && -n ${BUILD_STATE_OS_ID} && -n ${BUILD_STATE_OS_VERSION} && -n ${BUILD_STATE_OPTIONS} && -n ${BUILD_STATE_COMPILER} ]] && BUILD_STATE_VALID=true
}

write_build_state() {
    local temporary installer_commit
    install -d -m 0755 "$(dirname "${BUILD_STATE_FILE}")"
    temporary=$(mktemp "$(dirname "${BUILD_STATE_FILE}")/.build-state.XXXXXX")
    installer_commit=$(git -C "${SCRIPT_DIR}" rev-parse HEAD 2>/dev/null || printf unknown)
    cat >"${temporary}" <<EOF
STATE_VERSION=1
SVXLINK_GIT_COMMIT=$(source_commit)
SVXLINK_VERSION=$(source_version)
ARCH=$(uname -m)
OS_ID=${OS_ID}
OS_VERSION_ID=${OS_VERSION}
BUILD_TYPE=Release
COMPILER=$(g++ --version | head -n 1)
CMAKE_OPTIONS_HASH=$(build_options_hash)
INSTALLER_COMMIT=${installer_commit}
BUILT_AT=$(date -Iseconds)
EOF
    chmod 0644 "${temporary}"
    if [[ ${SVXLINK_TEST_MODE:-false} != true ]]; then chown root:root "${temporary}"; fi
    mv -f "${temporary}" "${BUILD_STATE_FILE}"
}

build_required_reason() {
    local force=$1 current_commit current_version installed_version options_hash
    ${force} && { printf 'Erzwungene Neuinstallation'; return 0; }
    [[ -x $(command -v svxlink 2>/dev/null || true) ]] || { printf 'SvxLink ist noch nicht installiert'; return 0; }
    current_commit=$(source_commit); current_version=$(source_version); installed_version=$(installed_svxlink_version || true); options_hash=$(build_options_hash)
    [[ -n ${installed_version} ]] || { printf 'installierte Version kann nicht ermittelt werden'; return 0; }
    [[ ${installed_version} == "${current_version}" ]] || { printf 'installierte Version stimmt nicht mit dem Quellstand überein'; return 0; }
    read_build_state
    ${BUILD_STATE_VALID} || { printf 'Buildstatus fehlt oder ist ungültig'; return 0; }
    [[ ${BUILD_STATE_COMMIT} == "${current_commit}" ]] || { printf 'Buildstatus gehört zu einem anderen Git-Commit'; return 0; }
    [[ ${BUILD_STATE_VERSION} == "${current_version}" ]] || { printf 'Buildstatus-Version weicht ab'; return 0; }
    [[ ${BUILD_STATE_ARCH} == "$(uname -m)" && ${BUILD_STATE_OS_ID} == "${OS_ID}" && ${BUILD_STATE_OS_VERSION} == "${OS_VERSION}" ]] || { printf 'Buildplattform hat sich geändert'; return 0; }
    [[ ${BUILD_STATE_OPTIONS} == "${options_hash}" ]] || { printf 'Buildparameter haben sich geändert'; return 0; }
    [[ ${BUILD_STATE_COMPILER} == "$(g++ --version | head -n 1)" ]] || { printf 'Compiler hat sich geändert'; return 0; }
    return 1
}

log_build_comparison() {
    local installed_version current_version current_commit
    installed_version=$(installed_svxlink_version || true)
    current_version=$(source_version)
    current_commit=$(source_commit)
    read_build_state
    start_install_log || return 1
    {
        printf 'Installierte Releaseversion: %s\n' "${installed_version:-nicht eindeutig ermittelbar}"
        printf 'Quellversion:                %s\n' "${current_version}"
        printf 'Aktueller Quellcommit:       %s\n' "${current_commit}"
        printf 'Buildstatus-Commit:          %s\n' "${BUILD_STATE_COMMIT:-nicht vorhanden}"
        printf 'Buildstatus-Version:         %s\n' "${BUILD_STATE_VERSION:-nicht vorhanden}"
    } >>"${INSTALL_LOG_FILE}"
    if [[ -n ${installed_version} ]]; then print_success "Installierte SvxLink-Version: ${installed_version}"; else print_warning 'Installierte SvxLink-Version konnte nicht eindeutig ermittelt werden.'; fi
    print_success "Quellversion: ${current_version}"
}

prepare_svxlink_source() {
    local before after
    if [[ -d ${SOURCE_DIR}/.git ]]; then
        before=$(source_commit)
        run_logged 'SvxLink-master wird aktualisiert' runuser -u "${INSTALL_USER}" -- git -C "${SOURCE_DIR}" fetch --prune origin master || return 1
        run_logged 'SvxLink-master wird ausgecheckt' runuser -u "${INSTALL_USER}" -- git -C "${SOURCE_DIR}" checkout --quiet master || return 1
        run_logged 'SvxLink-master wird zusammengeführt' runuser -u "${INSTALL_USER}" -- git -C "${SOURCE_DIR}" merge --ff-only origin/master || return 1
        after=$(source_commit)
        if [[ ${before} == "${after}" ]]; then
            print_success 'SvxLink-Quellstand ist unverändert.'
        else
            print_info 'Neuer SvxLink-Quellstand erkannt.'
        fi
    elif [[ -e ${SOURCE_DIR} ]]; then
        die "Source directory exists but is not a SvxLink Git repository: ${SOURCE_DIR}"
    else
        run_logged 'SvxLink-master wird geladen' runuser -u "${INSTALL_USER}" -- git clone --branch master "${SVXLINK_REPOSITORY}" "${SOURCE_DIR}" || return 1
    fi
}

build_svxlink() {
    local force=${1:-false} reason
    prepare_svxlink_source || return 1
    log_build_comparison || return 1
    if ! reason=$(build_required_reason "${force}"); then
        print_success 'SvxLink ist unverändert und vollständig installiert.'
        print_info 'Kompilierung und Installation werden übersprungen.'
        return 0
    fi
    print_info "Build erforderlich: ${reason}."
    BUILD_DIR="${SOURCE_DIR}/build"
    if ${force} && [[ -d ${BUILD_DIR} && ! -L ${BUILD_DIR} ]]; then
        rm -rf -- "${BUILD_DIR}"
    fi
    [[ ! -L ${BUILD_DIR} ]] || die "Build directory must not be a symbolic link: ${BUILD_DIR}"
    run_logged 'CMake-Konfiguration wird ausgeführt' runuser -u "${INSTALL_USER}" -- cmake -S "${SOURCE_DIR}/src" -B "${BUILD_DIR}" "${CMAKE_OPTIONS[@]}" || return 1
    run_build_logged 'SvxLink wird kompiliert' runuser -u "${INSTALL_USER}" -- cmake --build "${BUILD_DIR}" --parallel "$(nproc)" || return 1
    run_logged 'SvxLink wird installiert' cmake --install "${BUILD_DIR}" || return 1
    run_logged 'Linker-Cache wird aktualisiert' ldconfig || return 1
    BUILD_PERFORMED=true
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

record_svxlink_service_state() {
    SVXLINK_SERVICE_WAS_PRESENT=false
    SVXLINK_SERVICE_WAS_ENABLED=false
    SVXLINK_SERVICE_WAS_ACTIVE=false
    if systemctl cat svxlink.service >/dev/null 2>&1; then
        SVXLINK_SERVICE_WAS_PRESENT=true
        systemctl is-enabled --quiet svxlink.service && SVXLINK_SERVICE_WAS_ENABLED=true
        systemctl is-active --quiet svxlink.service && SVXLINK_SERVICE_WAS_ACTIVE=true
    fi
    return 0
}

finalize_svxlink_service() {
    run_logged 'Systemd-Konfiguration wird neu geladen' systemctl daemon-reload || return 1
    systemctl cat svxlink.service >/dev/null 2>&1 || die "SvxLink systemd service was not installed."
    if ! ${SVXLINK_SERVICE_WAS_PRESENT}; then
        run_logged 'SvxLink-Dienst bleibt deaktiviert' systemctl disable --now svxlink.service || return 1
        print_info 'SvxLink bleibt deaktiviert und wurde nicht gestartet. Nach erfolgreicher Hardwareprüfung kann der Dienst aktiviert und gestartet werden.'
    elif ${SVXLINK_SERVICE_WAS_ENABLED} && ${SVXLINK_SERVICE_WAS_ACTIVE}; then
        print_info 'Der bereits aktivierte und laufende SvxLink-Dienst bleibt unverändert.'
    elif ${SVXLINK_SERVICE_WAS_ENABLED}; then
        print_info 'Der bereits aktivierte SvxLink-Dienst bleibt unverändert und wurde nicht gestartet.'
    else
        print_info 'Der vorhandene deaktivierte SvxLink-Dienst bleibt unverändert und wurde nicht gestartet.'
    fi
}

check_item() {
    local label=$1
    shift
    if "$@"; then
        print_success "${label}"
    else
        print_error "${label}"
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
    local callsign profile service_active
    detect_operating_system true
    print_section 'SYSTEMSTAND'
    printf 'System\n'
    if ${OS_SUPPORTED}; then print_success "Betriebssystem: Debian/Raspberry Pi OS ${OS_VERSION}"; else print_warning "Nicht unterstütztes System (nur Status, keine Änderungen): ${OS_ID:-unknown} ${OS_VERSION:-unknown}"; fi
    if ${IS_RASPBERRY_PI}; then print_info 'Raspberry Pi: ja'; else print_info 'Raspberry Pi: nein'; fi
    print_info "Architektur: $(uname -m)"
    if ${IS_RASPBERRY_PI}; then
        print_info "Bootkonfiguration: ${BOOT_CONFIG}"
        check_item "Fe-Pi Audio boot overlay" grep -Fqx "dtoverlay=fe-pi-audio" "${BOOT_CONFIG}"
    fi
    if ! ${IS_RASPBERRY_PI}; then
        print_skip 'ELENATA ALSA-Karte nicht zutreffend (kein Raspberry Pi)'
    elif elenata_profile_configured; then
        check_item "ELENATA ALSA card Audio" audio_card_available
    else
        print_info 'ALSA-Karte Audio nicht vorhanden; ELENATA-Profil nicht konfiguriert'
    fi
    printf '\nSvxLink\n'
    if check_svxlink_user; then
        print_success 'SvxLink-Benutzer'
        check_item "aplay as svxlink" check_svxlink_audio_access aplay
        check_item "arecord as svxlink" check_svxlink_audio_access arecord
    else
        print_error 'SvxLink-Benutzer'
        print_skip 'aplay als svxlink (Benutzer fehlt)'
        print_skip 'arecord als svxlink (Benutzer fehlt)'
    fi
    check_item "SvxLink binary" bash -c 'command -v svxlink >/dev/null 2>&1'
    check_item "systemd-Service aktiviert" systemctl is-enabled --quiet svxlink.service 2>/dev/null
    service_active=$(systemctl is-active svxlink.service 2>/dev/null || true)
    if [[ ${service_active} == active ]]; then
        print_success 'systemd-Service aktiv'
    else
        print_skip 'systemd-Service nicht gestartet'
    fi
    callsign=$(ini_value "${SVXLINK_CONFIG}" RepeaterLogic CALLSIGN 2>/dev/null || true)
    if [[ -n ${callsign} ]]; then
        print_success "Rufzeichen: ${callsign}"
    else
        print_error 'Rufzeichen nicht konfiguriert'
    fi
    profile=$(detected_hardware_profile)
    print_info "Hardwareprofil: ${profile} – $(hardware_profile_name "${profile}")"
    printf '\nBuildstatus\n'
    read_build_state
    if ${BUILD_STATE_VALID}; then
        print_success "Letzter erfolgreicher Build: ${BUILD_STATE_VERSION} (${BUILD_STATE_COMMIT:0:12})"
        if [[ ${BUILD_STATE_ARCH} == "$(uname -m)" && ${BUILD_STATE_OS_ID} == "${OS_ID}" && ${BUILD_STATE_OS_VERSION} == "${OS_VERSION}" && ${BUILD_STATE_OPTIONS} == "$(build_options_hash)" ]]; then
            print_success 'Buildparameter und Plattform unverändert'
        else
            print_warning 'Buildstatus weicht von aktueller Plattform oder Buildparametern ab'
        fi
    else
        print_warning 'Kein verlässlicher Buildstatus vorhanden; beim nächsten Update wird neu gebaut.'
    fi
    printf '\nSprache\n'
    check_sound_status
    printf '\nBackup und Logs\n'
    check_item "SvxLink log file" test -f "${SVXLINK_LOG}"
    check_logrotate_configuration
    if [[ -f ${APT_CONFIG} ]]; then
        check_item "Automatic APT updates disabled" automatic_updates_disabled
    else
        print_error 'Automatische APT-Updates deaktiviert'
    fi
    print_info "Freier Speicher: $(df -h / | awk 'NR == 2 {print $4}')"
    if command -v lsof >/dev/null 2>&1; then
        if lsof +L1 2>/dev/null | grep -Eq 'svxlink.*(/var/log/svxlink).*\(deleted\)'; then
            print_error 'SvxLink hat eine offene gelöschte Logdatei'
        else
            print_success 'Keine offene gelöschte SvxLink-Logdatei'
        fi
    else
        print_error 'lsof ist nicht installiert'
    fi
    printf '\nGesamtergebnis\n'
    print_warning 'Installation kann vorhanden sein; Hardwarevalidierung ist weiterhin ausstehend.'
}

check_sound_status() {
    local language simplex_language repeater_language
    for language in en_US de_DE; do
        if sound_directory_has_wav "${SVXLINK_SOUNDS_DIR}/${language}"; then
            print_success "${language} vorhanden: $(sound_wav_count "${SVXLINK_SOUNDS_DIR}/${language}") WAV-Dateien"
        else
            print_error "${language} Soundordner fehlt"
        fi
    done
    [[ -f ${SVXLINK_CONFIG} ]] || return 0
    simplex_language=$(ini_value "${SVXLINK_CONFIG}" "SimplexLogic" "DEFAULT_LANG" || true)
    repeater_language=$(ini_value "${SVXLINK_CONFIG}" "RepeaterLogic" "DEFAULT_LANG" || true)
    print_info "SimplexLogic: ${simplex_language:-missing}"
    print_info "RepeaterLogic: ${repeater_language:-missing}"
    [[ ${simplex_language} == "${repeater_language}" ]] || print_warning 'SimplexLogic und RepeaterLogic verwenden unterschiedliche Sprachen.'
    for language in "${simplex_language}" "${repeater_language}"; do
        [[ -z ${language} ]] || sound_directory_has_wav "${SVXLINK_SOUNDS_DIR}/${language}" || \
            print_warning "Aktive Sprache ${language} hat keinen nutzbaren Soundordner."
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
    log "Soundverzeichnis: ${SVXLINK_SOUNDS_DIR}"
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
        prompt_value answer "${target} exists but is unusable. Backup and replace it? [j/N]: "
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
Die deutsche Sprache verwendet den vollständigen
Sprachsatz aus dem passwortgeschützten Nextcloud-Archiv.

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
Deutsche Sounds:    werden geprüft
Englische Sounds:   werden geprüft
Standardsprache:    Deutsch wird geprüft und bei Bedarf aktiviert
EOF
    if ${ACTION_YES}; then
        return 0
    fi
    prompt_value answer 'Installation jetzt starten? [j/N]: '
    [[ ${answer} == j || ${answer} == J ]]
}

run_installation() {
    local mode=${1:-automatic} existing_profile existing_callsign
    require_root_for_action --install || return 1
    detect_operating_system
    log "Detected Debian/Raspberry Pi OS ${OS_VERSION}; Raspberry Pi: ${IS_RASPBERRY_PI}."
    if ${HARDWARE_PROFILE_PROVIDED} && ! ${IS_RASPBERRY_PI} && [[ ${HARDWARE_PROFILE} != 0 ]]; then
        die "Hardwareprofil ${HARDWARE_PROFILE} kann nur auf einem erkannten Raspberry Pi verwendet werden."
    fi
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
    record_svxlink_service_state
    install_packages
    require_base_tools || die "Grundabhängigkeiten fehlen; SvxLink-Build wurde nicht gestartet."
    print_info 'Installation wird vorbereitet ...'
    disable_automatic_updates
    ensure_svxlink_account
    print_success 'Installation wird vorbereitet'
    build_svxlink "$([[ ${mode} == force ]] && printf true || printf false)" || return 1
    configure_logging
    configure_base_svxlink
    configure_hardware_profile
    if ${BUILD_PERFORMED}; then
        write_build_state || die 'Buildstatus konnte nicht geschrieben werden.'
    fi
    if install_german_sounds; then
        GERMAN_SOUNDS_AVAILABLE=true
    else
        print_warning 'Die deutschen Sounds konnten nicht installiert werden. Englisch bleibt aktiv.'
    fi
    if ! install_english_sounds; then
        if ${BUILD_PERFORMED}; then
            print_warning 'SvxLink-Build und Grundkonfiguration wurden abgeschlossen, die Gesamtinstallation ist jedoch unvollständig.'
        else
            print_warning 'Die vorhandene SvxLink-Installation blieb unverändert, die Gesamtinstallation ist jedoch unvollständig.'
        fi
        print_error 'Die Soundinstallation konnte nicht vollständig abgeschlossen werden.'
        print_info 'Der Updatevorgang kann erneut gestartet werden.'
        return 1
    fi
    if ${GERMAN_SOUNDS_AVAILABLE}; then
        activate_sound_language de_DE false || die 'Die deutschen Sounds wurden installiert, konnten aber nicht aktiviert werden.'
    fi
    if ${BUILD_PERFORMED}; then
        print_success 'SvxLink wurde erfolgreich installiert oder aktualisiert.'
    else
        print_success 'SvxLink ist bereits aktuell.'
        print_info 'Build und Installation wurden übersprungen.'
    fi
    print_success 'Englische Sounddateien sind installiert.'
    if ${GERMAN_SOUNDS_AVAILABLE}; then
        print_success 'Deutsche Sounddateien sind installiert und Deutsch ist aktiv.'
    else
        print_warning 'Die deutschen Sounds sind nicht verfügbar; Englisch bleibt aktiv.'
    fi
    finalize_svxlink_service
    if [[ ${HARDWARE_PROFILE} == 0 ]]; then
        print_info 'Die Grundinstallation ist abgeschlossen.'
        print_info 'Profil 0 erstellt keine produktive Audio-, PTT- oder Squelch-Konfiguration.'
    else
        log "Installation abgeschlossen. Prüfe die Hardware vor der Inbetriebnahme mit sudo ./${SCRIPT_NAME} --check."
    fi
    if [[ ${HARDWARE_PROFILE} == 4 ]]; then
        printf '\n============================================================\nNEUSTART ERFORDERLICH\n============================================================\nDie ELENATA-Bootkonfiguration wurde vorbereitet.\n\nBitte jetzt neu starten:\n\n  reboot\n\nNach dem Neustart die Hardware prüfen und anschließend SvxLink starten.\n============================================================\n'
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
    [[ -d ${SVXLINK_BACKUP_DIR} ]] || { log "Keine Backups gefunden."; return 0; }
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
        prompt_value choice 'Auswahl: ' || return 0
        case ${choice} in
            1) create_full_backup ;;
            2)
                if [[ ${SVXLINK_TEST_MODE:-false} == true ]]; then
                    log "WARN: Backup restore is disabled in test mode."
                    continue
                fi
                list_backups
                prompt_value selected 'Backupname zur Wiederherstellung: '
                [[ -d ${SVXLINK_BACKUP_DIR}/${selected} ]] || { log "Backup nicht gefunden."; continue; }
                prompt_value answer 'Aktuelle Installation wird vorher gesichert und vorhandene Dateien ersetzt. Fortfahren? [j/N]: '
                [[ ${answer} == j || ${answer} == J ]] || { log "Keine Wiederherstellung durchgeführt."; continue; }
                create_full_backup
                cp -a "${SVXLINK_BACKUP_DIR}/${selected}/." /
                log 'Backup wurde wiederhergestellt. SvxLink wurde nicht gestartet.'
                ;;
            3) list_backups ;;
            4) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
    done
}

install_menu() {
    local choice answer status
    while :; do
        cat <<'EOF'
============================================================
INSTALLIEREN / AKTUALISIEREN
============================================================

1) Automatisch installieren oder aktualisieren
2) Erzwungene Neuinstallation
3) Zurück
EOF
        prompt_value choice 'Auswahl: ' || return 0
        case ${choice} in
            1)
                if run_installation automatic; then return 0; else return $?; fi
                ;;
            2)
                require_root_for_action --install || return 1
                cat <<'EOF'
Dieser Modus ist für beschädigte oder unvollständige Installationen vorgesehen.

Vorher wird automatisch ein vollständiges Backup erstellt.

Neu aufgebaut werden SvxLink-Quellcode, Build-Verzeichnis, Programme,
Bibliotheken, systemd-Dateien, Standardressourcen und beide Sprachsätze.
Konfiguration, lokale Events, systemd-Overrides und Soundanpassungen werden
gesichert und nicht ungefragt gelöscht.
EOF
                prompt_value answer 'Erzwungene Neuinstallation starten? [j/N]: '
                [[ ${answer} == j || ${answer} == J ]] || { log "Abgebrochen."; return 0; }
                detect_operating_system
                if ${IS_RASPBERRY_PI}; then
                    HARDWARE_PROFILE=$(detected_hardware_profile)
                    printf 'Erkanntes Hardwareprofil: %s) %s\n\n1) Profil beibehalten\n2) Hardwareprofil neu auswählen\n3) Abbrechen\n' "${HARDWARE_PROFILE}" "$(hardware_profile_name "${HARDWARE_PROFILE}")"
                    prompt_value answer 'Auswahl: ' || return 0
                    case ${answer} in
                        1) HARDWARE_PROFILE_PROVIDED=true ;;
                        2) choose_hardware_profile; HARDWARE_PROFILE_PROVIDED=true ;;
                        3) log "Abgebrochen."; return 0 ;;
                        *) log "Ungültige Auswahl."; return 0 ;;
                    esac
                else
                    HARDWARE_PROFILE=0
                    HARDWARE_PROFILE_PROVIDED=true
                    print_info 'Kein Raspberry Pi erkannt; Force-Modus verwendet Profil 0.'
                fi
                create_full_backup
                if run_installation force; then status=0; else status=$?; fi
                HARDWARE_PROFILE_PROVIDED=false
                return "${status}"
                ;;
            3) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
    done
}

run_menu() {
    local choice
    while :; do
        show_header
        show_menu
        prompt_value choice 'Auswahl: ' || return 0
        case ${choice} in
            1) install_menu || print_error 'Installationsaktion wurde nicht vollständig abgeschlossen.' ;;
            2) run_checks; prompt_value _ 'ENTER zum Hauptmenü ...' ;;
            3) require_root_for_action --backup && backup_menu ;;
            4) if require_root_for_action --install-german-sounds; then install_sound_interactively de_DE || log 'Installation der deutschen Sounds fehlgeschlagen.'; fi ;;
            5) if require_root_for_action --install-english-sounds; then install_sound_interactively en_US || log 'Installation der englischen Sounds fehlgeschlagen.'; fi ;;
            6) if require_root_for_action --activate-german-sounds; then show_german_activation_information; activate_sound_language de_DE true || log "Deutsch wurde nicht aktiviert."; fi ;;
            7) if require_root_for_action --activate-english-sounds; then activate_sound_language en_US true || log "Englisch wurde nicht aktiviert."; fi ;;
            8) show_configuration ;;
            9) return 0 ;;
            *) log "Ungültige Auswahl." ;;
        esac
        printf '\n'
    done
}

main_menu() {
    run_menu
}

show_help() {
    cat <<EOF
Usage: sudo ./${SCRIPT_NAME} [-D] [--menu|--install|--check|--install-german-sounds|--install-english-sounds|--activate-german-sounds|--activate-english-sounds|--show-config] [--callsign=<name>] [--profile=0..4] [--yes]

Without an action parameter, the interactive menu is shown. Writing non-interactive actions require --yes.
-D enables development diagnostics: shell traces with source lines, commands and prior exit codes are written to /var/log/svxlink-setup/debug-<timestamp>.log. Standard output and error from logged commands are appended there as well. Debug logs are mode 0600.
EOF
}

main() {
    local action="" argument
    if (( $# == 0 )); then
        main_menu
        return 0
    fi
    for argument in "$@"; do
        case ${argument} in
            -D) DEBUG_MODE=true ;;
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
                [[ -z ${action} ]] || die "Only one action parameter is allowed."
                action=${argument}
                ;;
            *) die "Unknown parameter: ${argument}. Use --help." ;;
        esac
    done
    start_debug_log
    [[ -n ${action} ]] || { main_menu; return 0; }
    [[ ${action} != --help ]] || { show_help; return 0; }
    case ${action} in
        --menu) main_menu ;;
        --check) run_checks ;;
        --show-config) show_configuration ;;
        --install|--install-german-sounds|--install-english-sounds|--activate-german-sounds|--activate-english-sounds)
            ${ACTION_YES} || die "Non-interactive write actions require --yes."
            require_root_for_action "${action}" || return 1
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

close_output_fds() {
    set +x
    stop_activity_indicator
    [[ -z ${DEBUG_FD} ]] || exec {DEBUG_FD}>&-
    [[ -z ${DEBUG_STDOUT_FD} ]] || exec {DEBUG_STDOUT_FD}>&-
    [[ -z ${DEBUG_STDERR_FD} ]] || exec {DEBUG_STDERR_FD}>&-
    [[ -z ${TERMINAL_FD} ]] || exec {TERMINAL_FD}>&-
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    if main "$@"; then exit_code=0; else exit_code=$?; fi
    set +x
    close_output_fds
    exit "${exit_code}"
fi
