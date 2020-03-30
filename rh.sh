#!/bin/bash

VERSION="0.0.1"

function ShowHelp {
    printf "%s\n" \
        "Usage: rh.sh [--url] [--send-start] [--log] [--source] [--destination] | [--help] | [--version]" \
	    "" \
        "Ping Healthchecks after running rsync." \
        "To measuring the rsync duration add the parameter [--send-start]." \
        "To send rsync output to Healthcheck as log add the parameter [--send-log]." \
        "" \
        "All other parameter will be passed to rsync, so be carefull!" \
        "" \
        "Parameters:" \
        "--url                Healthchecks url" \
        "--send-start         notify Healthchecks when rsync starts" \
        "--send-log           notify Healthchecks when rsync starts" \
        "                     send rsync output as log to Healthchecks" \
        "                     (max 1000 characters)" \
        "--log                path to log file for script output" \
        "                     (not rsync log)" \
        "--source             path to source for rsync" \
        "--destination        path to destination for rsync" \
        "" \
        "All other parameter will be passed to rsync!" \
        "" \
        "Optional Parameters" \
        "--help         display this help and exit" \
        "--version      output version information and exit" \
        "" \
        "created by gi8lino (2020)" \
        "https://github.com/gi8lino/rsync-healthchecks"
    	exit 0
}

shopt -s nocasematch  # set string compare to not case senstive
unset IFS

RSYNC_OPTIONS=()

# level: level of log entry
# text: message of log entry
function log() {
    local _level=$1
    local _text=$2

    local _current=$(date '+%Y-%m-%d %H:%M:%S')

    if [ -n "${LOG_FILE}" ];then
        echo "${_current}; ${_level}; ${_text}" >> "${LOG_FILE}"
    else
        echo "${_current}; ${_level}; ${_text}"
    fi
}

# read start parameter
while [[ $# -gt 0 ]];do
    key="$1"
    case $key in
	    --url)
	    HEALTHCHECKS_URL="$2"
	    shift  # pass argument
	    shift  # pass value
	    ;;
	    --send-start)
	    SEND_START=true
	    shift  # pass argument
	    ;;
        --send-output)
	    SEND_OUTPUT=true
	    shift  # pass argument
	    ;;
	    --log)
	    LOG_FILE="$2"
	    shift  # pass argument
	    shift  # pass value
	    ;;
	    --source)
	    SOURCE="$2"
	    shift  # pass argument
	    shift  # pass value
	    ;;
	    --destination)
	    DESTINATION="$2"
	    shift  # pass argument
	    shift  # pass value
	    ;;        
	    --version)
	    printf "rsynch-healthchecks version: %s\n" "${VERSION}"
	    exit 0
	    ;;
	    --help)
	    ShowHelp
	    ;;
	    *)  # unknown option
	    RSYNC_OPTIONS+=($key)
        shift
	    ;;
    esac  # end case
done

log "INFO" "start script"

if [ ${#RSYNC_OPTIONS} != 0 ]; then
    log "INFO" "rsync options: ${RSYNC_OPTIONS[*]}"
else
    log "ERROR" "no rsync log options passed. exit"
    exit 1
fi

if [ -n "$SEND_START" ]; then
    return=$(curl -fsS --retry 3 $HEALTHCHECKS_URL/start)  # track execution time
    if [ "${return}" != "OK" ]; then
        log "ERROR" "cannot send 'start to healthchecks! healthchecks returned '${return}'"
        exit 1
    fi
fi

# run rsync
rsync_output=$(rsync "${RSYNC_OPTIONS[@]}" $SOURCE $DESTINATION)
rsync_exit_code=$?

log "INFO" "rsync exit code is $rsync_exit_code"

# update healthchecks
if [ -n "$SEND_OUTPUT" ] && [ ${#rsync_output} != 0 ] && [ ${#rsync_output} -lt 1000 ]; then
    return=$(curl -fsS --retry 3 -X POST --data "$rsync_output" $HEALTHCHECKS_URL)
else
    return=$(curl -fsS --retry 3 $HEALTHCHECKS_URL)
fi

if [ "${return}" != "OK" ]; then
    log "ERROR" "cannot update healthchecks! healthchecks returned '${return}'"
    exit 1SEND_OUTPUT
fi

log "INFO" "finish script"

exit 0
