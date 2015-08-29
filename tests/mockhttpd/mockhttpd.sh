#!/bin/sh
# HTTP server to output JSON files for certain paths
#
# Usage:
#   socat TCP-L:8011,crlf,reuseaddr,fork EXEC:./mockhttpd.sh

BASEDIR="$(dirname $0)"

response() {
    # Format an HTTP response
    #
    local code="${1:?Status code required.}"
    #   The HTTP status code.
    local body="${2:?Response body required.}"
    #   The HTTP response body.

    local text

    case $code in
        200) text='OK';;
        404) text='NOT FOUND';;
        500) text='INTERNAL SERVER ERROR';;
        501) text='NOT IMPLEMENTED';;
    esac

    printf 'HTTP/1.1 %s %s\n\n%s\n' "$code" "$text" "$body"
    exit
}

find_response() {
    # Find the stored HTTP response for a URL path
    #
    # The path-to-file mapping is stored in the index files in each method
    # directory.
    #
    local method="${1:?Method is required.}"
    #   The HTTP method; looks for a corresponding directory containing a file
    #   named 'index'.
    local path="${2:?Path is required.}"
    #   The request path

    local mdir="${BASEDIR}/${method}"
    local mindex="${mdir}/index"

    if [ ! -d "$mdir" ]; then
        response 501 "Directory ${mdir} is missing."
    fi

    if [ ! -r "$mindex" ]; then
        response 500 "Index file ${mindex} is missing."
    fi

    local rfile=$(awk -v "path=${path}" \
        '$1 == path { print $2; exit }' "${mindex}")
    local rfile_path="${mdir}/${rfile}"

    if [ -z "$rfile" ]; then
        response 404 "Saved response for ${path} not found in ${method}/index."
    fi

    if [ ! -r "$rfile_path" ]; then
        response 404 "Expected file ${rfile_path} not found."
    else
        cat "$rfile_path"
    fi
}

main() {
    # stdin is the request; stdout is the response.

    local method path proto
    read -r method path proto

    case $path in
        /test_error) response 500 'Server-side error';;
        *) find_response "$method" "$path";;
    esac
}

main "$@"
