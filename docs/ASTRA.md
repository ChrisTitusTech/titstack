# Astra configuration and instruction audit

Checked against official OpenAI documentation on 2026-10-06. This is a
quality-to-credit baseline, not a measured optimum.

## Model defaults

| Setting | Choice | Reason |
| --- | --- | --- |
| `model` | `gpt-6-astra` | Preserve the requested model |
| `model_reasoning_effort` | `medium` | Existing live setting and local catalog default |
| `plan_mode_reasoning_effort` | `high` | Retain the existing planning setting |
| `model_verbosity` | `low` | Concise output |
| `features.fast_mode` | `false` | Disable Fast-tier selection in the TUI |
| `service_tier` | unset | Do not request priority processing |

The repo previously installed Sol/high over a live Astra/medium configuration.
The updated defaults resolve that drift. The local model catalog describes
medium as balancing speed and reasoning depth. OpenAI's
[Astra migration guidance](https://developers.openai.com/api/docs/guides/latest-model)
recommends retaining effective effort when migrating from supported levels.

The [pricing page](https://learn.chatgpt.com/docs/pricing) distinguishes included
subscription usage from purchased credits and Enterprise pay-as-you-go usage:

| Speed mode | Included usage multiplier | Purchased-credit / pay-as-you-go multiplier |
| --- | --- | --- |
| Fast | 2.5x | 2x |
| Astra Ultrafast | 8x | 6x |

These are billing multipliers relative to Standard for the same model, not
speed or quality guarantees. Availability depends on plan and workspace.
API dollar prices are separate and do not establish subscription usage saved
per task. Recheck dated rates before making cost decisions.

The [configuration reference](https://developers.openai.com/codex/config-reference)
distinguishes Fast-tier selection from `service_tier`. An explicit task, profile,
project, or app override can supersede global defaults. Existing tasks may retain
their model settings; start a new task and check its model and effort.

For simple work or difficult debugging, use an explicit per-session override:

```bash
codex -c model_reasoning_effort='"low"'
codex -c model_reasoning_effort='"high"'
```

Keep medium as the starting point. Compare accepted results, rework, elapsed
time, and actual account usage on representative tasks before changing the
default further. No credit-savings benchmark was run during this audit.

## October 2026 follow-up

The `python-ai`, `rust-cli`, and `find-skills` skills were removed on
2026-10-27. Their mentions below record the earlier audit, not the current
skill inventory.

The [current model guide](https://learn.chatgpt.com/docs/models) recommends
GPT-6.1 Sol for complex coding and agentic work when available, with Astra for
the most demanding work and Luna for focused tasks. Keep the explicitly chosen
Astra baseline; compare accepted results and actual usage before switching.
GPT-5.5 retires from ChatGPT and Codex on October 14, 2026, but not from the API.
The former `tui.model_availability_nux` entries were notification state, not
model selections. They were removed from the portable configuration along
with personal project paths during the portability cleanup.

The [September 11 skills guidance](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)
emphasizes focused triggers, conditional references, and clear completion
boundaries. The follow-up changes apply it as follows:

- Global instructions authorize validated local commits as work progresses;
  external publication still needs authorization.
- `pr-readiness` selects uncommitted, branch, or commit review scope.
- `hugo` and `mdbook` inspect context relevant to the requested change.
- `python-ai` validates affected components and routes API migrations to a
  dated migration reference (removed with the skill on 2026-10-27).
- `autofix`, `code-review`, and `find-skills` are now repository-managed.
  Local fixes do not imply publication; generic review and how-to requests
  no longer select CodeRabbit or skill discovery indiscriminately.
- [Skill authoring guidance](SKILLS.md) covers invocation policy and behavioral
  evaluation cases. These cases are proposed checks, not claimed passing runs.

All 17 skill entrypoints are in scope; bundled domain manuals are not an
exhaustive current-version audit. Model defaults and security settings remain
unchanged. Plugin-owned skills remain separate and may still overlap; loading
a plugin does not supersede repository review policy.

## September 2026 findings and changes

All 14 repository skill entrypoints, global and root instructions, and the
planning instruction template were inspected. Conditional references were read
where needed to reconcile a finding; bundled upstream manuals were not rewritten.

- Global instructions now resolve skill precedence explicitly, preserve existing
  authorization, scope diagnostic examples, and reuse passing evidence.
- `python-ai` removes an environment dump that could disclose API keys and stops
  requiring speculative feature flags or provider fallbacks.
- `homelab-admin` keeps TLS verification enabled and scopes disruptive testing.
- `linux-sysadmin`, `forgejo-maintainer`, and `podman-operator` distinguish
  diagnosis from mutation, target affected paths, and preserve deployment modes.
  Container inspection must select fields rather than expose credentials.
- `quickshell` and its build reference preserve required features when build
  dependencies are missing.
- `ai-project-manager` scales planning to the request and cannot mark skipped
  required checks complete. Its template reuses prior authorization.
- `pr-readiness` distinguishes local validation from remote merge gates and
  accepts existing independent review evidence when repository policy permits.
- `bash-scripting`, `hugo`, `mdbook`, `rust-cli`, `wayfinder`, and
  `youtube-thumbnail` retain their domain guidance. Planning-only boundaries,
  shell correctness, publication examples, and photographed-person preservation
  remain intact.

OpenAI's [Astra instruction guidance](https://developers.openai.com/api/docs/guides/latest-model#instruction-following)
calls for auditing conflicting skills. Its verification guidance favors relevant
checks over repeated unchanged tests. The changes apply those principles while
retaining required gates.

## Global scope and security

During the September audit, standalone CLI 0.149.0 was rejected by the server
for Astra requests. The then-installed app bundled CLI 0.153.0-alpha.5, which
successfully started Astra review. The local `~/.local/bin/codex` launcher was linked to
`/usr/lib/chatgpt/resources/codex`; its former symlink is backed up under
`~/.codex/backups/astra-cli-20260908-190153/`. This machine-specific repair is
not part of the portable installer. If the app is removed, install a current
standalone CLI before replacing the launcher; restoring the old launcher also
restores its Astra incompatibility.

The installer links global `AGENTS.md` and managed skills into this repository,
so edits to linked files apply globally. The live config is a regular file;
update only the intended model settings when applying this audit to an existing
installation. The normal installer renders broader defaults and trust entries,
so inspect its dry run before using it on a customized machine.

This audit preserves the existing `approval_policy = "never"` and
`sandbox_mode = "danger-full-access"`, trust entries, command rules, disabled
memory features, and machine-local integrations. These are existing full-access
preferences, not a sandboxed security baseline. Written authorization rules do
not create OS isolation. No permission or security control was relaxed for cost.

The October follow-up brings the previously unmanaged `autofix`, `code-review`,
and `find-skills` into the portable skill collection. Preserve existing local
copies in backups before replacing them with managed links. Plugin-owned
caches remain untouched; future upstream updates need re-auditing.

Credentials, session data, runtime caches, and plugin settings are not copied
into this repository. Required verification remains `./scripts/validate.sh`,
skill frontmatter validation, and `codex review --uncommitted` after local gates.
