#!/usr/bin/env sh

FAILED_TESTS=0
unit_tests="./unit.sh"

_main() {
    unit_tests
    exit $FAILED_TESTS
}

unit_tests() {
    local funcs="$(awk '/^test_[a-zA-Z0-9_]+\s*\(\)/ {
        sub(/\(\)$/, "", $1); print $1 }' "$unit_tests")"

    for func in $funcs; do
        "$unit_tests" "$func"
        [ $? -ne 0 ] && FAILED_TESTS=$(( $FAILED_TESTS + 1 ));
    done
}

_main "$@"
