# mesh-review

Multi-model review orchestrated from inside the agent session: `/mesh-review:mesh-review` for
code, `/mesh-review:mesh-design-review` for a design document and its plan. Reviewers run in
parallel — the session's own model, Codex, Gemini, Grok and alt-provider models — and the
orchestrator merges their findings, fixes the clear ones and walks you through the disputed
ones. For Claude Code and Grok. Split out of claude-mesh 0.15.0.

For everyday code review consider [herdr-review](https://github.com/zinin/herdr-review): it runs
under any harness and keeps every reviewer in a visible tab. mesh-review stays for sessions
without herdr and for design review, which herdr-review does not do.

## Commands and skills

- **`/mesh-review:mesh-review`** — orchestrate code review across multiple models in parallel;
  add `autodecide` to have the disputed issues decided for you — same full analysis, an explicit
  self-check, one commit per decision. `default` runs the `defaults.code_review` preset,
  `BASE_BRANCH=<branch>` sets the base.
- **`/mesh-review:mesh-design-review`** — iterative design-doc review with discussion of issues;
  remembers earlier answers and filters duplicates; takes the same `autodecide` argument.
- **`/mesh-review:auto-decide-disputed`** — invoke mid-review to hand the remaining disputed
  issues to the agent itself: it writes the same structured analysis, rebuts its own
  recommendation in a `Проверка решения` section, marks each decision `уверенно` /
  `под вопросом`, and commits them one by one — `git log --grep=auto-decide-disputed` lists the
  run, `git revert` undoes any single decision.
- **`/mesh-review:code-review-fresh-session`, `/mesh-review:design-review-fresh-session`** —
  sandbox-aware prompts for a fresh session that reviews rather than implements. They never
  name a model: the session runs mesh-exec's `skills/shared/preflight-env.sh` where it actually
  lives and picks reviewers from what that reports — for a review in another machine, VM or
  sandbox with its own `config.yaml`.
- **Reviewer agents `mesh-review:codex-code-reviewer`, `gemini-code-reviewer`,
  `grok-code-reviewer`, `ext-claude-code-reviewer`, `claude-code-reviewer`** and the matching
  `/mesh-review:<engine>-code-review` skills — one external reviewer each, run through
  mesh-exec's exec skills. The grok reviewer takes a `MODEL` from the `grok.models` catalog, so
  one review can run several grok models; `claude-code-reviewer` is how `builtin: claude`
  resolves on Grok, where there is no in-process Claude.
- **Grok Build** — both orchestrators detect Grok by the presence of `spawn_subagent` and
  dispatch native `general-purpose` reviewers (`builtin: native`, slugs from `grok models`)
  alongside the CLI wrappers.

## Requires

- **mesh-exec** — the config loader, the run scripts, the exec skills and the executor agents.
  Claude Code installs it together with mesh-review (`dependencies` in `plugin.json`).
  `skills/shared/find-mesh-exec.sh` finds it: `$MESH_EXEC_ROOT`, then
  `~/.grok/installed-plugins` inside a Grok session, then `~/.claude/plugins`, then
  `~/.grok/plugins`.
- **session-relay** — design review ends by handing over to
  `/session-relay:continue-plan-fresh-session`.
- **The config** is mesh-exec's `~/.config/mesh/config.yaml`; review presets live in its
  `defaults:` section, runs under `~/.local/state/mesh/runs/`. See mesh-exec's README.

## Install

### Claude Code

```
/plugin marketplace add zinin/agent-plugins
/plugin install mesh-review@zinin
```

### Grok

Loaded from the Claude Code install. Without Claude Code: `grok plugin marketplace add
zinin/agent-plugins`, then `grok plugin install <name> --trust` for mesh-exec, session-relay
and mesh-review.

### Codex

Not supported: the orchestrators dispatch plugin agents, and Codex has none.

## Tests

`for f in skills/shared/tests/test-*.sh; do bash "$f"; done`

## License

MIT — see [LICENSE](LICENSE).
