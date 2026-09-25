#!/usr/bin/env bash
# Tests for skills/shared/find-mesh-exec.sh — how mesh-review reaches the mesh-exec plugin.
#
# Order under test: MESH_EXEC_ROOT (a --plugin-dir working tree) → ~/.grok/installed-plugins
# (only inside a Grok session) → ~/.claude/plugins → ~/.grok/plugins, each root on its own and
# version-sorted. A claude-mesh cache left over from before the split must never be taken
# for mesh-exec.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$TESTS_DIR/../find-mesh-exec.sh"
FAIL=0
PASS=0
assert_eq() {
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "  PASS: $1"
    else FAIL=$((FAIL+1)); echo "  FAIL: $1 (expected '$2', got '$3')"; fi
}
assert_has() {
    case "$3" in *"$2"*) PASS=$((PASS+1)); echo "  PASS: $1" ;;
    *) FAIL=$((FAIL+1)); echo "  FAIL: $1 (no '$2' in '$3')" ;; esac
}
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
plant() {   # plant <dir>: a fake mesh-exec root
    mkdir -p "$1/skills/shared" && : > "$1/skills/shared/config-loader.sh"
}
run() {     # run <HOME> [GROK_SESSION_ID] [MESH_EXEC_ROOT] → OUT ERR RC
    OUT="$(env -u MESH_EXEC_ROOT -u GROK_SESSION_ID HOME="$1" ${2:+GROK_SESSION_ID="$2"} ${3:+MESH_EXEC_ROOT="$3"} \
        bash -euo pipefail "$SCRIPT" 2>"$T/err")"; RC=$?
    ERR="$(cat "$T/err")"
}

echo "=== MESH_EXEC_ROOT: a working tree wins over anything installed ==="
H="$T/h1"; plant "$H/.claude/plugins/cache/zinin/mesh-exec/9.9.9"; plant "$T/dev"
run "$H" "" "$T/dev"
assert_eq "rc 0" "0" "$RC"; assert_eq "prints the dev tree" "$T/dev" "$OUT"
run "$H" "" "$T/nowhere"
assert_eq "a MESH_EXEC_ROOT without mesh-exec fails loudly (rc 1)" "1" "$RC"
assert_has "…naming the variable" "MESH_EXEC_ROOT=$T/nowhere" "$ERR"

echo "=== the Claude cache: highest version, and never claude-mesh ==="
H="$T/h2"
plant "$H/.claude/plugins/cache/zinin/mesh-exec/0.9.0"; plant "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0"
plant "$H/.claude/plugins/cache/zinin/claude-mesh/0.15.0"
run "$H"
assert_eq "rc 0" "0" "$RC"
assert_eq "0.16.0 over 0.9.0, the old claude-mesh ignored" "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0" "$OUT"
H="$T/h3"; plant "$H/.claude/plugins/cache/zinin/claude-mesh/0.15.0"
run "$H"
assert_eq "only claude-mesh installed → not found (rc 1)" "1" "$RC"
assert_has "…telling what to install" "mesh-exec@zinin" "$ERR"

echo "=== installed-plugins wins only inside a Grok session ==="
H="$T/h4"
plant "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0"; plant "$H/.grok/installed-plugins/mesh-exec-aabbccdd"
run "$H" "grok-session-1"
assert_eq "Grok session: the snapshot" "$H/.grok/installed-plugins/mesh-exec-aabbccdd" "$OUT"
run "$H"
assert_eq "no Grok session: the Claude cache" "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0" "$OUT"

echo "=== set -euo pipefail: a missing installed-plugins dir falls through ==="
H="$T/h5"; plant "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0"
run "$H" "grok-session-1"
assert_eq "rc 0 under strict mode" "0" "$RC"
assert_eq "…and the Claude cache is found" "$H/.claude/plugins/cache/zinin/mesh-exec/0.16.0" "$OUT"

echo "=== ~/.grok/plugins is the last root ==="
H="$T/h6"; plant "$H/.grok/plugins/cache/z/mesh-exec/1.0.0"
run "$H"
assert_eq "found under .grok/plugins" "$H/.grok/plugins/cache/z/mesh-exec/1.0.0" "$OUT"

echo "=== nothing installed ==="
run "$T/empty"
assert_eq "rc 1" "1" "$RC"
assert_eq "nothing on stdout" "" "$OUT"
assert_has "the message says what to do" "mesh-exec не найден: поставьте mesh-exec@zinin" "$ERR"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
