<!---
This README file is generated. Changes will be overwritten.
-->
[![Build Status](https://travis-ci.org/whiteinge/ok.sh.svg?branch=master)](https://travis-ci.org/whiteinge/ok.sh)

# A GitHub API client library written in POSIX sh

https://github.com/whiteinge/ok.sh
BSD licensed.

## Requirements

* A POSIX environment (tested against Busybox v1.19.4)
* curl (tested against 7.32.0)

## Optional requirements

* jq <http://stedolan.github.io/jq/> (tested against 1.3)
  If jq is not installed commands will output raw JSON; if jq is installed
  the output will be formatted and filtered for use with other shell tools.

## Setup

Authentication credentials are read from a `$HOME/.netrc` file on UNIX
machines or a `_netrc` file in `%HOME%` for UNIX environments under Windows.
[Generate the token on GitHub](https://github.com/settings/tokens) under
"Account Settings -> Applications".
Restrict permissions on that file with `chmod 600 ~/.netrc`!

    machine api.github.com
        login <username>
        password <token>

    machine uploads.github.com
        login <username>
        password <token>

## Configuration

The following environment variables may be set to customize ok.sh.

* OK_SH_URL=https://api.github.com
  Base URL for GitHub or GitHub Enterprise.
* OK_SH_ACCEPT=application/vnd.github.v3+json
  The 'Accept' header to send with each request.
* OK_SH_JQ_BIN=jq
  The name of the jq binary, if installed.
* OK_SH_VERBOSE=0
  The debug logging verbosity level. Same as the verbose flag.
* OK_SH_RATE_LIMIT=0
  Output current GitHub rate limit information to stderr.
* OK_SH_DESTRUCTIVE=0
  Allow destructive operations without prompting for confirmation.
* OK_SH_MARKDOWN=1
  Output some text in Markdown format.

## Usage

`ok.sh [<flags>] (command [<arg>, <name=value>...])`

      ok.sh -h              # Short, usage help text.
      ok.sh help            # All help text. Warning: long!
      ok.sh help command    # Command-specific help text.
      ok.sh command         # Run a command with and without args.
      ok.sh command foo bar baz=Baz qux='Qux arg here'

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

Flags _must_ be the first argument to `ok.sh`, before `command`.

## Table of Contents

### Utility and request/response commands

* [_all_funcs](#_all_funcs)
* [_log](#_log)
* [_helptext](#_helptext)
* [_awk_map](#_awk_map)
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

### GitHub commands

* [help](#help)
* [show_scopes](#show_scopes)
* [org_repos](#org_repos)
* [org_teams](#org_teams)
* [org_members](#org_members)
* [list_repos](#list_repos)
* [list_branches](#list_branches)
* [list_contributors](#list_contributors)
* [list_collaborators](#list_collaborators)
* [add_collaborator](#add_collaborator)
* [delete_collaborator](#delete_collaborator)
* [create_repo](#create_repo)
* [delete_repo](#delete_repo)
* [fork_repo](#fork_repo)
* [list_releases](#list_releases)
* [release](#release)
* [create_release](#create_release)
* [delete_release](#delete_release)
* [release_assets](#release_assets)
* [upload_asset](#upload_asset)
* [list_milestones](#list_milestones)
* [create_milestone](#create_milestone)
* [list_issues](#list_issues)
* [user_issues](#user_issues)
* [org_issues](#org_issues)
* [labels](#labels)
* [add_label](#add_label)
* [update_label](#update_label)
* [add_team_repo](#add_team_repo)

## Commands

### _all_funcs

List all functions found in the current file in the order they appear

Keyword arguments

* public : `1`

  `0` do not output public functions.
* private : `1`

  `0` do not output private functions.

### _log

A lightweight logging system based on file descriptors

Usage:

    _log debug 'Starting the combobulator!'

Positional arguments

* level : `$1`

  The level for a given log message. (info or debug)
* message : `$2`

  The log message.

### _helptext

Extract contiguous lines of comments and function params as help text

Indentation will be ignored. She-bangs will be ignored. Local variable
declarations and their default values can also be pulled in as
documentation. Exits upon encountering the first blank line.

Exported environment variables can be used for string interpolation in
the extracted commented text.

Input

* (stdin)
  The text of a function body to parse.

### _awk_map

Invoke awk with a function that will empty the ENVIRON map

Positional arguments

* prg : `$1`

The body of an awk program to run

### _format_json

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

### _format_urlencode

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

### _filter_json

Filter JSON input using jq; outputs raw JSON if jq is not installed

Usage:

    printf '[{"foo": "One"}, {"foo": "Two"}]' | \
        ok.sh _filter_json '.[] | "\(.foo)"'

* (stdin)
  JSON input.
* _filter : `"$1"`

  A string of jq filters to apply to the input stream.

### _get_mime_type

Guess the mime type for a file based on the file extension

Usage:

    local mime_type
    _get_mime_type "foo.tar"; printf 'mime is: %s' "$mime_type"

Sets the global variable `mime_type` with the result. (If this function
is called from within a function that has declared a local variable of
that name it will update the local copy and not set a global.)

Positional arguments

* filename : `$1`

  The full name of the file, with extension.

### _get_confirm

Prompt the user for confirmation

Usage:

    local confirm; _get_confirm
    [ "$confirm" -eq 1 ] && printf 'Good to go!\n'

If global confirmation is set via `$OK_SH_DESTRUCTIVE` then the user
is not prompted. Assigns the user's confirmation to the `confirm` global
variable. (If this function is called within a function that has a local
variable of that name, the local variable will be updated instead.)

Positional arguments

* message : `$1`

  The message to prompt the user with.

### _opts_filter

Extract common jq filter keyword options and assign to vars

Usage:

      local filter
      _opts_filter "$@"

### _opts_pagination

Extract common pagination keyword options and assign to vars

Usage:

      local _follow_next
      _opts_pagination "$@"

### _opts_qs

Extract common query string keyword options and assign to vars

Usage:

      local qs
      _opts_qs "$@"
      _get "/some/path"

### _request

A wrapper around making HTTP requests with curl

Usage:
```
# Get JSON for all issues:
_request /repos/saltstack/salt/issues

# Send a POST request; parse response using jq:
printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
  | _request /some/path | jq -r '.[url]'

# Send a PUT request; parse response using jq:
printf '{"title": "%s", "body": "%s"}\n' "Stuff" "Things" \
  | _request /repos/:owner/:repo/issues method=PUT | jq -r '.[url]'

# Send a conditional-GET request:
_request /users etag=edd3a0d38d8c329d3ccc6575f17a76bb
```

Input

* (stdin)
  Data that will be used as the request body.

Positional arguments

* path : `$1`

  The URL path for the HTTP request.
  Must be an absolute path that starts with a `/` or a full URL that
  starts with http(s). Absolute paths will be append to the value in
  `$OK_SH_URL`.

Keyword arguments

* method : `'GET'`

  The method to use for the HTTP request.
* content_type : `'application/json'`

  The value of the Content-Type header to use for the request.
*  : `etag`

  An optional Etag to send as the If-None-Match header.

### _response

Process an HTTP response from curl

Output only headers of interest followed by the response body. Additional
processing is performed on select headers to make them easier to parse
using shell tools.

Usage:
```
# Send a request; output the response and only select response headers:
_request /some/path | _response status_code ETag Link_next

# Make request using curl; output response with select response headers;
# assign response headers to local variables:
curl -isS example.com/some/path | _response status_code status_text | {
  local status_code status_text
  read -r status_code
  read -r status_text
}
```

Header reformatting

* HTTP Status

  The HTTP line is split into separate `http_version`, `status_code`, and
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

### _get

A wrapper around _request() for common GET patterns

Will automatically follow 'next' pagination URLs in the Link header.

Usage:

    _get /some/path
    _get /some/path _follow_next=0
    _get /some/path _follow_next_limit=200 | jq -c .

Positional arguments

* path : `$1`

  The HTTP path or URL to pass to _request().

Keyword arguments

_follow_next=1
  Automatically look for a 'Links' header and follow any 'next' URLs.
_follow_next_limit=50
  Maximum number of 'next' URLs to follow before stopping.

### _post

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

### _delete

A wrapper around _request() for common DELETE patterns

Usage:

    _delete '/some/url'

Return: 0 for success; 1 for failure.

Positional arguments

* url : `$1`

  The URL to send the DELETE request to.

### help

Output the help text for a command

Usage:

    help commandname

Positional arguments

* fname : `"$1"`

  Function name to search for; if omitted searches whole file.

### show_scopes

Show the permission scopes for the currently authenticated user

Usage:

    show_scopes

### org_repos

List organization repositories

Usage:

    org_repos myorg
    org_repos myorg type=private per_page=10
    org_repos myorg _filter='.[] | "\(.name)\t\(.owner.login)"'

Positional arguments

* org : `$1`

  Organization GitHub login or id for which to list repos.

Keyword arguments

*  : `_follow_next`

  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`

  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.name)\t\(.ssh_url)"'`

  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type

### org_teams

List teams

Usage:

    org_teams org

Positional arguments

* org : `$1`

  Organization GitHub login or id.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.id)\t\(.permission)"'`

  A jq filter to apply to the return data.

### org_members

List organization members

Usage:

    org_members org

Positional arguments

* org : `$1`

  Organization GitHub login or id.

Keyword arguments

* _filter : `'.[] | "\(.login)\t\(.id)"'`

  A jq filter to apply to the return data.

### list_repos

List user repositories

Usage:

    list_repos
    list_repos user

Positional arguments

* user : `"$1"`

  Optional GitHub user login or id for which to list repos.

Keyword arguments

* _filter : `'.[] | "\(.name)\t\(.html_url)"'`

  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type, sort, direction

### list_branches

List branches of a specified repository.
( https://developer.github.com/v3/repos/#list_branches )

Usage:

    list_branches user repo

Positional arguments
  GitHub user login or id for which to list branches
  Name of the repo for which to list branches

* user : `$1`

* repo : `$2`


Keyword arguments

* _filter : `'.[] | "\(.name)"'`

  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type, sort, direction

### list_contributors

List contributors to the specified repository, sorted by the number of commits per contributor in descending order.
( https://developer.github.com/v3/repos/#list-contributors )

Usage:

    list_contributors user repo

Positional arguments
  GitHub user login or id for which to list contributors
  Name of the repo for which to list contributors

* user : `$1`

* repo : `$2`


Keyword arguments

* _filter : `'.[] | "\(.login)\t\(.type)\tType`

  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type, sort, direction

### list_collaborators

List collaborators to the specified repository, sorted by the number of commits per collaborator in descending order.
( https://developer.github.com/v3/repos/#list-collaborators )

Usage:

    list_collaborators someuser/somerepo

Positional arguments
  GitHub user login or id for which to list collaborators
  Name of the repo for which to list collaborators

* repo : `$1`


Keyword arguments

* _filter : `'.[] | "\(.login)\t\(.type)\tType`

  A jq filter to apply to the return data.

Querystring arguments may also be passed as keyword arguments:
per_page, type, sort, direction

### add_collaborator

Add a collaborator to a repository

Usage:
      add_collaborator someuser/somerepo collaboratoruser permission

Positional arguments

* repo : `$1`

  A GitHub repository.
* collaborator : `$2`

  A new collaborator.
* permission : `$3`

  The permission level for this collaborator.  One of: push pull admin
  The pull and admin permissions are valid for organization repos only.

Keyword arguments

* _filter : `'"\(.name)\t\(.color)"'`

  A jq filter to apply to the return data.

### delete_collaborator

Delete a collaborator to a repository

Usage:
      delete_collaborator someuser/somerepo collaboratoruser permission

Positional arguments

* repo : `$1`

  A GitHub repository.
* collaborator : `$2`

  A new collaborator.

### create_repo

Create a repository for a user or organization

Usage:

    create_repo foo
    create_repo bar description='Stuff and things' homepage='example.com'
    create_repo baz organization=myorg

Positional arguments

* name : `$1`

  Name of the new repo

Keyword arguments

* _filter : `'"\(.name)\t\(.html_url)"'`

  A jq filter to apply to the return data.

POST data may also be passed as keyword arguments:
description, homepage, private, has_issues, has_wiki, has_downloads,
organization, team_id, auto_init, gitignore_template

### delete_repo

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

### fork_repo

Fork a repository from a user or organization to own account

Usage:

    fork_repo owner repo

Positional arguments

* owner : `$1`

  Name of existing user or organization
* repo : `$2`

  Name of the existing repo

Keyword arguments

* _filter : `'"\(.clone_url)\t\(.ssh_url)"'`

  A jq filter to apply to the return data.

### list_releases

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

### release

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

### create_release

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

### delete_release

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

### release_assets

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

### upload_asset

Upload a release asset

Note, this command requires `jq` to find the release `upload_url`.

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

### list_milestones

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
* _filter : `'.[] | "\(.number)\t\(.open_issues)/\(.closed_issues)\t\(.title)"'`

  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, state, sort, direction

### create_milestone

Create a milestone for a repository

Usage:

      create_milestone someuser/somerepo MyMilestone

      create_milestone someuser/somerepo MyMilestone \
          due_on=2015-06-16T16:54:00Z \
          description='Long description here
      that spans multiple lines.'

Positional arguments

* repo : `$1`

  A GitHub repository.
* title : `$2`

  A unique title.

Keyword arguments

* _filter : `'"\(.number)\t\(.html_url)"'`

  A jq filter to apply to the return data.

Milestone options may also be passed as keyword arguments:
state, description, due_on

### list_issues

List issues for the authenticated user or repository

Usage:

      list_issues
      list_issues someuser/somerepo
      list_issues someuser/somerepo state=closed labels=foo,bar

Positional arguments

* repository : `"$1"`

  A GitHub repository.

Keyword arguments

*  : `_follow_next`

  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`

  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.number)\t\(.title)"'`

  A jq filter to apply to the return data.

GitHub querystring arguments may also be passed as keyword arguments:
per_page, milestone, state, assignee, creator, mentioned, labels, sort,
direction, since

### user_issues

List all issues across owned and member repositories for the authenticated user

Usage:

      user_issues
      user_issues since=2015-60-11T00:09:00Z

Positional arguments

* repository : `"$1"`

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

### org_issues

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

### labels

List available labels for a repository

Usage:

      labels someuser/somerepo

Positional arguments

* repo : `"$1"`

  A GitHub repository.

Keyword arguments

*  : `_follow_next`

  Automatically look for a 'Links' header and follow any 'next' URLs.
*  : `_follow_next_limit`

  Maximum number of 'next' URLs to follow before stopping.
* _filter : `'.[] | "\(.name)\t\(.color)"'`

  A jq filter to apply to the return data.

### add_label

Add a label to a repository

Usage:
      add_label someuser/somerepo LabelName color

Positional arguments

* repo : `$1`

  A GitHub repository.
* label : `$2`

  A new label.
* color : `$3`

  A color, in hex, without the leading `#`.

Keyword arguments

* _filter : `'"\(.name)\t\(.color)"'`

  A jq filter to apply to the return data.

### update_label

Update a label

Usage:
      update_label someuser/somerepo OldLabelName \
          label=NewLabel color=newcolor

Positional arguments

* repo : `$1`

  A GitHub repository.
* label : `$2`

  The name of the label which will be updated

Keyword arguments

* _filter : `'"\(.name)\t\(.color)"'`

  A jq filter to apply to the return data.

Label options may also be passed as keyword arguments, these will update
the existing values:
name, color

### add_team_repo

Add a team repository

Usage:

    add_team_repo team_id organization repository_name permission

Positional arguments

* team_id : `$1`

  Team id to add repository to
* organization : `$2`

  Organization to add repository to
* repository_name : `$3`

  Repository name to add
* permission : `$4`

  Permission to grant: pull, push, admin

* url : `"/teams/$team_id}/repos/${organization}/${repository_name}"`


