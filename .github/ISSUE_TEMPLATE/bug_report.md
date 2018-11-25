---
name: Bug report
about: Report a bug

---

**Describe the bug**

A clear and concise description of what the bug is and what the expected
behavior is.

**Include logs**

- Run `ok.sh` with the `-vvv` flag to look for any potential problems  in the
  HTTP response from GitHub. Feel free to attach that output but remember to
  remove the `Authorization` header first!
- Run `ok.sh -x [...command here...] 2> ok-shdebug.log` and attach that file.

**Environment (please complete the following information)**

 - `ok.sh` release.
- curl version.
- jq version.
- What operating system and version.
- What shell.

  If you are unsure, download
  [whatshell.sh](https://www.in-ulm.de/~mascheck/various/whatshell/) and run
  `/usr/bin/env sh /path/to/whatshell.sh`.

**Additional context**

Add any other context about the problem here.
