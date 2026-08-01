#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2015,SC2016

set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly ROOT
# shellcheck disable=SC1091
source "${ROOT}/tests/test_output.sh"
TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR
export SVXLINK_TEST_MODE=true
export SVXLINK_BUILD_STATE_FILE="${TEMP_DIR}/state/build-state"
export SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/logs"
export SVXLINK_TEST_OS_VERSION=13
export SVXLINK_TEST_OS_ID=debian

failures=0
successes=0
cleanup() { rm -rf "${TEMP_DIR}"; }
trap cleanup EXIT
pass() { test_line '[ OK ]' "$*"; successes=$((successes + 1)); }
fail() { test_line '[FEHLER]' "$*" >&2; failures=$((failures + 1)); }
expect() { [[ $1 == "$2" ]] && pass "$3" || fail "$3 (expected $2, got $1)"; }

# shellcheck disable=SC1091
source "${ROOT}/svxlink_setup.sh"
trap - ERR
test_line '[TEST]' 'Buildentscheidungs-Simulation'

SOURCE_DIR="${TEMP_DIR}/source"
BUILD_DIR="${SOURCE_DIR}/build"
INSTALL_USER="$(id -un)"
mkdir -p "${SOURCE_DIR}/.git"
mkdir -p "${TEMP_DIR}/bin"
printf '#!/usr/bin/env bash\nprintf "SvxLink v1.10.1\\n1.10.1@26.05.1\\n"\n' >"${TEMP_DIR}/bin/svxlink"
chmod 0755 "${TEMP_DIR}/bin/svxlink"
PATH="${TEMP_DIR}/bin:${PATH}"
detect_operating_system

expect "$(normalize_svxlink_release_version <<<'SvxLink v1.10.1')" 1.10.1 'labelled component version is normalized but not fabricated as release version'
expect "$(normalize_svxlink_release_version <<<'1.10.1@26.05.1')" 26.05.1 'combined component@release selects the release part'
expect "$(printf '1.10.1\nSvxLink v26.05.1\n' | normalize_svxlink_release_version)" 26.05.1 'labelled release version is selected over unrelated version tokens'
expect "$(normalize_svxlink_release_version <<<'  Version: 26.05.1  ')" 26.05.1 'prefixes and whitespace are removed'
if normalize_svxlink_release_version <<<'component 1.10.1 and 26.05.1' >/dev/null; then fail 'embedded arbitrary SemVer tokens are not selected'; else pass 'embedded arbitrary SemVer tokens are rejected'; fi
expect "$(installed_svxlink_version)" 26.05.1 'installed version uses combined release marker instead of first component version'

git() {
    if [[ $* == *'rev-parse HEAD'* ]]; then printf '%s\n' abcdef1234567890; return 0; fi
    if [[ $* == *'describe --tags --exact-match'* || $* == *'describe --tags --always'* ]]; then printf '%s\n' 26.05.1; return 0; fi
    return 0
}
g++() { printf '%s\n' 'g++ (test compiler) 13.0'; }
uname() { [[ $1 == -m ]] && printf '%s\n' x86_64 || command uname "$@"; }

if reason=$(build_required_reason false); then
    [[ ${reason} == *'Buildstatus fehlt'* ]] && pass 'missing build state requires build' || fail 'missing build state reason'
else fail 'missing build state must require build'; fi

write_build_state
[[ -f ${BUILD_STATE_FILE} ]] && pass 'successful build state is written atomically' || fail 'successful build state is written atomically'
expect "$(stat -c '%a' "${BUILD_STATE_FILE}")" 644 'build state mode'
if build_required_reason false >/dev/null; then fail 'matching state must skip build'; else pass 'matching commit, version and platform skip build'; fi
prepare_svxlink_source() { :; }
log_build_comparison() { :; }
run_logged() { printf 'BUILD_COMMAND_CALLED\n'; }
skip_output=$(build_svxlink false)
[[ ${skip_output} != *BUILD_COMMAND_CALLED* ]] && pass 'matching state skips CMake, build and install commands' || fail 'matching state must not call build commands'
if reason=$(build_required_reason true); then [[ ${reason} == 'Erzwungene Neuinstallation' ]] && pass 'force always requires build' || fail 'force reason'; else fail 'force must require build'; fi

sed -i 's/^SVXLINK_GIT_COMMIT=.*/SVXLINK_GIT_COMMIT=other/' "${BUILD_STATE_FILE}"
if reason=$(build_required_reason false); then [[ ${reason} == *'anderen Git-Commit'* ]] && pass 'changed commit requires build' || fail 'changed commit reason'; else fail 'changed commit must require build'; fi
write_build_state
sed -i 's/^CMAKE_OPTIONS_HASH=.*/CMAKE_OPTIONS_HASH=other/' "${BUILD_STATE_FILE}"
if reason=$(build_required_reason false); then [[ ${reason} == *'Buildparameter'* ]] && pass 'changed build options require build' || fail 'changed build options reason'; else fail 'changed build options must require build'; fi

printf 'EVIL=$(touch %s/unsafe)\nUNKNOWN=value\n' "${TEMP_DIR}" >>"${BUILD_STATE_FILE}"
read_build_state
[[ ! -e ${TEMP_DIR}/unsafe ]] && pass 'build state is parsed without source execution' || fail 'build state must not execute content'

printf '\n============================================================\nTESTERGEBNIS\n============================================================\nErfolgreich: %d\nWarnungen:   0\nFehler:      %d\n' "${successes}" "${failures}"
if (( failures == 0 )); then printf 'Ergebnis:    ERFOLGREICH\n============================================================\n'; else printf 'Ergebnis:    FEHLGESCHLAGEN\n============================================================\n' >&2; exit 1; fi
