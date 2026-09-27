# Changelog

All notable changes to mesh-review will be documented here.

## [Unreleased]

### Changed
- **Split out of claude-mesh 0.15.0.** `/mesh-review`, `/mesh-design-review`,
  `auto-decide-disputed`, the two review prompt generators, the five `*-code-review` skills and
  `*-code-reviewer` agents, and `review-discussion` moved here with their history. Names
  change: `/claude-mesh:mesh-review` is `/mesh-review:mesh-review`.
- **Depends on mesh-exec and session-relay** (`dependencies` in `plugin.json`). The loader and
  the run scripts are mesh-exec's; `skills/shared/find-mesh-exec.sh` finds its root.
- **The config is mesh-exec's `~/.config/mesh/config.yaml`**, runs live under
  `~/.local/state/mesh/runs/`. With no config yet, the orchestrators pass on the loader's
  message, which names the command that copies an old claude-mesh config into place.
