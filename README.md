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

The first executable found is marked `selected`. Later executable matches are marked `shadowed`.

An empty `PATH` component is interpreted as the current directory, matching traditional Unix `PATH` semantics.

## Exit status

- `0` — at least one executable match was found
- `1` — no executable match was found, or a runtime failure occurred
- `2` — command-line usage error

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

Version 0.1 deliberately does not diagnose duplicate, missing, relative, or insecure `PATH` directories yet. Those belong in the next milestone after the basic lookup behavior is solid.

## Development plan

See [ROADMAP.md](ROADMAP.md) for milestones and [TODO.md](TODO.md) for the ordered checklist. The next step is to strengthen lookup validation and regression coverage, then add PATH diagnostics.
