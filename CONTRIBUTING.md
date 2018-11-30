# Contributor Guidelines

Contributions of all kinds are very welcome! Consistent contributors will be
considered for co-maintainership.

## Target Platforms & Compatibility

All additions should be best-effort tested against a POSIX environment and a
bourne-compatible shell (no bashisms). The target platforms for this script are
fairly modern systems (ten to fifteen years old), although concessions can be
made for legacy or unusual systems if that does not burden the overall
maintainability of the script.

### Development Environment

A development environment can be quickly created if you have Docker installed
by running `make dev` from the main repo directory. This will drop you into
a shell with the local directory mounted as a volume.

### POSIX Documentation

The [POSIX documentation is available
online](https://pubs.opengroup.org/onlinepubs/9699919799/). In addition you can
download a local copy for offline viewing by running `make posixdocs`.

## Generate README

The README file is a generated file from extracting comments in the main
script. It should not be modified directly. See the Makefile for details but
tl;dr execute:

```
make readme
```

## Code Structure

Please try to match the style of the existing code. Each function should begin
with contiguous comment lines or variable declarations; these are used for the
automatic documentation. A blank line then follows to separate the docs from
the function body.

The following helper functions process common arguments and then assign those
values to locally-scope vars: `_opts_filter`, `_opts_pagination`, `_opts_qs`.

## Style Changes

Style and formatting changes are generally discouraged as they present risk for
regressions and usually without much functional gain. The issue tracker is a
good place to raise discussion for maintainability improvements and ideas.

## Misc

### A note on `local`

The `local` keyword is used deliberately. Although it is not part of the POSIX
spec at this time I am under the impression that all modern bourne shell
implementations support it.
