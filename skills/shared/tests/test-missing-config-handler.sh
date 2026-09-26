#!/usr/bin/env bash
# With no config yet, both orchestrators must hand the loader's own message to the user.
#
# The first run after the rename finds the old claude-mesh config in Claude Code's plugin-data
# dir and no ~/.config/mesh/config.yaml. The loader exits 2 and prints the exact cp command on
# stderr; an rc=2 arm that swallows stderr leaves the user with a generic "copy the example"
# and a config they already have. The arm must also name the file through `config-path` —
# `data-dir` is the state dir now, not where the config lives.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$TESTS_DIR/../../.." && pwd)"
FAIL=0
PASS=0
check() {   # check <desc> <file>
    local desc="$1" f="$2" arm
    arm="$(grep -E '^[[:space:]]*2\) ' "$f" | grep -F 'config.yaml ещё не создан')"
    if [ "$(printf '%s\n' "$arm" | grep -c .)" != 1 ]; then
        FAIL=$((FAIL+1)); echo "  FAIL: $desc: expected exactly one rc=2 arm, found $(printf '%s\n' "$arm" | grep -c .)"; return
    fi
    case "$arm" in
        *'cat "$LOADER_ERR" >&2'*) PASS=$((PASS+1)); echo "  PASS: $desc passes the loader's stderr on" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: $desc swallows the loader's stderr" ;;
    esac
    case "$arm" in
        *'"$LOADER" config-path'*) PASS=$((PASS+1)); echo "  PASS: $desc names the file via config-path" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: $desc does not name the file via config-path" ;;
    esac
    case "$arm" in
        *'data-dir)/config.yaml'*) FAIL=$((FAIL+1)); echo "  FAIL: $desc still points at the data dir" ;;
        *) PASS=$((PASS+1)); echo "  PASS: $desc no longer points at the data dir" ;;
    esac
}
check "mesh-review" "$REPO/commands/mesh-review.md"
check "mesh-design-review" "$REPO/skills/mesh-design-review/SKILL.md"
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
