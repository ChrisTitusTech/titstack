# titstack - custom skills for your AI agent

<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/238cb52f-00e0-423b-8f9d-4563e24bb9d8" align="center" />



Reusable Codex instructions, command rules, model profiles, and skills for
Linux, macOS, and Windows. Install the full setup or copy individual skills
from the [skill inventory](docs/SKILLS.md#repository-skills).

## Install

You need Git and an installed, authenticated Codex CLI or desktop app. Use Bash
on Linux/macOS or PowerShell on Windows. Windows requires symbolic-link
permissions; enable Developer Mode to install without an administrator terminal.

Review [global instructions](codex-home/AGENTS.md) and
[configuration defaults](codex-home/config.toml) first. Fresh configs use
GPT-6 Astra, full filesystem access, no approval prompts, and trust repositories
under `~/github`. Adapt these defaults before installing if needed.

```bash
git clone https://github.com/ChrisTitusTech/titstack.git
cd titstack
```

Linux or macOS:

```bash
./scripts/install.sh --dry-run
./scripts/install.sh
```

Windows:

```powershell
.\scripts\install.ps1 -DryRun
.\scripts\install.ps1
```

Restart Codex after installation. Keep this checkout: installed instructions,
rules, profiles, and skills link to it. Replaced targets are backed up under
`~/.codex/backups/`. Credentials, sessions, and caches are untouched.

**Your existing `config.toml` stays unchanged.** Model choices, MCP servers,
project trust, and other settings survive repeat installs. Defaults are copied
only when no config exists. Customize your installed config directly; adopt
future default changes manually. Other managed files are replaced with links.

Plugins are optional: add `--plugins` on Linux/macOS or `-Plugins` on Windows.
See [setup and customization](docs/SETUP.md) for custom paths, plugin selections,
model examples, updates, and recovery instructions.

## Use

Start Codex normally:

```bash
codex
```

Invoke a skill when needed:

```text
$linux-sysadmin diagnose this service failure
```

- [Skills and inventory](docs/SKILLS.md)
- [Planning and pull-request workflow](docs/WORKFLOW.md)
- [PhotoCraft image editing](docs/PHOTOCRAFT.md)
- [Configuration layout](docs/CODEX_LAYOUT.md)
- [Model defaults and rationale](docs/ASTRA.md)

## Contribute

Read [AGENTS.md](AGENTS.md), keep changes focused, and include reproduction
steps and check results with a pull request. Never include credentials or
machine-local state.

```bash
./scripts/validate.sh
```

For full local validation, install Python 3.11+ (or an older Python with
`tomli`), ShellCheck, and the Codex CLI. Some checks are skipped when optional
tools are absent. CI also exercises macOS and Windows installers.

## License

Original repository content is available under the [MIT License](LICENSE).
Third-party reference material retains its upstream license and attribution.
