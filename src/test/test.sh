#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Function
function start_graphile () {
    # Start server
    npm run serve --prefix ${SCRIPTPATH}/.. &
    NODE_PID=$!

    # Wait for graphile availability
    max_retry=5
    HTTP_RETURN=0
    while [ $HTTP_RETURN -ne 200 -a ${max_retry} -gt 0 ]; do
        sleep 1
        max_retry=$((max_retry-1))
        HTTP_RETURN=$(curl -s -o /dev/null -w "%{http_code}" -k -X POST -H "Content-Type: application/json" -d '{"query":"query{session}"}' "http://localhost:${HTTP_PORT_LISTENING}/data/graphql" || true)
    done
    if [ ${max_retry} -eq 0 ]; then exit 1; fi
    sleep 2
}

function run_tests () {
    . ${SCRIPTPATH}/test_environment.sh
    test_name="${2}"
    suffix="-${3}"
    export HTTP_PORT_LISTENING=${1}
    export PGDATABASE="agoston${suffix}"
    export POSTGRAPHILE_USER="postgraphile${suffix}"
    export DEVELOPER_USER="developer${suffix}"
    start_graphile
    # Tests in db
    cp ${SCRIPTPATH}/${test_name}.sql /tmp/${test_name}.sql
    sudo su - postgres -c "
        psql agoston${suffix} \
        -f /tmp/${test_name}.sql \
        -v developer_user=\"'${DEVELOPER_USER}'\" \
        -v postgraphile_user=\"'${POSTGRAPHILE_USER}'\"
    "
}

function run_auth_tests () {
    . ${SCRIPTPATH}/test_environment.sh
    export HTTPS_LISTENING=1
    openssl req -x509 -newkey rsa:4096 -keyout /tmp/server.key -out /tmp/server.crt -sha256 -days 3650 -nodes -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
    start_graphile
    # Test logout
    curl -k -X POST -d 'username=anyuser&password=s2ssDD3hf3-' -c /tmp/cookie.txt https://localhost:${HTTPS_PORT_LISTENING}/auth/user-pwd
    returned_code=$(curl -k -X POST --cookie /tmp/cookie.txt -s -o /dev/null -w "%{http_code}" https://localhost:${HTTPS_PORT_LISTENING}/auth/logout)
    if [ $returned_code -ne 201 ]; then
        echo "Error while logging out of the session!"; exit 1
    fi
    returned_code=$(curl -k -X POST --cookie /tmp/cookie.txt -s -o /dev/null -w "%{http_code}" https://localhost:${HTTPS_PORT_LISTENING}/auth/logout)
    if [ $returned_code -ne 404 ]; then
        echo "Error while deleting a none existing session!"; exit 1
    fi
}

function run_configuration_tests () {
    suffix="-${2}"
    export HTTP_PORT_LISTENING=${1}
    export PGDATABASE="agoston${suffix}"

    start_graphile
    # create a token
    token=$(sudo su - postgres -c "psql ${PGDATABASE} <<<\"select 'token:'||set_user_token(p_user_id => agoston_api.add_user());\""|grep 'token:'|awk -F':' '{print $2}')

    role_detected=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        "http://localhost:${HTTP_PORT_LISTENING}/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.currentSession.role')
    if [[ "${role_detected}" != "anonymous" ]]; then
        echo "role_detected != anonymous"; exit 1
    fi

    role_detected=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        "http://localhost:${HTTP_PORT_LISTENING}/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.customGraphQLQueryResult.data.session.role')
    if [[ "${role_detected}" != "anonymous" ]]; then
        echo "role_detected != anonymous"; exit 1
    fi

    role_detected=$(curl -s -X GET \
        -H ""Authorization": Bearer ${token}" \
        -H "Content-Type: application/json" \
        "http://localhost:${HTTP_PORT_LISTENING}/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.currentSession.role')
    if [[ "${role_detected}" != "authenticated" ]]; then
        echo "role_detected != authenticated"; exit 1
    fi

    role_detected=$(curl -s -X GET \
        -H ""Authorization": Bearer ${token}" \
        -H "Content-Type: application/json" \
        "http://localhost:${HTTP_PORT_LISTENING}/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.customGraphQLQueryResult.data.session.role')
    if [[ "${role_detected}" != "authenticated" ]]; then
        echo "role_detected != authenticated"; exit 1
    fi
}


# Program
echo "START"
# -- single db mode
${SCRIPTPATH}/stop_any_graphile.sh
${SCRIPTPATH}/test_reset_db.sh
run_tests 8880 "test" 1
${SCRIPTPATH}/stop_any_graphile.sh
run_configuration_tests 8880 1
${SCRIPTPATH}/stop_any_graphile.sh
run_tests 8880 "test-cron-job" 1
${SCRIPTPATH}/stop_any_graphile.sh
run_auth_tests
# -- Isolated db mode
${SCRIPTPATH}/stop_any_graphile.sh
${SCRIPTPATH}/test_reset_db.sh
run_tests 8881 "test" 2
run_tests 8882 "test" 3
# --
if [[ ${SKIP_FINAL_CLEANUP} -ne 1 ]]; then
    ${SCRIPTPATH}/stop_any_graphile.sh
fi
echo "END"
