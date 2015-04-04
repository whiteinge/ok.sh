#!/usr/bin/env sh
# A GitHub API client library written in POSIX sh
#
# Requirements
#
# * A POSIX environment (tested against Busybox v1.19.4)
# * curl (tested against 7.32.0)
#
# Optional requirements
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
#     machine api.github.com
#         login <username>
#         password <token>
#
# Configuration
#
# The following environment variables may be set to customize ${NAME}.
#
# * OCTOKIT_SH_URL=${OCTOKIT_SH_URL}
#   Base URL for GitHub or GitHub Enterprise.
# * OCTOKIT_SH_ACCEPT=${OCTOKIT_SH_ACCEPT}
#   The 'Accept' header to send with each request.
# * OCTOKIT_SH_JQ_BIN=${OCTOKIT_SH_JQ_BIN}
#   The name of the jq binary, if installed.
# * OCTOKIT_SH_VERBOSE=${OCTOKIT_SH_VERBOSE}
#   The debug logging verbosity level. Same as the verbose flag.
# * OCTOKIT_SH_RATE_LIMIT=${OCTOKIT_SH_RATE_LIMIT}
#   Output current GitHub rate limit information to stderr.

export NAME=$(basename $0)
export VERSION='0.1.0'

ALL_FUNCS=$(awk 'BEGIN {ORS=" "} !/^_/ && /^[a-zA-Z0-9_]+\s*\(\)/ {
    sub(/\(\)$/, "", $1); print $1 }' $0 | sort)
export ALL_FUNCS

export OCTOKIT_SH_URL=${OCTOKIT_SH_URL:-'https://api.github.com'}
export OCTOKIT_SH_ACCEPT=${OCTOKIT_SH_ACCEPT:-'application/vnd.github.v3+json'}
export OCTOKIT_SH_JQ_BIN="${OCTOKIT_SH_JQ_BIN:-jq}"
export OCTOKIT_SH_VERBOSE="${OCTOKIT_SH_VERBOSE:-0}"
export OCTOKIT_SH_RATE_LIMIT="${OCTOKIT_SH_RATE_LIMIT:-0}"

# Detect if jq is installed.
type "$OCTOKIT_SH_JQ_BIN" 1>/dev/null 2>/dev/null
NO_JQ=$?

# Customizable logging output.
exec 4>/dev/null
exec 5>/dev/null
exec 6>/dev/null
export LINFO=4      # Info-level log messages.
export LDEBUG=5     # Debug-level log messages.
export LSUMMARY=6   # Summary output.

_log() {
    # A lightweight logging system based on file descriptors
    #
    # Usage:
    #
    #     _log debug 'Starting the combobulator!'
    #
    # Positional arguments
    #
    local level=${1:?Level is required.}
    #   The level for a given log message. (info or debug)
    local message=${2:?Message is required.}
    #   The log message.

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
    # (this is to ignore the she-bang of a file or the function name). Local
    # variable declarations and their default values can also be pulled in as
    # documentation. Exits upon encountering the first blank line.
    #
    # Exported environment variables can be used for string interpolation in
    # the extracted commented text.
    #
    # Input
    #
    # * (stdin)
    #   The text of a function body to parse.
    #
    # Positional arguments
    #
    local name=$1
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
        sub(/^\s*local /, "* ")
        sub(/:.*$/, "")
        sub(/=/, " : ")
        sub(/\${/, "$")
        print
    }
    !NF { exit }' "$name"
}

help() {
    # Output the help text for a command
    #
    # Usage:
    #
    #     help commandname
    #
    # Positional arguments
    #
    local fname=$1
    #   Function name to search for; if omitted searches whole file.

    if [ $# -gt 0 ]; then
        awk -v fname="^$fname" '$0 ~ fname, /^}/ { print }' $0 | _helptext
    else
        _helptext $0
        printf '\n'
        help _main
    fi
}

_main() {
    # Available commands: ${ALL_FUNCS}
    #
    # Usage: `${NAME} [<options>] command [<name=value>]`
    # Command-specific help: `${NAME} help command`
    #
    # Flag | Description
    # ---- | -----------
    # -h   | Show this screen.
    # -V   | Show version.
    # -v   | Logging output; specify multiple times: info, debug, trace.
    # -x   | Enable xtrace debug logging.
    # -r   | Print current GitHub API rate limit to stderr.
    # -q   | Quiet; don't print to stdout.
    # -j   | Output raw JSON; don't process with jq.

    local cmd ret opt OPTARG OPTIND
    local quiet=0
    local temp_dir="/tmp/oksh-${RANDOM}-${$}"
    local summary_fifo="${temp_dir}/oksh_summary.fifo"

    trap '
        excode=$?; trap - EXIT;
        exec 4>&-
        exec 5>&-
        exec 6>&-
        rm -rf '"$temp_dir"'
        exit
        echo $excode
    ' INT TERM EXIT

    while getopts jqrvVxh opt; do
        case $opt in
        j)  NO_JQ=1;;
        q)  quiet=1;;
        r)  OCTOKIT_SH_RATE_LIMIT=1;;
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

    if (( $OCTOKIT_SH_RATE_LIMIT )) ; then
        mkdir -m 700 "$temp_dir" || {
            printf 'failed to create temp_dir\n' >&2; exit 1;
        }
        mkfifo "$summary_fifo"
        # Hold the fifo open so it will buffer input until emptied.
        exec 6<>$summary_fifo
    fi

    # Run the command.
    cmd="$1" && shift
    _log debug "Running command ${cmd}."
    "$cmd" "$@"
    ret=$?
    _log debug "Command ${cmd} exited with ${?}."

    # Output any summary messages.
    if (( $OCTOKIT_SH_RATE_LIMIT )) ; then
        cat "$summary_fifo" 1>&2 &
        exec 6>&-
    fi

    exit $ret
}

_format() {
    # Create formatted JSON from name=value pairs
    #
    # Usage:
    # ```
    # _format foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
    # string'
    # ```
    #
    # Return:
    # ```
    # {"bar":123,"qux":"Qux=Qux","foo":"Foo","quux":"Multi-line\nstring","baz":true}
    # ```
    #
    # Tries not to quote numbers and booleans. If jq is installed it will also
    # validate the output.
    #
    # Positional arguments
    #
    # * $1 - $9
    #   Each positional arg must be in the format of `name=value` which will be
    #   added to a single, flat JSON object.

    _log debug "Formatting ${#} parameters as JSON."

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
    # Usage:
    #
    #     _filter '.[] | "\(.foo)"' < something.json
    #
    # * (stdin)
    #   JSON input.
    local filter=$1
    #   A string of jq filters to apply to the input stream.

    _log debug 'Filtering JSON.'

    if [ $NO_JQ -ne 0 ] ; then
        cat
        return
    fi

    "${OCTOKIT_SH_JQ_BIN}" -c -r "${filter}"
    [ $? -eq 0 ] || printf 'jq parse error; invalid JSON.\n' 1>&2
}

request() {
    # A wrapper around making HTTP requests with curl
    #
    # Usage:
    # ```
    # request /repos/:owner/:repo/issues
    # printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #   | request /repos/:owner/:repo/issues | jq -r '.[url]'
    # printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #   | request /repos/:owner/:repo/issues method=PUT | jq -r '.[url]'
    # ```
    #
    # Input
    #
    # * (stdin)
    #   Data that will be used as the request body.
    #
    # Positional arguments
    #
    local path=${1:?Path is required.}
    #   The URL path for the HTTP request.
    #   Must be an absolute path that starts with a `/` or a full URL that
    #   starts with http(s). Absolute paths will be append to the value in
    #   `$OCTOKIT_SH_URL`.
    #
    # Keyword arguments
    #
    local method='GET'
    #   The method to use for the HTTP request.
    local content_type='application/json'
    #   The value of the Content-Type header to use for the request.

    shift 1

    local cmd arg has_stdin trace_curl

    case $path in
        (http*) : ;;
        *) path="${OCTOKIT_SH_URL}${path}" ;;
    esac

    for arg in "$@"; do
        case $arg in
            (method=*) method="${arg#*=}";;
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
        -H "Content-Type: ${content_type}" \
        ${has_stdin:+--data-binary @-} \
        ${trace_curl:+--trace-ascii /dev/stderr} \
        -X "${method}" \
        "${path}"
    set +x
}

response() {
    # Process an HTTP response from curl
    #
    # Output only headers of interest followed by the response body. Additional
    # processing is performed on select headers to make them easier to work
    # with in sh. See below.
    #
    # Usage:
    # ```
    # request /some/path | response status_code ETag Link_next
    # curl -isS example.com/some/path | response status_code status_text | {
    #   local status_code status_text
    #   read -r status_code
    #   read -r status_text
    # }
    # ```
    #
    # Header reformatting
    #
    # * HTTP Status
    #   The HTTP line is split into `http_version`, `status_code`, and
    #   `status_text` variables.
    # * ETag
    #   The surrounding quotes are removed.
    # * Link
    #   Each URL in the Link header is expanded with the URL type appended to
    #   the name. E.g., `Link_first`, `Link_last`, `Link_next`.
    #
    # Positional arguments
    #
    # * $1 - $9
    #   Each positional arg is the name of an HTTP header. Each header value is
    #   output in the same order as each argument; each on a single line. A
    #   blank line is output for headers that cannot be found.

    local hdr val http_version status_code status_text headers output

    _log debug 'Processing response.'

    read -r http_version status_code status_text
    status_text="${status_text%}"
    http_version="${http_version#HTTP/}"

    _log debug "Response status is: ${status_code} ${status_text}"

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
            X-RateLimit-Remaining)
                printf 'GitHub remaining requests: %s\n' "$val" 1>&$LSUMMARY ;;
            X-RateLimit-Reset)
                awk -v gh_reset="$val" 'BEGIN {
                    srand(); curtime = srand()
                    print "GitHub seconds to reset: " gh_reset - curtime
                }' 1>&$LSUMMARY ;;

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
        _log debug "Outputting requested header '${arg}'."
        output=$(printf '%s' "$headers" | while IFS=": " read -r hdr val; do
            [ "$hdr" = "$arg" ] && printf '%s' "$val"
        done)
        printf '%s\n' "$output"
    done

    # Output the response body.
    cat
}

get() {
    # A wrapper around request() for common GET patterns
    #
    # Will automatically follow 'next' pagination URLs in the Link header.
    #
    # Usage:
    #
    #     get /some/path
    #     get /some/path follow_next=0
    #     get /some/path follow_next_limit=200 | jq -c .
    #
    # Positional arguments
    #
    local path=${1:?Path is required.}
    #   The HTTP path or URL to pass to request().
    #
    # Keyword arguments
    #
    local follow_next=1
    #   Whether to automatically look for a 'Links' header and follow any
    #   'next' URLs found there.
    local follow_next_limit=50
    #   The maximum number of 'next' URLs to follow before stopping.

    shift 1

    local status_code status_text next_url

    for arg in "$@"; do
        case $arg in
            (follow_next=*) follow_next="${arg#*=}";;
            (follow_next_limit=*) follow_next_limit="${arg#*=}";;
        esac
    done

    request "$path" | response status_code status_text Link_next | {
        read -r status_code
        read -r status_text
        read -r next_url

        case "$status_code" in
            20*) : ;;
            4*) printf 'Client Error: %s %s\n' \
                "$status_code" "$status_text" 1>&2; exit 1 ;;
            5*) printf 'Server Error: %s %s\n' \
                "$status_code" "$status_text" 1>&2; exit 1 ;;
        esac

        # Output response body.
        cat

        (( $follow_next )) || return

        _log info "Remaining next link follows: ${follow_next_limit}"
        if [ -n "$next_url" ] && [ $follow_next_limit -gt 0 ] ; then
            follow_next_limit=$(( $follow_next_limit - 1 ))

            get "$next_url" "follow_next_limit=${follow_next_limit}"
        fi
    }
}

_get_mime_type() {
    # Guess the mime type for a file based on the file extension
    #
    # Usage:
    #
    #     local mime_type
    #     _get_mime_type "foo.tar"; printf 'mime is: %s' "$mime_type"
    #
    # Sets the global variable `mime_type` with the result. (If this function
    # is called from within a function that has declared a local variable of
    # that name it will update the local copy and not set a global.)
    #
    # Positional arguments
    #
    local filename=${1:?Filename is required.}
    #   The full name of the file, with exension.

    local ext="${filename#*.}"

    # Taken from Apache's mime.types file (public domain).
    case "$ext" in
        bz2) mime_type=application/x-bzip2 ;;
        exe) mime_type=application/x-msdownload ;;
        gz | tgz) mime_type=application/x-gzip ;;
        jpg | jpeg | jpe | jfif) mime_type=image/jpeg ;;
        json) mime_type=application/json ;;
        pdf) mime_type=application/pdf ;;
        png) mime_type=image/png ;;
        rpm) mime_type=application/x-rpm ;;
        svg | svgz) mime_type=image/svg+xml ;;
        tar) mime_type=application/x-tar ;;
        yaml) mime_type=application/x-yaml ;;
        zip) mime_type=application/zip ;;
    esac

    _log debug "Guessed mime type of '${mime_type}' for '${filename}'."
}

post() {
    # A wrapper around request() for commoon POST / PUT patterns
    #
    # Usage:
    #
    #     _format foo=Foo bar=Bar | post /some/path
    #     _format foo=Foo bar=Bar | post /some/path method='PUT'
    #     post /some/path filename=somearchive.tar
    #     post /some/path filename=somearchive.tar mime_type=application/x-tar
    #     post /some/path filename=somearchive.tar \
    #       mime_type=$(file -b --mime-type somearchive.tar)
    #
    # Input
    #
    # * (stdin)
    #   Optional. See the `filename` argument also.
    #   Data that will be used as the request body.
    #
    # Positional arguments
    #
    local path=${1:?Path is required.}
    #   The HTTP path or URL to pass to request().
    #
    # Keyword arguments
    #
    local method='POST'
    #   The method to use for the HTTP request.
    local filename
    #   Optional. See the `stdin` option above also.
    #   Takes precedence over any data passed as stdin and loads a file off the
    #   file system to serve as the request body.
    local mime_type
    #   The value of the Content-Type header to use for the request.
    #   If the `filename` argument is given this value will be guessed from the
    #   file extension. If the `filename` argument is not given (i.e., using
    #   stdin) this value defaults to `application/json`. Specifying this
    #   argument overrides all other defaults or guesses.

    shift 1

    for arg in "$@"; do
        case $arg in
            (method=*) method="${arg#*=}";;
            (filename=*) filename="${arg#*=}";;
            (mime_type=*) mime_type="${arg#*=}";;
        esac
    done

    # Make either the file or stdin available as fd7.
    if [ -n "$filename" ] ; then
        if [ -r "$filename" ] ; then
            _log debug "Using '${filename}' as POST data."
            [ -n "$mime_type" ] || _get_mime_type "$filename"
            : ${mime_type:?The MIME type could not be guessed.}
            exec 7<"$filename"
        else
            printf 'File could not be found or read.\n' 1>&2
            exit 1
        fi
    else
        _log debug "Using stdin as POST data."
        mime_type='application/json'
        exec 7<&0
    fi

    request "$path" method="$method" content_type="$mime_type" 0<&7 \
            | response status_code status_text \
            | {
        read -r status_code
        read -r status_text

        case "$status_code" in
            20*) : ;;
            4*) printf 'Client Error: %s %s\n' \
                "$status_code" "$status_text" 1>&2; exit 1 ;;
            5*) printf 'Server Error: %s %s\n' \
                "$status_code" "$status_text" 1>&2; exit 1 ;;
        esac

        # Output response body.
        cat
    }
}

org_repos() {
    # List organization repositories
    #
    # Usage:
    #
    #     org_repos myorg
    #     org_repos myorg type=private per_page=10
    #     org_repos myorg filter='.[] | "\(.name)\t\(.owner.login)"'
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
    local filter='.[] | "\(.name)\t\(.ssh_url)"'
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

    get "/orgs/${org}/repos?type=${type}&per_page=${per_page}" \
        | _filter "${filter}"
}

org_teams() {
    # List teams
    #
    # Usage:
    #
    #     org_teams org
    #
    # Positional arguments
    #
    local org=${1:?Org name required.}
    #   Organization GitHub login or id.
    #
    # Keyword arguments
    #
    local filter='.[] | "\(.name)\t\(.id)\t\(.permission)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   team in the return data.

    shift 1

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    get "/orgs/${org}/teams" \
        | _filter "${filter}"
}

list_repos() {
    # List user repositories
    #
    # Usage:
    #
    #     list_repos
    #     list_repos user
    #
    # Positional arguments
    #
    local user=$1
    #   Optional GitHub user login or id for which to list repos.
    #
    # Keyword arguments
    #
    local filter='.[] | "\(.name)\t\(.html_url)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   repository in the return data.
    #
    # type, sort, direction

    shift 1

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    if [ -n "$user" ] ; then
        url="/users/${user}/repos?per_page=100"
    else
        url='/user/repos?per_page=100'
    fi

    get "$url" | _filter "${filter}"
}

create_repo() {
    # Create a repository for a user or organization
    #
    # Usage:
    #
    #     create_repo foo
    #     create_repo bar description='Stuff and things' homepage='example.com'
    #     create_repo baz organization=myorg
    #
    # Positional arguments
    #
    local name=${1:?Repo name required.}
    #   Name of the new repo
    #
    # Keyword arguments
    #
    local filter='.[] | "\(.name)\t\(.html_url)"'
    #
    # description, homepage, private, has_issues, has_wiki, has_downloads,
    # organization, team_id, auto_init, gitignore_template

    shift 1

    local url organization

    for arg in "$@"; do
        case $arg in
            (organization=*) organization="${arg#*=}";;
            (filter=*) filter="${arg#*=}";;
        esac
    done

    if [ -n "$organization" ] ; then
        url="/orgs/${organization}/repos"
    else
        url='/user/repos'
    fi

    _format "name=${name}" "$@" | post "$url" | _filter "${filter}"
}

list_releases() {
    # List releases for a repository
    #
    # Usage:
    #
    #     list_releases org repo '\(.assets[0].name)\t\(.name.id)'
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
    local filter='.[] | "\(.name)\t\(.id)\t\(.html_url)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release in the return data.

    shift 2

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    get "/repos/${owner}/${repo}/releases" \
        | _filter "${filter}"
}

release() {
    # Get a release
    #
    # Usage:
    #
    #     release user repo 1087855
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
    local filter='"\(.author.login)\t\(.published_at)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release in the return data.

    shift 3

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    get "/repos/${owner}/${repo}/releases/${release_id}" \
        | _filter "${filter}"
}

create_release() {
    # Create a release
    #
    # Usage:
    #
    #     create_release org repo v1.2.3
    #     create_release user repo v3.2.1 draft=true
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
    local filter='"\(.name)\t\(.id)\t\(.html_url)"'
    #   A jq filter using string-interpolation syntax that is applied to the
    #   release data.
    #
    # body, draft, name, prerelease, target_commitish

    shift 3

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    _format "tag_name=${tag_name}" "$@" \
        | post "/repos/${owner}/${repo}/releases" \
        | _filter "${filter}"
}

delete_release() {
    # Delete a release
    #
    # Usage:
    #
    #     delete_release org repo 1087855
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
    #
    #     release_assets user repo 1087855
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
    local filter='.[] | "\(.id)\t\(.name)\t\(.updated_at)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release asset in the return data.

    shift 3

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    get "/repos/${owner}/${repo}/releases/${release_id}/assets" \
        | _filter "$filter"
}

upload_asset() {
    # Upload a release asset
    #
    # Usage:
    #
    #     upload_asset username reponame 1087938 \
    #         foo.tar application/x-tar < foo.tar
    #
    # * (stdin)
    #   The contents of the file to upload.
    #
    # Positional arguments
    #
    local owner=${1:?Owner name required.}
    #   A GitHub user or organization.
    local repo=${2:?Repo name required.}
    #   A GitHub repository.
    local release_id=${3:?Release ID required.}
    #   The unique ID of the release; see list_releases.
    local name=${4:?File name is required.}
    #   The file name of the asset.
    #
    # Keyword arguments
    #
    local filter='"\(.state)\t\(.browser_download_url)"'
    #   A jq filter using string-interpolation syntax that is applied to each
    #   release asset in the return data.

    shift 4

    for arg in "$@"; do
        case $arg in
            (filter=*) filter="${arg#*=}";;
        esac
    done

    local upload_url=$(release "$owner" "$repo" "$release_id" \
        'filter="\(.upload_url)"' | sed -e 's/{?name}/?name='"$name"'/g')

    : ${upload_url:?Upload URL could not be retrieved.}

    post "$upload_url" filename="$name" \
        | _filter "$filter"
}

_main "$@"
