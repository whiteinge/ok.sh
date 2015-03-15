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
#   -j      Output raw JSON; don't process with jq.
#               (Default if jq is not installed).
#
# Available environment vars:
#
# OCTOKIT_SH_URL=${OCTOKIT_SH_URL}
#   Base URL for GitHub or GitHub Enterprise.
# OCTOKIT_SH_ACCEPT=${OCTOKIT_SH_ACCEPT}
#   The 'Accept' header to send with each request.
# OCTOKIT_SH_NEXT=${OCTOKIT_SH_NEXT}
#   Instructs ${NAME} to automatically follow 'next' links from the 'Links'
#   header by making additional HTTP requests.
# OCTOKIT_SH_NEXT_MAX=${OCTOKIT_SH_NEXT_MAX}
#   The maximum number of 'next' links to follow at one time.
# OCTOKIT_SH_JQ_BIN=${OCTOKIT_SH_JQ_BIN}
#   The name of the jq binary, if installed.
#
# Requirements:
#
# * A POSIX environment (tested against Busybox v1.19.4)
# * curl (tested against 7.32.0)
#
# Optional requirements:
#
# * jq <http://stedolan.github.io/jq/> (tested against 1.3)
#   If jq is not installed commands will output raw JSON; if jq is installed
#   commands can be pretty-printed for use with other shell tools.
#
# Setup
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
export OCTOKIT_SH_ACCEPT='application/vnd.github.v3+json'
export OCTOKIT_SH_NEXT=${OCTOKIT_SH_NEXT:-0}
export OCTOKIT_SH_NEXT_MAX=${OCTOKIT_SH_NEXT_MAX:-100}
export OCTOKIT_SH_RATELIMIT=0
export OCTOKIT_SH_JQ_BIN="${OCTOKIT_SH_JQ_BIN:-jq}"

# Detect if jq is installed.
type "$OCTOKIT_SH_JQ_BIN" 1>/dev/null 2>/dev/null
NO_JQ=$?

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

    while getopts l:jqrvVdh opt; do
        case $opt in
        j)  NO_JQ=1;;
        q)  quiet=1;;
        r)  OCTOKIT_SH_RATELIMIT=1;;
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

_filter() {
    # Filter JSON input using jq; outputs raw JSON if jq is not installed
    #
    # - (stdin)
    #   JSON input.
    # filter
    #   A string of jq filters to apply to the input stream.

    local filter="$1"

    if [ $NO_JQ -ne 0 ] ; then
        cat
        return
    fi

    "${OCTOKIT_SH_JQ_BIN}" -c -r "${filter}"
}

request() {
    # Return JSON from one or more HTTP calls
    #
    # - (stdin)
    #   JSON data to send as the request body.
    # o_path : /
    #   The URL path for the HTTP request.
    # o_method : GET
    #   The HTTP method to send in the request.
    #
    # Usage:
    #   request /repos/:owner/:repo/issues
    #   request /repos/:owner/:repo/issues GET
    #   printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #       | request /repos/:owner/:repo/issues POST | jq -r '.[url]'

    awk \
        -v o_path="${1:-/}" \
        -v o_method="${2:-GET}" \
    '
    function _log(level, message) {
        # Output log messages to the logging fds of the parent script.

        if (level == "ratelimit") log_file = 2
        if (level == "error") log_file = 2
        if (level == "info")  log_file = ENVIRON["LINFO"]
        if (level == "debug") log_file = ENVIRON["LDEBUG"]

        printf("%s %s: %s\n", ENVIRON["NAME"], toupper(level), message) \
            | "cat 1>&" log_file
    }

    function check_status(response_code, response_text) {
        # Exit early on failure response codes.

        if (substr(response_code, 1, 1) == 2) level = "info"
        else level = "error"

        _log(level, "Response code " response_code " " response_text)

        if (substr(response_code, 1, 1) == 2) return
        else if (substr(response_code, 1, 1) == 4) exit 4
        else if (substr(response_code, 1, 1) == 5) exit 5
        else exit 1
    }

    function show_rate_limit(rate_limit) {
        # Output the GitHub rate limit from the last HTTP response.

        if (ENVIRON["OCTOKIT_SH_RATELIMIT"])
            _log("ratelimit", "Remaining GitHub requests: " rate_limit)
    }

    function get_next(link_hdr) {
        # Process the Link header into a map.
        # Return a "next" link if there is one.

        split(link_hdr, links, ", ")

        for (i in links) {
            sub(/</, "", links[i])
            sub(/>;/, "", links[i])
            sub(/rel="/, "", links[i])
            sub(/"/, "", links[i])
            split(links[i], a, " ")
            links[a[2]] = a[1]
        }

        if ("next" in links) return links["next"]
    }

    function req(o_method, url) {
        # Separate status from headers from body.

        cmd = sprintf("curl -nsSi -H \"Accept: %s\" -X %s \"%s\"",
            ENVIRON["OCTOKIT_SH_ACCEPT"],
            o_method,
            url)

        _log("info", "Executing: " cmd)

        response_code=""
        is_headers = 1
        split("", headers, ":")  # initialize headers array
        while((cmd | getline line) > 0) {
            sub(/\r$/, "", line)
            if (line == "") {
                is_headers = 0
                continue
            }

            if (!response_code) {
                idx = index(line, " ")
                response_code = substr(line, idx + 1, 3)
                response_text = substr(line, idx + 5)

                check_status(response_code, response_text)
                continue
            }

            if (is_headers) {
                idx = index(line, ": ")
                headers[substr(line, 0, idx - 1)] = substr(line, idx + 2)
                continue
            }

            # Output body
            print line
        }

        close(cmd)

        if ("X-RateLimit-Remaining" in headers)
            show_rate_limit(headers["X-RateLimit-Remaining"])

        if ("Link" in headers)
            return get_next(headers["Link"])
    }

    BEGIN {
        follow_next = ENVIRON["OCTOKIT_SH_NEXT"]
        follow_next_limit = ENVIRON["OCTOKIT_SH_NEXT_MAX"]
        next_url = req(o_method, ENVIRON["OCTOKIT_SH_URL"] "/" o_path)

        do {
            next_url = req(o_method, next_url)
            follow_next_limit -= 1
            _log("debug", "Following \"next\" links: " follow_next_limit)
        } while(follow_next && follow_next_limit > 0 && next_url)
    }
    '
}

_main "$@"
