# tests/assert.sh - a tiny test helper. Source it from a test file.
#
#   assert_eq EXPECTED ACTUAL DESCRIPTION
#   assert_status EXPECTED_STATUS DESCRIPTION -- COMMAND [ARGS...]
#   test_summary           # prints totals; exit status 1 if anything failed

_TESTS_RUN=0
_TESTS_FAILED=0

assert_eq() {
    local expected=$1 actual=$2 description=$3
    _TESTS_RUN=$(( _TESTS_RUN + 1 ))
    if [[ $expected == "$actual" ]]; then
        printf '  ok    %s\n' "$description"
    else
        _TESTS_FAILED=$(( _TESTS_FAILED + 1 ))
        printf '  FAIL  %s\n        expected: [%s]\n        actual:   [%s]\n' \
            "$description" "$expected" "$actual"
    fi
}

assert_status() {
    local expected=$1 description=$2 status=0
    shift 2
    [[ ${1-} == -- ]] && shift
    "$@" 2>/dev/null || status=$?
    assert_eq "$expected" "$status" "$description (exit status)"
}

test_summary() {
    printf '%d tests, %d failed\n' "$_TESTS_RUN" "$_TESTS_FAILED"
    (( _TESTS_FAILED == 0 ))
}
