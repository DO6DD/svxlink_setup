#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT
export SVXLINK_TEST_MODE=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/logs"
# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

failures=0 successes=0
pass() { printf '[ OK ] %s\n' "$1"; successes=$((successes + 1)); }
fail() { printf '[FEHLER] %s\n' "$1" >&2; failures=$((failures + 1)); }
start_install_log

export SVXLINK_TEST_FORCE_BUILD_PROGRESS=true
success_output=$(run_build_logged 'SvxLink wird kompiliert' bash -c 'printf "[ 37%%] Building CXX object\n[100%%] Built target svxlink\n"')
if [[ ${success_output} == *'[BUILD]  37 %'* && ${success_output} == *'[BUILD] 100 %'* ]]; then pass 'percent progress is displayed'; else fail 'percent progress is displayed'; fi
if grep -Fq '[ 37%] Building CXX object' "${INSTALL_LOG_FILE}" && grep -Fq '[100%] Built target svxlink' "${INSTALL_LOG_FILE}"; then pass 'complete successful output is logged'; else fail 'complete successful output is logged'; fi

if run_build_logged 'SvxLink wird kompiliert' bash -c 'printf "[ 42%%] Building CXX object\ncompiler error\n"; exit 7' >"${TEMP_DIR}/failure.out" 2>&1; then fail 'failed build returns failure'; else pass 'failed build returns failure'; fi
if grep -Fq 'compiler error' "${INSTALL_LOG_FILE}" && grep -Fq 'Letzte Protokollzeilen:' "${TEMP_DIR}/failure.out"; then pass 'failure output and tail are retained'; else fail 'failure output and tail are retained'; fi

unset SVXLINK_TEST_FORCE_BUILD_PROGRESS
plain_output=$(run_build_logged 'SvxLink wird kompiliert' bash -c 'printf "plain build output\n"')
if [[ ${plain_output} != *$'\r'* && ${plain_output} == *'[ OK ] SvxLink wird kompiliert'* ]]; then pass 'noninteractive fallback has no control sequences'; else fail 'noninteractive fallback has no control sequences'; fi
if grep -Fq 'plain build output' "${INSTALL_LOG_FILE}"; then pass 'non-percent output is logged'; else fail 'non-percent output is logged'; fi

printf 'Erfolgreich: %d\nFehler: %d\n' "${successes}" "${failures}"
(( failures == 0 ))
