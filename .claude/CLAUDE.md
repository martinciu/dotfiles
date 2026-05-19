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

## Worktree commands — always `wt`, never `git worktree`

For any worktree operation (create, switch, remove, list) use the
worktrunk CLI (`wt`). Never use `git worktree add`/`remove`/`move`,
and never `rm -rf` a worktree directory by hand.

- Create: `wt switch --create <branch>`
- Remove: `wt remove [<branch>...]`
- Switch / list: `wt switch <branch>`, `wt list`

Why: worktrunk's lifecycle hooks (`pre-start`, `post-start`,
`pre-remove`, `post-remove`, etc.) only fire through `wt`. This
setup relies on them — `[post-start] copy = "wt step copy-ignored"`
carries gitignored content (`.superpowers/`, `.autonomo/`,
`.claude/settings.local.json`, etc.) into new worktrees, and
`[pre-remove] save-shared` runs `wt step copy-ignored` in reverse
to flow gitignored content (specs, plans, autonomo logs,
`autonomo-workspace/`, anything else gitignored) back to the
primary worktree before deletion. Bypassing `wt` silently skips
both, which usually means lost specs/plans/logs.

How to apply: when a task says "spawn a worktree for X", "switch
to the foo worktree", or "remove/cleanup the worktree", reach for
`wt` first. Cleanup of multiple merged worktrees is `wt list`
(merged ones are dimmed) followed by `wt remove a b c` — there is
no `wt prune` / `wt cleanup`. Only fall back to raw `git worktree`
if `wt` itself is unavailable, and call that out before doing it.

## Worktree cleanup — cheapest-signal-first before `wt remove`

`wt list`'s `⊂` marker is a strict ancestor check (`git branch --merged`).
It misses squash-merges by design, so worktrees that landed on `main` via a
squash-merged PR show as `↑/✗` indefinitely. Worktrunk has a patch-id
fallback (since v0.34, max-sixty/worktrunk#1820) but it only fires when
`git merge-tree` reports a conflict — when `main` has moved many commits
past the squash with no contested lines, the fallback never runs and the
branch stays undimmed.

When deciding whether a worktree is safe to remove (especially one shown
as `↑/✗`), run these checks in cost order. Stop at the first positive
signal — don't run a more expensive check after a cheaper one has already
confirmed merged.

1. **Branch name encodes an issue/PR number** (e.g. `100-legend`,
   `134-preserve-scroll`) — extract the leading number `N`.
2. **Local commit-message grep (instant)** —
   `git log main --oneline --grep '#<N>' -1`. Squash-merged PRs land on
   `main` with `(#<PR-number>)` in the subject and often `closes #<N>` in
   the body. A hit ⇒ the work is in main.
3. **Local ancestor check (instant)** —
   `git branch --merged main | grep <branch>`. Catches non-squash merges
   (rebase, fast-forward, merge-commit). Redundant with the `⊂` marker
   but cheap enough to run as a sanity check.
4. **GitHub issue state (one API call, ~200ms)** —
   `gh issue view <N> --json state,closedAt`. Closed ⇒ likely merged
   but not authoritative (issues close for "won't fix" / "duplicate" too).
5. **GitHub PR state (one API call, ~200ms)** —
   `gh pr list --head <branch> --state merged --limit 1`. Authoritative
   on whether a PR with this branch ref was merged.
6. **Patch-id equivalence (local, slowest)** —
   `git cherry main <branch>`. All commits prefixed `-` ⇒ squash-merged
   via patch-id matching. The final fallback — catches squash-merges
   even when no PR-number convention exists in the commit subject.

Once a positive signal is found, proceed with `wt remove <branch>` per
the always-`wt` rule above. If all six checks fail, the worktree
contains unmerged work — surface the local commits to the user before
removing anything.

Why: cheap local greps are ~10ms each; `gh` API calls are ~200ms each.
For a `wt list` of 30 stale worktrees, running steps 1–3 across all of
them costs <1s total and catches the common case (squash-merged with PR
number in the subject). Reserve the network checks (4–5) and the
heavier `git cherry` scan (6) for branches that survive the cheap pass.

## Exploration scope — ignore other worktrees

When exploring a repo (Read, Grep, Glob, or shell `find`/`rg`), never
descend into `.claude/worktrees/`. Those directories are isolated checkouts
of the same repo used for parallel task work — they are not additional
source. Reading them duplicates results, pollutes search output with stale
branches, and risks acting on code from an unrelated task.

How to apply:

- Skip `.claude/worktrees/**` when listing files, grepping, or globbing.
- When running `rg`/`find` via Bash, exclude the path explicitly
  (`rg --glob '!.claude/worktrees'`, `find . -path ./.claude/worktrees -prune -o ...`).
- If a search legitimately needs to span worktrees (rare — usually only
  when comparing branches), say so first and confirm before proceeding.

## Planning artifacts (Superpowers, Compound Engineering, etc.)

- All specs, plans, and design docs go in `.superpowers/` (e.g.
  `.superpowers/specs/`, `.superpowers/plans/`). `.superpowers/` is
  gitignored — these are never committed.
- Never write to `docs/superpowers/`. Superpowers skills default to that
  path, but it is wrong here.
- `/autonomo` run logs and bail reports go in `.autonomo/` (e.g.
  `.autonomo/<slug>-<RUN_TIMESTAMP>.log` and
  `.autonomo/<slug>-<RUN_TIMESTAMP>.md`). `.autonomo/` is gitignored —
  these are never committed. The skill's SKILL.md hardcodes
  `tmp/autonomo/` in its examples; override that path to `.autonomo/`
  when running the skill.
- Worktree directory: `.claude/worktrees/` (project-local; gitignored).

## Issue tracking — GitHub, not beads

When I say "create a card" / "open an issue" / "track this as work", that
means a **GitHub issue** (`gh issue create`), **not** a bd issue
(`bd create`). Beads is reserved for tracking the `/mc:*` slash-command
workflow (mc:brainstorm → mc:execute → mc:fix → mc:review → mc:workflow),
not general task planning.

Why: planning, feature scoping, follow-ups, and cross-tool work all live
in GitHub — that's where conversation history, labels, milestones, and
PR linkage are. A planning card filed into beads is buried: invisible to
collaborators (typical stealth-mode init), can't be linked cleanly from
a PR, and doesn't show up in `gh issue list` / `gh dash`.

How to apply:

- Default to `gh issue create` for any planning / follow-up / "this
  should be tracked" ask. Match the project's existing issue style (one
  emoji in title, structured body with emoji-prefixed headings/bullets)
  and reference parent issues with `Parent: #N`.
- Use `bd create` only when the work is explicitly part of an `/mc:*`
  flow — a brainstorm spawning child tasks, an execute step needing a
  sub-issue, a fix queued for `mc:fix` to pick up.
- Dupe-check before creating: skim `gh issue list --state=all --search
  "<keyword>"`. `bd search` queries a different (per-project, stealth)
  store and won't surface GitHub issues.

## Superpowers in auto mode

Auto mode doesn't relax Superpowers' clarifying-question phase. When a
Superpowers skill (`brainstorming`, `writing-plans`, etc.) is active,
ask every clarifying question the skill prescribes — one at a time —
before proposing a design, approach, or plan. Don't bundle questions,
don't shortcut to a recommendation, don't assume on the user's behalf.
Auto mode's "prefer action, make reasonable assumptions" applies to
mechanical execution, not to intent gathering.

## Plan execution — SDD vs inline

When a plan is ready to execute, choose between Subagent-Driven Development
(SDD: a fresh subagent per task with two-stage review) and inline execution
(run the tasks directly in the current session). Don't default to SDD just
because Superpowers labels it "recommended" — that label is generic.

- **Pick inline when** most tasks are mechanical edits where the plan
  dictates the exact bytes (TOML/YAML/HTML fragments, single-line config
  changes, dotfiles, cheatsheet updates), constrained to one or two files
  per task with no branching judgment, or sensitive to working-directory
  discipline (worktrees, monorepos with multiple checkouts) — a fresh
  subagent can't inherit your `cd` context.
- **Pick SDD when** most tasks are real code with logic, tests, and
  multi-file integration; roughly 50–300 lines of new/changed code per
  task with judgment calls the plan doesn't fully specify; and quality
  matters enough that two-stage review (spec compliance, then code
  quality) earns its cost.
- **Mixed plan:** do the first task inline to feel out the profile, then
  switch to SDD only if subsequent tasks are heavier than the first.

State the choice and the reason in one sentence before starting
("Inline — Tasks are TOML/HTML edits with bytes specified" / "SDD —
each task is ~150 lines of TS with branching logic"). Forces honesty
about the call.

Why: SDD's value is fresh per-task context plus quality gates on judgment.
Mechanical dotfiles/config work has no judgment surface for "code quality
review" to assess, and the subagent's fresh context drops the working-
directory discipline the controller is carrying — which is exactly the
discipline that matters most in a worktree-heavy setup.


## Language runtimes — preferred install methods

For Python, Ruby, Rust, and Node, prefer the **specialized tool** if it
offers something `mise` can't replicate; otherwise use `mise`.

- **Rust → `rustup`**. Toolchain channels (stable/beta/nightly), components
  (`clippy`, `rustfmt`, `rust-analyzer`), and `rust-toolchain.toml`
  per-project pinning. `mise`'s rust plugin wraps `rustup` anyway and
  loses the ergonomics.
- **Python → `uv` (preferred) or `mise`**. `uv` covers the whole Python
  lifecycle: installs interpreters, runs scripts (`uv run`), manages
  projects (`uv init` / `add` / `sync`), installs CLIs (`uv tool`),
  provides a pip-compatible surface (`uv pip`). 10–100× faster than
  `pip`. Use `mise` only if consistency with other runtimes outweighs
  `uv`'s lifecycle wins.
  - **Global `python3` on PATH:** `uv python install <ver> --default`
    drops `python` / `python3` / `python3.<minor>` symlinks into
    `~/.local/bin`. Without `--default`, uv interpreters are reachable
    only through `uv run` / `uv tool`, and bare `python3` falls through
    to Apple's 3.9.6 (EOL Oct 2025).
  - **Apple's `/usr/bin/python3`** is system-only — used by macOS
    internal scripts (Xcode, launchd, App Bundles). Leave it physically
    untouched. After `--default` it stops being the PATH default;
    reach it by full path if a system tool needs it.
  - **No system `pip`.** Inside a project: `uv add` (modifies
    `pyproject.toml`) or `uv pip install` (pip-syntax shim). One-off
    script: `uv run --with <pkg> script.py`. One-off CLI: `uvx <cli>`.
    Never need `pip3` on PATH.
- **Node → `mise`**. No specialized Node manager offers materially more.
  `fnm` is faster but offers nothing else; `nvm` is shell-script-slow.
- **Ruby → `mise`**. Same logic. `rbenv`/`chruby` are good but offer
  nothing `mise` doesn't.

### Anti-patterns — avoid

- ❌ `brew install python` / `brew install python@3.x` (except as a
  transitive dep of another formula like `platformio`).
- ❌ `brew install rust` / installing `rustup-init` and ignoring its
  toolchain machinery afterwards.
- ❌ Mixing `nvm` + `mise` (PATH conflicts, double-shimming).
- ❌ `pipx` once `uv` is available — `uv tool install` supersedes it.
- ❌ Installing Python-based CLIs via `brew` when `uv tool install <cli>`
  works (e.g. `httpie`, `yt-dlp`, `aws-cli`, `platformio`). Brew formulas
  pin a specific brew Python and force a parallel Python stack.
- ❌ Apple's `/usr/bin/python3` for development — frozen at 3.9.6,
  EOL Oct 2025, PEP 668 lockdown blocks system-wide `pip`.
- ❌ System `pip` / `pip3` on PATH — superseded by `uv add` and
  `uv pip` inside venvs.

How to apply: when adding/upgrading a runtime or a Python CLI, default
to the row above. If a brew formula hard-depends on a brew Python
runtime, prefer reinstalling the tool via `uv tool install` and
removing the brew formula instead of carrying both Python stacks.

## Shell preferences

Fish is the only shell I want to maintain config for. When a task involves
adding or modifying shell config (completions, aliases, functions, prompt
glue, hooks), do it in fish only — do not write a parallel zsh version,
do not "port to zsh later", do not suggest it. Existing zsh config stays
working but is in maintenance mode; don't extend it.

How to apply: when asked to add a shell-level feature, write the fish
version and stop. If a project-level CLAUDE.md still references zsh
parity (e.g. dotfiles/CLAUDE.md), follow the user's per-project guidance
but default to fish-only when the project rule is silent.

@~/.claude/CLAUDE.local.md

