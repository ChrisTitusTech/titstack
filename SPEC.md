# titstack specification

## Problem

Codex installations mix portable configuration with credentials, sessions,
caches, and other machine-local state. Coding agents also need consistent
instructions and reusable workflows without replacing project-specific
requirements.

## Users

The primary user is a developer who works across Linux, macOS, and Windows and
wants the same safe Codex baseline in multiple repositories.

## Required behavior

- Install global Codex instructions, configuration, rules, local-model
  profiles, and reusable skills from this repository.
- Optionally install an explicit list of recommended Codex plugins from
  configured marketplaces.
- Trust the current user's `~/github` directory and every Git worktree
  discovered recursively beneath it on each installation.
- Preview installation without changing the target system.
- Preserve existing managed targets in timestamped backups before replacement.
- Leave credentials, sessions, history, caches, plugin state, and runtime
  databases untouched unless plugin installation is explicitly requested.
- Support repeated installation without replacing already-correct links.
- Provide project-planning templates and separate planning from pull-request
  readiness.
- Use built-in Codex review with the scope matching uncommitted work, a branch,
  or a commit, with affected validation and review repeated after actionable fixes.
- Commit validated task-owned changes in coherent batches under standing local
  authorization; require separate authorization for publication actions.
- Validate repository structure, configuration syntax, skill metadata,
  documentation consistency, and installer behavior.
- Run Linux, macOS, and Windows validation for pull requests and default-branch
  pushes.

## Architecture

- `codex-home/` contains portable files installed into `CODEX_HOME`.
- The installer renders `config.toml` with machine-specific exact trust entries
  while linking the other managed files.
- `.agents/skills/` contains reusable workflows linked into `AGENTS_HOME`.
- `scripts/install.sh` and `scripts/install.ps1` perform user-scoped
  installation.
- `codex-plugins.txt` records plugin selectors installed only through the
  explicit plugin option.
- `scripts/validate.sh` and installer integration tests provide local and CI
  evidence.
- `AGENTS.md`, this specification, `ROADMAP.md`, and `TASKS.md` define how the
  repository is maintained.

## Security and privacy

- Never track authentication files, session history, caches, logs, or runtime
  databases.
- Do not require administrator privileges for normal installation.
- Keep destructive actions narrowly scoped and require explicit authorization.
- Give GitHub Actions the minimum permissions required by each job.
- Pin third-party actions and let Dependabot keep those pins current.

## Compatibility

- The shell installer targets Bash on Linux and macOS.
- The PowerShell installer targets supported Windows PowerShell environments
  capable of creating symbolic links.
- Optional tools may add validation but must not make ordinary installation
  depend on unrelated developer tooling.

## Non-goals

- Mirroring the complete Codex home directory.
- Managing credentials, plugin caches or authentication, sessions, or caches.
- Installing plugins without an explicit opt-in.
- Replacing project-specific `AGENTS.md` or requirements.
- Installing Codex, Claude Code, third-party review CLIs, or local model
  servers.
- Adding security scanners that do not support the repository's languages.

## Acceptance criteria

- `./scripts/validate.sh` passes from a clean checkout.
- Linux and macOS installer integration tests verify dry-run safety, backup
  preservation, machine-local configuration state, correct links, generated
  GitHub trust entries, and idempotence in isolated temporary directories.
- Windows CI verifies the equivalent PowerShell installer behavior.
- Installer tests verify plugin opt-in and dry-run behavior without contacting
  a live marketplace.
- Every skill has valid front matter and the documented skill inventory matches
  the actual directories.
- The pull-request readiness workflow requires a clean Codex review loop and
  does not depend on a third-party review service.
- Pull requests run validation and dependency review on the latest commit.
- Workflow documentation covers planning, implementation, review, manual
  testing, and merge gates.

## Unresolved questions

- Whether future installers should offer optional user-wide Claude Code
  instructions in addition to the repository-local `CLAUDE.md` routing.
