#!/usr/bin/env sh
# A GitHub API client library written in POSIX sh
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
#
# Configuration
#
# The following environment variables may be set to customize ${NAME}.
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

export NAME=$(basename $0)
export VERSION='0.1.0'

ALL_FUNCS=$(awk 'BEGIN {ORS=" "} !/^_/ && /^[a-zA-Z0-9_]+\s*\(\)/ {
    sub(/\(\)$/, "", $1); print $1 }' $0 | sort)
export ALL_FUNCS

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

E_INVALID_FLAG=70
E_NO_COMMAND=71
E_COMMAND_NOT_FOUND=73
E_INVALID_ARGS=74

_err() {
    # Print error message to stderr and exit
    #
    # Usage:
    #   _err 'Oh noes!' E_SOME_ERROR
    #
    local msg="$1"
    #   Error message.
    local code="$2"
    #   Exit code.

    printf '%s\n' "$msg" 1>&2
    exit $(( $code ))
}

_helptext() {
    # Extract contiguous lines of comments and function params as help text
    #
    # Indentation will be ignored. The first line of the match will be ignored
    # (this is to ignore the she-bang of a file or the function name).
    # Local variable declarations and their default values can also be pulled
    # in as documentation.
    # Exits upon encountering the first blank line.
    #
    # Exported environment variables can be used for string interpolation in
    # the extracted commented text.
    #
    # - (stdin)
    #   The text of a function body to parse.
    # $1
    #   A file name to parse.

    awk 'NR != 1 && /^\s*#/ {
        line=$0
        while(match(line, "[$]{[^}]*}")) {
            var=substr(line, RSTART+2, RLENGTH -3)
            gsub("[$]{"var"}", ENVIRON[var], line)
        }
        gsub(/^\s*#\s?/, "", line)
        print line
    }
    /^\s*local/ {
        sub(/^\s*local /, "")
        sub(/=/, " : ")
        print
    }
    !NF { exit }' "$@"
}

help() {
    # Output the help text for a command
    #
    # Usage:
    #   help commandname
    #
    # $1
    #   Function name to search for; if omitted searches whole file.

    if [ $# -gt 0 ]; then
        awk -v fname="^$1" '$0 ~ fname, /^}/ { print }' $0 | _helptext
    else
        _helptext $0
        printf '\n'
        help _main
    fi
}

_main() {
    # Available commands: ${ALL_FUNCS}
    #
    # Usage: ${NAME} [<options>] command [<name=value>]
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

    while getopts jqrvVdh opt; do
        case $opt in
        j)  NO_JQ=1;;
        q)  quiet=1;;
        r)  OCTOKIT_SH_RATELIMIT=1;;
        v)  verbose=$(( $verbose + 1 ));;
        V)  printf 'Version: %s\n' $VERSION
            exit;;
        d)  set -x;;
        h)  help
            help _main
            printf '\n'
            exit;;
        \?) help _main
            _err 'Invalid flag.' E_INVALID_FLAG;;
        esac
    done
    shift $(( $OPTIND - 1 ))

    if [ -z "$1" ] ; then
        help _main 1>&2; printf '\n'
        _err 'No command given.' E_NO_COMMAND
    fi

    [ $verbose -gt 0 ] && exec 4>&2
    [ $verbose -gt 1 ] && exec 5>&2
    if [ $quiet -eq 1 ]; then
        exec 1>/dev/null 2>/dev/null
    fi

    # Run the command.
    local cmd="$1" && shift
    "$cmd" "$@"

    case $? in
    0)      :
            ;;
    127)    help _main; printf '\n'
            _err 'Command not found.' E_COMMAND_NOT_FOUND;;
    *)      exit $?;;
    esac
}

_format() {
    # Create formatted JSON from name=value pairs
    #
    # Tries not to quote numbers and booleans. If jq is installed it will also
    # validate the output.
    #
    # Usage:
    #   _format foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
    # string'
    #
    # Return:
    #   {"bar":123,"qux":"Qux=Qux","foo":"Foo","quux":"Multi-line\nstring","baz":true}

    env -i "$@" awk '
    BEGIN {
        bools["true"] = 1; bools["false"] = 1;
        printf("{")

        for (name in ENVIRON) {
            val = ENVIRON[name]

            # If not bool or number, quote it.
            if ((!(val in bools)) && match(val, /[0-9.-]+/) != 1) {
                val = "\"" val "\""
            }

            printf("%s\"%s\": %s", sep, name, val)
            sep = ", "
        }

        printf("}\n")
    }
    ' | _filter
}

_filter() {
    # Filter JSON input using jq; outputs raw JSON if jq is not installed
    #
    # - (stdin)
    #   JSON input.
    local filter="$1"
    #   A string of jq filters to apply to the input stream.

    if [ $NO_JQ -ne 0 ] ; then
        cat
        return
    fi

    "${OCTOKIT_SH_JQ_BIN}" -c -r "${filter}"
}

request() {
    # Return JSON from one or more HTTP calls
    #
    # Usage:
    #   request /repos/:owner/:repo/issues
    #   request /repos/:owner/:repo/issues GET
    #   printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #       | request /repos/:owner/:repo/issues POST | jq -r '.[url]'
    #
    # - (stdin)
    #   JSON data to send as the request body.
    # o_path : /
    #   The URL path for the HTTP request.
    # o_method : GET
    #   The HTTP method to send in the request.

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

    function req(o_method, url, body) {
        # Separate status from headers from body.

        curl = "curl -nsSi -H \"Accept: %s\" -X %s \"%s\""

        if (body) {
            curl = "printf '\''" body "'\'' | " \
                curl " -H \"Content-type: application/json\" --data-binary @-"
        }

        cmd = sprintf(curl,
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

        if (o_method == "POST" || o_method == "PUT") {
            while((getline line) > 0) {
                body = body line "\n"
            }
        }

        follow_next = ENVIRON["OCTOKIT_SH_NEXT"]
        follow_next_limit = ENVIRON["OCTOKIT_SH_NEXT_MAX"]
        next_url = req(o_method, ENVIRON["OCTOKIT_SH_URL"] o_path, body)

        do {
            next_url = req(o_method, next_url)
            follow_next_limit -= 1
            _log("debug", "Following \"next\" links: " follow_next_limit)
        } while(follow_next && follow_next_limit > 0 && next_url)
    }
    '
}

org_repos() {
    # List organization repositories
    #
    # Usage:
    #   org_repos myorg
    #   org_repos myorg type=private per_page=10
    #   org_repos myorg filter='\(.name)\t\(.ssh_url)\t\(.owner.login)'
    #
    # Positional arguments
    #
    local org=$1
    #   Organization GitHub login or id for which to list repos.
    #
    # Keyword arguments
    #
    local type=all
    #   Filter by repository type. all, public, member, sources, forks, or
    #   private.
    local per_page=100
    #   The number of repositories to return in each single request.
    local filter='\(.name)\t\(.ssh_url)'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   repository in the return data.

    [ -n "$org" ] && shift || _err 'Org name required.' E_INVALID_ARGS

    for arg in "$@"; do
        case $arg in
            (type=*) type="${arg#*=}";;
            (per_page=*) per_page="${arg#*=}";;
            (filter=*) filter="${arg#*=}";;
        esac
    done

    request "/orgs/${org}/repos?type=${type}&per_page=${per_page}" \
        | _filter ".[] | \"${filter}\""
}

create_repo() {
    # Create a repository for a user or organization
    #
    # Usage:
    #   create_repo foo
    #   create_repo bar description='Stuff and things' homepage='example.com'
    #   create_repo baz organization=myorg
    #
    # Positional arguments
    #
    local name=$1
    #   Name of the new repo
    #
    # Keyword arguments
    #
    # description, homepage, private, has_issues, has_wiki, has_downloads,
    # organization, team_id, auto_init, gitignore_template

    local url organization

    [ -n "$name" ] && shift || _err 'Repo name required.' E_INVALID_ARGS

    for arg in "$@"; do
        case $arg in
            (organization=*) organization="${arg#*=}";;
        esac
    done

    if [ -n "$organization" ] ; then
        url="/orgs/${organization}/repos"
    else
        url='/user/repos'
    fi

    _format "name=${name}" "$@" | request "$url" POST
}

_main "$@"
