---
name: photocraft
description: Create, inspect, edit, composite, and export images through the photocraft-cli MCP server. Use for image work, layered artwork, photo edits, logos, and thumbnail assembly; combine with task-specific design skills when applicable.
---

# PhotoCraft

Use the native `photocraft-cli mcp` server for image work. Discover the connected
PhotoCraft tools before editing; a binary on PATH alone does not mean an MCP
connection is available. Follow explicit user tool choices and higher-priority
tool requirements.

## Connection and scope

The Titus AI default configuration starts the server with read and write roots
set to its startup directory. Install the CLI, rerun the Titus AI installer to
link this skill and refresh configuration, then restart Codex. No profile is
needed for ordinary CLI or desktop sessions. The optional
`codex --profile photocraft` makes a missing server a startup error. For another client,
configure `photocraft-cli mcp --automation-read-root <artwork-directory>
--automation-write-root <artwork-directory>` using that client's MCP settings.
Use paths within the granted roots; do not broaden them to bypass a denial.

If the connection is unavailable, explain the missing setup before using an
alternative. Do not silently replace the MCP workflow with shell image edits.
AI generation can supply new assets when needed; inspect those assets and use
PhotoCraft for supported assembly, finishing, and export operations.

## Editing workflow

1. Inspect supplied images and establish the required dimensions, format,
   transparency, and output destination. Preserve the source files.
2. Discover tool schemas, then use `session_list` and `doc_inspect` to identify
   existing work. Use `doc_open` for a source or `doc_new` for a new canvas.
   Confirm the target document before mutating a stateful session.
3. Use `command_list` with a relevant filter to discover engine command IDs,
   parameter documentation, and enabled state. Do not guess commands or assume
   every desktop feature is available through headless MCP.
4. Apply supported edits with `command_run`. Keep elements on separate layers
   when future edits or compositing require it. For experiments on existing
   work, discover and use `image.duplicate` to create a separate active copy.
5. Use `command_batch` only for known ordered steps. It is not atomic: successful
   earlier steps remain after failure. Inspect the document and results before
   retrying; undo does not reverse files already written to disk.
6. Render with `doc_render_preview` and inspect the actual image after meaningful
   edits. Check the final export at full resolution as well as its intended
   display size. A successful command is not proof of visual correctness.
7. Save layered work with `doc_save` as `.pcraft` and export the requested image
   with `doc_export`. Save before closing or ending the MCP session. Use new
   output paths unless replacing an existing deliverable is authorized.
8. Verify that the exported artifact exists, has the requested dimensions and
   format, and is accessible to the user. Deliver an absolute local artifact
   link or image embed, not only an MCP preview or a server-relative path.

## Image constraints

- For YouTube thumbnails, also use `youtube-thumbnail` for composition and
  visual acceptance criteria.
- Preserve supplied people as original pixels when identity preservation is
  required. Use separate generated backgrounds or objects and non-generative
  compositing; do not pass the person through generative edits.
- Report unsupported operations or file-access failures accurately. Discover a
  supported alternative before claiming the edit was performed.
- Headless MCP does not require the desktop application. Use desktop-only tools
  only when a separately configured bridge is available and needed.
