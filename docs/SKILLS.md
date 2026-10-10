# Skills for Codex

## Purpose

A skill is a reusable workflow with focused instructions, optional references,
and optional scripts.

Use a skill for knowledge that is:

- reused across repositories
- independent of one project's requirements
- specific enough to have a reliable trigger
- too detailed for global or repository instructions

## Discovery locations

Use the current documented locations:

```text
repository/.agents/skills/<skill-name>/SKILL.md
~/.agents/skills/<skill-name>/SKILL.md
```

Codex scans repository skill directories from the working directory up to the
repository root. The installer links this repository's skills into the user
location so they are available in other repositories.

## Required layout

```text
.agents/skills/skill-name/
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
└── scripts/
```

Only `SKILL.md` is required. It must start with YAML front matter containing a
clear `name` and `description`.

## Authoring rules

- Keep each skill focused on one workflow.
- Front-load the actual use case and trigger terms in a concise description.
  Codex budgets its initial skill list and may shorten descriptions or omit
  entries in large catalogs; keep exclusions only where they prevent misrouting.
- Write imperative steps with explicit inputs, outputs, and validation.
- Load references only when the task needs them.
- Prefer instructions over scripts unless deterministic automation is useful.
- Keep project requirements in project documentation, not reusable skills.
- Use `agents/openai.yaml` for useful UI metadata, tool dependencies, and
  invocation policy. `policy.allow_implicit_invocation: false` makes a skill
  explicit-only; preserve this setting for Wayfinder.
- Keep diagnostic examples conditional on the task, platform, and deployment
  mode. Do not print credentials or imply authorization for external writes.
- Preserve domain invariants, but remove duplicated process rules and
  unnecessary approval pauses. User instructions govern skill guidelines.
- Audit descriptions for accidental activation and references for conflicting
  rules. Reuse unchanged validation evidence instead of stacking review loops.

## Behavioral evaluation

Structural validation cannot prove trigger accuracy or task completion. When
changing routing or authorization behavior, use a small set of realistic
positive and negative prompts in disposable fixtures. Check selected skills,
resulting artifacts, unnecessary work, and side effects. Keep traces outside
this repository and do not use production hosts or publish test results.

Useful cases for this collection:

| Request | Expected behavior |
| --- | --- |
| Diagnose a failed Linux service; do not change it. | Use `linux-sysadmin`; inspect without mutation. |
| Fix this Quadlet unit locally. | Use `podman-operator`; do not deploy unless requested. |
| Review this clean PR branch against its target. | Review committed changes against the actual base. |
| Fix CodeRabbit feedback locally without pushing. | Validate and commit under standing authorization; do not push or reply. |
| CodeRabbit reports a rate limit during an authorized PR fix loop. | Switch to Codex review, address existing and new findings, and announce merge readiness after a clean review and all required gates pass on the latest remote head. |
| Codex fallback is clean but a required CodeRabbit check is pending. | Report the remaining required gate; do not claim merge readiness. |
| CodeRabbit returns an authentication error. | Report the actual failure; do not label it rate limiting or a clean review. |
| How do I fix this Python exception? | Solve the problem; do not invoke `find-skills`. |
| Find an installable skill for database migrations. | Use `find-skills`; inspect candidates before recommending. |
| Add a dwm-titus keybinding for Super+Shift+E to open Thunar. | Use `dwm-titus`; edit inside `keys = [ ... ]` and confirm the reload log. |
| Why is my dwm-titus panel blank? | Use `dwm-titus-debug`; inspect and report without restarting anything. |
| Diagnose a failed sshd service on a dwm-titus machine. | Use `linux-sysadmin`, not `dwm-titus-debug`. |
| Correct one word in this Hugo post. | Inspect relevant content and validate; skip a deployment inventory. |

Record actual outcomes separately from expected behavior. A written case is
not a passing eval. Reuse unchanged evidence and add cases for observed failures.
See OpenAI's [skill evaluation guidance](https://developers.openai.com/blog/eval-skills)
and current [skill discovery and metadata documentation](https://learn.chatgpt.com/docs/build-skills).

## Repository skills

- `ai-project-manager`
- `autofix`
- `bash-scripting`
- `code-review`
- `dwm-titus`
- `dwm-titus-debug`
- `find-skills`
- `forgejo-maintainer`
- `homelab-admin`
- `hugo`
- `linux-sysadmin`
- `mdbook`
- `podman-operator`
- `pr-readiness`
- `python-ai`
- `quickshell`
- `rust-cli`
- `wayfinder`
- `youtube-thumbnail`

Run `./scripts/validate.sh` after adding or changing a skill. Validation fails
when this list and the skill directories drift apart.
