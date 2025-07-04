#!/bin/bash

# Make sure we don't have any old logs laying around
rm -rf logs/ && mkdir -p logs/
# Empty the test cache for our tests so any previous runs will not affect it.
go clean -testcache

function error() {
    local RED='\033[0;31m'
    local NC='\033[0m'

    # Use echo with -e to enable interpretation of backslash escapes
    # "$@" expands to all arguments passed to the function
    echo -e "${RED}${@}${NC}"
}

# 1. Run with the DRONE_COMMIT_SHA variable set to blank, expected: no cached packages.
# Note: Go will only cache the test results when it's in package list mode, i.e. the "./..." mode
echo "[01] DRONE_COMMIT_SHA empty and never run"

go test ./... | tee logs/01.log

actual="$(grep -c '(cached)' logs/01.log)"
if [ "${actual}" -ne 0 ] ; then
  error "[01] Expected 0 cached lines actual='${actual}' in the output from the first test run, which should not be cached."
fi

# 2. Run again with no variables set, should see it cached
echo -e "\n[02] DRONE_COMMIT_SHA empty and run without changes, expect to cache"

go test ./... | tee logs/02.log

actual=$(grep -c '(cached)' logs/02.log)
if [ "${actual}" -ne 3 ]; then
  error "[02] Expected exactly 3 cached packages actual='${actual}' to be cached when running unchanged"
fi

# 3. Run with DRONE_COMMIT_SHA set to 1, expect no caches
echo -e "\n[03] DRONE_COMMIT_SHA=1, expect no cache in packages that uses the variable, directly or indirectly through a library"
export DRONE_COMMIT_SHA=1

go test ./... | tee logs/03.log

actual="$(grep -c '(cached)' logs/03.log)"
if [ "${actual}" -ne 1 ] ; then
  error "[03] Expected 1 cached package actual='${actual}' to be cached AFTER setting the DRONE_COMMIT_SHA variable, because it didn't rely on it"
fi

# 4. Run with DRONE_COMMIT_SHA set to 1, expect 3 cached packages
echo -e "\n[04] DRONE_COMMIT_SHA=1, expect 3 cached packages"
export DRONE_COMMIT_SHA=1

go test ./... | tee logs/04.log

actual="$(grep -c '(cached)' logs/04.log)"
if [ "${actual}" -ne 3 ] ; then
  error "[04] Expected exactly 3 cached packages actual='${actual}' to be cached when running with the same value for DRONE_COMMIT_SHA"
fi
