#!/usr/bin/env bash

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

failures=0
successes=0
pass() { printf '[ OK ] %s\n' "$1"; successes=$((successes + 1)); }
fail() { printf '[FEHLER] %s\n' "$1" >&2; failures=$((failures + 1)); }

service_present=false
service_enabled=false
service_active=false
mock_log="${TEMP_DIR}/systemctl.log"

systemctl() {
    printf '%q ' "$@" >>"${mock_log}"
    printf '\n' >>"${mock_log}"
    case $1 in
        cat) ${service_present} ;;
        is-enabled) ${service_enabled} ;;
        is-active) ${service_active} ;;
        daemon-reload) : ;;
        disable)
            service_enabled=false
            [[ ${2:-} != --now && ${3:-} != --now ]] || service_active=false
            ;;
        enable) service_enabled=true ;;
        *) : ;;
    esac
}

export SVXLINK_TEST_MODE=true
export SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/logs"
# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

fresh_output="${TEMP_DIR}/fresh.out"
record_svxlink_service_state
service_present=true
finalize_svxlink_service >"${fresh_output}" 2>&1
if ! ${service_enabled} && ! ${service_active} && grep -Fq 'disable --now svxlink.service' "${mock_log}" && ! grep -Fq 'enable svxlink.service' "${mock_log}"; then
    pass 'fresh installation keeps SvxLink disabled and inactive without enable'
else
    fail 'fresh installation must not enable or start SvxLink'
fi
if grep -Fq 'SvxLink bleibt deaktiviert und wurde nicht gestartet.' "${fresh_output}"; then pass 'fresh installation output matches disabled service state'; else fail 'fresh installation output must describe disabled state'; fi

: >"${mock_log}"
service_present=true
service_enabled=true
service_active=true
record_svxlink_service_state
finalize_svxlink_service >"${TEMP_DIR}/update.out" 2>&1
if ${service_enabled} && ${service_active} && ! grep -Eq '(^| )disable |(^| )enable ' "${mock_log}"; then
    pass 'update preserves an already enabled and active SvxLink service'
else
    fail 'update must not alter an existing SvxLink service state'
fi
if grep -Fq 'bereits aktivierte und laufende SvxLink-Dienst bleibt unverändert' "${TEMP_DIR}/update.out"; then pass 'update output describes preserved enabled state'; else fail 'update output must describe preserved state'; fi

printf 'Erfolgreich: %d\nFehler: %d\n' "${successes}" "${failures}"
(( failures == 0 ))
