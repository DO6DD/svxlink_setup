#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

failures=0 successes=0
pass() { printf '[ OK ] %s\n' "$1"; successes=$((successes + 1)); }
fail() { printf '[FEHLER] %s\n' "$1" >&2; failures=$((failures + 1)); }

run_debug_case() {
    local output=$1 debug_dir=$2 no_color=$3
    NO_COLOR=${no_color} TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_TEST_FORCE_BUILD_PROGRESS=true SVXLINK_INSTALL_LOG_DIR="${debug_dir}/install" SVXLINK_DEBUG_LOG_DIR="${debug_dir}" bash -c '
        source "$1/svxlink_setup.sh"
        DEBUG_MODE=true
        start_debug_log
        print_info "Farbig"
        print_success "Erfolgreich"
        print_warning "Warnung"
        print_error "Fehler"
        run_build_logged "Testbuild" bash -c "printf '\''[ 51%%] Building CXX object\\n'\''"
    ' _ "${ROOT}" >"${output}" 2>&1
}

color_output="${TEMP_DIR}/color.out"
run_debug_case "${color_output}" "${TEMP_DIR}/color-debug" ''
color_log=$(find "${TEMP_DIR}/color-debug" -name 'debug-*.log' -print -quit)
if grep -Fq $'\033[36m[INFO]\033[0m Farbig' "${color_output}" && grep -Fq $'\033[32m[ OK ]\033[0m Erfolgreich' "${color_output}" && grep -Fq $'\033[33m[WARN]\033[0m Warnung' "${color_output}" && grep -Fq $'\033[31m[FEHLER]\033[0m Fehler' "${color_output}"; then pass 'debug redirection retains terminal colors'; else fail 'debug redirection must retain terminal colors'; fi
if grep -Fq $'\r[BUILD]  51 %' "${color_output}"; then pass 'debug redirection retains build progress'; else fail 'debug redirection must retain build progress'; fi
if grep -Fq '[ 51%] Building CXX object' "${color_log}" && ! grep -q $'\033\|\r\[BUILD\]' "${color_log}"; then pass 'debug log contains raw build output without terminal controls'; else fail 'debug log must not contain terminal controls'; fi

no_color_output="${TEMP_DIR}/no-color.out"
run_debug_case "${no_color_output}" "${TEMP_DIR}/no-color-debug" 1
if ! grep -q $'\033\[' "${no_color_output}"; then pass 'NO_COLOR suppresses colors after debug redirection'; else fail 'NO_COLOR must suppress colors'; fi

dumb_output="${TEMP_DIR}/dumb.out"
TERM=dumb SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/dumb-install" bash -c '
    source "$1/svxlink_setup.sh"
    print_info "Stilles Terminal"
    run_build_logged "Stiller Build" bash -c "printf '\''[ 51%%] Building CXX object\\n'\''"
' _ "${ROOT}" >"${dumb_output}" 2>&1
if ! grep -q $'\033\|\r\|\[BUILD\]' "${dumb_output}"; then pass 'TERM=dumb suppresses terminal controls'; else fail 'TERM=dumb must suppress terminal controls'; fi

spinner_success="${TEMP_DIR}/spinner-success.out"
TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_TEST_FORCE_ACTIVITY=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/spinner-install" bash -c '
    source "$1/svxlink_setup.sh"
    run_logged "Lange Aktion" bash -c "sleep 0.25"
' _ "${ROOT}" >"${spinner_success}" 2>&1
if grep -Fq '[WORK]' "${spinner_success}" && grep -Fq $'\r\033[K' "${spinner_success}" && grep -Fq '[ OK ] Lange Aktion' "${spinner_success}"; then pass 'activity indicator is cleared after success'; else fail 'activity indicator must finish cleanly after success'; fi

download_output="${TEMP_DIR}/download.out"
TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_TEST_FORCE_ACTIVITY=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/download-install" bash -c '
    source "$1/svxlink_setup.sh"
    run_logged "Deutsche Sounds werden heruntergeladen" bash -c "sleep 0.25"
' _ "${ROOT}" >"${download_output}" 2>&1
if grep -Fq '[DOWNLOAD]' "${download_output}"; then pass 'download without known size uses download activity indicator'; else fail 'download without known size must use activity indicator'; fi

spinner_failure="${TEMP_DIR}/spinner-failure.out"
spinner_status=0
TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_TEST_FORCE_ACTIVITY=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/spinner-failure-install" bash -c '
    source "$1/svxlink_setup.sh"
    run_logged "Fehlende Aktion" bash -c "sleep 0.25; exit 7"
' _ "${ROOT}" >"${spinner_failure}" 2>&1 || spinner_status=$?
if [[ ${spinner_status} == 7 ]]; then pass 'activity failure retains command exit status'; else fail "activity failure must retain exit 7 (got ${spinner_status})"; fi
if grep -Fq '[WORK]' "${spinner_failure}" && grep -Fq $'\r\033[K' "${spinner_failure}" && grep -Fq '[FEHLER] Fehlende Aktion fehlgeschlagen.' "${spinner_failure}"; then pass 'activity indicator is cleared after failure'; else fail 'activity indicator must finish cleanly after failure'; fi

spinner_signal="${TEMP_DIR}/spinner-signal.out"
signal_status=0
TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_TEST_FORCE_ACTIVITY=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/spinner-signal-install" bash -c '
    source "$1/svxlink_setup.sh"
    run_logged "Abgebrochene Aktion" sleep 5
' _ "${ROOT}" >"${spinner_signal}" 2>&1 &
action_pid=$!
sleep 0.2
kill -TERM "${action_pid}"
wait "${action_pid}" || signal_status=$?
if [[ ${signal_status} == 143 ]] && grep -Fq $'\r\033[K' "${spinner_signal}"; then pass 'signal stops and clears activity indicator'; else fail "signal must stop activity indicator (got ${signal_status})"; fi

plain_output="${TEMP_DIR}/plain.out"
SVXLINK_TEST_MODE=true SVXLINK_INSTALL_LOG_DIR="${TEMP_DIR}/plain-install" bash -c '
    source "$1/svxlink_setup.sh"
    run_logged "Stille Aktion" bash -c "sleep 0.05"
    run_build_logged "Stiller Build" bash -c "printf '\''[ 51%%] Building CXX object\\n'\''"
' _ "${ROOT}" >"${plain_output}" 2>&1
if ! grep -q $'\033\|\r\|\[WORK\]\|\[BUILD\]' "${plain_output}"; then pass 'noninteractive output has no colors, spinner, or progress line'; else fail 'noninteractive output must remain plain'; fi

prompt_output="${TEMP_DIR}/prompt.out"
printf 'Antwort\nGeheimnis\n' | NO_COLOR='' TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true SVXLINK_DEBUG_LOG_DIR="${TEMP_DIR}/prompt-debug" bash -c '
    source "$1/svxlink_setup.sh"
    DEBUG_MODE=true
    start_debug_log
    prompt_value answer "Installation jetzt starten? [j/N]: "
    prompt_secret password "Passwort für die deutschen Sounds: "
    [[ ${answer} == Antwort ]]
' _ "${ROOT}" >"${prompt_output}" 2>&1
prompt_log=$(find "${TEMP_DIR}/prompt-debug" -name 'debug-*.log' -print -quit)
if grep -Fq $'\033[1;35mInstallation jetzt starten? [j/N]: \033[0m' "${prompt_output}" && grep -Fq $'\033[1;35mPasswort für die deutschen Sounds: \033[0m' "${prompt_output}" && ! grep -Fq '[EINGABE]' "${prompt_output}" && ! grep -Fq Geheimnis "${prompt_log}"; then pass 'debug prompts stay highlighted without prefix and secret input stays out of debug log'; else fail 'prompts or secret logging are incorrect'; fi

plain_prompt_output="${TEMP_DIR}/plain-prompt.out"
printf 'Antwort\n' | NO_COLOR=1 TERM=xterm-256color SVXLINK_TEST_MODE=true SVXLINK_TEST_FORCE_INTERACTIVE_OUTPUT=true bash -c '
    source "$1/svxlink_setup.sh"
    prompt_value answer "Auswahl: "
' _ "${ROOT}" >"${plain_prompt_output}" 2>&1
if grep -Fq 'Auswahl: ' "${plain_prompt_output}" && ! grep -q $'\033\|\[EINGABE\]' "${plain_prompt_output}"; then pass 'NO_COLOR keeps prompts readable without prefix'; else fail 'NO_COLOR prompt formatting is incorrect'; fi

cleanup_output="${TEMP_DIR}/cleanup.out"
SVXLINK_TEST_MODE=true SVXLINK_DEBUG_LOG_DIR="${TEMP_DIR}/cleanup-debug" bash "${ROOT}/svxlink_setup.sh" -D --help >"${cleanup_output}" 2>&1
cleanup_log=$(find "${TEMP_DIR}/cleanup-debug" -name 'debug-*.log' -print -quit)
if ! grep -Eq 'close_output_fds|: exec|main: exit=0: exit 0|\[\[ -z [0-9]+' "${cleanup_output}" && grep -Fq 'show_help' "${cleanup_log}"; then pass 'debug cleanup hides internal xtrace while retaining prior trace'; else fail 'debug cleanup must hide only internal cleanup trace'; fi

printf 'Erfolgreich: %d\nFehler: %d\n' "${successes}" "${failures}"
(( failures == 0 ))
