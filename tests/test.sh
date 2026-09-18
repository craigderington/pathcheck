#!/bin/sh

set -eu

PATHCHECK=$(pwd)/pathcheck
TEST_ROOT=${TMPDIR:-/tmp}/pathcheck-test-$$

cleanup()
{
    rm -rf "$TEST_ROOT"
}

trap cleanup EXIT HUP INT TERM
mkdir -p "$TEST_ROOT/first" "$TEST_ROOT/second"

make_program()
{
    file=$1
    printf '#!/bin/sh\nexit 0\n' > "$file"
    chmod +x "$file"
}

make_program "$TEST_ROOT/first/tool"
make_program "$TEST_ROOT/second/tool"
make_program "$TEST_ROOT/localtool"
printf 'plain file\n' > "$TEST_ROOT/first/plain"
mkdir "$TEST_ROOT/first/folder"

output=$(PATH="$TEST_ROOT/first:$TEST_ROOT/second" "$PATHCHECK" tool)
printf '%s\n' "$output" | grep -q "$TEST_ROOT/first/tool.*selected"
printf '%s\n' "$output" | grep -q "$TEST_ROOT/second/tool.*shadowed"

if PATH="$TEST_ROOT/first" "$PATHCHECK" absent >/dev/null 2>&1; then
    echo "expected absent program to return 1" >&2
    exit 1
fi

output=$(PATH="$TEST_ROOT/first" "$PATHCHECK" plain 2>&1 || true)
printf '%s\n' "$output" | grep -q "not executable"

output=$(PATH="$TEST_ROOT/first" "$PATHCHECK" folder 2>&1 || true)
printf '%s\n' "$output" | grep -q "is a directory"

(cd "$TEST_ROOT" && PATH=":/nowhere" "$PATHCHECK" localtool) |
    grep -q "./localtool.*selected"

if env -u PATH "$PATHCHECK" tool >/dev/null 2>&1; then
    echo "expected an unset PATH to return 1" >&2
    exit 1
fi

status=0
"$PATHCHECK" >/dev/null 2>&1 || status=$?
test "$status" -eq 2

echo "pathcheck tests passed"
