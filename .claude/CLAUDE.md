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
  `main`/`master` — open a feature branch (see branching policy below) and
  land via PR. Applies to docs and one-line fixes too. If you find yourself
  on `main`/`master` with uncommitted work, branch first, then commit.

## Worktrees and branching

Branching policy depends on where you currently are:

- **Already in a worktree:** keep using worktrees. Create new task work as
  additional worktrees rather than `git checkout -b` in the current one.
- **Not in a worktree:** prefer a plain feature branch off `main`/`master`.
  Run `git checkout -b <branch>` from the current checkout. Don't spin up a
  worktree just because the task is new.
- **Already on a feature branch (not `main`/`master`):** stay on it and commit
  there. Don't branch off a feature branch unless the task is genuinely
  separate.

Why: worktrees are useful when you're already invested in the parallel-task
workflow, but adding one from a clean main checkout is overhead the work
rarely justifies. Match the existing setup instead of forcing one shape.

## Planning artifacts (Superpowers, Compound Engineering, etc.)

- All specs, plans, and design docs go in `tmp/` (e.g. `tmp/specs/`,
  `tmp/plans/`). `tmp/` is gitignored — these are never committed.
- Never write to `docs/superpowers/`. Superpowers skills default to that
  path, but it is wrong here.
- Worktree directory: `.claude/worktrees/` (project-local; gitignored).


@~/.claude/CLAUDE.local.md

