# PhotoCraft MCP

PhotoCraft already implements a stateful MCP server in Rust, exposed by
`photocraft-cli mcp`. titstack provides default Codex configuration, a strict optional profile, and an
integration test; no wrapper server, Python SDK, Node runtime, or desktop
window is needed. Python is needed only for the test.

## Setup

Build and install the CLI from a PhotoCraft checkout (Rust 1.95 or newer):

```sh
cd /path/to/photocraft
cargo install --locked --path apps/photocraft-cli
photocraft-cli --version
```

Ensure Cargo's bin directory is on the PATH visible to Codex. It is normally
`~/.cargo/bin` on Linux/macOS or `%USERPROFILE%\.cargo\bin` on Windows.
If using a prebuilt binary instead, it must support `mcp` and the two
`--automation-*-root` flags. This integration was tested with PhotoCraft 0.8.2.

Run the usual titstack installer from this repository:

```sh
./scripts/install.sh
```

On Windows, use `./scripts/install.ps1`. Both installers install the default MCP configuration, the
`photocraft.config.toml` profile, and the `photocraft` skill automatically.
Rerun the installer after updating titstack: existing sessions do not gain
new tools simply because the CLI is installed. Restart Codex (including the
desktop app) and start a session from the directory containing your artwork:

```sh
cd /path/to/artwork
codex --profile photocraft
```

No profile is needed in ordinary CLI or desktop sessions. The explicit profile
above leaves the model unchanged and makes a missing CLI a startup failure.
Default sessions enable PhotoCraft but tolerate an unavailable binary.
Use `/mcp` to inspect the active connection, or `codex mcp get photocraft` to
verify registration. Confirm `~/.agents/skills/photocraft/SKILL.md` exists.
If the skill is missing, rerun the installer before restarting Codex.

## Transport and file access

Both the default configuration and strict profile launch this command over stdio:

```sh
photocraft-cli mcp --automation-read-root . --automation-write-root .
```

The `.` roots resolve against the server's working directory at startup. In
Codex CLI, launch from the intended artwork directory. For other MCP clients,
set the server's working directory explicitly or replace both roots with an
absolute artwork-directory path. There is no listening port or authentication
token in this headless configuration.

Use paths relative to those roots, such as `logos/ctt.pcraft` and
`logos/ctt.png`. PhotoCraft rejects traversal and access outside its granted
roots. These roots grant read and write access throughout the chosen directory;
they do not make overwriting an existing file harmless. Without roots,
PhotoCraft's MCP file operations are denied.

## Tools and example workflow

The managed global instructions route image work to the `photocraft` skill.
It covers command discovery, stateful editing, visual verification, and delivery
of both editable and exported files. The `youtube-thumbnail` skill uses that
workflow for assembly while retaining its source-person preservation rules.
These skills do not start an MCP connection themselves; the installed default
configuration starts it when a new session loads. If the connection or a required operation is
unavailable, report that limitation before choosing another tool.

The server exposes the engine's command registry through `command_list` and
`command_run`, alongside document and preview tools:

| Tool | Purpose |
| --- | --- |
| `session_list` | List documents in the server's current session |
| `doc_new`, `doc_open`, `doc_inspect` | Create, load, and inspect documents |
| `command_list` | Find engine command IDs and parameter documentation |
| `command_run`, `command_batch` | Apply one command or several ordered commands |
| `doc_render_preview` | Return a PNG preview directly to the MCP client |
| `doc_save`, `doc_export` | Save editable `.pcraft` files or export images |
| `doc_close` | Close a document without saving |

For example, ask Codex:

```text
Use the PhotoCraft MCP tools to make a blue-and-white geometric CTT logo.
Discover shape.create's parameters with command_list, create separate shape
layers, render a preview, and save logos/ctt.pcraft plus logos/ctt.png.
```

A minimal tool sequence is:

```json
[
  {"tool":"doc_new","arguments":{"width":256,"height":256,"background":"transparent"}},
  {"tool":"command_run","arguments":{"id":"shape.create","params":{"kind":"rect","rect":[32,32,192,192],"fill":"#165DDE","name":"Blue square"}}},
  {"tool":"doc_render_preview","arguments":{"max_side":256}},
  {"tool":"doc_save","arguments":{"path":"square.pcraft"}},
  {"tool":"doc_export","arguments":{"path":"square.png"}}
]
```

This JSON illustrates separate MCP tool calls; it is not a CLI action file.
The process retains document state between calls. Save before ending the
session. Desktop UI tools require PhotoCraft's separate `--bridge` mode and
are outside this headless profile.

## Verification

Run the repository gate, then the live MCP smoke test:

```sh
./scripts/validate.sh
python3 scripts/test-photocraft-mcp.py
python3 scripts/test-photocraft-mcp.py --config codex-home/photocraft.config.toml
```

To test a locally built binary without installing it:

```sh
python3 scripts/test-photocraft-mcp.py --cli /path/to/photocraft/target/release/photocraft-cli
```

On Windows, use `python` and the `.exe` path. The smoke test uses Python 3.11+
(or Python 3.9+ with `tomli`), reads the selected configuration's arguments (the default config unless overridden), performs an
MCP handshake and tool discovery, creates a shape, checks the PNG preview and
export, reopens the editable file, and verifies out-of-root access is refused.
It uses an isolated temporary directory and requires no model/API credentials.
Missing binaries, timeouts, protocol failures, and failed assertions return a
nonzero exit status. The standard repository gate does not build or download
PhotoCraft; run the live test separately when changing this integration.

References: [Codex MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
and [PhotoCraft CLI source](https://github.com/storytold/photocraft/tree/main/apps/photocraft-cli).
