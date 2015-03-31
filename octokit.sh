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
# OCTOKIT_SH_JQ_BIN=${OCTOKIT_SH_JQ_BIN}
#   The name of the jq binary, if installed.
# OCTOKIT_SH_VERBOSE=${OCTOKIT_SH_VERBOSE}
#   The debug logging verbosity level.
#   1 for info; 2 for debug; 3 for trace (full curl request/reponse output).

export NAME=$(basename $0)
export VERSION='0.1.0'

ALL_FUNCS=$(awk 'BEGIN {ORS=" "} !/^_/ && /^[a-zA-Z0-9_]+\s*\(\)/ {
    sub(/\(\)$/, "", $1); print $1 }' $0 | sort)
export ALL_FUNCS

export OCTOKIT_SH_URL=${OCTOKIT_SH_URL:-'https://api.github.com'}
export OCTOKIT_SH_ACCEPT=${OCTOKIT_SH_ACCEPT:-'application/vnd.github.v3+json'}
export OCTOKIT_SH_JQ_BIN="${OCTOKIT_SH_JQ_BIN:-jq}"
export OCTOKIT_SH_VERBOSE="${OCTOKIT_SH_VERBOSE:-0}"
export OCTOKIT_SH_RATE_LIMIT
export OCTOKIT_SH_RATE_RESET

# Detect if jq is installed.
type "$OCTOKIT_SH_JQ_BIN" 1>/dev/null 2>/dev/null
NO_JQ=$?

# Customizable logging output.
exec 4>/dev/null
exec 5>/dev/null
export LINFO=4
export LDEBUG=5

_log() {
    # A lightweight logging system based on file descriptors
    #
    local level=${1:?Level is required.}
    #   The level for a given log message. (info or debug)
    local message=${2:?Message is required.}
    #   The log message.
    #
    # Usage:
    #   _log debug 'Starting the combobulator!'

    shift 2

    local lname

    case "$level" in
        info) lname='INFO'; level=$LINFO ;;
        debug) lname='DEBUG'; level=$LDEBUG ;;
        *) printf 'Invalid logging level: %s\n' "$level" ;;
    esac

    printf '%s %s: %s\n' "$NAME" "$lname" "$message" 1>&$level
}

_helptext() {
    # Extract contiguous lines of comments and function params as help text
    #
    # Indentation will be ignored. The first line of the match will be ignored
    # (this is to ignore the she-bang of a file or the function name).  Local
    # variable declarations and their default values can also be pulled in as
    # documentation.  Exits upon encountering the first blank line.
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
        sub(/:.*$/, "")
        sub(/=/, " : ")
        sub(/\${/, "$")
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
    #   -v      Enable verbose output; same as `$OCTOKIT_SH_VERBOSE`.
    #   -x      Enable xtrace debug logging.
    #   -r      Print your current GitHub API rate limit to stderr.
    #   -q      Quiet; don't print to stdout.
    #   -j      Output raw JSON; don't process with jq.

    local cmd ret opt OPTARG OPTIND
    local quiet=0 ratelimit=0

    trap '
        excode=$?; trap - EXIT;
        exec 4>&-
        exec 5>&-
        exit
        echo $excode
    ' INT TERM EXIT

    while getopts jqrvVxh opt; do
        case $opt in
        j)  NO_JQ=1;;
        q)  quiet=1;;
        r)  ratelimit=1;;
        v)  OCTOKIT_SH_VERBOSE=$(( $OCTOKIT_SH_VERBOSE + 1 ));;
        V)  printf 'Version: %s\n' $VERSION
            exit;;
        x)  set -x;;
        h)  help
            help _main
            printf '\n'
            exit;;
        esac
    done
    shift $(( $OPTIND - 1 ))

    if [ -z "$1" ] ; then
        help _main 1>&2; printf '\n'
        : ${1:?No command given; see available commands above.}
    fi

    [ $OCTOKIT_SH_VERBOSE -gt 0 ] && exec 4>&2
    [ $OCTOKIT_SH_VERBOSE -gt 1 ] && exec 5>&2
    if [ $quiet -eq 1 ]; then
        exec 1>/dev/null 2>/dev/null
    fi

    # Run the command.
    cmd="$1" && shift
    "$cmd" "$@"
    ret=$?

    if [ $ratelimit -ne 0 ]; then
        printf '\nGitHub rate limit:\t%s remaining requests\t %s seconds to reset\n' \
            "${OCTOKIT_SH_RATE_LIMIT:-Unknown}" "${OCTOKIT_SH_RATE_RESET:-Unkown}"
    fi

    exit $ret
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
    function isnum(x){ return (x == x + 0) }
    function isbool(x){ if (x == "true" || x == "false") return 1 }
    BEGIN {
        printf("{")

        for (name in ENVIRON) {
            val = ENVIRON[name]

            # If not bool or number, quote it.
            if (!isbool(val) && !isnum(val)) {
                gsub(/"/, "\\\"", val)
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
    # A wrapper around making HTTP requests with curl
    #
    # Usage:
    #   request /repos/:owner/:repo/issues
    #   printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #       | request /repos/:owner/:repo/issues | jq -r '.[url]'
    #   printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #       | request /repos/:owner/:repo/issues method=PUT | jq -r '.[url]'
    #
    # Input
    #
    # - (stdin)
    #   Data that will be used as the request body. If present the HTTP request
    #   method used will be 'POST' unless overridden.
    #
    # Positional arguments
    #
    local path=${1:?Path is required.}
    #   The URL path for the HTTP request.
    #   Must be an absolute path that starts with a '/' or a full URL that
    #   starts with http(s). Absolute paths will be append to the value in
    #   $OCTOKIT_SH_URL.
    #
    # Keyword arguments
    #
    # method : GET or POST
    #   The method to use for the HTTP request.
    #   If data is passed to this function via stdin, 'POST' will be used as
    #   the default instead of 'GET'.
    local content_type='application/json'
    #   The value of the Content-Type header to use for the request.
    local follow_next=0
    #   Whether to automatically look for a 'Links' header and follow any
    #   'next' URLs found there.
    local follow_next_limit=50
    #   The maximum number of 'next' URLs to follow before stopping.

    shift 1

    local method cmd arg has_stdin trace_curl

    case $path in
        (http*) : ;;
        *) path="${OCTOKIT_SH_URL}${path}" ;;
    esac

    method='GET'
    [ ! -t 0 ] && method='POST'

    for arg in "$@"; do
        case $arg in
            (method=*) method="${arg#*=}";;
            (follow_next=*) follow_next="${arg#*=}";;
            (follow_next_limit=*) follow_next_limit="${arg#*=}";;
            (content_type=*) content_type="${arg#*=}";;
        esac
    done

    case "$method" in
        POST | PUT | PATCH) has_stdin=1;;
    esac

    [[ $OCTOKIT_SH_VERBOSE -eq 3 ]] && trace_curl=1

    (( $OCTOKIT_SH_VERBOSE )) && set -x
    curl -nsSi \
        -H "Accept: ${OCTOKIT_SH_ACCEPT}" \
        -H "Content-type: ${content_type}" \
        ${has_stdin:+--data-binary @-} \
        ${trace_curl:+--trace-ascii /dev/stderr} \
        -X "${method}" \
        "${path}"
    set +x
}

response() {
    # Process an HTTP response from curl
    #
    # Output only headers of interest. Additional processing is performed on
    # select headers to make them easier to work with in sh. See below.
    #
    # Usage:
    #   request /some/path | response status_code ETag Link_next
    #   curl -isS example.com/some/path | response status_text
    #   curl -IsS example.com/some/path | response status_text
    #
    # Header reformatting
    #
    # HTTP Status
    #   The HTTP line is split into `http_version`, `status_code`, and
    #   `status_text` variables.
    # ETag
    #   The surrounding quotes are removed.
    # Link
    #   Each URL in the Link header is expanded with the URL type appended to
    #   the name. E.g., `Link_first`, `Link_last`, `Link_next`.
    #
    # Positional arguments
    #
    # $1 - $9
    #   Each positional arg is the name of an HTTP header. Each header value is
    #   output in the order requested; each on a single line. A blank line is
    #   output for headers that cannot be found.

    local hdr val http_version status_code status_text headers output

    read -r http_version status_code status_text
    status_text="${status_text%}"
    http_version="${http_version#HTTP/}"

    headers="http_version: ${http_version}
status_code: ${status_code}
status_text: ${status_text}
"
    while IFS=": " read -r hdr val; do
        # Headers stop at the first blank line.
        [ "$hdr" == "" ] && break
        val="${val%}"

        # Process each header; reformat some to work better with sh tools.
        case "$hdr" in
            # Update the GitHub rate limit trackers.
            X-RateLimit-Remaining) OCTOKIT_SH_RATE_LIMIT=$val ;;
            X-RateLimit-Reset)
                curtime=$(PATH=$(getconf PATH) awk 'BEGIN{srand(); print srand()}')
                OCTOKIT_SH_RATE_RESET=$(( $val - $curtime )) ;;

            # Remove quotes from the etag header.
            ETag) val="${val#\"}"; val="${val%\"}" ;;

            # Split the URLs in the Link header into separate pseudo-headers.
            Link) headers="${headers}$(printf '%s' "$val" | awk '
                BEGIN { RS=", "; FS="; "; OFS=": " }
                {
                    sub(/^rel="/, "", $2); sub(/"$/, "", $2)
                    sub(/^</, "", $1); sub(/>$/, "", $1)
                    print "Link_" $2, $1
                }')
"  # need trailing newline
            ;;
        esac

        headers="${headers}${hdr}: ${val}
"  # need trailing newline

    done

    # Output requested headers in deterministic order.
    for arg in "$@"; do
        output=$(printf '%s' "$headers" | while IFS=": " read -r hdr val; do
            [ "$hdr" = "$arg" ] && printf '%s' "$val"
        done)
        printf '%s\n' "$output"
    done

    # Output the response body.
    cat
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
    local org=${1:?Org name required.}
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

    shift 1

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

org_teams() {
    # List teams
    #
    # Usage:
    #   org_teams org
    #
    # Positional arguments
    #
    local org=${1:?Org name required.}
    #   Organization GitHub login or id.
    #
    # Keyword arguments
    #
    local filter='\(.name)\t\(.id)\t\(.permission)'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   team in the return data.

    shift 1

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    request "/orgs/${org}/teams" \
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
    local name=${1:?Repo name required.}
    #   Name of the new repo
    #
    # Keyword arguments
    #
    # description, homepage, private, has_issues, has_wiki, has_downloads,
    # organization, team_id, auto_init, gitignore_template

    shift 1

    local url organization

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

    _format "name=${name}" "$@" | request "$url"
}

list_releases() {
    # List releases for a repository
    #
    # Usage:
    #   list_releases org repo '\(.assets[0].name)\t\(.name.id)'
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local filter='\(.name)\t\(.id)\t\(.html_url)'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release in the return data.

    shift 2

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    request "/repos/${owner}/${repo}/releases" \
        | _filter ".[] | \"${filter}\""
}

release() {
    # Get a release
    #
    # Usage:
    #   release user repo 1087855
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    local release_id=${3:?Release ID required.}
    #   The unique ID of the release; see list_releases.
    #
    # Keyword arguments
    #
    local filter='\(.author.login)\t\(.published_at)'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release in the return data.

    shift 3

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    request "/repos/${owner}/${repo}/releases/${release_id}" \
        | _filter "\"${filter}\""
}

create_release() {
    # Create a release
    #
    # Usage:
    #   create_release org repo v1.2.3
    #   create_release user repo v3.2.1 draft=true
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    local tag_name=${3:?Tag name required.}
    #   Git tag from which to create release.
    #
    # Keyword arguments
    #
    # body, draft, name, prerelease, target_commitish

    shift 3

    _format "tag_name=${tag_name}" "$@" \
        | request "/repos/${owner}/${repo}/releases"
}

delete_release() {
    # Delete a release
    #
    # Usage:
    #   delete_release org repo 1087855
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    local release_id=${3:?Release ID required.}
    #   The unique ID of the release; see list_releases.

    shift 3

    request "/repos/${owner}/${repo}/releases/${release_id}" method=DELETE
}

release_assets() {
    # List release assets
    #
    # Usage:
    #   release_assets user repo 1087855
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    local release_id=${3:?Release ID required.}
    #   The unique ID of the release; see list_releases.

    shift 3

    request "/repos/${owner}/${repo}/releases/${release_id}/assets"
}

_main "$@"
