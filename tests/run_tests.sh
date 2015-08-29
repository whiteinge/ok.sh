#!/usr/bin/env sh

FAILED_TESTS=0

_main() {
    local socat_pid

    printf 'Running unit tests.\n'
    run_tests "./unit.sh"


    socat tcp-l:8011,crlf,reuseaddr,fork EXEC:./mockhttpd/mockhttpd.sh &
    socat_pid=$!

    trap '
        excode=$?; trap - EXIT;
        kill '"$socat_pid"'
        exit $excode
    ' INT TERM EXIT


    printf 'Running integration tests.\n'
    run_tests "./integration.sh"

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

_main "$@"
