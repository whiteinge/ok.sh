#!/usr/bin/env sh
# # A GitHub API client library written in POSIX sh
#
# ## Requirements
#
# * A POSIX environment (tested against Busybox v1.19.4)
# * curl (tested against 7.32.0)
#
# ## Optional requirements
#
# * jq <http://stedolan.github.io/jq/> (tested against 1.3)
#   If jq is not installed commands will output raw JSON; if jq is installed
#   the output will be formatted and filtered for use with other shell tools.
#
# ## Setup
#
# Authentication credentials are read from a `~/.netrc` file.
# Generate the token on GitHub under "Account Settings -> Applications".
# Restrict permissions on that file with `chmod 600 ~/.netrc`!
#
#     machine api.github.com
#         login <username>
#         password <token>
#
# ## Configuration
#
# The following environment variables may be set to customize ${NAME}.
#
# * OK_SH_URL=${OK_SH_URL}
#   Base URL for GitHub or GitHub Enterprise.
# * OK_SH_ACCEPT=${OK_SH_ACCEPT}
#   The 'Accept' header to send with each request.
# * OK_SH_JQ_BIN=${OK_SH_JQ_BIN}
#   The name of the jq binary, if installed.
# * OK_SH_VERBOSE=${OK_SH_VERBOSE}
#   The debug logging verbosity level. Same as the verbose flag.
# * OK_SH_RATE_LIMIT=${OK_SH_RATE_LIMIT}
#   Output current GitHub rate limit information to stderr.
# * OK_SH_DESTRUCTIVE=${OK_SH_DESTRUCTIVE}
#   Allow destructive operations without prompting for confirmation.

export NAME=$(basename $0)
export VERSION='0.1.0'

export OK_SH_URL=${OK_SH_URL:-'https://api.github.com'}
export OK_SH_ACCEPT=${OK_SH_ACCEPT:-'application/vnd.github.v3+json'}
export OK_SH_JQ_BIN="${OK_SH_JQ_BIN:-jq}"
export OK_SH_VERBOSE="${OK_SH_VERBOSE:-0}"
export OK_SH_RATE_LIMIT="${OK_SH_RATE_LIMIT:-0}"
export OK_SH_DESTRUCTIVE="${OK_SH_DESTRUCTIVE:-0}"

# Detect if jq is installed.
type "$OK_SH_JQ_BIN" 1>/dev/null 2>/dev/null
NO_JQ=$?

# Customizable logging output.
exec 4>/dev/null
exec 5>/dev/null
exec 6>/dev/null
export LINFO=4      # Info-level log messages.
export LDEBUG=5     # Debug-level log messages.
export LSUMMARY=6   # Summary output.

# ## Main
# Generic functions not necessarily specific to working with GitHub.

# ### Help
# Functions for fetching and formatting help text.

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
        _helptext < $0
        printf '\n'
        help __main
    fi
}

_all_funcs() {
    # List all functions found in the current file in the order they appear
    #
    # Keyword arguments
    #
    local pretty=1
    #   `0` output one function per line; `1` output a formatted paragraph.
    local public=1
    #   `0` do not output public functions.
    local private=1
    #   `0` do not output private functions.

    for arg in "$@"; do
        case $arg in
            (pretty=*) pretty="${arg#*=}";;
            (public=*) public="${arg#*=}";;
            (private=*) private="${arg#*=}";;
        esac
    done

    awk -v public="$public" -v private="$private" '
        $1 !~ /^__/ && /^[a-zA-Z0-9_]+\s*\(\)/ {
            sub(/\(\)$/, "", $1)
            if (!public && substr($1, 1, 1) != "_") next
            if (!private && substr($1, 1, 1) == "_") next
            print $1
        }
    ' $0 | {
        if [ "$pretty" -eq 1 ] ; then
            cat | sed ':a;N;$!ba;s/\n/, /g' | fold -w 79 -s
        else
            cat
        fi
    }
}

__main() {
    # Usage: `${NAME} [<flags>] (command [<arg>, <name=value>...])`
    #
    #       ${NAME} -h              # Short, usage help text.
    #       ${NAME} help            # All help text. Warning: long!
    #       ${NAME} help command    # Command-specific help text.
    #       ${NAME} command         # Run a command with and without args.
    #       ${NAME} command foo bar baz=Baz qux='Qux arg here'
    #
    # See the full list of commands below.
    #
    # Flags _must_ be the first argument to `${NAME}`, before `command`.
    #
    # Flag | Description
    # ---- | -----------
    # -V   | Show version.
    # -h   | Show this screen.
    # -j   | Output raw JSON; don't process with jq.
    # -q   | Quiet; don't print to stdout.
    # -r   | Print current GitHub API rate limit to stderr.
    # -v   | Logging output; specify multiple times: info, debug, trace.
    # -x   | Enable xtrace debug logging.
    # -y   | Answer 'yes' to any prompts.

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

    while getopts Vhjqrvxy opt; do
        case $opt in
        V)  printf 'Version: %s\n' $VERSION
            exit;;
        h) help __main
            printf '\nAvailable commands:\n\n'
            _all_funcs public=0
            printf '\n'
            _all_funcs private=0
            printf '\n'
            exit;;
        j)  NO_JQ=1;;
        q)  quiet=1;;
        r)  OK_SH_RATE_LIMIT=1;;
        v)  OK_SH_VERBOSE=$(( $OK_SH_VERBOSE + 1 ));;
        x)  set -x;;
        y)  OK_SH_DESTRUCTIVE=1;;
        esac
    done
    shift $(( $OPTIND - 1 ))

    if [ -z "$1" ] ; then
        printf 'No command given. Available commands:\n\n%s\n' \
            "$(_all_funcs)" 1>&2
        exit 1
    fi

    [ $OK_SH_VERBOSE -gt 0 ] && exec 4>&2
    [ $OK_SH_VERBOSE -gt 1 ] && exec 5>&2
    if [ $quiet -eq 1 ]; then
        exec 1>/dev/null 2>/dev/null
    fi

    if [ "$OK_SH_RATE_LIMIT" -eq 1 ] ; then
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
    if [ "$OK_SH_RATE_LIMIT" -eq 1 ] ; then
        cat "$summary_fifo" 1>&2 &
        exec 6>&-
    fi

    exit $ret
}

_log() {
    # A lightweight logging system based on file descriptors
    #
    # Usage:
    #
    #     _log debug 'Starting the combobulator!'
    #
    # Positional arguments
    #
    local level="${1:?Level is required.}"
    #   The level for a given log message. (info or debug)
    local message="${2:?Message is required.}"
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
    # Indentation will be ignored. She-bangs will be ignored. Local variable
    # declarations and their default values can also be pulled in as
    # documentation. Exits upon encountering the first blank line.
    #
    # Exported environment variables can be used for string interpolation in
    # the extracted commented text.
    #
    # Input
    #
    # * (stdin)
    #   The text of a function body to parse.

    awk '
    NR != 1 && /^\s*#/ {
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
        idx = index($0, "=")
        name = substr($0, 1, idx - 1)
        val = substr($0, idx + 1)
        sub(/"{0,1}\${/, "$", val)
        sub(/:.*$/, "", val)
        print "* " name " : `" val "`"
    }
    !NF { exit }'
}

# ### Request-response
# Functions for making HTTP requests and processing HTTP responses.

_format_json() {
    # Create formatted JSON from name=value pairs
    #
    # Usage:
    # ```
    # _format_json foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
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
        delete ENVIRON["AWKPATH"]       # GNU addition.
        printf("{")

        for (name in ENVIRON) {
            val = ENVIRON[name]

            # If not bool or number, quote it.
            if (!isbool(val) && !isnum(val)) {
                gsub(/"/, "\\\"", val)  # Escape double-quotes.
                gsub(/\n/, "\\n", val)  # Replace newlines with \n text.
                val = "\"" val "\""
            }

            printf("%s\"%s\": %s", sep, name, val)
            sep = ", "
        }

        printf("}\n")
    }
    ' | _filter_json
}

_format_urlencode() {
    # URL encode and join name=value pairs
    #
    # Usage:
    # ```
    # _format_urlencode foo='Foo Foo' bar='<Bar>&/Bar/'
    # ```
    #
    # Return:
    # ```
    # foo=Foo%20Foo&bar=%3CBar%3E%26%2FBar%2F
    # ```
    #
    # Ignores pairs if the value begins with an underscore.

    _log debug "Formatting ${#} parameters as urlencoded"

    env -i "$@" awk '
    function escape(str, c, len, res) {
        len = length(str)
        res = ""
        for (i = 1; i <= len; i += 1) {
            c = substr(str, i, 1);
            if (c ~ /[0-9A-Za-z]/)
                res = res c
            else
                res = res "%" sprintf("%02X", ord[c])
        }
        return res
    }

    BEGIN {
        for (i = 0; i <= 255; i += 1) ord[sprintf("%c", i)] = i;

        delete ENVIRON["AWKPATH"]       # GNU addition.
        for (name in ENVIRON) {
            if (substr(name, 1, 1) == "_") continue
            val = ENVIRON[name]

            printf("%s%s=%s", sep, name, escape(val))
            sep = "&"
        }
    }
    '
}

_filter_json() {
    # Filter JSON input using jq; outputs raw JSON if jq is not installed
    #
    # Usage:
    #
    #     _filter_json '.[] | "\(.foo)"' < something.json
    #
    # * (stdin)
    #   JSON input.
    local _filter=$1
    #   A string of jq filters to apply to the input stream.

    _log debug 'Filtering JSON.'

    if [ $NO_JQ -ne 0 ] ; then
        cat
        return
    fi

    "${OK_SH_JQ_BIN}" -c -r "${_filter}"
    [ $? -eq 0 ] || printf 'jq parse error; invalid JSON.\n' 1>&2
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
    local filename="${1:?Filename is required.}"
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

_get_confirm() {
    # Prompt the user for confirmation
    #
    # Usage:
    #
    #     local confirm; _get_confirm
    #     [ "$confirm" -eq 1 ] && printf 'Good to go!\n'
    #
    # If global confirmation is set via `$OK_SH_DESTRUCTIVE` then the user
    # is not prompted. Assigns the user's confirmation to the `confirm` global
    # variable. (If this function is called within a function that has a local
    # variable of that name, the local variable will be updated instead.)
    #
    # Positional arguments
    #
    local message="${1:-Are you sure?}"
    #   The message to prompt the user with.

    local answer

    if [ "$OK_SH_DESTRUCTIVE" -eq 1 ] ; then
        confirm=$OK_SH_DESTRUCTIVE
        return
    fi

    printf '%s ' "$message"
    read -r answer

    ! printf '%s\n' "$answer" | grep -Eq "$(locale yesexpr)"
    confirm=$?
}

_opts_filter() {
    # Extract common jq filter keyword options and assign to vars
    #
    # Usage:
    #
    #       local filter
    #       _opts_filter "$@"

    for arg in "$@"; do
        case $arg in
            (_filter=*) _filter="${arg#*=}";;
        esac
    done
}

_opts_pagination() {
    # Extract common pagination keyword options and assign to vars
    #
    # Usage:
    #
    #       local _follow_next
    #       _opts_pagination "$@"

    for arg in "$@"; do
        case $arg in
            (_follow_next=*) _follow_next="${arg#*=}";;
            (_follow_next_limit=*) _follow_next_limit="${arg#*=}";;
        esac
    done
}

_opts_qs() {
    # Format a querystring to append to an URL or a blank string
    #
    # Usage:
    #
    #       local qs
    #       _opts_qs "$@"
    #       _get "/some/path${qs}"

    local querystring=$(_format_urlencode "$@")
    qs="${querystring:+?$querystring}"
}

_request() {
    # A wrapper around making HTTP requests with curl
    #
    # Usage:
    # ```
    # _request /repos/:owner/:repo/issues
    # printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #   | _request /repos/:owner/:repo/issues | jq -r '.[url]'
    # printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
    #   | _request /repos/:owner/:repo/issues method=PUT | jq -r '.[url]'
    # ```
    #
    # Input
    #
    # * (stdin)
    #   Data that will be used as the request body.
    #
    # Positional arguments
    #
    local path="${1:?Path is required.}"
    #   The URL path for the HTTP request.
    #   Must be an absolute path that starts with a `/` or a full URL that
    #   starts with http(s). Absolute paths will be append to the value in
    #   `$OK_SH_URL`.
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
        *) path="${OK_SH_URL}${path}" ;;
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

    [[ $OK_SH_VERBOSE -eq 3 ]] && trace_curl=1

    [ "$OK_SH_VERBOSE" -eq 1 ] && set -x
    curl -nsSi \
        -H "Accept: ${OK_SH_ACCEPT}" \
        -H "Content-Type: ${content_type}" \
        ${has_stdin:+--data-binary @-} \
        ${trace_curl:+--trace-ascii /dev/stderr} \
        -X "${method}" \
        "${path}"
    set +x
}

_response() {
    # Process an HTTP response from curl
    #
    # Output only headers of interest followed by the response body. Additional
    # processing is performed on select headers to make them easier to work
    # with in sh. See below.
    #
    # Usage:
    # ```
    # _request /some/path | _response status_code ETag Link_next
    # curl -isS example.com/some/path | _response status_code status_text | {
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
        [ "$hdr" = "" ] && break
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

_get() {
    # A wrapper around _request() for common GET patterns
    #
    # Will automatically follow 'next' pagination URLs in the Link header.
    #
    # Usage:
    #
    #     _get /some/path
    #     _get /some/path _follow_next=0
    #     _get /some/path _follow_next_limit=200 | jq -c .
    #
    # Positional arguments
    #
    local path="${1:?Path is required.}"
    #   The HTTP path or URL to pass to _request().
    #
    # Keyword arguments
    #
    # _follow_next=1
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    # _follow_next_limit=50
    #   Maximum number of 'next' URLs to follow before stopping.

    shift 1
    local status_code status_text next_url

    # If the variable is unset or empty set it to a default value. Functions
    # that call this function can pass these parameters in one of two ways:
    # explicitly as a keyword arg or implicity by setting variables of the same
    # names within the local scope.
    if [ -z ${_follow_next+x} ] || [ -z "${_follow_next}" ]; then
        local _follow_next=1
    fi
    if [ -z ${_follow_next_limit+x} ] || [ -z "${_follow_next_limit}" ]; then
        local _follow_next_limit=50
    fi

    _opts_pagination "$@"

    _request "$path" | _response status_code status_text Link_next | {
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

        [ "$_follow_next" -eq 1 ] || return

        _log info "Remaining next link follows: ${_follow_next_limit}"
        if [ -n "$next_url" ] && [ $_follow_next_limit -gt 0 ] ; then
            _follow_next_limit=$(( $_follow_next_limit - 1 ))

            _get "$next_url" "_follow_next_limit=${_follow_next_limit}"
        fi
    }
}

_post() {
    # A wrapper around _request() for commoon POST / PUT patterns
    #
    # Usage:
    #
    #     _format_json foo=Foo bar=Bar | _post /some/path
    #     _format_json foo=Foo bar=Bar | _post /some/path method='PUT'
    #     _post /some/path filename=somearchive.tar
    #     _post /some/path filename=somearchive.tar mime_type=application/x-tar
    #     _post /some/path filename=somearchive.tar \
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
    local path="${1:?Path is required.}"
    #   The HTTP path or URL to pass to _request().
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

    _request "$path" method="$method" content_type="$mime_type" 0<&7 \
            | _response status_code status_text \
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

_delete() {
    # A wrapper around _request() for common DELETE patterns
    #
    # Usage:
    #
    #     _delete '/some/url'
    #
    # Return: 0 for success; 1 for failure.
    #
    # Positional arguments
    #
    local url="${1:?URL is required.}"
    #   The URL to send the DELETE request to.

    local status_code

    _request "${url}" method='DELETE' | _response status_code | {
        read -r status_code
        [ "$status_code" = "204" ]
        exit $?
    }
}

# ## GitHub
# Friendly functions for common GitHub tasks.

# ### Authorization
# Perform authentication and authorization.

show_scopes() {
    # Show the permission scopes for the currently authenticated user
    #
    # Usage:
    #
    #     show_scopes

    local oauth_scopes

    _request '/' | _response X-OAuth-Scopes | {
        read -r oauth_scopes

        printf '%s\n' "$oauth_scopes"

        # Dump any remaining response body.
        cat >/dev/null
    }
}

# ### Repository
# Create, update, delete, list repositories.

org_repos() {
    # List organization repositories
    #
    # Usage:
    #
    #     org_repos myorg
    #     org_repos myorg type=private per_page=10
    #     org_repos myorg _filter='.[] | "\(.name)\t\(.owner.login)"'
    #
    # Positional arguments
    #
    local org="${1:?Org name required.}"
    #   Organization GitHub login or id for which to list repos.
    #
    # Keyword arguments
    #
    local _filter='.[] | "\(.name)\t\(.ssh_url)"'
    #   A jq filter to apply to the return data.
    #
    # Querystring arguments may also be passed as keyword arguments:
    # per_page, type

    shift 1
    local qs

    _opts_filter "$@"
    _opts_qs "$@"

    _get "/orgs/${org}/repos${qs}" | _filter_json "${_filter}"
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
    local org="${1:?Org name required.}"
    #   Organization GitHub login or id.
    #
    # Keyword arguments
    #
    local _filter='.[] | "\(.name)\t\(.id)\t\(.permission)"'
    #   A jq filter to apply to the return data.

    shift 1

    _opts_filter "$@"

    _get "/orgs/${org}/teams" \
        | _filter_json "${_filter}"
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
    local _filter='.[] | "\(.name)\t\(.html_url)"'
    #   A jq filter to apply to the return data.
    #
    # Querystring arguments may also be passed as keyword arguments:
    # per_page, type, sort, direction

    shift 1
    local qs

    _opts_filter "$@"
    _opts_qs "$@"

    if [ -n "$user" ] ; then
        url="/users/${user}/repos"
    else
        url='/user/repos'
    fi

    _get "${url}${qs}" | _filter_json "${_filter}"
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
    local name="${1:?Repo name required.}"
    #   Name of the new repo
    #
    # Keyword arguments
    #
    local _filter='.[] | "\(.name)\t\(.html_url)"'
    #   A jq filter to apply to the return data.
    #
    # POST data may also be passed as keyword arguments:
    # description, homepage, private, has_issues, has_wiki, has_downloads,
    # organization, team_id, auto_init, gitignore_template

    shift 1

    _opts_filter "$@"

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

    _format_json "name=${name}" "$@" | _post "$url" | _filter_json "${_filter}"
}

delete_repo() {
    # Create a repository for a user or organization
    #
    # Usage:
    #
    #     delete_repo owner repo
    #
    # The currently authenticated user must have the `delete_repo` scope. View
    # current scopes with the `show_scopes()` function.
    #
    # Positional arguments
    #
    local owner="${1:?Owner name required.}"
    #   Name of the new repo
    local repo="${2:?Repo name required.}"
    #   Name of the new repo

    shift 2

    local confirm

    _get_confirm 'This will permanently delete a repository! Continue?'
    [ "$confirm" -eq 1 ] || exit 0

    _delete "/repos/${owner}/${repo}"
    exit $?
}

# ### Releases
# Create, update, delete, list releases.

list_releases() {
    # List releases for a repository
    #
    # Usage:
    #
    #     list_releases org repo '\(.assets[0].name)\t\(.name.id)'
    #
    # Positional arguments
    #
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local _filter='.[] | "\(.name)\t\(.id)\t\(.html_url)"'
    #   A jq filter to apply to the return data.

    shift 2

    _opts_filter "$@"

    _get "/repos/${owner}/${repo}/releases" \
        | _filter_json "${_filter}"
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
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    local release_id="${3:?Release ID required.}"
    #   The unique ID of the release; see list_releases.
    #
    # Keyword arguments
    #
    local _filter='"\(.author.login)\t\(.published_at)"'
    #   A jq filter to apply to the return data.

    shift 3

    _opts_filter "$@"

    _get "/repos/${owner}/${repo}/releases/${release_id}" \
        | _filter_json "${_filter}"
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
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    local tag_name="${3:?Tag name required.}"
    #   Git tag from which to create release.
    #
    # Keyword arguments
    #
    local _filter='"\(.name)\t\(.id)\t\(.html_url)"'
    #   A jq filter to apply to the return data.
    #
    # POST data may also be passed as keyword arguments:
    # body, draft, name, prerelease, target_commitish

    shift 3

    _opts_filter "$@"

    _format_json "tag_name=${tag_name}" "$@" \
        | _post "/repos/${owner}/${repo}/releases" \
        | _filter_json "${_filter}"
}

delete_release() {
    # Delete a release
    #
    # Usage:
    #
    #     delete_release org repo 1087855
    #
    # Return: 0 for success; 1 for failure.
    #
    # Positional arguments
    #
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    local release_id="${3:?Release ID required.}"
    #   The unique ID of the release; see list_releases.

    shift 3

    local confirm

    _get_confirm 'This will permanently delete a release. Continue?'
    [ "$confirm" -eq 1 ] || exit 0

    _delete "/repos/${owner}/${repo}/releases/${release_id}"
    exit $?
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
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    local release_id="${3:?Release ID required.}"
    #   The unique ID of the release; see list_releases.
    #
    # Keyword arguments
    #
    local _filter='.[] | "\(.id)\t\(.name)\t\(.updated_at)"'
    #   A jq filter to apply to the return data.

    shift 3

    _opts_filter "$@"

    _get "/repos/${owner}/${repo}/releases/${release_id}/assets" \
        | _filter_json "$_filter"
}

upload_asset() {
    # Upload a release asset
    #
    # Note, this command requires `jq` to find the release `upload_url`.
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
    local owner="${1:?Owner name required.}"
    #   A GitHub user or organization.
    local repo="${2:?Repo name required.}"
    #   A GitHub repository.
    local release_id="${3:?Release ID required.}"
    #   The unique ID of the release; see list_releases.
    local name="${4:?File name is required.}"
    #   The file name of the asset.
    #
    # Keyword arguments
    #
    local _filter='"\(.state)\t\(.browser_download_url)"'
    #   A jq filter to apply to the return data.

    shift 4

    _opts_filter "$@"

    local upload_url=$(release "$owner" "$repo" "$release_id" \
        'filter="\(.upload_url)"' | sed -e 's/{?name}/?name='"$name"'/g')

    : ${upload_url:?Upload URL could not be retrieved.}

    _post "$upload_url" filename="$name" \
        | _filter_json "$_filter"
}

# ### Issues
# Create, update, edit, delete, list issues and milestones.

list_milestones() {
    # List milestones for a repository
    #
    # Usage:
    #
    #       list_milestones someuser/somerepo
    #       list_milestones someuser/somerepo state=closed
    #
    # Positional arguments
    #
    local repository="${1:?Repo name required.}"
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local _follow_next
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    local _follow_next_limit
    #   Maximum number of 'next' URLs to follow before stopping.
    local _filter='.[] | "\(.number)\t\(.open_issues)/\(.closed_issues)\t\(.title)"'
    #   A jq filter to apply to the return data.
    #
    # GitHub querystring arguments may also be passed as keyword arguments:
    # per_page, state, sort, direction

    shift 1
    local qs

    _opts_pagination "$@"
    _opts_filter "$@"
    _opts_qs "$@"

    _get "/repos/${repository}/milestones${qs}" | _filter_json "$_filter"
}

create_milestone() {
    # Create a milestone for a repository
    #
    # Usage:
    #
    #       create_milestone someuser/somerepo MyMilestone
    #
    #       create_milestone someuser/somerepo MyMilestone \
    #           due_on=2015-06-16T16:54:00Z \
    #           description='Long description here
    #       that spans multiple lines.'
    #
    # Positional arguments
    #
    local repo="${1:?Repo name required.}"
    #   A GitHub repository.
    local title="${2:?Milestone name required.}"
    #   A unique title.
    #
    # Keyword arguments
    #
    local _filter='"\(.number)\t\(.html_url)"'
    #   A jq filter to apply to the return data.
    #
    # Milestone options may also be passed as keyword arguments:
    # state, description, due_on

    shift 2

    _opts_filter "$@"

    _format_json title="$title" "$@" \
        | _post "/repos/${repo}/milestones" \
        | _filter_json "$_filter"
}

list_issues() {
    # List issues for the authenticated user or repository
    #
    # Usage:
    #
    #       list_issues
    #       list_issues someuser/somerepo
    #       list_issues someuser/somerepo state=closed labels=foo,bar
    #
    # Positional arguments
    #
    local repository=$1
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local _follow_next
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    local _follow_next_limit
    #   Maximum number of 'next' URLs to follow before stopping.
    local _filter='.[] | "\(.number)\t\(.title)"'
    #   A jq filter to apply to the return data.
    #
    # GitHub querystring arguments may also be passed as keyword arguments:
    # per_page, milestone, state, assignee, creator, mentioned, labels, sort,
    # direction, since

    shift 1
    local url qs

    _opts_pagination "$@"
    _opts_filter "$@"
    _opts_qs "$@"

    if [ -n "$repository" ] ; then
        url="/repos/${repository}/issues"
    else
        url='/user/issues'
    fi

    _get "${url}${qs}" | _filter_json "$_filter"
}

user_issues() {
    # List all issues across owned and member repositories for the authenticated user
    #
    # Usage:
    #
    #       user_issues
    #       user_issues since=2015-60-11T00:09:00Z
    #
    # Positional arguments
    #
    local repository=$1
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local _follow_next
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    local _follow_next_limit
    #   Maximum number of 'next' URLs to follow before stopping.
    local _filter='.[] | "\(.number)\t\(.title)"'
    #   A jq filter to apply to the return data.
    #
    # GitHub querystring arguments may also be passed as keyword arguments:
    # per_page, filter, state, labels, sort, direction, since

    shift 1
    local qs

    _opts_pagination "$@"
    _opts_filter "$@"
    _opts_qs "$@"

    _get "/issues${qs}" | _filter_json "$_filter"
}

org_issues() {
    # List all issues for a given organization for the authenticated user
    #
    # Usage:
    #
    #       org_issues someorg
    #
    # Positional arguments
    #
    local org="${1:?Organization name required.}"
    #   Organization GitHub login or id.
    #
    # Keyword arguments
    #
    local _follow_next
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    local _follow_next_limit
    #   Maximum number of 'next' URLs to follow before stopping.
    local _filter='.[] | "\(.number)\t\(.title)"'
    #   A jq filter to apply to the return data.
    #
    # GitHub querystring arguments may also be passed as keyword arguments:
    # per_page, filter, state, labels, sort, direction, since

    shift 1
    local qs

    _opts_pagination "$@"
    _opts_filter "$@"
    _opts_qs "$@"

    _get "/orgs/${org}/issues${qs}" | _filter_json "$_filter"
}

labels() {
    # List available labels for a repository
    #
    # Usage:
    #
    #       labels someuser/somerepo
    #
    # Positional arguments
    #
    local repo=$1
    #   A GitHub repository.
    #
    # Keyword arguments
    #
    local _follow_next
    #   Automatically look for a 'Links' header and follow any 'next' URLs.
    local _follow_next_limit
    #   Maximum number of 'next' URLs to follow before stopping.
    local _filter='.[] | "\(.name)\t\(.color)"'
    #   A jq filter to apply to the return data.

    _opts_pagination "$@"
    _opts_filter "$@"

    _get "/repos/${repo}/labels" | _filter_json "$_filter"
}

add_label() {
    # Add a label to a repository
    #
    # Usage:
    #       add_label someuser/somereapo LabelName color
    #
    # Positional arguments
    #
    local repo="${1:?Repo name required.}"
    #   A GitHub repository.
    local label="${2:?Label name required.}"
    #   A new label.
    local color="${3:?Hex color required.}"
    #   A color, in hex, without the leading `#`.
    #
    # Keyword arguments
    #
    local _filter='"\(.name)\t\(.color)"'
    #   A jq filter to apply to the return data.

    _opts_filter "$@"

    _format_json name="$label" color="$color" \
        | _post "/repos/${repo}/labels" \
        | _filter_json "$_filter"
}

__main "$@"
