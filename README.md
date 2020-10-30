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

 Or set an environment `GITHUB_TOKEN=token`

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


## Table of Contents

### Utility and request/response commands

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

### GitHub commands

* [help](#help)
* [show_scopes](#show_scopes)
* [org_repos](#org_repos)
* [org_teams](#org_teams)
* [org_members](#org_members)
* [org_collaborators](#org_collaborators)
* [team_members](#team_members)
* [list_repos](#list_repos)
* [list_branches](#list_branches)
* [list_commits](#list_commits)
* [list_contributors](#list_contributors)
* [list_collaborators](#list_collaborators)
* [list_hooks](#list_hooks)
* [list_gists](#list_gists)
* [public_gists](#public_gists)
* [gist](#gist)
* [add_collaborator](#add_collaborator)
* [delete_collaborator](#delete_collaborator)
* [create_repo](#create_repo)
* [delete_repo](#delete_repo)
* [fork_repo](#fork_repo)
* [list_releases](#list_releases)
* [release](#release)
* [create_release](#create_release)
* [edit_release](#edit_release)
* [delete_release](#delete_release)
* [release_assets](#release_assets)
* [upload_asset](#upload_asset)
* [list_milestones](#list_milestones)
* [create_milestone](#create_milestone)
* [list_issue_comments](#list_issue_comments)
* [add_comment](#add_comment)
* [list_commit_comments](#list_commit_comments)
* [add_commit_comment](#add_commit_comment)
* [close_issue](#close_issue)
* [list_issues](#list_issues)
* [user_issues](#user_issues)
* [create_issue](#create_issue)
* [org_issues](#org_issues)
* [list_my_orgs](#list_my_orgs)
* [list_orgs](#list_orgs)
* [list_users](#list_users)
* [labels](#labels)
* [add_label](#add_label)
* [update_label](#update_label)
* [add_team_repo](#add_team_repo)
* [list_pulls](#list_pulls)
* [create_pull_request](#create_pull_request)
* [update_pull_request](#update_pull_request)
* [transfer_repo](#transfer_repo)
* [archive_repo](#archive_repo)

## Commands

### _all_funcs


### _log


### _helptext


### _format_json


### _format_urlencode


### _filter_json


### _get_mime_type


### _get_confirm


### _opts_filter


### _opts_pagination


### _opts_qs


### _request


### _response


### _get


### _post


### _delete


### help


### show_scopes


### org_repos


### org_teams


### org_members


### org_collaborators


### team_members


### list_repos


### list_branches


### list_commits


### list_contributors


### list_collaborators


### list_hooks


### list_gists


### public_gists


### gist


### add_collaborator


### delete_collaborator


### create_repo


### delete_repo


### fork_repo


### list_releases


### release


### create_release


### edit_release


### delete_release


### release_assets


### upload_asset


### list_milestones


### create_milestone


### list_issue_comments


### add_comment


### list_commit_comments


### add_commit_comment


### close_issue


### list_issues


### user_issues


### create_issue


### org_issues


### list_my_orgs


### list_orgs


### list_users


### labels


### add_label


### update_label


### add_team_repo


### list_pulls


### create_pull_request


### update_pull_request


### transfer_repo


### archive_repo


