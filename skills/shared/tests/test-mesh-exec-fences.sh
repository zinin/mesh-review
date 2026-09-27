#!/usr/bin/env bash
# Every bash fence that uses $MESH_EXEC must assign it first.
#
# mesh-review reaches mesh-exec's loader and run scripts through $MESH_EXEC, printed by
# find-mesh-exec.sh. Each fence runs in a fresh shell, so a fence that uses the variable
# without assigning it runs `/skills/shared/config-loader.sh` — a path that does not exist —
# and fails far from the cause. The fences are extracted and checked one by one.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$TESTS_DIR/../../.." && pwd)"
FAIL=0
PASS=0
USES=0
bad=0
for f in "$REPO"/skills/*/SKILL.md "$REPO"/commands/*.md; do
    report="$(awk -v file="${f#"$REPO"/}" '
        /^[ \t]*```bash[ \t]*$/ { in_f = 1; start = NR; assigned = 0; next }
        in_f && /^[ \t]*```[ \t]*$/ { in_f = 0; next }
        in_f {
            line = $0
            if (line ~ /^[ \t]*MESH_EXEC="?\$\(bash "(\$FINDER|\$SKILL_BASE\/\.\.\/shared\/find-mesh-exec\.sh)"\)"? \|\| exit 1[ \t]*$/) { assigned = 1; next }
            tmp = line; gsub(/MESH_EXEC_ROOT/, "", tmp)
            if (tmp ~ /MESH_EXEC=/ && tmp !~ /echo "MESH_EXEC=/) printf "BAD %s:%d MESH_EXEC assigned outside the pinned form\n", file, NR
            if (tmp ~ /\$MESH_EXEC/ || tmp ~ /\$\{MESH_EXEC/) {
                uses++
                if (!assigned) printf "BAD %s:%d (fence from line %d)\n", file, NR, start
            }
        }
        END { printf "USES %d\n", uses }' "$f")"
    USES=$((USES + $(printf '%s\n' "$report" | awk '/^USES/ {print $2}')))
    while IFS= read -r l; do
        [ -n "$l" ] || continue
        bad=$((bad+1)); echo "    $l"
    done < <(printf '%s\n' "$report" | grep '^BAD' || true)
done
if [ "$bad" = 0 ]; then PASS=$((PASS+1)); echo "  PASS: every \$MESH_EXEC use follows its assignment in the same fence"
else FAIL=$((FAIL+1)); echo "  FAIL: $bad use(s) of \$MESH_EXEC before assignment"; fi
if [ "$USES" -ge 10 ]; then PASS=$((PASS+1)); echo "  PASS: the check saw $USES uses (non-vacuous)"
else FAIL=$((FAIL+1)); echo "  FAIL: only $USES uses of \$MESH_EXEC seen — did the fences move?"; fi
echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
