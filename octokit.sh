#!/usr/bin/env sh
# A GitHub API client library written in POSIX sh
#
# Available commands: ${ALL_FUNCS}
#
# Usage: ${NAME} [<options>] command [<args>]
# Command-specific help: ${NAME} help command
#
# Options:
#   -h      Show this screen.
#   -V      Show version.
#   -v      Enable verbose output; can be specified multiple times.
#   -d      Enable xtrace debug logging.
#   -r      Print your current GitHub API rate limit to stderr.
#   -q      Quiet; don't print to stdout.
#
# Available environment vars:
#
#   OCTOKIT_SH_URL=${OCTOKIT_SH_URL}
#   OCTOKIT_SH_V=${OCTOKIT_SH_V}
#
# Requirements and setup:
#
# * A POSIX environment (tested against Busybox v1.19.4)
# * curl (tested against 7.32.0)
# * jq <http://stedolan.github.io/jq/> (tested against 1.3)
#
# Authentication credentials are read from a ~/.netrc file with the following
# format. Generate the token on GitHub under Account Settings -> Applications.
# Restrict permissions on that file with `chmod 600 ~/.netrc`!
#
#   machine api.github.com
#       login <username>
#       password <token>

export NAME=$(basename $0)
export VERSION='0.1.0'

export ALL_FUNCS=$(awk 'BEGIN {ORS=" "} !/^_/ && /^[a-zA-Z0-9_]+\s*\(\)/ {
    sub(/\(\)$/, "", $1); print $1 }' $0 | sort)

export OCTOKIT_SH_URL=${OCTOKIT_SH_URL:-'https://api.github.com'}
export OCTOKIT_SH_V='Accept: application/vnd.github.v3+json'
export OCTOKIT_SH_RATELIMIT=0

# Customizable logging output.
exec 4>/dev/null
exec 5>/dev/null
export LINFO=4
export LDEBUG=5

E_NO_COMMAND=71
E_COMMAND_NOT_FOUND=73

_helptext() {
    # Extract lines of contiguous comment characters as inline help text
    #
    # Indentation will be ignored. The first line of the match will be ignored
    # (this is to ignore the she-bang of a file or the function name.
    # Exits upon encountering the first blank line.
    #
    # Exported environment variables can be used for string interpolation in
    # the extracted text.

    # FIXME: gensub is not Posix (present in busybox & bsd but not solaris(?))
    awk 'NR != 1 && /^\s*#/ { while(match($0,"[$]{[^}]*}")) {
            var=substr($0,RSTART+2,RLENGTH -3)
            gsub("[$]{"var"}",ENVIRON[var])
            }; print gensub(/^\s*#\s?/, "", $0) }
        !NF { exit }' "$@"
}

help() {
    # Output the help text for a command
    #
    # Usage: ${NAME} help commandname

    if [ $# -gt 0 ]; then
        awk -v fname="^$1" '$0 ~ fname, /^}/ { print }' $0 | _helptext
    else
        _helptext $0
    fi
}

_main() {
    # Parse command line options and call the given command

    local cmd opt OPTARG OPTIND
    local quiet=0
    local verbose=0

    trap '
        excode=$?; trap - EXIT;
        exec 4>&-
        exec 5>&-
        exit
        echo $excode
    ' INT TERM EXIT

    while getopts l:qrvVdh opt; do
        case $opt in
        q)  quiet=1;;
        r)  GH_RATE_LIMIT=1;;
        v)  verbose=$(( $verbose + 1 ));;
        V)  printf 'Version: %s\n' $VERSION
            exit;;
        d)  set -x;;
        h)  help
            printf '\n'
            exit;;
        \?) help
            exit 3;;
        esac
    done
    shift $(($OPTIND - 1))

    if [ -z "$1" ] ; then
        printf 'No command given\n\n'
        help
        exit ${E_NO_COMMAND}
    fi

    [ $verbose -gt 0 ] && exec 4>&2
    [ $verbose -gt 1 ] && exec 5>&2
    if [ $quiet -eq 1 ]; then
        exec 1>/dev/null 2>/dev/null
    fi

    # Run the command.
    local cmd="${1}" && shift
    ${cmd} "$@"

    case $? in
    0)      :
            ;;
    127)    help
            exit $(( E_COMMAND_NOT_FOUND ));;
    *)      exit $?;;
    esac

}

_main "$@"
