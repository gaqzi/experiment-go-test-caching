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

ANY_FAILED=0

# A helper to run a test, log its output, and check the cache count.
# It will exit the script on the first failure.
#
# Usage: run_and_check <test_num> <expected_count> <failure_description> <go_test_args...>
run_and_check() {
    local test_num="$1"
    local expected_count="$2"
    local failure_desc="$3"
    shift 3
    local go_args=("$@")

    go test "${go_args[@]}" | tee "logs/${test_num}.log"

    local actual_count
    actual_count=$(grep -c '(cached)' "logs/${test_num}.log")

    if [ "${actual_count}" -ne "${expected_count}" ]; then
        error "[${test_num}] FAILED: ${failure_desc}. Expected ${expected_count} cached lines, but found ${actual_count}."
        ANY_FAILED=$((ANY_FAILED+1))
    fi
}

# 1. Run with the DRONE_COMMIT_SHA variable set to blank, expected: no cached packages.
# Note: Go will only cache the test results when it's in package list mode, i.e. the "./..." which we use to indicate "run all tests"
echo "[01] DRONE_COMMIT_SHA empty and never run"
run_and_check "01" 0 "First run should not produce cached output" ./...

# 2. Run again with no variables set, should see it cached
echo -e "\n[02] DRONE_COMMIT_SHA empty and run without changes, expect to cache"
run_and_check "02" 3 "Running unchanged should use the cache for all 3 packages" ./...

# 3. Run with DRONE_COMMIT_SHA set to 1, expect 1 cached package
echo -e "\n[03] DRONE_COMMIT_SHA=1, expect cache invalidation for packages using the variable"
export DRONE_COMMIT_SHA=1
run_and_check "03" 1 "Setting an env var should only cache the 1 package that doesn't use it" ./...

# 4. Run with DRONE_COMMIT_SHA set to 1 again, expect 3 cached packages
echo -e "\n[04] DRONE_COMMIT_SHA=1, expect 3 cached packages"
export DRONE_COMMIT_SHA=1
run_and_check "04" 3 "Running with the same env var should cache all 3 packages" ./...

# 5. Does it cache if I list the packages manually?
echo -e "\n[05] DRONE_COMMIT_SHA=1, list the 3 packages manually, expect 3 cached packages"
export DRONE_COMMIT_SHA=1
run_and_check "05" 3 "Listing packages manually should still cache all 3" ./ ./envthroughlibrary/ ./withoutenv

# 6. Single package that is *not the current folder* is cached
echo -e "\n[06] DRONE_COMMIT_SHA=1, list 1 package manually, expect 1 cached package"
export DRONE_COMMIT_SHA=1
run_and_check "06" 1 "Running a single package should cache it" ./withoutenv

# 7. Single package that is the current folder is also cached
echo -e "\n[07] DRONE_COMMIT_SHA=1, list current folder (./) package manually, expect 1 cached package"
export DRONE_COMMIT_SHA=1
run_and_check "07" 1 "Running the current directory as a package should cache it" ./

# 8. No argument
echo -e "\n[08] DRONE_COMMIT_SHA=1, no arguments, nothing cached"
export DRONE_COMMIT_SHA=1
run_and_check "08" 0 "Running 'go test' with no package args should not cache"

# 9. Multiple files
echo -e "\n[09] DRONE_COMMIT_SHA=1, several files from the CLI are not cached"
export DRONE_COMMIT_SHA=1
run_and_check "09" 0 "Running 'go test' with file args should not cache" experiment_test.go file2_test.go

if [ "${ANY_FAILED}" -gt 0 ]; then
  error "Some test failed"
  exit 1
fi

echo -e "\nAll tests passed successfully!"
