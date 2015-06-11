<!---
This README file is generated. Changes will be overwritten.
-->
[![Build Status](https://travis-ci.org/whiteinge/octokit.sh.svg?branch=master)](https://travis-ci.org/whiteinge/octokit.sh)
# A GitHub API client library written in POSIX sh

## Requirements

* A POSIX environment (tested against Busybox v1.19.4)
* curl (tested against 7.32.0)

## Optional requirements

* jq <http://stedolan.github.io/jq/> (tested against 1.3)
  If jq is not installed commands will output raw JSON; if jq is installed
  commands can be pretty-printed for use with other shell tools.

## Setup

Authentication credentials are read from a ~/.netrc file with the following
format. Generate the token on GitHub under Account Settings -> Applications.
Restrict permissions on that file with `chmod 600 ~/.netrc`!

    machine api.github.com
        login <username>
        password <token>

## Configuration

The following environment variables may be set to customize octokit.sh.

* OCTOKIT_SH_URL=https://api.github.com
  Base URL for GitHub or GitHub Enterprise.
* OCTOKIT_SH_ACCEPT=application/vnd.github.v3+json
  The 'Accept' header to send with each request.
* OCTOKIT_SH_JQ_BIN=jq
  The name of the jq binary, if installed.
* OCTOKIT_SH_VERBOSE=0
  The debug logging verbosity level. Same as the verbose flag.
* OCTOKIT_SH_RATE_LIMIT=0
  Output current GitHub rate limit information to stderr.
* OCTOKIT_SH_DESTRUCTIVE=0
  Allow destructive operations without prompting for confirmation.

## Usage

Usage: `octokit.sh [<options>] (command [<name=value>...])`

Full help output: `octokit.sh help`
Command-specific help: `octokit.sh help command`

Flag | Description
---- | -----------
-V   | Show version.
-h   | Show this screen.
-j   | Output raw JSON; don't process with jq.
-q   | Quiet; don't print to stdout.
-r   | Print current GitHub API rate limit to stderr.
-v   | Logging output; specify multiple times: info, debug, trace.
-x   | Enable xtrace debug logging.
-y   | Answer 'yes' to any prompts.

## Available commands

help, show_scopes, org_repos, org_teams, list_repos, create_repo, delete_repo, 
list_releases, release, create_release, delete_release, release_assets, 
upload_asset, list_milestones, list_issues, user_issues, org_issues

## Table of Contents
* [help](#help)
* [_all_funcs](#_all_funcs)
* [_log](#_log)
* [_helptext](#_helptext)
* [_format_json](#_format_json)
* [_format_urlencode](#_format_urlencode)
* [_filter_json](#_filter_json)
* [_get_mime_type](#_get_mime_type)
* [_get_confirm](#_get_confirm)
* [_opts_filter](#_opts_filter)
* [_opts_pagination](#_opts_pagination)
* [_opts_qs](#_opts_qs)
* [_request](#_request)
* [_response](#_response)
* [_get](#_get)
* [_post](#_post)
* [_delete](#_delete)
* [show_scopes](#show_scopes)
* [org_repos](#org_repos)
* [org_teams](#org_teams)
* [list_repos](#list_repos)
* [create_repo](#create_repo)
* [delete_repo](#delete_repo)
* [list_releases](#list_releases)
* [release](#release)
* [create_release](#create_release)
* [delete_release](#delete_release)
* [release_assets](#release_assets)
* [upload_asset](#upload_asset)
* [list_milestones](#list_milestones)
* [list_issues](#list_issues)
* [user_issues](#user_issues)
* [org_issues](#org_issues)

### help()

Output the help text for a command

Usage:

    help commandname

Positional arguments

* fname : `$1`
  Function name to search for; if omitted searches whole file.

### _all_funcs()

List all functions found in the current file in the order they appear

Keyword arguments

* pretty : `1`
  0 output one function per line; 1 output a formatted paragraph.
* public : `1`
  0 output all functions; 1 output only public functions.

### _log()

A lightweight logging system based on file descriptors

Usage:

    _log debug 'Starting the combobulator!'

Positional arguments

* level : `$1`
  The level for a given log message. (info or debug)
* message : `$2`
  The log message.

### _helptext()

Extract contiguous lines of comments and function params as help text

Indentation will be ignored. She-bangs will be ignored. The _main()
function will be ignored. Local variable declarations and their default
values can also be pulled in as documentation. Exits upon encountering
the first blank line.

Exported environment variables can be used for string interpolation in
the extracted commented text.

Input

* (stdin)
  The text of a function body to parse.

Positional arguments

* name : `$1`
  A file name to parse.

### _format_json()

Create formatted JSON from name=value pairs

Usage:
```
_format_json foo=Foo bar=123 baz=true qux=Qux=Qux quux='Multi-line
string'
```

Return:
```
{"bar":123,"qux":"Qux=Qux","foo":"Foo","quux":"Multi-line\nstring","baz":true}
```

Tries not to quote numbers and booleans. If jq is installed it will also
validate the output.

Positional arguments

* $1 - $9
  Each positional arg must be in the format of `name=value` which will be
  added to a single, flat JSON object.

### _format_urlencode()

URL encode and join name=value pairs

Usage:
```
_format_urlencode foo='Foo Foo' bar='<Bar>&/Bar/'
```

Return:
```
foo=Foo%20Foo&bar=%3CBar%3E%26%2FBar%2F
```

Ignores pairs if the value begins with an underscore.

### _filter_json()

Filter JSON input using jq; outputs raw JSON if jq is not installed

Usage:

    _filter_json '.[] | "\(.foo)"' < something.json

* (stdin)
  JSON input.
* _filter : `$1`
  A string of jq filters to apply to the input stream.

### _get_mime_type()

Guess the mime type for a file based on the file extension

Usage:

    local mime_type
    _get_mime_type "foo.tar"; printf 'mime is: %s' "$mime_type"

Sets the global variable `mime_type` with the result. (If this function
is called from within a function that has declared a local variable of
that name it will update the local copy and not set a global.)

Positional arguments

* filename : `$1`
  The full name of the file, with exension.

### _get_confirm()

Prompt the user for confirmation

Usage:

    local confirm; _get_confirm
    [ "$confirm" -eq 1 ] && printf 'Good to go!\n'

If global confirmation is set via `$OCTOKIT_SH_DESTRUCTIVE` then the user
is not prompted. Assigns the user's confirmation to the `confirm` global
variable. (If this function is called within a function that has a local
variable of that name, the local variable will be updated instead.)

Positional arguments

* message : `$1`
  The message to prompt the user with.

### _opts_filter()

Extract common jq filter keyword options and assign to vars

Usage:

      local filter
      _opts_filter "$@"

### _opts_pagination()

Extract common pagination keyword options and assign to vars

Usage:

      local _follow_next
      _opts_pagination "$@"

### _opts_qs()

Format a querystring to append to an URL or a blank string

Usage:

  local qs
  _opts_qs "$@"
  _get "/some/path"

### _request()

A wrapper around making HTTP requests with curl

Usage:
```
_request /repos/:owner/:repo/issues
printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
  | _request /repos/:owner/:repo/issues | jq -r '.[url]'
printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
  | _request /repos/:owner/:repo/issues method=PUT | jq -r '.[url]'
```

Input

* (stdin)
  Data that will be used as the request body.

Positional arguments

* path : `$1`
  The URL path for the HTTP request.
  Must be an absolute path that starts with a `/` or a full URL that
  starts with http(s). Absolute paths will be append to the value in
  `$OCTOKIT_SH_URL`.

Keyword arguments

* method : `'GET'`
  The method to use for the HTTP request.
* content_type : `'application/json'`
  The value of the Content-Type header to use for the request.

### _response()

Process an HTTP response from curl

Output only headers of interest followed by the response body. Additional
processing is performed on select headers to make them easier to work
with in sh. See below.

Usage:
```
_request /some/path | _response status_code ETag Link_next
curl -isS example.com/some/path | _response status_code status_text | {
  local status_code status_text
  read -r status_code
  read -r status_text
}
```

Header reformatting

* HTTP Status
  The HTTP line is split into `http_version`, `status_code`, and
  `status_text` variables.
* ETag
  The surrounding quotes are removed.
* Link
  Each URL in the Link header is expanded with the URL type appended to
  the name. E.g., `Link_first`, `Link_last`, `Link_next`.

Positional arguments

* $1 - $9
  Each positional arg is the name of an HTTP header. Each header value is
  output in the same order as each argument; each on a single line. A
  blank line is output for headers that cannot be found.

### _get_mime_type()

Guess the mime type for a file based on the file extension

Usage:

    local mime_type
    _get_mime_type "foo.tar"; printf 'mime is: %s' "$mime_type"

Sets the global variable `mime_type` with the result. (If this function
is called from within a function that has declared a local variable of
that name it will update the local copy and not set a global.)

Positional arguments

* filename : `$1`
  The full name of the file, with exension.

### _post()

A wrapper around _request() for commoon POST / PUT patterns

Usage:

    _format_json foo=Foo bar=Bar | _post /some/path
    _format_json foo=Foo bar=Bar | _post /some/path method='PUT'
    _post /some/path filename=somearchive.tar
    _post /some/path filename=somearchive.tar mime_type=application/x-tar
    _post /some/path filename=somearchive.tar \
      mime_type=$(file -b --mime-type somearchive.tar)

Input

* (stdin)
  Optional. See the `filename` argument also.
  Data that will be used as the request body.

Positional arguments

* path : `$1`
  The HTTP path or URL to pass to _request().

Keyword arguments

* method : `'POST'`
  The method to use for the HTTP request.
*  : `filename`
  Optional. See the `stdin` option above also.
  Takes precedence over any data passed as stdin and loads a file off the
  file system to serve as the request body.
*  : `mime_type`
  The value of the Content-Type header to use for the request.
  If the `filename` argument is given this value will be guessed from the
  file extension. If the `filename` argument is not given (i.e., using
  stdin) this value defaults to `application/json`. Specifying this
  argument overrides all other defaults or guesses.

### _delete()

A wrapper around _request() for common DELETE patterns

Usage:

    _delete '/some/url'

Return: 0 for success; 1 for failure.

Positional arguments

* url : `$1`
  The URL to send the DELETE request to.

### show_scopes()

Show the permission scopes for the currently authenticated user

Usage:

    show_authorizations

### org_repos()

List organization repositories

Usage:

    org_repos myorg
    org_repos myorg type=private per_page=10
    org_repos myorg _filter='.[] | "\(.name)\t\(.owner.login)"'

Positional arguments

* org : `$1`
  Organization GitHub login or id for which to list repos.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.ssh_url)"'`
  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type

### org_teams()

List teams

Usage:

    org_teams org

Positional arguments

* org : `$1`
  Organization GitHub login or id.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.id)\t\(.permission)"'`
  A jq filter to apply to the return data.

### list_repos()

List user repositories

Usage:

    list_repos
    list_repos user

Positional arguments

* user : `$1`
  Optional GitHub user login or id for which to list repos.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.html_url)"'`
  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type, sort, direction

### create_repo()

Create a repository for a user or organization

Usage:

    create_repo foo
    create_repo bar description='Stuff and things' homepage='example.com'
    create_repo baz organization=myorg

Positional arguments

* name : `$1`
  Name of the new repo

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.html_url)"'`
  A jq filter to apply to the return data.

POST data may also be passed as keyword arguments:
description, homepage, private, has_issues, has_wiki, has_downloads,
organization, team_id, auto_init, gitignore_template

### delete_repo()

Create a repository for a user or organization

Usage:

    delete_repo owner repo

The currently authenticated user must have the `delete_repo` scope. View
current scopes with the `show_scopes()` function.

Positional arguments

* owner : `$1`
  Name of the new repo
* repo : `$2`
  Name of the new repo

### list_releases()

List releases for a repository

Usage:

    list_releases org repo '\(.assets[0].name)\t\(.name.id)'

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.id)\t\(.html_url)"'`
  A jq filter to apply to the return data.

### release()

Get a release

Usage:

    release user repo 1087855

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.
* release_id : `$3`
  The unique ID of the release; see list_releases.

Keyword arguments

* _filter : `'"\(.author.login)\t\(.published_at)"'`
  A jq filter to apply to the return data.

### create_release()

Create a release

Usage:

    create_release org repo v1.2.3
    create_release user repo v3.2.1 draft=true

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.
* tag_name : `$3`
  Git tag from which to create release.

Keyword arguments

* _filter : `'"\(.name)\t\(.id)\t\(.html_url)"'`
  A jq filter to apply to the return data.

POST data may also be passed as keyword arguments:
body, draft, name, prerelease, target_commitish

### delete_release()

Delete a release

Usage:

    delete_release org repo 1087855

Return: 0 for success; 1 for failure.

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.
* release_id : `$3`
  The unique ID of the release; see list_releases.

### release_assets()

List release assets

Usage:

    release_assets user repo 1087855

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.
* release_id : `$3`
  The unique ID of the release; see list_releases.

Keyword arguments

* _filter : `'.[] | "\(.id)\t\(.name)\t\(.updated_at)"'`
  A jq filter to apply to the return data.

### upload_asset()

Upload a release asset

Usage:

    upload_asset username reponame 1087938 \
        foo.tar application/x-tar < foo.tar

* (stdin)
  The contents of the file to upload.

Positional arguments

* owner : `$1`
  A GitHub user or organization.
* repo : `$2`
  A GitHub repository.
* release_id : `$3`
  The unique ID of the release; see list_releases.
* name : `$4`
  The file name of the asset.

Keyword arguments

* _filter : `'"\(.state)\t\(.browser_download_url)"'`
  A jq filter to apply to the return data.

### list_milestones()

List milestones for a repository

Usage:

      list_milestones someuser/somerepo
      list_milestones someuser/somerepo state=closed

Positional arguments

* repository : `$1`
  A GitHub repository.

Keyword arguments

*  : `_follow_next`
  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`
  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.id)\t\(.open_issues)/\(.closed_issues)\t\(.title)"'`
  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, state, sort, direction

### list_issues()

List issues for the authenticated user or repository

Usage:

      list_issues
      list_issues someuser/somerepo
      list_issues someuser/somerepo state=closed labels=foo,bar

Positional arguments

* repository : `$1`
  A GitHub repository.

Keyword arguments

*  : `_follow_next`
  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`
  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.number)\t\(.title)"'`
  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, filter, state, labels, sort, direction, since

### user_issues()

List all issues across owned and member repositories for the authenticated user

Usage:

      user_issues
      user_issues since=2015-60-11T00:09:00Z

Positional arguments

* repository : `$1`
  A GitHub repository.

Keyword arguments

*  : `_follow_next`
  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`
  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.number)\t\(.title)"'`
  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, filter, state, labels, sort, direction, since

### org_issues()

List all issues for a given organization for the authenticated user

Usage:

      org_issues someorg

Positional arguments

* org : `$1`
  Organization GitHub login or id.

Keyword arguments

*  : `_follow_next`
  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`
  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.number)\t\(.title)"'`
  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, filter, state, labels, sort, direction, since

