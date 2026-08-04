#!/usr/bin/env bash

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

failures=0
successes=0
pass() { printf '[ OK ] %s\n' "$1"; successes=$((successes + 1)); }
fail() { printf '[FEHLER] %s\n' "$1" >&2; failures=$((failures + 1)); }

export SVXLINK_TEST_MODE=true
export SVXLINK_CONFIG_FILE="${TEMP_DIR}/svxlink.conf"
# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

require_root_for_action() { :; }
detect_operating_system() { OS_VERSION='test'; IS_RASPBERRY_PI=false; }
detected_hardware_profile() { printf '0\n'; }
confirm_installation() { :; }
record_svxlink_service_state() { :; }
install_packages() { :; }
require_base_tools() { :; }
disable_automatic_updates() { :; }
ensure_svxlink_account() { :; }
build_svxlink() { BUILD_PERFORMED=true; }
configure_logging() { :; }
configure_base_svxlink() { :; }
configure_hardware_profile() { :; }
write_build_state() { :; }
install_german_sounds() { return 0; }
activate_sound_language() { :; }
install_english_sounds() { return 1; }
finalize_svxlink_service() { :; }

CALLSIGN=DM0DOS
CALLSIGN_PROVIDED=true
HARDWARE_PROFILE=0
HARDWARE_PROFILE_PROVIDED=true
ACTION_YES=true
status=0
run_installation automatic >"${TEMP_DIR}/output" 2>&1 || status=$?
if [[ ${status} == 1 ]] && grep -Fq 'SvxLink-Build und Grundkonfiguration wurden abgeschlossen, die Gesamtinstallation ist jedoch unvollständig.' "${TEMP_DIR}/output" && grep -Fq 'Die Soundinstallation konnte nicht vollständig abgeschlossen werden.' "${TEMP_DIR}/output"; then
    pass 'English sound failure reports partial progress and incomplete total installation'
else
    fail 'English sound failure must report incomplete installation'
fi
if grep -Fq 'SvxLink wurde erfolgreich aktualisiert.' "${TEMP_DIR}/output"; then
    fail 'English sound failure must not report a successful update'
else
    pass 'English sound failure suppresses misleading successful-update message'
fi

printf 'Erfolgreich: %d\nFehler: %d\n' "${successes}" "${failures}"
(( failures == 0 ))
