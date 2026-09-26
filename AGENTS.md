# mesh-review (plugin source)

This file is for work inside this repository. It is not a plugin component.

## Load the working tree

mesh-review needs mesh-exec and session-relay. Load all three working trees and point the
finder at mesh-exec's:

```bash
MESH_EXEC_ROOT=/path/to/mesh-exec claude --plugin-dir /path/to/mesh-exec \
  --plugin-dir /path/to/session-relay --plugin-dir "$PWD"
```

Disable marketplace copies of the three first (`claude plugin disable <name>@zinin`) and
re-enable them afterwards. In Grok install a snapshot of each (`grok plugin install <path>
--trust`), one snapshot per plugin; `MESH_EXEC_ROOT` is not needed there — the finder takes
the `installed-plugins` snapshot inside a Grok session. Grok ignores `dependencies`:
installing mesh-review brings neither mesh-exec nor session-relay. Grok names a snapshot after
its source directory, and the finder matches `mesh-exec` only, so install mesh-exec from a
directory named `mesh-exec` (a copy is fine — refresh it from the working tree before each
reinstall): a checkout still named `claude-mesh` gives `claude-mesh-<hash>`, which the finder
never takes. A snapshot is a copy: after editing a tree, `grok plugin uninstall <name>
--confirm`, install it again and start a new session.

## Cross-plugin contract

mesh-review runs mesh-exec's `config-loader.sh` (subcommands `data-dir`, `config-path`,
`get-flag`, `get-defaults`, `get-runtime`, `list-models`, `list-claude-models`,
`list-grok-models`, `get-codex`, `get-gemini`), `preflight-env.sh`, `watch-runs.sh`,
`verify-delegation.sh`, `watchdog.sh` and `list-host-models.sh`, invokes its exec skills
(`mesh-exec:<engine>-exec`) and executor agents (`mesh-exec:<engine>-executor`) by name, and
reads its run directories directly (`<data-dir>/runs/<engine>/…` with `.session_id`,
`output.txt`, `final/` and `watchdog.log`). A change to that interface ships in the same
release on both sides.

## While working in this repo

- Agents never edit the user's `~/.config/mesh/config.yaml`.
- Do not bump `.claude-plugin/plugin.json` on a feature branch; a release is a separate
  `chore(release): X.Y.Z` commit on master with an annotated tag `mesh-review--vX.Y.Z`.
- Before a PR: `git rm -r docs/superpowers/` when it exists, and commit.
- Tests: `for f in skills/shared/tests/test-*.sh; do bash "$f"; done`.
