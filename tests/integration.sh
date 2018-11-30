#!/usr/bin/env sh
# Integration tests for the ok.sh script.

SCRIPT='../ok.sh'
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

test_pagination_follow() {
    local outx out expected

    outx=$($SCRIPT _get /test_pagination | tr -d "\r"; echo x)
    out="${outx%x}"

    expected='Current page: 1
Current page: 2
Current page: 3
Current page: 4
'

    if [ "$out" = "$expected" ]; then
        return 0
    else
        printf 'Bad pagination output. Got "%s"; expected "%s"\n' "$out" "$expected"
        return 1
    fi
}

test_pagination_follow_subset() {
    local outx out expected

    outx=$($SCRIPT _get '/test_pagination?page=3' | tr -d "\r"; echo x)
    out="${outx%x}"

    expected='Current page: 3
Current page: 4
'

    if [ "$out" = "$expected" ]; then
        return 0
    else
        printf 'Bad pagination output. Got "%s"; expected "%s"\n' "$out" "$expected"
        return 1
    fi
}

test_pagination_nofollow() {
    local outx out expected

    outx=$($SCRIPT _get /test_pagination _follow_next=0 | tr -d "\r"; echo x)
    out="${outx%x}"

    expected='Current page: 1
'

    if [ "$out" = "$expected" ]; then
        return 0
    else
        printf 'Bad pagination output. Got "%s"; expected "%s"\n' "$out" "$expected"
        return 1
    fi
}

test_pagination_follow_limit() {
    local outx out expected

    outx=$($SCRIPT _get /test_pagination _follow_next_limit=1 | tr -d "\r"; echo x)
    out="${outx%x}"

    expected='Current page: 1
Current page: 2
'

    if [ "$out" = "$expected" ]; then
        return 0
    else
        printf 'Bad pagination output. Got "%s"; expected "%s"\n' "$out" "$expected"
        return 1
    fi
}

test_conditional_get() {
    local has_header

    $SCRIPT -vvv _request /ok etag=edd3a0d38d8c329d3ccc6575f17a76bb 2>&1 \
        | grep -q 'If-None-Match: "edd3a0d38d8c329d3ccc6575f17a76bb"'

    has_header=$?

    if [ "$has_header" -eq 0 ]; then
        return 0
    else
        printf 'Missing or malformed If-None-Match header.\n'
        return 1
    fi
}

_main "$@"
