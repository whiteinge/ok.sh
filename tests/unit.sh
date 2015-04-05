#!/usr/bin/env sh
# Unit tests for the octokit.sh script.

abs_path=$(dirname $0)
SCRIPT="${abs_path}/../octokit.sh"

_main() {
    local cmd ret

    cmd="$1" && shift
    "$cmd" "$@"
    ret=$?

    [ $ret -eq 0 ] || printf 'Fail: %s\n' "$cmd" 1>&2
    exit $ret
}

_main "$@"
