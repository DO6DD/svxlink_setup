#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT
export SVXLINK_TEST_MODE=true
# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR

failures=0 successes=0
pass() { printf '[ OK ] %s\n' "$1"; successes=$((successes + 1)); }
fail() { printf '[FEHLER] %s\n' "$1" >&2; failures=$((failures + 1)); }
run_logged() { printf '%s\n' "$*" >>"${TEMP_DIR}/commands"; }

required_packages=(
    build-essential git libasound2-dev g++ gcc make cmake groff gzip doxygen tar graphviz
    libsigc++-2.0-dev libspeex-dev libspeexdsp-dev libopus-dev libogg-dev libpopt-dev
    libgcrypt20-dev libgsm1-dev librtlsdr-dev libjsoncpp-dev tcl-dev alsa-utils
    libcurl4-openssl-dev i2c-tools libi2c-dev rtl-sdr gpiod libgpiod-dev vorbis-tools dnsutils mc
    bzip2 ca-certificates curl libopusenc-dev libsndfile1-dev libssl-dev libvorbis-dev logrotate lsof
)

IS_RASPBERRY_PI=false
install_packages
general_command=$(tail -n 1 "${TEMP_DIR}/commands")
for package in "${required_packages[@]}"; do
    if [[ ${general_command} == *" ${package}"* ]]; then pass "general package ${package}"; else fail "missing general package ${package}"; fi
done
if [[ ${general_command} == *' libsigc++-2.0-dev'* && ${general_command} == *' libgcrypt20-dev'* ]]; then pass 'concrete Debian compatibility packages are installed'; else fail 'concrete Debian compatibility packages are missing'; fi
if [[ ${general_command} != *' libsigc++-dev'* && ${general_command} != *' libgcrypt-dev'* ]]; then pass 'obsolete package aliases are not installed'; else fail 'obsolete package aliases are installed'; fi

printf 'Erfolgreich: %d\nFehler: %d\n' "${successes}" "${failures}"
(( failures == 0 ))
