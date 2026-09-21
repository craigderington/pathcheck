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
```

Supply exactly one nonempty command name without `/`. Invalid arguments produce a diagnostic on standard error and exit status 2.

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

- `0` — at least one executable match was found and no inspection error occurred
- `1` — no executable match was found, or a runtime failure occurred
- `2` — command-line usage error

Missing candidates and non-directory path components are ordinary misses.
A failed executable permission check is reported as non-executable.
Other inspection failures produce a diagnostic on standard error, including the
candidate path and system error. The search continues, but any inspection error
makes the final status 1, even when a match is found. Output then ends with
`lookup incomplete: inspection errors occurred`; selected/shadowed labels describe
only the candidates successfully inspected.

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

See [ROADMAP.md](ROADMAP.md) for milestones and [TODO.md](TODO.md) for the ordered checklist. Lookup and PATH diagnostics are complete; the next step is standalone PATH inspection with `--path`.
