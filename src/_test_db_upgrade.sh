#!/bin/bash
set -x
set -e

testMe(){
    echo "## Testing version '${1}'"
    git checkout ${1}
    set +e
    timeout --preserve-status --kill-after=10 --signal=SIGINT 5 npm run serve
    if [ $? -ne 130 ]; then
        echo "FATAL!"
        exit 1
    fi
    set -e
}

echo "## Testing fresh new backend..."
testMe "$(git tag|sort --version-sort|tail -1)"

/tmp/test_reset_db.sh

echo "## Testing upgrade from 10 versions behing..."
for version in $(git tag|sort --version-sort|tail -10); do
    testMe "${version}"
done

echo "## git checkout master"
git checkout master

echo "SUCCESS"
