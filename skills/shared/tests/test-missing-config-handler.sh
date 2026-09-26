#!/usr/bin/env bash
# With no config yet, both orchestrators must hand the loader's own message to the user.
#
# The first run after the rename finds the old claude-mesh config in Claude Code's plugin-data
# dir and no ~/.config/mesh/config.yaml. The loader exits 2 and prints the exact cp command on
# stderr; an rc=2 arm that swallows stderr leaves the user with a generic "copy the example"
# and a config they already have. The arm must also name the file through `config-path` —
# `data-dir` is the state dir now, not where the config lives.
#
# Passing stderr on is not enough when the arm's own hint then orders the copy regardless: the
# user gets the loader's move command and, right below it, "copy config.example.yaml, fill
# tokens" — two contradicting instructions. The hint must defer to the move command, in both
# orchestrators and in grok-code-review's rc=2 STOP, and the orchestrators' hint must say that
# running it is the user's step: the agent reading the arm never creates or copies the config.
# Each place is found by its code (the `2)` arm, the `FLAG_RC -eq 2` branch), not by the
# sentence it prints: that is what gets checked.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$TESTS_DIR/../../.." && pwd)"
FAIL=0
PASS=0
check() {   # check <desc> <file>
    local desc="$1" f="$2" arm
    arm="$(grep -E '^[[:space:]]*2\) ' "$f")"
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
    case "$arm" in
        *'команду переноса старого конфига claude-mesh'*) PASS=$((PASS+1)); echo "  PASS: $desc defers to the loader's move command" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: $desc does not mention the loader's move command" ;;
    esac
    case "$arm" in
        *'это шаг пользователя'*) PASS=$((PASS+1)); echo "  PASS: $desc says moving the config is the user's step" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: $desc does not say moving the config is the user's step" ;;
    esac
    case "$arm" in
        *'Скопируйте config.example.yaml в'*) FAIL=$((FAIL+1)); echo "  FAIL: $desc still orders the copy of config.example.yaml unconditionally" ;;
        *) PASS=$((PASS+1)); echo "  PASS: $desc no longer orders the copy unconditionally" ;;
    esac
}
check "mesh-review" "$REPO/commands/mesh-review.md"
check "mesh-design-review" "$REPO/skills/mesh-design-review/SKILL.md"

# grok-code-review has no case arm: its rc=2 branch is `if [ "$FLAG_RC" -eq 2 ]; then`, and the
# STOP echo inside that branch is what the user reads above the loader's lines.
stop="$(awk '
    index($0, "if [ \"$FLAG_RC\" -eq 2 ]; then") { inb = 1; next }
    inb && /^[ \t]*(elif|else|fi)([ \t;]|$)/ { inb = 0 }
    inb && index($0, "echo \"STOP") { print }' "$REPO/skills/grok-code-review/SKILL.md")"
if [ "$(printf '%s\n' "$stop" | grep -c .)" != 1 ]; then
    FAIL=$((FAIL+1)); echo "  FAIL: grok-code-review: expected exactly one rc=2 STOP, found $(printf '%s\n' "$stop" | grep -c .)"
else
    case "$stop" in
        *'moves the old claude-mesh config'*) PASS=$((PASS+1)); echo "  PASS: grok-code-review's rc=2 STOP defers to the loader's move command" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: grok-code-review's rc=2 STOP does not mention the loader's move command" ;;
    esac
    case "$stop" in
        *'$("$LOADER" config-path)'*) PASS=$((PASS+1)); echo "  PASS: grok-code-review's rc=2 STOP names the file via config-path" ;;
        *) FAIL=$((FAIL+1)); echo "  FAIL: grok-code-review's rc=2 STOP does not name the file via config-path" ;;
    esac
fi
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
