# pathcheck

`pathcheck` explains how a Unix shell-style `PATH` search resolves a command name.

It is intentionally small: one program, one job.

## Goals

- ANSI C / C89 language level
- Small POSIX surface area
- No GNU-only helper functions
- Explicit memory ownership
- Predictable exit status
- Useful diagnostics

## Build

```sh
make
```

The default build is intentionally strict:

```sh
cc -std=c89 -pedantic -Wall -Wextra -Werror -O2 -o pathcheck pathcheck.c
```

## Use

```sh
./pathcheck cc
./pathcheck sh
./pathcheck python
./pathcheck --path
./pathcheck --help
./pathcheck -- --path
```

For command lookup, supply exactly one nonempty name without `/`.
Use `--` before a name beginning with `-`, including a command literally named
`--path` or `--help`. Unknown options and extra arguments are usage errors:
a diagnostic on standard error and status 2.

`--path` inspects PATH entries without looking for a command. It prints a
`PATH:` heading, then each directory with its entry number and diagnostics.
Empty components display as `. (empty entry)`. For example:

```sh
PATH=:: ./pathcheck --path
```

```text
PATH:
[1] . (empty entry)
      warning: PATH[1] empty entry searches current directory
[2] . (empty entry)
      warning: PATH[2] duplicates PATH[1]
      warning: PATH[2] empty entry searches current directory
[3] . (empty entry)
      warning: PATH[3] duplicates PATH[1]
      warning: PATH[3] empty entry searches current directory
```

Additional mode-bit warnings depend on the current directory.
`--help` prints usage to standard output and returns 0 without inspecting PATH.

Only regular files that pass the executable permission check qualify for selection.
Symlinks are followed: links to executable regular files qualify; dangling links
are ordinary misses. Directories and special files (such as FIFOs and devices)
are never selected.

The first qualifying candidate is marked `selected`. Later matches are marked
`shadowed`, including repeated occurrences of the same path.

An empty `PATH` component is interpreted as the current directory, including an
entirely empty PATH and leading, trailing, or consecutive colons. Relative entries
are resolved from the current directory. An unset PATH produces a diagnostic on
standard error and status 1.

## PATH entry diagnostics

Warnings appear on standard output after the associated candidate and selection
label. Entry numbers follow the original PATH order. For example:

```text
      warning: PATH[3] duplicates PATH[1]
      warning: PATH[4] directory missing
      warning: PATH[5] not a directory
      warning: PATH[6] empty entry searches current directory
      warning: PATH[7] relative entry
      warning: PATH[8] world-writable directory (sticky bit set)
```

Duplicates reference the first entry with exactly the same component text.
Repeated empty components also count as duplicates; an empty component and
`.` do not. Trailing slashes, alternate spellings, and symlink aliases are not
normalized. Every entry is still searched in order.

Missing directories, non-directory entries, and non-directory intermediate
components produce warnings. Warnings alone do not change lookup status.
Other directory inspection failures produce a standard-error diagnostic and
status 1, following the same rule as candidate inspection failures.

Empty entries are labeled as current-directory searches. Nonempty entries that
do not start with `/` are labeled relative, including `.` and `./bin`.
These labels describe the original component text, even if the directory is
missing.

A directory with the other-write mode bit set is labeled world-writable.
The warning states whether its sticky bit is set; it remains a warning in
either case. The sticky bit restricts removal and renaming of directory entries,
but does not prevent others from creating new entries or make command lookup
safe. Symlinks are followed, so warnings describe the target directory.
These are observations of mode bits, not a security audit: ACLs, parent-directory
permissions, mount options, and concurrent filesystem changes are not evaluated.

## Exit status

- `0` — lookup found an executable without inspection errors; or `--path` completed without inspection errors (warnings allowed); or help was displayed
- `1` — lookup found no executable, PATH is unset, or a runtime failure occurred
- `2` — command-line usage error

Missing candidates and non-directory path components are ordinary misses.
A failed executable permission check is reported as non-executable.
Other inspection failures produce a diagnostic on standard error, including the
candidate path and system error. The search continues, but any inspection error
makes the final status 1, even when a match is found. Output then ends with
`lookup incomplete: inspection errors occurred`; selected/shadowed labels describe
only the candidates successfully inspected. In `--path` mode the summary is
`inspection incomplete: inspection errors occurred`. Inspection continues after
filesystem errors in both modes. Missing directories and other warnings alone
still return 0 in `--path` mode.

Output write failures return status 1, including failures while displaying help.

## Tests

```sh
make test
```

## Install

```sh
sudo make install
```

Override the prefix if desired:

```sh
make PREFIX="$HOME/.local" install
```

## Current scope

This tool inspects filesystem candidates. It does not resolve shell aliases,
functions, builtins, or cached command locations. An executable permission check
does not guarantee successful execution.

PATH diagnostics cover duplicates, missing/non-directory entries, empty and
relative entries, and world-writable directories.

## Development plan

See [ROADMAP.md](ROADMAP.md) for milestones and [TODO.md](TODO.md) for the ordered checklist. Lookup, PATH diagnostics, and standalone inspection are complete; release readiness is next.

## Release preparation

Current version: 0.3.0 release candidate. See CHANGELOG.md and VALIDATION.md
for behavior changes and actual compiler/platform checks. Pathcheck is licensed under GPL-3.0-or-later.

Build and test with `make test`. Stage an installation without administrator
privileges using `make DESTDIR="/tmp/pathcheck stage" PREFIX=/usr install`;
use the same variables with `make uninstall` to remove the installed files.

Run `make dist` (requires Python 3) to create
`dist/pathcheck-0.3.0.tar.gz`. The archive contains an explicit source list,
excludes binaries and the kernel learning directory, and includes LICENSE. Extract it into a fresh directory and run `make test` there.
Compilation and normal use do not require Python.

## License

Pathcheck (its source, tests, build scripts, and accompanying documentation)
is licensed under the GNU General Public License, version 3 or, at your option,
any later version (SPDX: GPL-3.0-or-later). See [LICENSE](LICENSE) for the terms.

Pathcheck is distributed without any warranty, including the implied warranties
of merchantability or fitness for a particular purpose.

The separate kernel learning directory is not part of the Pathcheck release
or this licensing declaration.
