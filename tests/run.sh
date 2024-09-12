#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Function
function backend_start () {
    docker compose -f ./docker-compose.yml up -d --wait
}

function backend_stop () {
    docker compose -f ./docker-compose.yml kill || true
}

function backend_remove () {
    docker rm agoston-postgraphile-postgraphile-1 agoston-postgraphile-postgres-1 || true
    docker rmi -f agoston-postgraphile-dev agoston-postgres-dev || true
}

function run_sql_tests () {
    docker exec -it -u postgres agoston-postgraphile-postgres-1 \
        psql agoston \
        -f /tests/${1}.sql \
        -v developer_user=developer \
        -v postgraphile_user=postgraphile
}

function run_auth_tests () {
    curl -k -X POST -d 'username=user-123456789&password=azerty' https://localhost:8043/auth/user-pwd/signup
    curl -k -X POST -d 'username=user-123456789&password=azerty' -c /tmp/cookie.txt https://localhost:8043/auth/user-pwd/login
    returned_code=$(curl -k -X POST --cookie /tmp/cookie.txt -s -o /dev/null -w "%{http_code}" https://localhost:8043/auth/logout)
    if [ $returned_code -ne 201 ]; then
        echo "Error while logging out of the session!"; exit 1
    fi
    returned_code=$(curl -k -X POST --cookie /tmp/cookie.txt -s -o /dev/null -w "%{http_code}" https://localhost:8043/auth/logout)
    if [ $returned_code -ne 404 ]; then
        echo "Error while deleting a none existing session!"; exit 1
    fi
    curl -k -X PATCH -d 'username=user-123456789&old_password=azerty&password=azertyazerty' https://localhost:8043/auth/user-pwd/login
    curl -k -X POST -d 'username=user-123456789&password=azertyazerty' -c /tmp/cookie.txt https://localhost:8043/auth/user-pwd/login
    returned_code=$(curl -k -X POST --cookie /tmp/cookie.txt -s -o /dev/null -w "%{http_code}" https://localhost:8043/auth/logout)
    if [ $returned_code -ne 201 ]; then
        echo "Error while logging out of the session!"; exit 1
    fi
}

function run_configuration_tests () {

    user_id="$(docker exec -i -u postgres agoston-postgraphile-postgres-1 psql agoston -c "select 'user_id:'||agoston_api.add_user();"|grep 'user_id:'|awk -F':' '{print $2}')"
    token="$(docker exec -i -u postgres agoston-postgraphile-postgres-1 psql agoston -c "select 'token:'||agoston_api.set_user_token(p_user_id => ${user_id});"|grep 'token:'|awk -F':' '{print $2}')"

    role_detected=$(curl -k -s -X GET \
        -H "Content-Type: application/json" \
        "https://localhost:8043/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.currentSession.role')
    if [[ "${role_detected}" != "anonymous" ]]; then
        echo "role_detected != anonymous"; exit 1
    fi

    role_detected=$(curl -k -s -X GET \
        -H "Content-Type: application/json" \
        "https://localhost:8043/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.customGraphQLQueryResult.data.session.role')
    if [[ "${role_detected}" != "anonymous" ]]; then
        echo "role_detected != anonymous"; exit 1
    fi

    role_detected=$(curl -k -s -X GET \
        -H "Authorization: Bearer ${user_id}:${token}" \
        -H "Content-Type: application/json" \
        "https://localhost:8043/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.currentSession.role')
    if [[ "${role_detected}" != "authenticated" ]]; then
        echo "role_detected != authenticated"; exit 1
    fi

    role_detected=$(curl -k -s -X GET \
        -H "Authorization: Bearer ${user_id}:${token}" \
        -H "Content-Type: application/json" \
        "https://localhost:8043/.well-known/configuration?gq=query%7Bsession%7D" | jq -r '.customGraphQLQueryResult.data.session.role')
    if [[ "${role_detected}" != "authenticated" ]]; then
        echo "role_detected != authenticated"; exit 1
    fi
}


# Program
echo "START"
backend_stop
backend_remove
backend_start
run_sql_tests "general"
run_auth_tests
backend_stop
backend_start
run_sql_tests "test-cron-job"
run_configuration_tests
if [[ ${SKIP_FINAL_CLEANUP} -ne 1 ]]; then
    backend_stop
fi
echo "END"