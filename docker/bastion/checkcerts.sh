#!/bin/bash

set -eu

declare IPSJSON="${IPSJSON:-""}"
declare WEBHOOK_URL="${WEBHOOK_URL:-""}"
declare STATSD_IPPORT="${STATSD_IPPORT:-""}"

# Use gdate util on mac
[[ "$(uname -o)" == "Darwin" ]] && 
declare DATE_CMD="gdate" || 
declare DATE_CMD="date"


# Retrieve ips from file.
get_ips_json(){
    jq -r \
        'to_entries[] | { key, value: .value[] } | "\(.key)-\(.value | split(".") | join("-")):\(.value)"' \
        ${IPSJSON}
}

# Create string as <service>:<ip_addr>:<port>.
map_service_ips(){
    for si in $(get_ips_json); do
        if [[ "${si%%:*}" == "callisto"* ]]; then
            echo "${si}:8000"
        else    
            echo "${si}:4000"
        fi
    done
}

# Use docker to create map to run against local ports for test
map_docker_ips(){
    docker container list --format '{{ .ID }}' | 
    while read id; do 
        docker container inspect $id --format \
            '{{.Config.Hostname}}:{{range .NetworkSettings.Ports}}{{range .}}127.0.0.1:{{.HostPort}}{{end}}{{end}}' 
    done
}

get_service_ips(){
    if [[ -n "${IPSJSON}" ]]; then
        map_service_ips
    elif [[ -e "/var/run/docker.sock" ]]; then
        map_docker_ips
    else
        echo "no source to parse ips from" 
        exit 1
    fi
}

# Output certificate content from client.
get_ssl_cert(){
    local ipport=$1
    openssl s_client -connect ${ipport} 2>/dev/null </dev/null | cat
}

# If any certificates were not re-issued, notify the Engineering team via Slack
# (in the form of sending data to a Slack webhook.)
ssl_check_reissue(){
    local si=$1
    local cert=$2
    local enddate=$(${DATE_CMD} -d "last thursday + 365 days" +%s)
    local now=$(${DATE_CMD} +%s)
    if !(echo "${cert}" | openssl x509 -checkend $((${enddate}-${now})) -noout -in /dev/stdin >/dev/null); then
        ssl_needs_reissue "$si"
        return 1
    fi
    return 0
}

# If any certificates are within 30 days of expiring, notify the team with an urgent message via Slack.
ssl_check_expiring(){
    local si=$1
    local cert=$2
    local seconds=$((60*60*24*30))
    if !(echo "${cert}" | openssl x509 -checkend ${seconds} -noout -in /dev/stdin >/dev/null); then 
        ssl_is_expiring "$si"
        return 1
    fi 
    return 0
} 

# If any certificates have expired, notify the team with an extremely urgent message.
ssl_check_expired(){
    local si=$1
    local cert=$2
    if !(echo "$cert" | openssl x509 -checkend 0 -noout -in /dev/stdin >/dev/null); then 
        ssl_is_expired "$si"
        return 1
    fi 
    return 0
} 

# If any other issues arise (such as connection issues), ensure that the team is notified.
ssl_check_error(){
    local si=$1
    local cert=$2
    if [[ -z "${cert}" ]]; then
        ssl_error "$si"
        return 1
    fi
    return 0
} 

main(){
    for si in $(get_service_ips); do
        ssl_cert="$(get_ssl_cert "${si#*:}")"
        ssl_check_error "$si" "$ssl_cert" &&
        ssl_check_expired "$si" "$ssl_cert" &&
        ssl_check_expiring "$si" "$ssl_cert" &&
        ssl_check_reissue "$si" "$ssl_cert" &&
        send_info "${si%%:*} is ok"
    done
}

ssl_needs_reissue(){
    local si=$1
    local msg="INFO: ${si%%:*} ssl certificate has not been reissued in the last 7 days"
    send_stats "outdated" "${si}"
    send_info "${msg}"
}

ssl_is_expiring(){
    local si=$1
    local msg="WARN: ${si%%:*} ssl certificate is expiring with the next 30 days"
    send_stats "expiring" "${si}"
    send_warn "${msg}"
}

ssl_is_expired(){
    local si=$1
    local msg="ERROR: ${si%%:*} ssl certificate has expired"
    send_stats "expired" "${si}"
    send_error "${msg}"
}

ssl_error(){
    local si=$1
    local msg="ERROR: ${si%%:*} ssl certificate could not be checked"
    send_error "${msg}"
}

send_slack(){
    local msg="$1"
    if [[ -n "${WEBHOOK_URL}" ]]; then
        curl -so /dev/null -X POST -H 'Content-type: application/json' --data "{\"text\":\"${msg}\"}" "${WEBHOOK_URL}" &
    fi
}

send_stats(){
    local status="$1"
    local si=$2
    if [[ -n "${STATSD_IPPORT}" ]]; then
        echo "certs.${si%%-*}.${status}:1|g" | socat -t 0 STDIN "UDP:${STATSD_IPPORT}"
    fi
}

send_info(){
    printf '\e[32m%b\e[0m' "$(date -Iseconds): $1\n"
}

send_warn(){
    send_slack "$1"
    printf '\e[33m%b\e[0m' "$(date -Iseconds): $1\n"
}

send_error(){
    send_slack "$1"
    printf '\e[31m%b\e[0m' "$(date -Iseconds): $1\n"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi