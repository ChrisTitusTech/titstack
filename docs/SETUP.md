# Setup and customization

Run the commands below from the repository checkout. For a quick start, see
[the README](../README.md).

## Before you install

You need Git and an installed, authenticated Codex CLI or desktop app. This
repository configures Codex; it does not install Codex or provide model access.
Linux and macOS use Bash and standard command-line utilities. Windows uses
PowerShell and requires permission to create symbolic links (enable Developer
Mode for installation without an administrator terminal).

Review [the configuration](../codex-home/config.toml) and
[global instructions](../codex-home/AGENTS.md) first. The defaults select GPT-6
Astra, disable approval prompts, and grant full filesystem access
(`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`). They also
authorize local commits and trust repositories under `~/github`. These are
opinionated defaults that you should adapt to your workflow before installing.
For sandboxed use with approval prompts, change the two settings to
`approval_policy = "on-request"` and `sandbox_mode = "workspace-write"`.
See the official [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

Clone into a permanent location, then enter the repository:

```bash
git clone https://github.com/ChrisTitusTech/titstack.git
cd titstack
```

Keep this checkout after installation: instructions, rules, profiles, and skills
are symbolic links to it. Editing those source files changes the installed
versions immediately. The main config is initialized only when absent, then belongs to you.

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

An existing `config.toml` is left byte-for-byte unchanged, including model
choices, MCP servers, project trust, comments, and unknown settings. A symbolic
link to an existing config file is also preserved. Directories and broken
config links fail before any managed files are changed. The installer does
not validate or repair an existing config. Explicit plugin installation can
still let Codex update its own plugin settings.

Global instructions, the entire rules directory, matching profiles, and
matching skills are still linked to repository versions, with prior targets
backed up. Customizing these linked files edits the checkout. Keep such changes
in your own fork. Unrelated skills and runtime files remain untouched.
The dry run lists file operations, not a configuration diff.

Both installers honor `CODEX_HOME` and `AGENTS_HOME` for custom destinations.
The defaults are `~/.codex` and `~/.agents` (under the Windows user profile on
Windows). Do not point either destination at this checkout.

### Trust GitHub projects

When no config exists, the installer initializes `~/.codex/config.toml` with
trusted-project entries for your `~/github` directory and every Git worktree
found recursively beneath it, including organization or grouping directories.
Common dependency and build directories are skipped during discovery.

Existing configs and trust decisions are preserved. Rerunning the installer
does not add new repositories or change an explicit untrusted entry. Manage
new project trust through Codex or edit your installed config yourself.

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
tier is requested. See [docs/ASTRA.md](ASTRA.md) for the dated rationale,
effort overrides, security boundaries, and skill audit.

Edit `~/.codex/config.toml` (or `CODEX_HOME/config.toml`) for persistent personal
settings. Reinstalling preserves this file. If your account does not offer the
configured model, select an available one with `codex --model MODEL_ID` or
change `model` in your installed config.

Repository defaults in `codex-home/config.toml` apply only when no installed
config exists. To adopt later defaults, compare that file with your installed
config and copy only the settings you want. Back up your config before editing;
do not commit machine-specific paths or credentials to your fork. New settings
and integrations are not merged automatically.

Invoke a skill explicitly when needed:

```text
$linux-sysadmin diagnose this service failure
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

See [docs/WORKFLOW.md](WORKFLOW.md) for the complete lifecycle.

## PhotoCraft image editing

The default configuration connects Codex to the native `photocraft-cli mcp`
server for document creation, shape commands, previews, and image export.
Install the CLI, run the titstack installer to install the skill and configuration,
then restart Codex. If you already have a config, copy the
`[mcp_servers.photocraft]` section from `codex-home/config.toml` into your
installed config if it is missing. Start sessions from your artwork directory; file access is
scoped there. The optional `codex --profile photocraft` makes server startup
required, while ordinary sessions can start on machines without the CLI. See
[PhotoCraft setup and verification](PHOTOCRAFT.md).

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

## Update or undo an installation

Before updating, commit your intentional customizations in your fork. From the
checkout, fetch updates with `git pull --ff-only`, review the changes, then
rerun the platform's dry-run and install commands above. Restart Codex. Linked
files reflect updates immediately; rerunning the installer installs new skills and preserves your main config.
Compare new repository defaults with your config and adopt changes manually.

To undo installation, close Codex and use the `backed up:` paths printed by the
installer to identify the correct backup under `CODEX_HOME/backups/`. Remove
only the managed links pointing into this checkout, then restore their prior
files or directories from that backup. Leave a pre-existing `config.toml` in place. If titstack initialized it,
remove it only if you no longer need it. Older installer backups may contain a
previous config you can restore after saving your current version. Skill backups live under the backup's `agents/`
subdirectory. If a managed target had no previous version, remove only that
installed target. Keep unrelated skills and runtime files. Plugins installed
with the opt-in flag must be managed separately through Codex.

