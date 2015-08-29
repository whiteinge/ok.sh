#!/usr/bin/env sh

FAILED_TESTS=0
unit_tests="./unit.sh"

_main() {
    unit_tests
    exit $FAILED_TESTS
}

run_tests() {
    # Find all the test functions in a file and run each one
    #
    local fname="${1?:File name is required.}"
    #   The file containing the tests to run.

    local funcs="$(awk '/^test_[a-zA-Z0-9_]+\s*\(\)/ {
        sub(/\(\)$/, "", $1); print $1 }' "$fname")"

    for func in $funcs; do
        "$fname" "$func"
        [ $? -ne 0 ] && FAILED_TESTS=$(( $FAILED_TESTS + 1 ));
    done
}

unit_tests() {
    run_tests "./unit.sh"
}
_main "$@"
