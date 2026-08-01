#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2015,SC2032

set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
readonly MOCK_LOG="${TEMP_DIR}/mock.log"
export SVXLINK_TEST_MODE=true SVXLINK_TEST_RASPBERRY_PI=true
export BOOT_CONFIG_FILE="${TEMP_DIR}/config.txt"
export SVXLINK_CONFIG_FILE="${TEMP_DIR}/svxlink.conf"
export ALSA_STATE_FILE="${TEMP_DIR}/asound.state"
export LOG_FILE="${TEMP_DIR}/svxlink.log"
export LOGROTATE_FILE="${TEMP_DIR}/svxlink.logrotate"
export SVXLINK_BACKUP_DIR="${TEMP_DIR}/backups"

audio_present=true
missing_control=""
failures=0

cleanup() { rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
pass() { printf 'PASS: %s\n' "$*"; }
expect() { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (expected $2, got $1)"; }
line() { grep -Fqx "$2" "$1" && pass "$3" || fail "$3"; }
section_value() { expect "$(ini_value "${SVXLINK_CONFIG}" "$1" "$2")" "$3" "$1/$2"; }

snapshot() {
    local phase=$1 file out identifier
    for file in /boot/config.txt /boot/firmware/config.txt /etc/svxlink/svxlink.conf /etc/default/svxlink /etc/logrotate.d/svxlink; do
        identifier=${file//\//_}
        out="${TEMP_DIR}/${phase}-${identifier}"
        if [[ -e ${file} ]]; then sha256sum "${file}" >"${out}"; stat -c '%F|%a|%u|%g|%s|%Y' "${file}" >>"${out}"; else printf absent >"${out}"; fi
    done
}
assert_snapshots() {
    local file identifier
    for file in /boot/config.txt /boot/firmware/config.txt /etc/svxlink/svxlink.conf /etc/default/svxlink /etc/logrotate.d/svxlink; do
        identifier=${file//\//_}
        cmp -s "${TEMP_DIR}/before-${identifier}" "${TEMP_DIR}/after-${identifier}" && pass "unchanged ${file}" || fail "changed ${file}"
    done
}

assert_no_duplicate_keys() {
    local section=$1 duplicates
    duplicates=$(awk -v section="${section}" '
        $0 == "[" section "]" { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && /^[A-Z0-9_]+=/ { count[substr($0, 1, index($0, "=") - 1)]++ }
        END { for (key in count) if (count[key] > 1) print key }
    ' "${SVXLINK_CONFIG}")
    [[ -z ${duplicates} ]] && pass "no duplicate keys in ${section}" || fail "duplicate keys in ${section}: ${duplicates}"
}

mock_command() {
    local command=$1
    shift
    {
        printf '%s' "${command}"
        printf ' <%q>' "$@"
        printf '\n'
    } >>"${MOCK_LOG}"
}

mock_has() {
    local expected=$1
    shift
    local argument
    for argument in "$@"; do printf -v expected '%s <%q>' "${expected}" "${argument}"; done
    grep -Fqx "${expected}" "${MOCK_LOG}"
}

amixer() {
    mock_command amixer "$@"
    if [[ $* == *scontrols* ]]; then
        ${audio_present} || return 1
        local control
        for control in 'Capture Mux' 'Capture' 'Capture Attenuate Switch (-6dB)' PCM Lineout AVC 'AVC Hard Limiter' Mic; do
            [[ ${control} == "${missing_control}" ]] || printf "Simple mixer control '%s',0\n" "${control}"
        done
    fi
}
asactl() { mock_command asactl "$@"; : >"${ALSA_STATE_FILE}"; }
aplay() { mock_command aplay "$@"; }
arecord() { mock_command arecord "$@"; }
systemctl() { mock_command systemctl "$@"; }
usermod() { mock_command usermod "$@"; }
getent() { mock_command getent "$@"; return 0; }
chown() { mock_command chown "$@"; }
chmod() { mock_command chmod "$@"; command chmod "$@"; }
logrotate() { mock_command logrotate "$@"; }

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR
audio_card_number() { ${audio_present} && printf '2\n'; }
snapshot before

detect_operating_system
expect "${IS_RASPBERRY_PI}" true 'test Raspberry Pi detection'
expect "${BOOT_CONFIG}" "${BOOT_CONFIG_FILE}" 'test boot path'
printf '%s\n' '# vorhandene Kommentare' 'dtparam=spi=on' 'dtparam=i2c_arm=on' 'dtoverlay=vc4-kms-v3d' 'dtoverlay=dwc2' 'enable_uart=1' '#dtparam=audio=on' '#dtoverlay=ir-receiver' >"${BOOT_CONFIG}"
configure_elenata_boot
boot_hash=$(sha256sum "${BOOT_CONFIG}" | awk '{print $1}')
backups=$(find "${SVXLINK_BACKUP_DIR}" -type f | wc -l)
configure_elenata_boot
expect "$(sha256sum "${BOOT_CONFIG}" | awk '{print $1}')" "${boot_hash}" 'idempotent boot configuration'
expect "$(find "${SVXLINK_BACKUP_DIR}" -type f | wc -l)" "${backups}" 'no repeated boot backup'
for value in 'dtparam=i2c0=on' 'dtparam=i2c1=on' 'dtparam=audio=off' 'dtoverlay=fe-pi-audio' 'dtoverlay=disable-bt'; do expect "$(grep -Fxc "${value}" "${BOOT_CONFIG}")" 1 "single ${value}"; done
for value in 'dtparam=spi=on' 'dtparam=i2c_arm=on' 'dtoverlay=vc4-kms-v3d' 'dtoverlay=dwc2' 'enable_uart=1' '# vorhandene Kommentare' '#dtparam=audio=on' '#dtoverlay=ir-receiver'; do line "${BOOT_CONFIG}" "${value}" "preserve ${value}"; done
cp "${BOOT_CONFIG}" "${TEMP_DIR}/readonly-config.txt"
sed -i '/dtparam=i2c1=on/d' "${TEMP_DIR}/readonly-config.txt"
saved_boot_config=${BOOT_CONFIG}
BOOT_CONFIG="${TEMP_DIR}/readonly-config.txt"
command chmod a-w "${BOOT_CONFIG}"
if (configure_elenata_boot) >/dev/null 2>&1; then fail 'unwritable boot file must fail'; else pass 'unwritable boot file fails'; fi
command chmod u+w "${BOOT_CONFIG}"
BOOT_CONFIG=${saved_boot_config}

printf '%s\n' '[GLOBAL]' 'LOGICS=SimplexLogic' '[SimplexLogic]' 'CALLSIGN=MYCALL' '[RepeaterLogic]' 'CALLSIGN=MYCALL' 'RX=Rx1' 'TX=Tx1' '[Rx1]' 'TYPE=Local' '[Tx1]' 'TYPE=Local' '[Rx2]' 'TYPE=Local' '[Tx2]' 'TYPE=Local' >"${SVXLINK_CONFIG}"
CALLSIGN=DM0DOS
HARDWARE_PROFILE=4
SECOND_CONNECTOR=false
CAPTURE_LEFT=6
CAPTURE_RIGHT=6
configure_base_svxlink
configure_elenata_svxlink
conf_hash=$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')
configure_base_svxlink
configure_elenata_svxlink
expect "$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')" "${conf_hash}" 'idempotent first connector'
section_value GLOBAL LOGICS RepeaterLogic
section_value RepeaterLogic CALLSIGN DM0DOS
section_value Rx1 AUDIO_DEV 'alsa:hw:CARD=Audio,DEV=0'
section_value Rx1 AUDIO_CHANNEL 0
section_value Rx1 SQL_DET GPIOD
section_value Rx1 SQL_GPIOD_CHIP gpiochip0
section_value Rx1 SQL_GPIOD_LINE 26
section_value Tx1 AUDIO_DEV 'alsa:hw:CARD=Audio,DEV=0'
section_value Tx1 AUDIO_CHANNEL 0
section_value Tx1 PTT_TYPE GPIOD
section_value Tx1 PTT_GPIOD_CHIP gpiochip0
section_value Tx1 PTT_GPIOD_LINE 13
expect "$(awk '/^\[Rx1\]/{on=1;next} /^\[/{on=0} on && /^PTT_/{n++} END {print n+0}' "${SVXLINK_CONFIG}")" 0 'no PTT in Rx1'
expect "$(awk '/^\[Tx1\]/{on=1;next} /^\[/{on=0} on && /^SQL_/{n++} END {print n+0}' "${SVXLINK_CONFIG}")" 0 'no SQL in Tx1'

SECOND_CONNECTOR=true
configure_elenata_svxlink
conf_hash=$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')
configure_elenata_svxlink
expect "$(sha256sum "${SVXLINK_CONFIG}" | awk '{print $1}')" "${conf_hash}" 'idempotent second connector'
section_value Rx2 AUDIO_CHANNEL 1
section_value Rx2 AUDIO_DEV 'alsa:hw:CARD=Audio,DEV=0'
section_value Rx2 SQL_DET GPIOD
section_value Rx2 SQL_GPIOD_CHIP gpiochip0
section_value Rx2 SQL_GPIOD_LINE 6
section_value Tx2 AUDIO_DEV 'alsa:hw:CARD=Audio,DEV=0'
section_value Tx2 AUDIO_CHANNEL 1
section_value Tx2 PTT_TYPE GPIOD
section_value Tx2 PTT_GPIOD_CHIP gpiochip0
section_value Tx2 PTT_GPIOD_LINE 5
section_value RepeaterLogic RX Rx1
section_value RepeaterLogic TX Tx1
for section in GLOBAL RepeaterLogic Rx1 Tx1 Rx2 Tx2; do assert_no_duplicate_keys "${section}"; done
for section in Rx1 Rx2; do expect "$(awk -v s="${section}" '$0 == "[" s "]" {on=1;next} /^\[/{on=0} on && /^PTT_/{n++} END {print n+0}' "${SVXLINK_CONFIG}")" 0 "no PTT in ${section}"; done
for section in Tx1 Tx2; do expect "$(awk -v s="${section}" '$0 == "[" s "]" {on=1;next} /^\[/{on=0} on && /^SQL_/{n++} END {print n+0}' "${SVXLINK_CONFIG}")" 0 "no SQL in ${section}"; done

configure_elenata_alsa
for controls in \
    'Capture Mux|LINE_IN' \
    'Capture|6,6|unmute' \
    'Capture Attenuate Switch (-6dB)|on' \
    'PCM|166,166' \
    'Lineout|21,21|unmute' \
    'AVC|off' \
    'AVC Hard Limiter|off' \
    'Mic|0'; do
    IFS='|' read -r control value option <<<"${controls}"
    if [[ -n ${option:-} ]]; then mock_has amixer -c Audio sset "${control}" "${value}" "${option}"; else mock_has amixer -c Audio sset "${control}" "${value}"; fi && pass "ALSA ${control}" || fail "ALSA ${control}"
done
mock_has asactl store -f "${ALSA_STATE_FILE}" 2 && pass 'ALSA state path and card number' || fail 'ALSA state path and card number'
[[ -f ${ALSA_STATE_FILE} ]] && pass 'ALSA state file created' || fail 'ALSA state file created'
CAPTURE_LEFT=8; CAPTURE_RIGHT=5; configure_elenata_alsa
mock_has amixer -c Audio sset Capture 8,5 unmute && pass 'separate capture levels' || fail 'separate capture levels'
audio_present=false
configure_elenata_alsa && pass 'missing Audio card handled' || fail 'missing Audio card handled'
audio_present=true; missing_control=PCM
if (configure_elenata_alsa) >/dev/null 2>&1; then fail 'missing required control must fail'; else pass 'missing required control fails'; fi
missing_control='AVC Hard Limiter'
configure_elenata_alsa && pass 'missing optional control handled' || fail 'missing optional control handled'
missing_control=''
printf '16\n8\n' >"${TEMP_DIR}/capture-input"
prompt_level 'Capture test' 6 <"${TEMP_DIR}/capture-input" >"${TEMP_DIR}/capture-output"
grep -Fqx 8 "${TEMP_DIR}/capture-output" && pass 'invalid capture value rejected' || fail 'invalid capture value rejected'

cp "${SVXLINK_CONFIG}" "${TEMP_DIR}/valid.conf"
printf '%s\n' '[GLOBAL]' 'LOGICS=SimplexLogic' >"${SVXLINK_CONFIG}"
if (configure_base_svxlink) >/dev/null 2>&1; then fail 'missing RepeaterLogic must fail'; else pass 'missing RepeaterLogic fails'; fi
cp "${TEMP_DIR}/valid.conf" "${SVXLINK_CONFIG}"
configure_logging
[[ -f ${LOG_FILE} && -f ${LOGROTATE_FILE} ]] && pass 'temporary logging files' || fail 'temporary logging files'
snapshot after
assert_snapshots
printf 'INFO: Function simulation only; no complete root installation or hardware validation was performed.\n'
for command in amixer asactl aplay arecord systemctl usermod getent chown chmod logrotate; do
    if grep -Fq "${command} <" "${MOCK_LOG}"; then
        printf 'INFO: mock invoked: %s\n' "${command}"
    else
        printf 'INFO: mock not invoked by this component simulation: %s\n' "${command}"
    fi
done

if (( failures == 0 )); then printf 'Simulation completed: all tests passed.\n'; else printf 'Simulation completed: %d failures.\n' "${failures}" >&2; exit 1; fi
