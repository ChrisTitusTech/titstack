# titstack

Portable Codex configuration, rules, and reusable skills.

## Install

Preview and install on Linux or macOS:

```bash
./scripts/install.sh --dry-run
./scripts/install.sh
```

On Windows, run the PowerShell installer from the repository root:

```powershell
.\scripts\install.ps1 -DryRun
.\scripts\install.ps1
```

Restart Codex after installation. Existing managed files are backed up under
`~/.codex/backups/`. Credentials, sessions, history, caches, and plugins are
not changed by default.

The installer manages:

- `codex-home/` configuration and rules in `~/.codex/`
- `.agents/skills/` into `~/.agents/skills/`

### Trust GitHub projects

Every installation renders `~/.codex/config.toml` with trusted-project entries
for that user's `~/github` directory and every Git worktree found recursively
beneath it. This includes repositories inside organization or grouping
subdirectories.

Codex trust entries match exact project roots rather than directory globs, so
the installer discovers each repository instead of relying on a parent or `*`
entry. Rerun the installer after creating or cloning repositories so new
worktrees are added. Common dependency and build directories are skipped during
discovery.

### Install recommended plugins

[Codex plugin](https://learn.chatgpt.com/docs/plugins) installation is opt-in
because plugins can add instructions, hooks, and connections to external
services. Preview or install the repository's selected plugins on Linux or
macOS with:

```bash
./scripts/install.sh --dry-run --plugins
./scripts/install.sh --plugins
```

On Windows:

```powershell
.\scripts\install.ps1 -DryRun -Plugins
.\scripts\install.ps1 -Plugins
```

The selected plugin IDs live in `codex-plugins.txt`. The initial selection is
`superpowers@openai-curated`. Start a new Codex session after installation so
its skills become available. The managed global instructions tell Codex to
skip the full Superpowers methodology for trivial, low-risk edits.

For GitHub-heavy projects, the broader priority order is:

1. **Superpowers plugin** for planning, TDD, debugging, and delivery workflows.
2. **GitHub plugin** for pull requests, issues, reviews, and repository
   operations.
3. **Context7 MCP server** for current framework and dependency documentation.
4. **Playwright or Chrome DevTools MCP server** for frontend testing and
   browser debugging.
5. **Codex Security plugin** for vulnerability analysis and remediation.
6. **Sentry plugin** for production debugging.

Only the entries in `codex-plugins.txt` are installed by `--plugins`. Context7,
Playwright, and Chrome DevTools are
[MCP servers](https://learn.chatgpt.com/docs/extend/mcp) rather than plugins and
require separate configuration. GitHub, Codex Security, and Sentry remain
opt-in until they are added to the manifest because they can require service
authorization or project-specific setup. Plugin directories do not provide
reliable public installation counts, so the ranking is based on fit for this
workflow rather than unverifiable popularity.

## Use

Start Codex normally to use the default configuration:

```bash
codex
```

Defaults use GPT-6 Astra with medium reasoning, high reasoning in Plan mode,
and low verbosity. Fast-mode selection is disabled and no priority service
tier is requested. See [docs/ASTRA.md](docs/ASTRA.md) for the dated rationale,
effort overrides, security boundaries, and skill audit.

Invoke a skill explicitly when needed:

```text
$linux-sysadmin diagnose this service failure
$python-ai add an Ollama-backed model provider
$rust-cli add a new subcommand
```

Codex can also select skills automatically based on their descriptions.

## AI development workflow

The reusable workflow separates planning from pull-request readiness:

- `$ai-project-manager` reads or creates `AGENTS.md`, `SPEC.md`, `ROADMAP.md`,
  and `TASKS.md`, pauses at plan-approval boundaries, and executes one
  reviewable phase at a time.
- `$pr-readiness` validates the final diff and selects built-in Codex review
  for uncommitted work, the actual target branch, or a commit. It resolves
  actionable findings, records manual testing, and verifies CI before merge.
- Completed changes are committed in validated batches under the global
  instructions. Pushes and pull requests still require authorization.

Project-document templates live under
`.agents/skills/ai-project-manager/assets/project-docs/`. Adapt them to the
project instead of leaving placeholder requirements.

See [docs/WORKFLOW.md](docs/WORKFLOW.md) for the complete lifecycle.

## PhotoCraft image editing

The default configuration connects Codex to the native `photocraft-cli mcp`
server for document creation, shape commands, previews, and image export.
Install the CLI, run the Titus AI installer to install the skill and configuration,
then restart Codex. Start sessions from your artwork directory; file access is
scoped there. The optional `codex --profile photocraft` makes server startup
required, while ordinary sessions can start on machines without the CLI. See
[PhotoCraft setup and verification](docs/PHOTOCRAFT.md).

## Local models

Local model profiles are optional and do not change the default provider.

Ollama:

```bash
ollama pull qwen3-coder
codex --profile ollama
```

llama.cpp:

```bash
llama-server --model /path/to/model.gguf --jinja --port 8080
codex --profile llamacpp
```

Override either profile's model with `--model`:

```bash
codex --profile ollama --model another-model
codex --profile llamacpp --model another-model
```

Local models need reliable structured tool calling for effective Codex use.
The llama.cpp profile expects a Responses-compatible endpoint at
`http://127.0.0.1:8080/v1`.

## Validate

```bash
./scripts/validate.sh
```

The validation includes an isolated Linux or macOS installer integration test.
GitHub Actions also exercises the PowerShell installer on Windows and runs
dependency review for pull requests.

## Repository layout

- `AGENTS.md`: instructions for maintaining this repository
- `SPEC.md`, `ROADMAP.md`, and `TASKS.md`: requirements, phase order, and
  validated task status
- `.agents/skills/`: reusable skills
- `codex-plugins.txt`: opt-in Codex plugin selections
- `codex-home/`: portable global instructions, configuration, profiles, and rules
- `docs/`: reference documentation loaded only when explicitly requested
- `scripts/`: installation and validation

See [docs/CODEX_LAYOUT.md](docs/CODEX_LAYOUT.md) for detailed discovery and
configuration behavior.
