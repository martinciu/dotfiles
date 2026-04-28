# Global Claude Instructions

## Git and GitHub

- Never add Claude Code as a git commit co-author.
- When pushing a branch to remote, strip the `worktree-` prefix from the
  branch name. Why: local worktree branches are namespaced with `worktree-`
  for the worktrunk/`EnterWorktree` workflow, but the remote should see the
  clean feature-branch name.

## Planning artifacts (Superpowers, Compound Engineering, etc.)

- All specs, plans, and design docs go in `tmp/` (e.g. `tmp/specs/`,
  `tmp/plans/`). `tmp/` is gitignored — these are never committed.
- Never write to `docs/superpowers/`. Superpowers skills default to that
  path, but it is wrong here.
- Worktree directory: `.claude/worktrees/` (project-local; gitignored).

