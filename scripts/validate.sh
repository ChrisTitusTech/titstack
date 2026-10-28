#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0
python_cmd=""
python_seen=0
powershell_cmd=""
host_os="$(uname -s)"

for candidate in python3 python; do
  if ! command -v "$candidate" >/dev/null 2>&1; then
    continue
  fi
  python_seen=1
  if "$candidate" -c 'import sys; __import__("tomllib" if sys.version_info >= (3, 11) else "tomli")' >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done

powershell_candidates=(pwsh)
case "$host_os" in
MINGW* | MSYS* | CYGWIN*)
  powershell_candidates+=(powershell.exe powershell)
  ;;
esac

for candidate in "${powershell_candidates[@]}"; do
  if command -v "$candidate" >/dev/null 2>&1 &&
    "$candidate" -NoProfile -NonInteractive -Command 'exit 0' >/dev/null 2>&1; then
    powershell_cmd="$candidate"
    break
  fi
done

fail() {
  printf 'error: %s\n' "$1" >&2
  errors=$((errors + 1))
}

if [[ -z "$python_cmd" && $python_seen -eq 1 ]]; then
  fail "Python requires tomllib or the tomli compatibility package"
fi

required_files=(
  "AGENTS.md"
  "CLAUDE.md"
  "README.md"
  "ROADMAP.md"
  "SPEC.md"
  "TASKS.md"
  "codex-plugins.txt"
  "codex-home/AGENTS.md"
  "codex-home/config.toml"
  "codex-home/ollama.config.toml"
  "codex-home/llamacpp.config.toml"
  "codex-home/photocraft.config.toml"
  "codex-home/rules/default.rules"
  "docs/CODEX_LAYOUT.md"
  "docs/PHOTOCRAFT.md"
  "docs/SKILLS.md"
  "docs/WORKFLOW.md"
  ".github/dependabot.yml"
  ".github/pull_request_template.md"
  ".github/workflows/validate.yml"
  "scripts/install.ps1"
  "scripts/install.sh"
  "scripts/test-install.ps1"
  "scripts/test-install.sh"
  "scripts/test-photocraft-mcp.py"
)

for relative in "${required_files[@]}"; do
  [[ -f "$repo_root/$relative" ]] || fail "missing $relative"
done

if grep -Evq '^[a-z0-9][a-z0-9-]*@[a-z0-9][a-z0-9-]*$' "$repo_root/codex-plugins.txt"; then
  fail "codex-plugins.txt contains an invalid plugin selector"
fi

plugin_count="$(grep -Ec '^[a-z0-9][a-z0-9-]*@[a-z0-9][a-z0-9-]*$' "$repo_root/codex-plugins.txt" || true)"
[[ "$plugin_count" -gt 0 ]] || fail "codex-plugins.txt contains no plugins"

duplicate_plugins="$(sort "$repo_root/codex-plugins.txt" | uniq -d)"
[[ -z "$duplicate_plugins" ]] || fail "codex-plugins.txt contains duplicate plugins"

if [[ -n "$python_cmd" ]]; then
  for config_file in "$repo_root"/codex-home/*.toml; do
    "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' "$config_file" ||
      fail "invalid TOML in ${config_file#"$repo_root"/}"
  done

  "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); raise SystemExit(config.get("features", {}).get("memories") is not False)' \
    "$repo_root/codex-home/config.toml" || fail "codex-home/config.toml must disable features.memories by default"

  "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); raise SystemExit(config.get("features", {}).get("fast_mode") is not False)' \
    "$repo_root/codex-home/config.toml" || fail "codex-home/config.toml must disable features.fast_mode by default"

  if command -v codex >/dev/null 2>&1 && codex_features="$(codex features list 2>/dev/null)"; then
    configured_features="$(
      "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); print("\n".join(config.get("features", {})))' \
        "$repo_root/codex-home/config.toml"
    )"
    removed_features="$(awk '$2 == "removed" { print $1 }' <<<"$codex_features")"

    while IFS= read -r feature; do
      [[ -n "$feature" ]] || continue
      if grep -Fxq -- "$feature" <<<"$removed_features"; then
        fail "codex-home/config.toml configures removed feature: $feature"
      fi
    done <<<"$configured_features"
  fi

  "$python_cmd" - "$repo_root/codex-home/config.toml" <<'PY' ||
import pathlib
import sys
try:
    import tomllib
except ModuleNotFoundError:
    import tomli as tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
forbidden = []

if "notify" in config:
    forbidden.append("notify")

for section in ("marketplaces", "notice", "plugins", "projects"):
    if section in config:
        forbidden.append(section)

if "model_availability_nux" in config.get("tui", {}):
    forbidden.append("tui.model_availability_nux")

if "state" in config.get("hooks", {}):
    forbidden.append("hooks.state")

if "node_repl" in config.get("mcp_servers", {}):
    forbidden.append("mcp_servers.node_repl")

if "set" in config.get("shell_environment_policy", {}):
    forbidden.append("shell_environment_policy.set")

if forbidden:
    print("runtime state in portable config: " + ", ".join(forbidden), file=sys.stderr)
    raise SystemExit(1)
PY
    fail "codex-home/config.toml contains machine-local runtime or plugin state"

  for profile_file in "$repo_root"/codex-home/*.config.toml; do
    "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); raise SystemExit("projects" in config)' \
      "$profile_file" || fail "${profile_file#"$repo_root"/} must not contain machine-specific project trust"
  done

  "$python_cmd" - "$repo_root/AGENTS.md" "$repo_root/codex-home/AGENTS.md" <<'PY' ||
import pathlib
import re
import sys


def bullet_rules(path):
    rules = []
    current = None

    for line in pathlib.Path(path).read_text().splitlines():
        if line.startswith("- "):
            if current is not None:
                rules.append(re.sub(r"\s+", " ", current).strip())
            current = line
        elif current is not None and line.startswith("  "):
            current += " " + line.strip()
        elif current is not None:
            rules.append(re.sub(r"\s+", " ", current).strip())
            current = None

    if current is not None:
        rules.append(re.sub(r"\s+", " ", current).strip())

    return set(rules)


duplicates = sorted(bullet_rules(sys.argv[1]) & bullet_rules(sys.argv[2]))
if duplicates:
    print("duplicate AGENTS.md rules:", file=sys.stderr)
    for duplicate in duplicates:
        print(f"  {duplicate}", file=sys.stderr)
    raise SystemExit(1)
PY
    fail "root and global AGENTS.md files contain duplicate rules"
fi

if [[ -d "$repo_root/.codex/skills" ]]; then
  fail "legacy .codex/skills directory still exists"
fi

skill_count=0
actual_skills=""
for skill_dir in "$repo_root"/.agents/skills/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_count=$((skill_count + 1))
  skill_file="$skill_dir/SKILL.md"
  skill_basename="$(basename "$skill_dir")"

  if [[ ! -f "$skill_file" ]]; then
    fail "missing ${skill_file#"$repo_root"/}"
    continue
  fi

  first_line="$(sed -n '1p' "$skill_file")"
  [[ "$first_line" == "---" ]] || fail "${skill_file#"$repo_root"/} has no YAML front matter"
  grep -q '^name: .\+' "$skill_file" || fail "${skill_file#"$repo_root"/} has no name"
  grep -q '^description: .\+' "$skill_file" || fail "${skill_file#"$repo_root"/} has no description"
  skill_name="$(sed -n 's/^name: //p' "$skill_file" | sed -n '1p')"
  [[ "$skill_name" == "$skill_basename" ]] ||
    fail "${skill_file#"$repo_root"/} name does not match its directory"
  ! grep -q '\[TODO:' "$skill_file" || fail "${skill_file#"$repo_root"/} contains TODO placeholders"
  actual_skills+="$skill_basename"$'\n'
done

[[ $skill_count -gt 0 ]] || fail "no skills found under .agents/skills"

# The sed expression is intentionally literal.
# shellcheck disable=SC2016
documented_skills="$(
  sed -n '/^## Repository skills$/,/^## /p' "$repo_root/docs/SKILLS.md" |
    sed -n 's/^- `\([^`]*\)`$/\1/p' |
    sort
)"
actual_skills="$(printf '%s' "$actual_skills" | sort)"
[[ "$documented_skills" == "$actual_skills" ]] ||
  fail "docs/SKILLS.md does not match .agents/skills"

for forbidden in auth.json history.jsonl installation_id state_5.sqlite goals_1.sqlite memories_1.sqlite; do
  [[ ! -e "$repo_root/$forbidden" ]] || fail "runtime file must not be tracked: $forbidden"
done

if grep -Fq "C:\\\\Program Files\\\\PowerShell\\\\" "$repo_root/codex-home/rules/default.rules"; then
  fail "codex-home/rules/default.rules contains a machine-specific PowerShell approval"
fi

if command -v git >/dev/null 2>&1 &&
  git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git -C "$repo_root" ls-files | grep -Eq '(^|/)(auth\.json|history\.jsonl|installation_id|.*\.sqlite(-shm|-wal)?)$'; then
    fail "tracked Codex runtime or credential files detected"
  fi
fi

if ! bash -n \
  "$repo_root/scripts/install.sh" \
  "$repo_root/scripts/test-install.sh" \
  "$repo_root/scripts/validate.sh"; then
  fail "Bash syntax validation failed"
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$repo_root/scripts/install.sh" \
    "$repo_root/scripts/test-install.sh" \
    "$repo_root/scripts/validate.sh" ||
    fail "ShellCheck failed"
fi

if command -v codex >/dev/null 2>&1 && codex --version >/dev/null 2>&1; then
  read_only_policy_result="$(
    codex execpolicy check \
      --rules "$repo_root/codex-home/rules/default.rules" \
      rg --files
  )" || fail "invalid codex-home/rules/default.rules"

  forbidden_policy_result="$(
    codex execpolicy check \
      --rules "$repo_root/codex-home/rules/default.rules" \
      gh repo delete owner/repo --yes
  )" || fail "invalid codex-home/rules/default.rules"

  wrapper_policy_result="$(
    codex execpolicy check \
      --rules "$repo_root/codex-home/rules/default.rules" \
      bash -lc 'git push --force'
  )" || fail "invalid codex-home/rules/default.rules"

  if [[ -n "$python_cmd" ]]; then
    "$python_cmd" -c 'import json, sys; raise SystemExit(json.loads(sys.argv[1]).get("decision") != "allow")' \
      "$read_only_policy_result" || fail "default rules must allow read-only inspection commands"
    "$python_cmd" -c 'import json, sys; raise SystemExit(json.loads(sys.argv[1]).get("decision") != "forbidden")' \
      "$forbidden_policy_result" || fail "default rules must forbid repository deletion"
    "$python_cmd" -c 'import json, sys; raise SystemExit(json.loads(sys.argv[1]).get("decision") == "allow")' \
      "$wrapper_policy_result" || fail "default rules must not blanket-allow shell wrappers"
  fi
fi

if [[ -n "$powershell_cmd" ]]; then
  for powershell_file in \
    "$repo_root/scripts/install.ps1" \
    "$repo_root/scripts/test-install.ps1"; do
    # The PowerShell variables must not expand in Bash.
    # shellcheck disable=SC2016
    TITSTACK_POWERSHELL_FILE="$powershell_file" "$powershell_cmd" -NoProfile -NonInteractive -Command \
      '$errors = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($env:TITSTACK_POWERSHELL_FILE, [ref]$null, [ref]$errors); if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }' ||
      fail "PowerShell syntax validation failed for ${powershell_file#"$repo_root"/}"
  done
fi

windows_symlink_supported() {
  # The PowerShell variables must not expand in Bash.
  # shellcheck disable=SC2016
  "$powershell_cmd" -NoProfile -NonInteractive -Command '
    $probeRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("titstack-symlink-probe-" + [guid]::NewGuid())
    $supported = $false
    try {
      [void](New-Item -ItemType Directory -Path $probeRoot)
      $target = Join-Path $probeRoot "target.txt"
      $link = Join-Path $probeRoot "link.txt"
      [System.IO.File]::WriteAllText($target, "probe")
      [void](New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop)
      $supported = $true
    } catch {
    } finally {
      Remove-Item -LiteralPath $probeRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not $supported) { exit 1 }
  '
}

case "$host_os" in
MINGW* | MSYS* | CYGWIN*)
  if [[ -z "$powershell_cmd" ]]; then
    fail "Windows PowerShell (pwsh or powershell.exe) is required for installer validation"
  elif windows_symlink_supported; then
    if ! "$powershell_cmd" -NoProfile -NonInteractive -File "$repo_root/scripts/test-install.ps1"; then
      fail "Windows installer integration test failed"
    fi
  else
    printf '%s\n' "warning: skipping Windows installer integration test because symlink creation requires Developer Mode or administrator privileges" >&2
  fi
  ;;
*)
  if ! bash "$repo_root/scripts/test-install.sh"; then
    fail "installer integration test failed"
  fi
  ;;
esac

if [[ $errors -gt 0 ]]; then
  printf 'validation failed with %d error(s)\n' "$errors" >&2
  exit 1
fi

printf 'validation passed: %d skills checked\n' "$skill_count"
