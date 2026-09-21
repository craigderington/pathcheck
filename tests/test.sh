#!/bin/sh
set -eu

BIN=${1:-./pathcheck}
case "$BIN" in
    /*) ;;
    *) BIN="$(pwd)/${BIN#./}" ;;
esac
TMPDIR_BASE=${TMPDIR:-/tmp}
T=$(mktemp -d "$TMPDIR_BASE/pathcheck-test.XXXXXX")
trap 'chmod u+rwx "$T/denied" 2>/dev/null || :; rm -rf "$T"' EXIT HUP INT TERM
mkdir -p "$T/a" "$T/b"

# Keep each argument intact, including an explicitly empty argument.
expect_usage_error()
{
    expected_message=$1
    shift
    status=0
    PATH="$T/a" "$BIN" "$@" > "$T/usage-out" 2> "$T/usage-err" || status=$?
    if [ "$status" -ne 2 ]; then
        echo "expected usage status 2, got $status: $expected_message" >&2
        exit 1
    fi
    if [ -s "$T/usage-out" ]; then
        echo "usage error unexpectedly wrote to stdout" >&2
        exit 1
    fi
    grep -F "$expected_message" "$T/usage-err" >/dev/null
}

expect_usage_error 'usage:'
expect_usage_error 'usage:' demo extra
expect_usage_error "program name must not contain '/'" ./demo
expect_usage_error 'program name must not be empty' ''

cat > "$T/a/demo" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
chmod +x "$T/a/demo"

cat > "$T/b/demo" <<'SCRIPT'
#!/bin/sh
exit 0
SCRIPT
chmod +x "$T/b/demo"

PATH="$T/a:$T/b" "$BIN" demo > "$T/out1"
grep 'selected' "$T/out1" >/dev/null
grep 'shadowed' "$T/out1" >/dev/null

echo data > "$T/a/noexec"
if PATH="$T/a" "$BIN" noexec > "$T/out2" 2>&1; then
    echo "expected non-executable file test to fail" >&2
    exit 1
fi
grep 'exists, not executable' "$T/out2" >/dev/null

if PATH="$T/a" "$BIN" missing > "$T/out3" 2>&1; then
    echo "expected missing program test to fail" >&2
    exit 1
fi
grep 'not found in PATH' "$T/out3" >/dev/null

(
    cd "$T"
    cp a/demo ./localdemo
    PATH=":$T/a" "$BIN" localdemo > "$T/out4"
)
grep './localdemo' "$T/out4" >/dev/null

# Capture the exact status without changing PATH for test utilities.
expect_lookup()
{
    expected=$1
    search_path=$2
    command_name=$3
    status=0
    PATH="$search_path" "$BIN" "$command_name" > "$T/lookup-out" 2> "$T/lookup-err" || status=$?
    if [ "$status" -ne "$expected" ]; then
        echo "expected lookup status $expected, got $status" >&2
        exit 1
    fi
}

expect_lookup 1 "$T/a" missing
test ! -s "$T/lookup-err"
expect_lookup 1 "$T/a" noexec
test ! -s "$T/lookup-err"

# Missing directories and non-directory components are ordinary misses.
expect_lookup 0 "$T/absent:$T/a/noexec:$T/a" demo
test ! -s "$T/lookup-err"
test "$(grep -c 'not found' "$T/lookup-out")" -eq 2
test "$(grep -c 'selected' "$T/lookup-out")" -eq 1

# A symlink loop deterministically fails inspection, even for privileged users.
mkdir "$T/loop"
ln -s demo "$T/loop/demo"
expect_lookup 1 "$T/loop" demo
grep -F "$T/loop/demo: stat:" "$T/lookup-err" >/dev/null
grep -F 'lookup incomplete' "$T/lookup-out" >/dev/null
if grep -F 'not found in PATH' "$T/lookup-out" >/dev/null; then
    echo "inspection failure incorrectly reported a definitive miss" >&2
    exit 1
fi

# Errors before or after a match must survive to the final status.
for search_path in "$T/loop:$T/a:$T/b" "$T/a:$T/b:$T/loop"; do
    expect_lookup 1 "$search_path" demo
    grep -F "$T/loop/demo: stat:" "$T/lookup-err" >/dev/null
    test "$(grep -c 'selected' "$T/lookup-out")" -eq 1
    test "$(grep -c 'shadowed' "$T/lookup-out")" -eq 1
done

mkdir "$T/denied"
cp "$T/a/demo" "$T/denied/demo"
chmod 000 "$T/denied"
if [ -x "$T/denied" ]; then
    echo "skip: privileges bypass directory permission restrictions"
else
    expect_lookup 1 "$T/denied:$T/a" demo
    grep -F "$T/denied/demo: stat:" "$T/lookup-err" >/dev/null
    grep -F 'selected' "$T/lookup-out" >/dev/null
fi
chmod 700 "$T/denied"


# Compare the path associated with each selection label, in output order.
expect_matches()
{
    awk '
        /^\[/ { candidate = $0; sub(/^\[[0-9]+\] +/, "", candidate);
                 sub(/ +executable$/, "", candidate) }
        /^      (selected|shadowed)$/ { print $1 ":" candidate }
    ' "$T/lookup-out" > "$T/matches"
    printf '%s\n' "$@" > "$T/expected-matches"
    diff "$T/expected-matches" "$T/matches"
    test ! -s "$T/lookup-err"
}

expect_lookup 0 "$T/a:$T/b:$T/a" demo
expect_matches "selected:$T/a/demo" "shadowed:$T/b/demo" "shadowed:$T/a/demo"

(
    unset PATH
    status=0
    "$BIN" demo > "$T/unset-out" 2> "$T/unset-err" || status=$?
    test "$status" -eq 1
    test ! -s "$T/unset-out"
)
grep -F 'PATH is not set' "$T/unset-err" >/dev/null

(
    cd "$T"
    cp a/demo demo
    expect_lookup 0 "" demo
    expect_matches "selected:./demo"
    expect_lookup 0 ":$T/a" demo
    expect_matches "selected:./demo" "shadowed:$T/a/demo"
    expect_lookup 0 "$T/a:" demo
    expect_matches "selected:$T/a/demo" "shadowed:./demo"
    expect_lookup 0 "$T/a::$T/b" demo
    expect_matches "selected:$T/a/demo" "shadowed:./demo" "shadowed:$T/b/demo"
    expect_lookup 0 "::" demo
    expect_matches "selected:./demo" "shadowed:./demo" "shadowed:./demo"
    expect_lookup 0 "a:./b" demo
    expect_matches "selected:a/demo" "shadowed:./b/demo"
)

mkdir "$T/directory" "$T/notexec" "$T/with spaces" "$T/links"
mkdir "$T/directory/demo"
printf 'data\n' > "$T/notexec/demo"
chmod 644 "$T/notexec/demo"
cp "$T/a/demo" "$T/with spaces/demo"
expect_lookup 0 "$T/directory:$T/notexec:$T/with spaces/:$T/a/" demo
expect_matches "selected:$T/with spaces/demo" "shadowed:$T/a/demo"
grep ' directory$' "$T/lookup-out" >/dev/null
grep ' exists, not executable$' "$T/lookup-out" >/dev/null
expect_lookup 1 "$T/directory" demo
test ! -s "$T/lookup-err"

ln -s ../a/demo "$T/links/demo"
expect_lookup 0 "$T/links:$T/a" demo
expect_matches "selected:$T/links/demo" "shadowed:$T/a/demo"
ln -s ../absent "$T/links/dangling"
expect_lookup 1 "$T/links" dangling
test ! -s "$T/lookup-err"
grep ' not found$' "$T/lookup-out" >/dev/null

# Execute bits do not make a FIFO a runnable regular file.
mkdir "$T/special"
mkfifo "$T/special/demo"
chmod 755 "$T/special/demo"
expect_lookup 1 "$T/special" demo
test ! -s "$T/lookup-err"
grep ' not a regular file$' "$T/lookup-out" >/dev/null
expect_lookup 0 "$T/special:$T/a" demo
expect_matches "selected:$T/a/demo"


# Entry warnings use stdout and must not alter lookup or status.
expect_lookup 0 "$T/a:$T/b:$T/a:$T/a" demo
expect_matches "selected:$T/a/demo" "shadowed:$T/b/demo" "shadowed:$T/a/demo" "shadowed:$T/a/demo"
grep -Fx '      warning: PATH[3] duplicates PATH[1]' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[4] duplicates PATH[1]' "$T/lookup-out" >/dev/null
test "$(grep -c 'duplicates' "$T/lookup-out")" -eq 2

ln -s a "$T/alias"
expect_lookup 0 "$T/a:$T/a/:$T/alias" demo
expect_matches "selected:$T/a/demo" "shadowed:$T/a/demo" "shadowed:$T/alias/demo"

if grep -F 'duplicates' "$T/lookup-out"; then
    echo "different component text treated as duplicate" >&2
    exit 1
fi
(
    cd "$T"
    expect_lookup 0 ":.:" demo
    expect_matches "selected:./demo" "shadowed:./demo" "shadowed:./demo"
    grep -Fx '      warning: PATH[3] duplicates PATH[1]' "$T/lookup-out" >/dev/null
    test "$(grep -c 'duplicates' "$T/lookup-out")" -eq 1
)

expect_lookup 0 "$T/absent:$T/absent:$T/a/noexec:$T/a/noexec/sub:$T/a" demo
expect_matches "selected:$T/a/demo"
grep -Fx '      warning: PATH[1] directory missing' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[2] duplicates PATH[1]' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[2] directory missing' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[3] not a directory' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[4] non-directory path component' "$T/lookup-out" >/dev/null
expect_lookup 1 "$T/absent" demo
test ! -s "$T/lookup-err"

ln -s entry-loop "$T/entry-loop"
expect_lookup 1 "$T/entry-loop:$T/a" demo
grep -F "PATH[1] $T/entry-loop: stat:" "$T/lookup-err" >/dev/null
grep -F 'selected' "$T/lookup-out" >/dev/null
grep -F 'lookup incomplete' "$T/lookup-out" >/dev/null


# Diagnose original component text, not the normalized "." used for lookup.
(
    cd "$T"
    expect_lookup 0 ":.:a:./b:missing:" demo
    expect_matches "selected:./demo" "shadowed:./demo" "shadowed:a/demo" "shadowed:./b/demo" "shadowed:./demo"
    for number in 1 6; do
        grep -Fx "      warning: PATH[$number] empty entry searches current directory" "$T/lookup-out" >/dev/null
    done
    for number in 2 3 4 5; do
        grep -Fx "      warning: PATH[$number] relative entry" "$T/lookup-out" >/dev/null
    done
    grep -Fx '      warning: PATH[5] directory missing' "$T/lookup-out" >/dev/null
    grep -Fx '      warning: PATH[6] duplicates PATH[1]' "$T/lookup-out" >/dev/null
    test "$(grep -c 'empty entry' "$T/lookup-out")" -eq 2
    test "$(grep -c 'relative entry' "$T/lookup-out")" -eq 4
    expect_lookup 0 "" demo
    expect_matches "selected:./demo"
    grep -Fx '      warning: PATH[1] empty entry searches current directory' "$T/lookup-out" >/dev/null
)

mkdir "$T/public" "$T/sticky" "$T/group-only"
cp "$T/a/demo" "$T/public/demo"
cp "$T/a/demo" "$T/sticky/demo"
cp "$T/a/demo" "$T/group-only/demo"
chmod 0777 "$T/public"
chmod 1777 "$T/sticky"
chmod 0775 "$T/group-only"
ln -s public "$T/public-link"
expect_lookup 0 "$T/public:$T/sticky:$T/group-only:$T/public-link:$T/public" demo
expect_matches "selected:$T/public/demo" "shadowed:$T/sticky/demo" "shadowed:$T/group-only/demo" "shadowed:$T/public-link/demo" "shadowed:$T/public/demo"
for number in 1 4 5; do
    grep -Fx "      warning: PATH[$number] world-writable directory (sticky bit not set)" "$T/lookup-out" >/dev/null
done
grep -Fx '      warning: PATH[2] world-writable directory (sticky bit set)' "$T/lookup-out" >/dev/null
grep -Fx '      warning: PATH[5] duplicates PATH[1]' "$T/lookup-out" >/dev/null
test "$(grep -c 'world-writable' "$T/lookup-out")" -eq 4
# No world-writable warning for a group-writable directory or a regular file.
chmod 0666 "$T/notexec/demo"
expect_lookup 0 "$T/group-only:$T/notexec/demo" demo
expect_matches "selected:$T/group-only/demo"
if grep -E 'world-writable|relative entry|empty entry' "$T/lookup-out"; then
    echo "unexpected directory warning" >&2
    exit 1
fi
(
    cd "$T/public"
    expect_lookup 0 ":.:" demo
    expect_matches "selected:./demo" "shadowed:./demo" "shadowed:./demo"
    test "$(grep -c 'world-writable' "$T/lookup-out")" -eq 3
    grep -Fx '      warning: PATH[3] duplicates PATH[1]' "$T/lookup-out" >/dev/null
)
expect_lookup 1 "$T/public:$T/sticky" missing
test ! -s "$T/lookup-err"
test "$(grep -c 'world-writable' "$T/lookup-out")" -eq 2


expect_usage_error 'usage:' --path demo
expect_usage_error 'usage:' --help demo
expect_usage_error 'usage:' --
expect_usage_error 'usage:' -- demo extra
expect_usage_error 'usage:' --unknown
expect_usage_error 'program name must not be empty' -- ''
expect_usage_error "program name must not contain '/'" -- ./demo

expect_lookup 0 "$T/a" --path
printf 'PATH:\n[1] %s\n' "$T/a" > "$T/expected-path"
diff "$T/expected-path" "$T/lookup-out"
test ! -s "$T/lookup-err"
(
    cd "$T"
    search_path=":public:public:$T/sticky:$T/absent:$T/notexec/demo"
    expect_lookup 0 "$search_path" demo
    grep '      warning:' "$T/lookup-out" > "$T/command-warnings"
    expect_lookup 0 "$search_path" --path
    grep '      warning:' "$T/lookup-out" > "$T/path-warnings"
    diff "$T/command-warnings" "$T/path-warnings"
    test ! -s "$T/lookup-err"
    expect_lookup 0 "" --path
    grep -Fx '[1] . (empty entry)' "$T/lookup-out" >/dev/null
)
expect_lookup 0 "$T/absent" --path
test ! -s "$T/lookup-err"
expect_lookup 1 "$T/entry-loop:$T/a" --path
grep -Fx "[2] $T/a" "$T/lookup-out" >/dev/null
grep -Fx 'inspection incomplete: inspection errors occurred' "$T/lookup-out" >/dev/null
grep -F 'PATH[1]' "$T/lookup-err" >/dev/null
(
    unset PATH
    status=0
    "$BIN" --path > "$T/unset-out" 2> "$T/unset-err" || status=$?
    test "$status" -eq 1
    test ! -s "$T/unset-out"
    "$BIN" --help > "$T/help-out" 2> "$T/help-err"
    test ! -s "$T/help-err"
)
grep -F 'PATH is not set' "$T/unset-err" >/dev/null
grep -F -- '--path' "$T/help-out" >/dev/null
for name in --path --help --unknown --; do
    cp "$T/a/demo" "$T/a/$name"
    PATH="$T/a" "$BIN" -- "$name" > "$T/lookup-out" 2> "$T/lookup-err"
    expect_matches "selected:$T/a/$name"
done

echo "all tests passed"
