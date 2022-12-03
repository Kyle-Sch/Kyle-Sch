#!/bin/bash

main() {

    echo "startScriptAsDaemon called"
    echo "Script = $1"
    echo "Args for script = $(echo "$@" | awk '{for (i=2; i<=NF; i++) print $i}')"

    echo "Starting script..."
    nohup "$@" > /dev/null 2>&1 &

    sleep 1
    echo "Searching for PID with command ps -eaf | grep \"$1\" | grep -v 'grep' | grep -v tail | awk '{print \$2}'"
    pid=$(ps -eaf | grep "$1" | grep -v startScriptAsDaemon | grep -v grep | grep -v tail | awk '{print $2}')
    echo "Found pid = $pid"
    if [[ "$pid" == "" ]]; then
        echo "Couldn't detect PID (got '$pid'), exiting as a failure"
        exit 1
    else
        echo "Daemon script $1 running with pid = $pid"
        echo "Daemon script $1 running with pid = $pid" >> /opt/fedex/iss/bin/stage/runningDaemonPIDs
    fi
}

main "$@"