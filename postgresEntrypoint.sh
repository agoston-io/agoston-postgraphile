#!/bin/sh
/tc.sh
exec /usr/local/bin/docker-entrypoint.sh postgres "$@"
