#!/usr/bin/env bash

test_output_color() {
    [[ -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]
}

test_line() {
    local kind=$1 message=$2 color='' reset=''
    if test_output_color; then
        case ${kind} in
            '[ OK ]') color='\033[32m' ;;
            '[WARN]') color='\033[33m' ;;
            '[FEHLER]') color='\033[31m' ;;
            '[TEST]') color='\033[36m' ;;
        esac
        reset='\033[0m'
    fi
    printf '%b%s%b %s\n' "${color}" "${kind}" "${reset}" "${message}"
}
