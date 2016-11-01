#!/bin/bash

function print_result {
    local result=$1
    local expected_status_code=$2
    local status_code=$(echo "${result}" | tail -n1)
    if [[ ${status_code} -eq ${expected_status_code} ]]; then
        printf "\033[1;32mOK\033[0m (${status_code})\n"
	else
        local message=$(echo "${result}" | sed '$d' | jq -r '.message')
        if [[ -n ${message} ]]; then
            printf "\033[1;31mKO\033[0m (${status_code}: ${message})\n"
        else
            printf "\033[1;31mKO\033[0m (${status_code})\n"
        fi
	fi
}

function check_command_exists {
    command_name=$1
    command -v ${command_name} >/dev/null 2>&1 || { echo "Please install ${command}. Aborting." >&2; exit 1; }
}

function jq {
   check_command_exists "jq"
   command jq "$@"
}
