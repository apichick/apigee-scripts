#!/bin/bash

ORG_RESOURCES=("api" "app" "apiproduct" "company" "developer" "environment" "resource")
DEVELOPER_RESOURCES=("developerapp")
COMPANY_RESOURCES=("companyapp")

CURL_OPTS="-k -s -u ${USERNAME}:${PASSWORD}"
CURL_OPTS_STATUS_CODE="${CURL_OPTS} -o /dev/null -w %{http_code}"
CURL_OPTS_STATUS_CODE_AND_BODY="${CURL_OPTS} -w \\n%{http_code}"
ORG_OPERATION_URL=${HOSTURL}/${APIVERSION}/organizations/${ORGANIZATION}
ENV_OPERATION_URL=${HOSTURL}/${APIVERSION}/organizations/${ORGANIZATION}/environments/${ENVIRONMENT}

PUBLISH_INFO=("apiproduct" "developer" "app")

function get_url {
    resource_type=$1
    local url
    if [[ ${ORG_RESOURCES[@]} =~ ${resource_type} ]]; then
        url=${ORG_OPERATION_URL}
    elif [[ ${DEVELOPER_RESOURCES[@]} =~ ${resource_type} ]]; then
        url=${DEVELOPER_OPERATION_URL}
    elif [[ ${COMPANY_RESOURCES[@]} =~ ${resource_type} ]]; then
        url=${COMPANY_OPERATION_URL}
    else
        url=${ENV_OPERATION_URL}
    fi
    if [[ "${resource_type}" = "company" ]]; then
        url=${url}/companies
    else
        if [ "${resource_type}" = "developerapp" -o "${resource_type}" = "companyapp" ]; then
            url=${url}/apps
        else
            url=${url}/${resource_type}s
        fi
    fi
    echo ${url}
}

function get_resources {
    local resource_type=$1
    local expression
    if [ "${resource_type}" = "vault" ]; then
        expression='.vault[]'
    elif [ "${resource_type}" = "deployment" ]; then
        expression='.aPIProxy[].name'
    else
        expression='.[]'
    fi
    local url=$(get_url ${resource_type})
    if [ "${resource_type}" = "keyvaluemap" ]; then
        curl ${CURL_OPTS} ${url} | jq -rc "${expression}" | sed 's/__apigee__.keystore//g' | sed 's/__apigee__.vaults//g'
    else
        curl ${CURL_OPTS} ${url} | jq -rc "${expression}"
    fi
}

function select_resource {
    resource_type=$1
    resources=($(get_resources ${resource_type}))
    options=(${resources[@]})
    options+=("QUIT")
    PS3="Please select a ${resource_type}: "
    select resource_name in ${resources[@]}; do
        if [[ ${resources[@]} =~ ${resource_name} ]]; then
            break
        fi
    done
    echo ${resource_name}
}

if [[ "${RESOURCE}" = "developerapp" ]]; then
    DEVELOPER_EMAIL=$(select_resource "developer")
elif [[ "${RESOURCE}" = "companyapp" ]]; then
    COMPANY_NAME=$(select_resource "company")
fi

DEVELOPER_OPERATION_URL=${HOSTURL}/${APIVERSION}/organizations/${ORGANIZATION}/developers/${DEVELOPER_EMAIL}
COMPANY_OPERATION_URL=${HOSTURL}/${APIVERSION}/organizations/${ORGANIZATION}/companies/${COMPANY_NAME}

function list_resources {
    resource_type=$1
    resources=($(get_resources ${resource_type}))
    count=${#resources[@]}
    for((i=0;i<${count};i++)); do
        echo "${resources[$i]}"
    done
}

function select_resource_list {
    local answer=""
    local resource_type=$1
    local resources=($(get_resources ${resource_type}))
    if [[ ${#resources[@]} -gt 0 ]]; then
        options=(${resources[@]})
        local is_done=false
        local selected_resource
        while [[ ${is_done} = false ]]; do
            PS3="Please select a(n) ${resource_type}: "
            select resource_name in ${resources[@]}; do
                if [[ ${resources[@]} =~ ${resource_name} ]]; then
                    selected_resource=${resource_name}
                    break
                fi
            done
            if [[ -n ${selected_resource} ]]; then
                answer="${answer} ${selected_resource}"
                selected_resources=(${answer})
                if [[ ${#resources[@]} -gt ${#selected_resources[@]} ]]; then
                    resources=(${resources[@]/$selected_resource})
                    is_done=$(ask_for_confirmation "Done?")
                else
                    is_done=true
                fi
            fi
        done
    fi
    echo ${answer}
}

function create_resource {
    local resource_type="$1"
    local payload="$2"
    local expression
    if [[ ${resource_type} = "developer" ]]; then
        expression='.email'
    else
        expression='.name'
    fi
    local resource_name=$(echo ${payload} | jq -r ${expression})
    local url=$(get_url ${resource_type})
    printf "Creating ${resource_type} \033[1;34m${resource_name}\033[0m..."
    if [[ "${resource_name}" != __apigee__.* ]]; then
	    local result=$(curl -X POST -H "Content-Type: application/json" -d "${payload}" ${CURL_OPTS_STATUS_CODE_AND_BODY} ${url})
        print_result "${result}" 201
	else
		printf "\033[1;31mSkipped\033[0m\n"
	fi
}

function create_resource_entry {
    local resource_type=$1
    local resource_name=$2
    local entry_name=$3
    local entry_value=$4
    local url=$(get_url ${resource_type})
    printf "Creating ${resource_type} entry \033[1;34m${entry_name}\033[0m with value \033[1;34m${entry_value}\033[0m in ${resource_type} \033[1;34m${resource_name}\033[0m..."
    local result=$(curl -X POST -H "Content-Type: application/json" -d "{ \"name\": \"${entry_name}\", \"value\": \"${entry_value}\"}" ${CURL_OPTS_STATUS_CODE_AND_BODY} ${url}/${resource_name}/entries)
	print_result "${result}" 201
}

function create_vault_entry {
	create_resource_entry "vault" "$1" "$2" "$3"
}

function create_keyvaluemap_entry {
	create_resource_entry "keyvaluemap" "$1" "$2" "$3"
}

function delete_resource {
    local resource_type=$1
    local resource_name=$2
    local url=$(get_url ${resource_type})
	printf "Deleting ${resource_type} \033[1;34m${resource_name}\033[0m..."
	result=$(curl -X DELETE ${CURL_OPTS_STATUS_CODE_AND_BODY} ${url}/${resource_name})
    print_result "${result}" 200
}

function ask_for_resource_info {
    resource_type=$1
    eval "ask_for_${resource_type}_info"
}

function ask_for_developer_info {
    email=$(ask_for_non_empty_input "Email")
    firstName=$(ask_for_non_empty_input "First Name")
    lastName=$(ask_for_non_empty_input "Last Name")
    userName=$(ask_for_non_empty_input "User Name")
    jq -n --arg email ${email} --arg firstName ${firstName} --arg lastName ${lastName} --arg userName ${userName} '{email: $email, firstName: $firstName, lastName: $lastName, userName: $userName}'
}

function ask_for_apiproduct_info {
    local name=$(ask_for_non_empty_input "Name")
    local display_name=$(ask_for_non_empty_input "Display Name")
    local payload=$(jq -n --arg name ${name} --arg displayName ${display_name} '{ name: $name, displayName: $displayName }')
    local approval_types=("auto" "manual")
    local approval_type=$(ask_for_any "Approval Type" "${approval_types[@]}")
    payload=$(echo ${payload} | jq --arg approvalType ${approval_type} '. |= .+ { approvalType: $approvalType }')
    local description=$(ask_for_input "Description")
    if [[ -n ${description} ]]; then
        payload=$(echo ${payload} | jq --arg description "${description}" '. |= .+ { description: $description }')
    fi
    local add_custom_attrs=$(ask_for_confirmation "Does the API product have custom attributes?")
    if [[ ${add_custom_attrs} = true ]]; then
        local attrs=$(ask_for_attrs)
        payload=$(echo ${payload} | jq --argjson attrs "${attrs}" '. |= .+ { attributes: $attrs }')
    fi
    local proxies=$(select_resource_list "api")
    if [[ -n ${api_products} ]]; then
        payload=$(echo ${payload} | jq --arg apiProducts "${api_products}" '. |= .+ { apiProducts: ($apiProducts|split(" ")) }')
    fi
    local environments=$(select_resource_list "environment")
    if [[ -n ${environments} ]]; then
        payload=$(echo ${payload} | jq --arg environments "${environments}" '. |= .+ { environments: ($environments|split(" ")) }')
    fi
    local api_resources=$(ask_for_input "API Resources (separated by spaces)")
    if [[ -n ${api_resources} ]]; then
        payload=$(echo ${payload} | jq --arg apiResources "${api_resources}" '. |= .+ { scope: ($apiResources|split(" ")) }')
    fi
    local quota=$(ask_for_empty_or_number "Quota")
    if [[ -n ${quota} ]]; then
        local quota_interval=$(ask_for_number "Quota Interval")
        local quota_time_units=("minute" "hour" "day" "month")
        local quota_time_unit=$(ask_for_any "Quota Time Unit")
        payload=$(echo ${payload} | jq --arg quota "${quota}" --arg quotaInterval ${quota_interval} --arg quotaTimeUnit ${quota_time_unit} '. |= .+ { quota: $quota, quotaInterval: $quotaInterval, quotaTimeUnit: $quotaTimeUnit }')
    fi
    local scopes=$(ask_for_input "Scopes (separated by spaces)")
    if [[ -n ${scopes} ]]; then
        payload=$(echo ${payload} | jq --arg scopes "${scopes}" '. |= .+ { scope: ($scopes|split(" ")) }')
    fi
    echo ${payload}
}

function ask_for_keyvaluemap_info {
    name=$(ask_for_non_empty_input "Name")
    jq -n --arg name ${name} '{name: $name}'
}

function ask_for_cache_info {
    local name=$(ask_for_non_empty_input "Name")
    local payload=$(jq -n --arg name ${name} '{ name: $name }')
    local use_defaults=$(ask_for_confirmation "Use default settings?")
    if [[ "${use_defaults}" = "false" ]]; then
        local expiry_date=$(ask_for_empty_or_date "Expiry settings -> Date (mm-dd-yyyy)")
        if [[ -n ${expiry_date} ]]; then
            local values_null=$(ask_for_confirmation "Expiry settings -> Always consider cache expiry date")
            payload=$(echo ${payload} | jq --arg expiryDate ${expiry_date} --arg valuesNull ${values_null} '. |= .+ { expiryDate: { value: $expiryDate }, valuesNull: $valuesNull }')
        fi
        local overflow_to_disk=$(ask_for_confirmation "Overflow to disk")
        payload=$(echo ${payload} | jq --arg overflowToDisk ${overflow_to_disk} '. |= .+ { overflowToDisk: $overflowToDisk }')
        local skip_cache_if_element_size_exceeds=$(ask_for_empty_or_number "Skip cache if element size exceeds (KB)")
        if [[ -n ${skip_cache_if_element_size_exceeds} ]]; then
            payload=$(echo ${payload} | jq --arg skipCacheIfElementSizeExceeds ${skip_cache_if_element_size_exceeds} '. |= .+ { skipCacheIfElementSizeExceeds: $skipCacheIfElementSizeExceeds | tonumber }')
        fi
    fi
    echo ${payload}
}

function ask_for_company_info {
    local name=$(ask_for_non_empty_input "Name")
    local payload=$(jq -n --arg name ${name} '{ name: $name }')
    echo ${payload}
}

function ask_for_developerapp_info {
    local payload=""
    local name=$(ask_for_non_empty_input "Name")
    payload=$(jq -n --arg name ${name} '{ name: $name }')
    local api_products=$(select_resource_list "apiproduct")
    if [[ -n ${api_products} ]]; then
        payload=$(echo ${payload} | jq --arg apiProducts "${api_products}" '. |= .+ { apiProducts: ($apiProducts|split(" ")) }')
    fi
    local key_expires_in=$(ask_for_number "Key expires in (milliseconds)")
    if [[ -n ${key_expires_in} ]]; then
        payload=$(echo ${payload} | jq --arg keyExpiresIn "${key_expires_in}" '. |= .+ { keyExpiresIn: $keyExpiresIn | tonumber }')
    fi
    local scopes=$(ask_for_input "Scopes (separated by spaces)")
    if [[ -n ${scopes} ]]; then
        payload=$(echo ${payload} | jq --arg scopes "${scopes}" '. |= .+ { scope: ($scopes|split(" ")) }')
    fi
    echo ${payload}
}

function ask_for_companyapp_info {
    local payload=""
    local name=$(ask_for_non_empty_input "Name")
    payload=$(jq -n --arg name ${name} '{ name: $name }')
    local api_products=$(select_resource_list "apiproduct")
    if [[ -n ${api_products} ]]; then
        payload=$(echo ${payload} | jq --arg apiProducts "${api_products}" '. |= .+ { apiProducts: ($apiProducts|split(" ")) }')
    fi
    local callbackUrl=$(ask_for_non_empty_input "Callback URL")
    if [[ -n ${callback_url} ]]; then
        payload=$(echo ${payload} | jq --arg callbackUrl "${callback_url}" '. |= .+ { callbackUrl: $callbackUrl }')
    fi
    echo ${payload}
}

function ask_for_input {
    local message=$1
    local answer
    read -p "${message}: " answer
    echo ${answer}
}

function ask_for_non_empty_input {
    local message=$1
    local answer
    while [[ -z "${answer}" ]]; do
        read -p "${message}: " answer
    done
    echo ${answer}
}

function ask_for_number {
    local message=$1
    local answer
    while [[ ! ${answer} =~ ^-?[0-9]+$ ]]; do
        read -p "${message}:" answer
    done
    echo ${answer}
}

function ask_for_empty_or_number {
    local message=$1
    local answer
    local is_done=false
    while [[ ${is_done} = false ]]; do
        read -p "${message}:" answer
        if [[ ${answer} =~ ^-?[0-9]*$ ]]; then
            is_done=true
        fi
    done
    echo ${answer}
}

function ask_for_empty_or_date {
    local message=$1
    local answer
    local is_done=false
    while [[ ${is_done} = false ]]; do
        read -p "${message}:" answer
        if [[ -z ${answer} ]]; then
            is_done=true
        else
            local os=$(uname)
            if [[ ${os} = "Darwin" ]]; then
                date -f "%m-%d-%Y" -j ${answer} > /dev/null 2>&1
            else
                date --date=$(echo ${answer} | sed "s/-/\//g") "+%m/%d/%Y" > /dev/null 2>&1
            fi
            if [[ $? -eq 0 ]]; then
                is_done=true
            fi
        fi
    done
    echo ${answer}
}

function ask_for_confirmation {
    local message=$1
    local answer
    read -p "${message} (y/N): " answer
    if [[ "${answer}" =~ ^[yY]$ ]]; then
        answer=true
    else
        answer=false
    fi
    echo ${answer}
}

function ask_for_any {
    local message=$1
    shift
    local choices=("${@}")
    local answer
    local is_done=false
    while [[ ${is_done} = false ]]; do
        read -p "${message} ("$(echo ${choices[*]} | sed 's/ /|/g')"): " answer
        if [[ ${choices[@]} =~ ${answer} ]]; then
            is_done=true
        else
            is_done=false
        fi
    done
    echo ${answer}
}

function ask_for_attrs {
    local attrs="[]";
    local is_done=false
    while [[ ${is_done} = false ]]; do
        local name=$(ask_for_non_empty_input "Attribute Name")
        local value=$(ask_for_non_empty_input "Attribute Value")
        attrs=$(echo ${attrs} | jq --arg name ${name} --arg value $value '. |= .+  [ {name: $name, value: $value} ] ')
        local is_done=$(ask_for_confirmation "Done?")
    done
    echo ${attrs}
}

function ask_for_ssl_info {
    local enabled=$(ask_for_confirmation "SSLInfo -> enabled")
    local sslinfo=$(jq -n --argjson enabled ${enabled} '{ "enabled": $enabled }')
    if [[ "${enabled}" = "true" ]]; then
        local client_auth_enabled=$(ask_for_confirmation "SSLInfo -> clientAuthEnabled")
        local sslinfo=$(echo ${sslinfo} | jq --argjson clientAuthEnabled ${client_auth_enabled} '. |= .+ { "clientAuthEnabled": $clientAuthEnabled }')
        if [[ ${client_auth_enabled} = true ]]; then
            read -p "SSLInfo -> keyStore: " keystore
            read -p "SSLInfo -> trustStore: " truststore
            read -p "SSLInfo -> keyAlias: " key_alias
            sslinfo=$(echo ${sslinfo} | jq --arg keystore "${keystore}" --arg truststore "${truststore}" --arg keyalias "${key_alias}" '. |= .+ { keystore: $keystore, truststore: $truststore, keyalias: $keyalias }')
        fi
        read -p "SSLInfo -> ciphers (separated by spaces): " ciphers
        read -p "SSLInfo -> protocols (separated by spaces): " protocols
        sslinfo=$(echo ${sslinfo} | jq --arg ciphers "${ciphers}" --arg protocols "${protocols}" '. |= .+ { ciphers: ($ciphers|split(" ")), protocols: ($protocols|split(" "))}')
    fi
    echo ${sslinfo}
}

function ask_for_virtualhost_info {
    local name=$(ask_for_non_empty_input "Name")
    local host_aliases=$(ask_for_non_empty_input "Host aliases (separated by spaces)")
    local port=$(ask_for_number "Port")
    read -p "Interfaces (separated by spaces): " interfaces
    local enabled=$(ask_for_confirmation "SSLInfo -> enabled")
    local payload=$(jq -n --arg name "${name}" --arg hostAliases "${host_aliases}" --arg interfaces "${interfaces}" --arg port ${port} '{name: $name, hostAliases: ($hostAliases|split(" ")), interfaces: ($interfaces|split(" ")), port: $port | tonumber }')
    local sslinfo=$(ask_for_ssl_info)
    payload=$(echo ${payload} | jq --argjson sslinfo "${sslinfo}" '. |= .+ { sSLInfo: $sslinfo }')
    echo ${payload}
}

function ask_for_targetserver_info {
    local name=$(ask_for_non_empty_input "Name")
    local host=$(ask_for_non_empty_input "Host")
    local enabled=$(ask_for_confirmation "isEnabled")
    local port=$(ask_for_number "Port")
    local payload=$(jq -n --arg name "${name}" --arg host "${host}" --arg port "${port}" --arg isEnabled "${enabled}" '{name: $name, host: $host, port: $port | tonumber, isEnabled: $isEnabled }')
    local sslinfo=$(ask_for_ssl_info)
    payload=$(echo ${payload} | jq --argjson sslinfo "${sslinfo}" '. |= .+ { sSLInfo: $sslinfo }')
    echo ${payload}
}

function get_resource_info {
    local resource_type=$1
    local resource_name=$2
    local url=$(get_url ${resource_type})
	curl ${CURL_OPTS} ${url}/${resource_name}
}

function get_resources_info {
    local resource_type=$1
	local json="[]"
    local resource_names=($(get_resources "${resource_type}"))
    for resource_name in ${resource_names[@]}; do
        local resource_info=$(get_resource_info ${resource_type} ${resource_name})
    	local expression=". |= . + [${resource_info}]"
    	local json=$(echo $json | jq "${expression}")
	done
	echo $json | jq '.'
}

function get_env_info {
	local resource_types=("cache" "keyvaluemap" "vault" "virtualhost" "targetserver")
    json={}
    for resource_type in ${resource_types[@]}; do
		resources=$(get_resources_info ${resource_type})
        expression='. |= . + { "'${resource_type}'": '${resources}' }'
        json=$(echo $json | jq "${expression}")
    done
    echo $json | jq '.'
}

function load_env_info {
    local resource_types=("cache" "keyvaluemap" "vault" "virtualhost" "targetserver")
    for resource_type in ${resource_types[@]}; do
        count=$(echo "${content}" | jq -c '.'${resource_type}' | length')
        for((i=0;i<${count};i++)); do
            resource_info=$(echo ${content} | jq -c '.'${resource_type}'['${i}']')
            create_resource ${resource_type} "${resource_info}"
    	done
    done
}

function clear_all_cache_entries {
    local resource_name=$1
    local url=$(get_url ${resource_type})
    printf "Clearing cache \033[1;34m${resource_name}s\033[0m instances..."
    local result=$(curl -X POST -H'Content-Type: application/octet-stream' ${CURL_OPTS_STATUS_CODE_AND_BODY} ${url}/${resource_name}/entries?action=clear)
    print_result "${result}" 200
}

function clear_cache_entry {
    local resource_name=$1
    local entry_name=$2
    local url=$(get_url ${resource_type})
    printf "Clearing cache \033[1;34m${resource_name}s\033[0m instances..."
    local result=$(curl -X POST -H'Content-Type: application/octet-stream' ${CURL_OPTS_STATUS_CODE_AND_BODY} ${url}/${resource_name}/entries/${entry_name}?action=clear)
    print_result "${result}" 200
}

function import_api {
    local api=$1
    local file=$2
    local out=$(curl -X POST -H "Accept: application/json" -F "file=@$file" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ORG_OPERATION_URL}/apis?action=import&name=${api}&validate=true")
    if [[ $? -eq 0 ]]; then
        local status_code=$(echo "${out}" | tail -n1)
        local body=$(echo "${out}" | sed '$d')
        if [[ ${status_code} -eq 201 ]]; then
            local revision=$(echo ${body} | jq -r '.revision')
            echo ${revision}
            return 0
        else
            echo ${body}
            return 1
        fi
    else
        return 1
    fi
}

function update_api_revision {
    local api=$1
    local file=$2
    local revision=$3
    local out=$(curl -X POST -H "Accept: application/json" -F "file=@$file" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ORG_OPERATION_URL}/apis/${api}/revisions/${revision}?validate=true")
    if [[ $? -eq 0 ]]; then
        local status_code=$(echo "${out}" | tail -n1)
        local body=$(echo "${out}" | sed '$d')
        echo ${out}
        return 0
    else
        return 1
    fi
}

function get_api_deployed_revision_in_env {
    local api=$1
    local out=$(curl -H "Accept: application/json" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ORG_OPERATION_URL}/apis/${api}/deployments")
    local code
    if [[ $? -eq 0 ]]; then
        local status_code=$(echo "${out}" | tail -n1)
        local body=$(echo "${out}" | sed '$d')
        case ${status_code} in
            200)
                code=0
                revision=$(echo ${body} | jq -r '.environment[] | select(.name="'${ENVIRONMENT}'") | .revision[0].name')
                echo ${revision}
                ;;
            404)
                code=0
                ;;
            *)
                code=1
                ;;
        esac
    else
        code=1
    fi
    return ${code}
}

function deploy_api_revision {
    local api=$1
    local revision=$2
    local override=$3
    local qparams=""
    if [[ ${override} -eq 1 ]]; then
        qparams="?override=true&delay=5"
    fi
    local out=$(curl -X POST -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ENV_OPERATION_URL}/apis/${api}/revisions/${revision}/deployments${qparams}")
    if [[ $? -eq 0 ]]; then
        local status_code=$(echo "${out}" | tail -n1)
        local body=$(echo "${out}" | sed '$d')
        if [[ ${status_code} -eq 200 ]]; then
            return 0
        else
            echo ${body}
            return 1
        fi
    fi
}

function undeploy_api_revision {
    local api=$1
    local environment=$2
    local revision=$3
    printf "Undeploying revision \033[1;34m${revision}\033[0m of API \033[1;34m${api}\033[0m in environment \033[1;34m${environment}\033[0m..."
    local result=$(curl -X DELETE -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ORG_OPERATION_URL}/environments/${environment}/apis/${api}/revisions/${revision}/deployments")
    print_result "${result}" 200
}

function delete_api {
    local api=$1
    local out=$(curl -H "Accept: application/json" ${CURL_OPTS_STATUS_CODE_AND_BODY} "${ORG_OPERATION_URL}/apis/${api}/deployments")
    if [[ $? -eq 0 ]]; then
        local status_code=$(echo "${out}" | tail -n1)
        local body=$(echo "${out}" | sed '$d')
        if [ ${status_code} -eq 200 ]; then
                environments=($(echo "${body}" | jq -r '.environment[].name'))
                for environment in ${environments[@]}; do
                    revisions=$(echo ${body} | jq -r '.environment[] | select(.name="'${environment}'") | .revision[].name')
                    for revision in ${revisions[@]}; do
                        state=$(echo ${body} | jq -r '.environment[] | select(.name="'${environment}'") | .revision[] | select(.name="'${revision}'") | .state')
                        if [ "${state}" = "deployed" ]; then
                            undeploy_api_revision ${api} ${environment} ${revision}
                        fi
                    done
                done
                delete_resource "api" ${api}
        else
            return 1
        fi
    fi
}
