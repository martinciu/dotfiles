# Contributing to dotfiles

Thanks for your interest in this repo.

This is a personal setup maintained by one person in spare time — a
multi-theme, multi-font configuration for Ghostty + tmux + vim + fish, wired
together with manual symlinks. It's deliberately opinionated and tailored to
my own machines, and that focus is what keeps it coherent.

## Pull requests

**I'm not accepting external pull requests.** Please don't open one — I'd hate
for you to spend hours on a change I can't merge. With a single maintainer and
limited review bandwidth, taking on outside code would mean either rushing
reviews or letting PRs go stale, and the personal, tightly-tailored scope is
something I want to protect.

That's not a brush-off — there's a better way to help.

## Issues are welcome

Bug reports **and** feature requests are genuinely welcome, and they shape
where this setup goes next. Opening an issue is the real way to influence the
repo — far more effective than a pull request would be.

- **Found a bug?** Open an issue.
- **Want a feature, or a different default?** Open an issue and make the case.

### Filing a good issue

A little detail goes a long way:

- What you ran, and what you expected versus what actually happened.
- Your OS and terminal (this setup targets macOS + Ghostty).
- Which tool, theme, or font is involved (e.g. `theme-set`, `font-set`, or a
  specific config file).
- The output of any relevant `scripts/test-*.sh` smoke test, if one applies.
- Minimal steps to reproduce, if you can.

## Want to change it yourself?

This repo is MIT-licensed — fork it freely and make it your own. The
[Setup (new machine)](README.md#setup-new-machine) section of the README has
everything you need to get a local checkout running, and `CLAUDE.md` documents
the conventions (symlink model, shell and scripting standards).

## Security

Please don't file security reports publicly. Report vulnerabilities privately
through GitHub's advisory flow — see [`SECURITY.md`](SECURITY.md).

## Code of conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By taking
part, you agree to uphold it.
