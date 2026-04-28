# Global Claude Instructions

This file = cross-project rules every machine should follow (committed via the dotfiles repo).
`~/.claude/CLAUDE.local.md` = personal/machine-local notes (untracked, imported below).

## Git and GitHub

- Never add Claude Code as a git commit co-author.
- When pushing a branch to remote, strip the `worktree-` prefix from the
  branch name. Why: local worktree branches are namespaced with `worktree-`
  for the worktrunk/`EnterWorktree` workflow, but the remote should see the
  clean feature-branch name.
- All changes go through a pull request. Never commit or merge directly to
  `main`/`master` — open a feature branch (preferably a worktree, per below)
  and land via PR. Applies to docs and one-line fixes too. If you find
  yourself on `main`/`master` with uncommitted work, branch first, then commit.

## Worktrees and branching

Default to **worktrees over plain branches** for new task work. A new feature,
bugfix, or experiment gets its own worktree — not a `git checkout -b` in the
current workspace. Why: lets multiple tasks proceed in parallel (each in its
own directory), keeps the main checkout clean for cross-cutting work (reviews,
hotfixes), and matches the dotfiles `.claude/worktrees/` convention.

When the `using-git-worktrees` skill runs (directly or via
`subagent-driven-development` / `executing-plans`), prefer
`wt switch --create <branch>` over the skill's default
`git worktree add … && cd …` sequence:

- wt's path template (`{{ repo_path }}/.claude/worktrees/{{ branch | sanitize }}`)
  already matches the project convention.
- wt runs lifecycle hooks from `.config/wt.toml` (currently none, but available
  later).
- The `wt` shell function propagates CWD via `WORKTRUNK_DIRECTIVE_CD_FILE`, so
  the agent's persistent working directory updates correctly across Bash tool
  calls.

After `wt switch --create`, skip the skill's auto-setup step
(`npm install`, `cargo build`, etc.) when a `pre-start` hook exists — the hook
handles it. Still run the baseline test step the skill prescribes.

If `wt` isn't available in the current project's environment, fall back to the
skill's default `git worktree add … && cd …` flow.

## Planning artifacts (Superpowers, Compound Engineering, etc.)

- All specs, plans, and design docs go in `tmp/` (e.g. `tmp/specs/`,
  `tmp/plans/`). `tmp/` is gitignored — these are never committed.
- Never write to `docs/superpowers/`. Superpowers skills default to that
  path, but it is wrong here.
- Worktree directory: `.claude/worktrees/` (project-local; gitignored).


@~/.claude/CLAUDE.local.md

