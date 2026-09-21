#!/bin/sh
set -eu

BIN=${1:-./pathcheck}
case "$BIN" in
    /*) ;;
    *) BIN="$(pwd)/${BIN#./}" ;;
esac
TMPDIR_BASE=${TMPDIR:-/tmp}
T="$TMPDIR_BASE/pathcheck-test-$$"
mkdir -p "$T/a" "$T/b"
trap 'rm -rf "$T"' EXIT HUP INT TERM

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

echo "all tests passed"
