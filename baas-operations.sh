#!/bin/bash

CURL_OPTS="-k -s"
CURL_OPTS_STATUS_CODE="${CURL_OPTS} -o /dev/null -w %{http_code}"
CURL_OPTS_STATUS_CODE_AND_BODY="${CURL_OPTS} -w \\n%{http_code}"

CREDENTIALS_QS="client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}"

# APP

function create_app {
    local name=$1
    printf "Creating app \033[1;34m${name}\033[0m in organization \033[1;34m${ORGANIZATION}\033[0m..."
    local result=$(curl ${CURL_OPTS_STATUS_CODE_AND_BODY} -X POST -d "{ \"name\": \"${name}\" }" "${HOSTURL}/management/orgs/${ORGANIZATION}/apps?${CREDENTIALS_QS}")
    print_result_and_status_code ${result} 200
}

function get_app_credentials {
    local name=$1
    local result=$(curl ${CURL_OPTS} "${HOSTURL}/management/orgs/${ORGANIZATION}/apps/${name}/credentials?${CREDENTIALS_QS}")
    local client_id=$(echo ${result} | jq -r '.credentials.client_id')
    local client_secret=$(echo ${result} | jq -r '.credentials.client_secret')
    printf "\n%-20s %-30s %-30s\n" "NAME" "CLIENT_ID" "CLIENT_SECRET"
    printf "===================================================================================\n"
    printf "%-20s %-30s %-30s\n" "${name}" "${client_id}" "${client_secret}"
}

function get_app_names {
    local result=$(curl ${CURL_OPTS} "${HOSTURL}/management/orgs/${ORGANIZATION}/apps?${CREDENTIALS_QS}")
    echo ${result} | jq -r '.data|keys[]' | while read key ; do
       echo ${key} | cut -d "/" -f 2
    done
    printf "\n"
}

function get_apps {
    local result=$(curl ${CURL_OPTS} "${HOSTURL}/management/orgs/${ORGANIZATION}/apps?${CREDENTIALS_QS}")
    printf "\n%-20s %-36s\n" "NAME" "UUID"
    printf "=========================================================\n"
    echo ${result} | jq -r '.data|keys[]' | while read key ; do
       local name=$(echo ${key} | cut -d "/" -f 2)
       local uuid=$(echo ${result} | jq -r '.data["'${key}'"]')
       printf "%-20s %-36s\n" ${name} ${uuid}
    done
    printf "\n"
}

# COLLECTION

function create_collection {
    local app_name=$1
    local collection_name=$2
    printf "Creating collection \033[1;34m${collection_name}\033[0m in app \033[1;34m${app_name}\033[0m..."
    local result=$(curl ${CURL_OPTS_STATUS_CODE_AND_BODY} -X POST "${HOSTURL}/${ORGANIZATION}/${app_name}/${collection_name}?${CREDENTIALS_QS}")
    print_result_and_status_code ${result} 200
}

function get_collection_names {
    local app_name=$1
    local result=$(curl ${CURL_OPTS} "${HOSTURL}/${ORGANIZATION}/${app_name}?${CREDENTIALS_QS}")
    echo ${result} | jq -r '.entities[].metadata.collections[].name'
}

function get_collections {
    local app_name=$1
    local result=$(curl ${CURL_OPTS} "${HOSTURL}/${ORGANIZATION}/${app_name}?${CREDENTIALS_QS}")
    printf "\n%-20s %-10s %-20s %-20s\n" "TITLE" "COUNT" "NAME" "TYPE"
    printf "=========================================================================\n"
    echo ${result} | jq -r '.entities[].metadata.collections|keys[]' | while read key ; do
        local c_title=$(echo ${result} | jq  -r '.entities[].metadata.collections["'${key}'"].title')
        local c_count=$(echo ${result} | jq  -r '.entities[].metadata.collections["'${key}'"].count')
        local c_name=$(echo ${result} | jq  -r '.entities[].metadata.collections["'${key}'"].name')
        local c_type=$(echo ${result} | jq  -r '.entities[].metadata.collections["'${key}'"].type')
        printf "%-20s %-10s %-20s %-20s\n" ${c_title} ${c_count} ${c_name} ${c_type}
    done
    printf "\n"
}

# ENTITY

function get_entities {
    local app_name=$1
    local collection_name=$2
    curl ${CURL_OPTS} "${HOSTURL}/${ORGANIZATION}/${app_name}/${collection_name}?${CREDENTIALS_QS}" | jq ".entities[]"
}
