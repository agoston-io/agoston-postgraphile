#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Function
function stop_any_graphile () {
    kill -9 $(ps -ef | egrep 'node index.js|npm run serve' | grep -v grep | awk '{print $2}') || true
}

stop_any_graphile
