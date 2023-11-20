#!/bin/bash
set -x
set -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

cp ${SCRIPTPATH}/test_reset_db.sh /tmp/test_reset_db.sh
chmod u+x /tmp/test_reset_db.sh
/tmp/test_reset_db.sh

cp ${SCRIPTPATH}/_test_db_upgrade.sh /tmp/_test_db_upgrade.sh
chmod u+x /tmp/_test_db_upgrade.sh
/tmp/_test_db_upgrade.sh
