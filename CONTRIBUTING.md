# Contributor Guidelines

Contributions of all kinds are very welcome! Consistent contributors will be
considered for co-maintainership.

## Target Platforms & Compatibility

All additions should be best-effort tested against a POSIX environment and a
bourne-compatible shell (no bashisms). The target platforms for this script are
fairly modern systems (ten to fifteen years old), although concessions can be
made for legacy or unusual systems if that does not burden the overall
maintainability of the script.

## README

The README file is a generated file from extracting comments in the main
script. It should not be modified directly. See the Makefile for details.

## Code Structure

Please try to match the style of the existing code. Discussion is welcome in
the issue tracker for better patterns or techniques.

The `local` keyword is used deliberately. Although it is not part of the POSIX
spec at this time I am under the impression that all modern bourne shell
implementations support it.

## Style Changes

Style and formatting changes are generally discouraged as they present risk for
regressions and usually without much functional gain. The issue tracker is a
good place to raise discussion for maintainability improvements and ideas.
