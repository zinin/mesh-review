#!/usr/bin/env bash
# Contract for the mesh-review wrapper agents and review skills.
#
# claude-code-reviewer dispatches official `claude -p` through mesh-exec's ext-claude-exec
# (HOST_CLAUDE=1): catalog aliases (opus, fable), no tooling constraint, run dirs under
# runs/claude/. The executor half of this file stayed in mesh-exec with the executors.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$TESTS_DIR/../../.." && pwd)"

FAIL=0
PASS=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS+1)); echo "  PASS: $desc"
    else
        FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected '$expected', got '$actual')"
    fi
}

assert_ge() {
    local desc="$1" min="$2" actual="$3"
    case "$actual" in
        ''|*[!0-9]*)
            FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected a count >= $min, got '$actual' — did the file move?)"
            return ;;
    esac
    if [ "$actual" -ge "$min" ]; then
        PASS=$((PASS+1)); echo "  PASS: $desc ($actual >= $min)"
    else
        FAIL=$((FAIL+1)); echo "  FAIL: $desc (expected >= $min, got $actual)"
    fi
}

echo "=== Test: claude CLI reviewer and review skill ==="
assert_eq "reviewer agent exists" "1" "$([ -f "$REPO/agents/claude-code-reviewer.md" ] && echo 1 || echo 0)"
assert_eq "review skill exists" "1" "$([ -f "$REPO/skills/claude-code-review/SKILL.md" ] && echo 1 || echo 0)"
assert_eq "reviewer does not STOP when MODEL is omitted" "0" \
    "$(grep -c 'ERROR: MODEL parameter is required on first line' "$REPO/agents/claude-code-reviewer.md")"
assert_ge "reviewer still invokes skill when MODEL omitted" "1" \
    "$(grep -c 'If the first line is not `MODEL=`, still invoke the skill' "$REPO/agents/claude-code-reviewer.md")"
assert_ge "reviewer names HOST_CLAUDE" "1" \
    "$(grep -c 'HOST_CLAUDE=1' "$REPO/skills/claude-code-review/SKILL.md")"
assert_eq "review skill has no tooling-constraint section" "0" \
    "$(grep -c '## Tooling constraint' "$REPO/skills/claude-code-review/SKILL.md")"

echo ""
echo "=== Test: wrapper dual-path invoke + Grok wait ==="
AGENTS="$REPO/agents"
WRAPPERS="codex-code-reviewer.md gemini-code-reviewer.md grok-code-reviewer.md ext-claude-code-reviewer.md claude-code-reviewer.md"
forbid=0
for f in $WRAPPERS; do
    grep -q 'Do NOT read SKILL.md' "$AGENTS/$f" && forbid=$((forbid+1))
done
assert_eq "no wrapper still forbids reading SKILL.md" "0" "$forbid"
missing=0
for f in $WRAPPERS; do
    grep -q 'If this host has no Skill tool' "$AGENTS/$f" || missing=$((missing+1))
    grep -q 'do not end the turn while the CLI is alive' "$AGENTS/$f" || missing=$((missing+1))
done
assert_eq "every wrapper has dual invoke + Grok wait" "0" "$missing"

echo ""
echo "=== Test: empty-SKILL_BASE else-branch is in the fence ==="
# Prose telling the LLM to rewrite is not enough: the executable fence must contain the find
# fallback. Every resolve-plugin-root.sh call via $SKILL_BASE must sit in `if [ -n "$SKILL_BASE" ]`,
# and the else-branch finds THIS plugin by its own marker, find-mesh-exec.sh.
SKILLS_WITH_RESOLVER="claude-code-review ext-claude-code-review codex-code-review gemini-code-review grok-code-review mesh-design-review"
mismatch=0
for s in $SKILLS_WITH_RESOLVER; do
    f="$REPO/skills/$s/SKILL.md"
    n_resolve="$(grep -c 'bash "$SKILL_BASE/../shared/resolve-plugin-root.sh"' "$f" || true)"
    n_if="$(grep -c 'if \[ -n "\$SKILL_BASE" \]; then' "$f" || true)"
    n_find="$(grep -c 'mesh-review\*/skills/shared/find-mesh-exec.sh' "$f" || true)"
    n_installed="$(grep -c 'installed-plugins' "$f" || true)"
    if [ "$n_resolve" != "$n_if" ] || [ "$n_find" -lt "$n_if" ]; then
        mismatch=$((mismatch+1))
        echo "    mismatch $s: resolve=$n_resolve if=$n_if find=$n_find"
    fi
    if [ "$n_installed" -lt "$n_if" ]; then
        mismatch=$((mismatch+1))
        echo "    mismatch $s: installed-plugins=$n_installed if=$n_if"
    fi
done
assert_eq "every resolver fence has empty-SKILL_BASE else-branch" "0" "$mismatch"

echo ""
echo "=== Test: Grok reads each exec skill from mesh-exec, through find-mesh-exec.sh ==="
# The review skill → exec SKILL.md hop crosses into another plugin. The no-Skill-tool paragraph
# must hand the path to find-mesh-exec.sh (MESH_EXEC_ROOT, then installed-plugins inside a Grok
# session, then .claude, then .grok) and must not name the old plugin.
REVIEW_SKILLS="claude-code-review ext-claude-code-review codex-code-review gemini-code-review grok-code-review"
read_bad=0
for s in $REVIEW_SKILLS; do
    para="$(awk '/If this host has no Skill tool/,/Following the skill/' "$REPO/skills/$s/SKILL.md")"
    printf '%s' "$para" | grep -q 'find-mesh-exec.sh' || { read_bad=$((read_bad+1)); echo "    $s: no find-mesh-exec.sh"; }
    if printf '%s' "$para" | grep -q 'claude-mesh'; then read_bad=$((read_bad+1)); echo "    $s: still names claude-mesh"; fi
done
assert_eq "every review→exec Read goes through find-mesh-exec.sh" "0" "$read_bad"

echo ""
echo "=== Test: resolver fences keep the ROOT ORDER, and the prose agrees ==="
# Every fence holds exactly one find per root, so pairing the i-th line of each root by position
# checks every fence: the installed-plugins line must precede the .claude line, which must
# precede the .grok line.
order_bad=0
for s in $SKILLS_WITH_RESOLVER; do
    f="$REPO/skills/$s/SKILL.md"
    inst="$(grep -boF 'find "$HOME"/.grok/installed-plugins -path' "$f" | cut -d: -f1)"
    cc="$(grep -boF 'find "$HOME"/.claude/plugins -path' "$f" | cut -d: -f1)"
    gp="$(grep -boF 'find "$HOME"/.grok/plugins -path' "$f" | cut -d: -f1)"
    n_i="$(printf '%s\n' "$inst" | grep -c .)"; n_c="$(printf '%s\n' "$cc" | grep -c .)"; n_g="$(printf '%s\n' "$gp" | grep -c .)"
    if [ "$n_i" -eq 0 ] || [ "$n_i" != "$n_c" ] || [ "$n_c" != "$n_g" ]; then
        order_bad=$((order_bad+1)); echo "    $s: find counts installed=$n_i claude=$n_c grok=$n_g"; continue
    fi
    if ! paste <(printf '%s\n' "$inst") <(printf '%s\n' "$cc") <(printf '%s\n' "$gp") | while IFS=$'\t' read -r a b c; do
            [ "$a" -lt "$b" ] && [ "$b" -lt "$c" ] || { echo "    $s: fence order wrong at byte offsets $a/$b/$c"; exit 1; }
        done; then
        order_bad=$((order_bad+1))
    fi
    [ "$(grep -cF 'searches `$HOME/.grok/installed-plugins` first' "$f")" = 1 ] \
        || { order_bad=$((order_bad+1)); echo "    $s: prose does not say installed-plugins first (exactly once)"; }
    [ "$(grep -cF 'searches `$HOME/.claude/plugins` first' "$f")" = 0 ] \
        || { order_bad=$((order_bad+1)); echo "    $s: stale prose says .claude first"; }
done
assert_eq "every skill fence searches installed-plugins, .claude, .grok in that order, and the prose says so" "0" "$order_bad"

echo ""
echo "=== Test: every root-find assignment is guarded against find rc=1 ==="
# The three roots are each a `find | sort | tail` assignment. Any one of them on a missing
# directory is a set -e hole; `|| true` after the assignment is the contract.
unprotected=0
while IFS= read -r line; do
    printf '%s\n' "$line" | grep -q '|| true[[:space:]]*$' && continue
    unprotected=$((unprotected+1))
    echo "    unguarded: $line"
done < <(grep -h 'find "$HOME"/.*/find-mesh-exec.sh' \
    "$REPO"/skills/*/SKILL.md "$REPO"/commands/*.md \
    "$REPO"/skills/shared/resolve-plugin-root.sh || true)
assert_ge "the guard check saw the finds" "20" \
    "$(grep -h 'find "$HOME"/.*/find-mesh-exec.sh' "$REPO"/skills/*/SKILL.md "$REPO"/commands/*.md "$REPO"/skills/shared/resolve-plugin-root.sh | grep -c .)"
assert_eq "every root find assignment ends with || true" "0" "$unprotected"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" = "0" ]
