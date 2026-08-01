#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2015

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT
# shellcheck disable=SC1091
source "${ROOT}/tests/test_output.sh"
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
export SVXLINK_TEST_MODE=true
export SVXLINK_TEST_RASPBERRY_PI=true
export BOOT_CONFIG_FILE="${TEMP_DIR}/config.txt"
export SVXLINK_CONFIG_FILE="${TEMP_DIR}/svxlink.conf"
export SVXLINK_SOUNDS_DIR="${TEMP_DIR}/sounds"
export SVXLINK_BACKUP_DIR="${TEMP_DIR}/backups"
export MODULES_FILE="${TEMP_DIR}/modules"
export SND_CARD_CONFIG_FILE="${TEMP_DIR}/snd-card.conf"
export RASPI_BLACKLIST_FILE="${TEMP_DIR}/raspi-blacklist.conf"
export GPIO_CONFIG_FILE="${TEMP_DIR}/gpio.conf"
export DRIVER_SOURCE_DIR="${TEMP_DIR}/drivers"

failures=0
successes=0
MOCK_LOG="${TEMP_DIR}/mock.log"
cleanup() { rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT
pass() { test_line '[ OK ]' "$*"; successes=$((successes + 1)); }
fail() { test_line '[FEHLER]' "$*" >&2; failures=$((failures + 1)); }
expect_line() { grep -Fqx "$2" "$1" && pass "$3" || fail "$3"; }
expect_count() { [[ $(grep -Fxc "$2" "$1" || true) == "$3" ]] && pass "$4" || fail "$4"; }
snapshot_production_paths() {
    local phase=$1 path output
    for path in /boot/config.txt /boot/firmware/config.txt /etc/modules /etc/modprobe.d/raspi-blacklist.conf /etc/svxlink/gpio.conf; do
        output="${TEMP_DIR}/${phase}-${path//\//_}"
        if [[ -e ${path} ]]; then
            sha256sum "${path}" >"${output}"
            stat -c '%F|%a|%u|%g|%s|%Y' "${path}" >>"${output}"
        else
            printf absent >"${output}"
        fi
    done
}
assert_production_paths_unchanged() {
    local path before after
    for path in /boot/config.txt /boot/firmware/config.txt /etc/modules /etc/modprobe.d/raspi-blacklist.conf /etc/svxlink/gpio.conf; do
        before="${TEMP_DIR}/before-${path//\//_}"
        after="${TEMP_DIR}/after-${path//\//_}"
        cmp -s "${before}" "${after}" && pass "unchanged ${path}" || fail "changed ${path}"
    done
}

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR
test_line '[TEST]' 'Historische Hardwareprofil-Simulation'

install_packages_for_profile() { printf 'package <%s>\n' "$1" >>"${MOCK_LOG}"; }
install_historical_driver() { printf 'driver <%s> <%s>\n' "$1" "$2" >>"${MOCK_LOG}"; }

printf '%s\n' 'dtparam=spi=on' >"${BOOT_CONFIG_FILE}"
printf '%s\n' 'snd-bcm2835' >"${MODULES_FILE}"
snapshot_production_paths before
detect_operating_system

HARDWARE_PROFILE=1
configure_hardware_profile
for line in 'dtparam=audio=off' 'dtparam=i2c_arm=on' 'dtoverlay=fe-pi-audio' 'dtoverlay=i2s-mmap' 'dtoverlay=mcp23017,addr=0x20,gpiopin=12' 'dtoverlay=mcp3008:spi0-0-present,spi0-0-speed=3600000' 'enable_uart=1'; do expect_line "${BOOT_CONFIG_FILE}" "${line}" "ICS boot ${line}"; done
expect_line "${MODULES_FILE}" '#snd-bcm2835' 'ICS disables snd-bcm2835 module'
expect_line "${MODULES_FILE}" 'i2c-dev' 'ICS enables i2c-dev module'
grep -Fqx 'package <i2c-tools>' "${MOCK_LOG}" && pass 'ICS installs i2c-tools' || fail 'ICS installs i2c-tools'
ics_hash=$(sha256sum "${BOOT_CONFIG_FILE}" "${MODULES_FILE}" | sha256sum | awk '{print $1}')
configure_hardware_profile
[[ $(sha256sum "${BOOT_CONFIG_FILE}" "${MODULES_FILE}" | sha256sum | awk '{print $1}') == "${ics_hash}" ]] && pass 'ICS idempotent' || fail 'ICS idempotent'
profile_one_boot_hash=$(sha256sum "${BOOT_CONFIG_FILE}" | awk '{print $1}')

HARDWARE_PROFILE=2
printf '%s\n' 'options snd_usb_audio index=0' 'options snd slots=snd_usb_audio,snd-bcm2835' >"${SND_CARD_CONFIG_FILE}"
configure_hardware_profile
expect_line "${RASPI_BLACKLIST_FILE}" 'blacklist snd_bcm2835' 'uSvxCard blacklist'
expect_line "${SND_CARD_CONFIG_FILE}" '#options snd_usb_audio index=0' 'uSvxCard sound index adjustment'
expect_line "${SND_CARD_CONFIG_FILE}" '#options snd slots=snd_usb_audio,snd-bcm2835' 'uSvxCard slot adjustment'
for line in 'GPIO_IN_HIGH="gpio23 gpio24"' 'GPIO_OUT_HIGH="gpio17"' 'GPIO_USER="svxlink"'; do expect_line "${GPIO_CONFIG_FILE}" "${line}" "uSvxCard GPIO ${line}"; done
grep -Fqx 'driver <seeed-voicecard> <https://github.com/respeaker/seeed-voicecard.git>' "${MOCK_LOG}" && pass 'uSvxCard historical driver source' || fail 'uSvxCard historical driver source'
usvx_hash=$(sha256sum "${RASPI_BLACKLIST_FILE}" "${SND_CARD_CONFIG_FILE}" "${GPIO_CONFIG_FILE}" | sha256sum | awk '{print $1}')
configure_hardware_profile
[[ $(sha256sum "${RASPI_BLACKLIST_FILE}" "${SND_CARD_CONFIG_FILE}" "${GPIO_CONFIG_FILE}" | sha256sum | awk '{print $1}') == "${usvx_hash}" ]] && pass 'uSvxCard idempotent' || fail 'uSvxCard idempotent'
[[ $(sha256sum "${BOOT_CONFIG_FILE}" | awk '{print $1}') == "${profile_one_boot_hash}" ]] && pass 'uSvxCard does not alter ICS boot configuration' || fail 'uSvxCard does not alter ICS boot configuration'

HARDWARE_PROFILE=3
configure_hardware_profile
grep -Fqx 'driver <WM8960-Audio-HAT> <https://github.com/waveshare/WM8960-Audio-HAT>' "${MOCK_LOG}" && pass 'WM8960 historical driver source' || fail 'WM8960 historical driver source'

HARDWARE_PROFILE=4
printf '%s\n' '[GLOBAL]' 'LOGICS=RepeaterLogic' '[RepeaterLogic]' 'CALLSIGN=DM0DOS' '[SimplexLogic]' 'CALLSIGN=DM0DOS' '[Rx1]' '[Tx1]' >"${SVXLINK_CONFIG_FILE}"
configure_hardware_profile
expect_line "${BOOT_CONFIG_FILE}" 'dtoverlay=disable-bt' 'ELENATA remains separate'
snapshot_production_paths after
assert_production_paths_unchanged

printf '\n============================================================\nTESTERGEBNIS\n============================================================\nErfolgreich: %d\nWarnungen:   0\nFehler:      %d\n' "${successes}" "${failures}"
if (( failures == 0 )); then printf 'Ergebnis:    ERFOLGREICH\n============================================================\n'; else printf 'Ergebnis:    FEHLGESCHLAGEN\n============================================================\n' >&2; exit 1; fi
