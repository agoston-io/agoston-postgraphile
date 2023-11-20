#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Function
function start_graphile () {
    http_port_listening=${1}

    # Start server
    npm run serve --prefix ${SCRIPTPATH}/.. &
    NODE_PID=$!

    # Wait for graphile availability
    max_retry=5
    HTTP_RETURN=0
    while [ $HTTP_RETURN -ne 200 -a ${max_retry} -gt 0 ]; do
        sleep 1
        max_retry=$((max_retry-1))
        HTTP_RETURN=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST -H "Content-Type: application/json" -d '{"query":"query{session}"}' "http://localhost:${http_port_listening}/data/graphql" || true)
    done
    if [ ${max_retry} -eq 0 ]; then exit 1; fi
    sleep 2
}

function run_tests () {
    test_name="${2}"
    suffix="-${3}"
    export HTTP_PORT_LISTENING=${1}
    export PGDATABASE="agoston${suffix}"
    export POSTGRAPHILE_USER="postgraphile${suffix}"
    export DEVELOPER_USER="developer${suffix}"
    start_graphile ${HTTP_PORT_LISTENING}
    cp ${SCRIPTPATH}/${test_name}.sql /tmp/${test_name}.sql
    sudo su - postgres -c "
        psql agoston${suffix} \
        -f /tmp/${test_name}.sql \
        -v developer_user=\"'${DEVELOPER_USER}'\" \
        -v postgraphile_user=\"'${POSTGRAPHILE_USER}'\"
    "
}

# Program
echo "START"
. ${SCRIPTPATH}/test_environment.sh
# -- single db mode
${SCRIPTPATH}/stop_any_graphile.sh
${SCRIPTPATH}/test_reset_db.sh
run_tests 8080 "test" 1
${SCRIPTPATH}/stop_any_graphile.sh
run_tests 8080 "test-cron-job" 1
# -- Isolated dbs
${SCRIPTPATH}/stop_any_graphile.sh
${SCRIPTPATH}/test_reset_db.sh
run_tests 8081 "test" 2
run_tests 8082 "test" 3
# --
if [[ ${SKIP_FINAL_CLEANUP} -ne 1 ]]; then
    ${SCRIPTPATH}/stop_any_graphile.sh
fi
echo "END"
