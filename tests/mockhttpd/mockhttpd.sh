#!/bin/sh
# HTTP server to output JSON files for certain paths
#
# Usage:
#   socat TCP-L:8011,crlf,reuseaddr,fork EXEC:./mockhttpd.sh

BASEDIR="$(dirname $0)"
OK_MPORT="${OK_MPORT:=8011}"

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

pagination() {
    # Mimic GitHub's next/prev Link header
    #
    local path="${1:?Path is required.}"
    #   The HTTP request path.

    awk -v "path=${path}" -v "port=${OK_MPORT}" '
    function genlink(num, rel) {
        return "<http://localhost:" port "/test_pagination?page=" num \
            ">; rel=\"" rel "\""
    }

    function genlinks(curnum,   first, last, links) {
        first = 1; last = 4; links = ""

        links = genlink(first, "first")
        links = links ", " genlink(last, "last")

        if (curnum != first) links = links ", " genlink(curnum - 1, "prev")
        if (curnum != last) links = links ", " genlink(curnum + 1, "next")

        return links
    }

    BEGIN {
        page_idx = match(path, /\?page=[0-9]+/)

        if (page_idx == 0) {
            page_num = 1
        } else {
            page_num = substr(path, page_idx + length("?page="))
        }

        links = genlinks(page_num)

        printf("HTTP/1.1 200 OK\n")
        printf("Link: %s\n", links)
        printf("\nCurrent page: %s\n", page_num)
    }
    '
}

main() {
    # stdin is the request; stdout is the response.

    local method path proto
    read -r method path proto

    printf 'Processing %s request for %s\n' "$method" "$path" 1>&2

    case $path in
        /test_error) response 500 'Server-side error';;
        /test_pagination*) pagination "$path";;
        *) find_response "$method" "$path";;
    esac
}

main "$@"
