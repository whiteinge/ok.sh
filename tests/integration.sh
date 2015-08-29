#!/usr/bin/env sh
# Integration tests for the ok.sh script.

SCRIPT='ok.sh'
export OK_SH_URL='localhost:8011'

_main() {
    local cmd ret

    cmd="$1" && shift
    "$cmd" "$@"
    ret=$?

    [ $ret -eq 0 ] || printf 'Fail: %s\n' "$cmd" 1>&2
    exit $ret
}

test_get_404() {
    $SCRIPT _get /path/does/not/exist 2>/dev/null
    local ret=$?

    if [ "$ret" -eq 1 ]; then
        return 0
    else
        printf 'Return code for 404 is "%s"; expected 1.\n' "$ret"
        return 1
    fi
}

test_get_500() {
    $SCRIPT _get /test_error 2>/dev/null
    local ret=$?

    if [ "$ret" -eq 1 ]; then
        return 0
    else
        printf 'Return code for 500 is "%s"; expected 1.\n' "$ret"
        return 1
    fi
}

_main "$@"
