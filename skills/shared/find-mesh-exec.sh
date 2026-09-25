#!/usr/bin/env bash
# find-mesh-exec.sh — print the root of the mesh-exec plugin that mesh-review should use.
#
# mesh-review runs mesh-exec's scripts (config-loader.sh, preflight-env.sh, watch-runs.sh,
# verify-delegation.sh, watchdog.sh, list-host-models.sh) and reads its exec skills. They live
# in another plugin, so no path relative to this file reaches them.
#
# Search order, first hit wins:
#   1. $MESH_EXEC_ROOT — a working tree loaded with --plugin-dir. Set but wrong is an error,
#      not a reason to fall back: a dev run must not quietly test the installed copy.
#   2. ~/.grok/installed-plugins — only inside a Grok session (GROK_SESSION_ID set): an
#      unpublished `grok plugin install <tree>` snapshot, the copy `grok inspect` loads.
#   3. ~/.claude/plugins — the marketplace copy; Grok loads it from here too.
#   4. ~/.grok/plugins.
# Each root is searched on its own and version-sorted: one find over several roots would let
# `sort -V` compare whole paths, and `.claude` < `.grok` would decide instead of the version.
# The pattern names mesh-exec only, so a claude-mesh cache left from before the split is
# never taken for it.
set -u
marker="skills/shared/config-loader.sh"
if [ -n "${MESH_EXEC_ROOT:-}" ]; then
    if [ -f "$MESH_EXEC_ROOT/$marker" ]; then
        (cd "$MESH_EXEC_ROOT" && pwd)
        exit 0
    fi
    echo "find-mesh-exec: MESH_EXEC_ROOT=$MESH_EXEC_ROOT has no $marker" >&2
    exit 1
fi
found=""
[ -z "${GROK_SESSION_ID:-}" ] || found="$(find "$HOME"/.grok/installed-plugins -path "*mesh-exec*/$marker" 2>/dev/null | sort -V | tail -1)" || true
[ -n "$found" ] || found="$(find "$HOME"/.claude/plugins -path "*mesh-exec*/$marker" 2>/dev/null | sort -V | tail -1)" || true
[ -n "$found" ] || found="$(find "$HOME"/.grok/plugins -path "*mesh-exec*/$marker" 2>/dev/null | sort -V | tail -1)" || true
if [ -n "$found" ]; then
    (cd "$(dirname "$found")/../.." && pwd)
    exit 0
fi
echo "mesh-exec не найден: поставьте mesh-exec@zinin (mesh-review работает через него)" >&2
exit 1
