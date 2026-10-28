#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_test_root="$(mktemp -d "${TMPDIR:-/tmp}/titstack-install-test.XXXXXX")"
test_codex_home="$task_test_root/codex home"
test_agents_home="$task_test_root/agents home"
test_user_home="$task_test_root/user home"
test_github_repo="$test_user_home/github/nested/project"
python_cmd=""
python_seen=0

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

cleanup() {
  if [[ -d "$task_test_root" && "$(basename "$task_test_root")" == titstack-install-test.* ]]; then
    rm -rf -- "$task_test_root"
  fi
}
trap cleanup EXIT

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

if [[ -z "$python_cmd" && $python_seen -eq 1 ]]; then
  fail "Python requires tomllib or the tomli compatibility package"
fi

assert_link() {
  local target="$1"
  local source="$2"

  [[ -L "$target" ]] || fail "expected symbolic link: $target"
  [[ "$(readlink "$target")" == "$source" ]] ||
    fail "unexpected link target: $target"
}

mkdir -p "$test_codex_home"
mkdir -p "$test_github_repo/.git"
printf 'original global instructions\n' >"$test_codex_home/AGENTS.md"
cat >"$test_codex_home/config.toml" <<'EOF'
notify = [
  "example-notifier",
  "turn-ended",
]

[plugins."example@personal"]
enabled = true

[marketplaces.personal]
source = "example"

[hooks.state]

[hooks.state."example"]
trusted_hash = "sha256:example"

[notice]
hide_example = true

[mcp_servers.node_repl]
command = "node"

[shell_environment_policy.set]
EXAMPLE_RUNTIME_PATH = "example"
EOF

HOME="$test_user_home" CODEX_HOME="$test_codex_home" AGENTS_HOME="$test_agents_home" \
  "$repo_root/scripts/install.sh" >/dev/null

assert_link "$test_codex_home/AGENTS.md" "$repo_root/codex-home/AGENTS.md"
[[ -f "$test_codex_home/config.toml" && ! -L "$test_codex_home/config.toml" ]] ||
  fail "expected generated config file: $test_codex_home/config.toml"
grep -Fqx "[projects.\"$test_user_home/github\"]" "$test_codex_home/config.toml" ||
  fail "generated config does not trust the user GitHub root"
grep -Fqx "[projects.\"$test_github_repo\"]" "$test_codex_home/config.toml" ||
  fail "generated config does not trust a nested Git repository"
if [[ -n "$python_cmd" ]]; then
  "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); tomllib.loads(pathlib.Path(sys.argv[1]).read_text())' \
    "$test_codex_home/config.toml" || fail "generated config is invalid TOML"
  "$python_cmd" -c 'import pathlib, sys; tomllib = __import__("tomllib" if sys.version_info >= (3, 11) else "tomli"); config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text()); raise SystemExit(config.get("features", {}).get("fast_mode") is not False)' \
    "$test_codex_home/config.toml" || fail "generated config must disable features.fast_mode by default"
fi
for preserved_line in \
  'notify = [' \
  '[plugins."example@personal"]' \
  '[marketplaces.personal]' \
  '[hooks.state."example"]' \
  '[notice]' \
  '[mcp_servers.node_repl]' \
  '[shell_environment_policy.set]'; do
  grep -Fqx "$preserved_line" "$test_codex_home/config.toml" ||
    fail "generated config dropped machine-local state: $preserved_line"
done
assert_link "$test_codex_home/rules" "$repo_root/codex-home/rules"
assert_link "$test_codex_home/ollama.config.toml" "$repo_root/codex-home/ollama.config.toml"
assert_link "$test_codex_home/llamacpp.config.toml" "$repo_root/codex-home/llamacpp.config.toml"
assert_link "$test_codex_home/photocraft.config.toml" "$repo_root/codex-home/photocraft.config.toml"

for skill_dir in "$repo_root"/.agents/skills/*; do
  [[ -d "$skill_dir" ]] || continue
  assert_link "$test_agents_home/skills/$(basename "$skill_dir")" "$skill_dir"
done

shopt -s nullglob
instruction_backups=("$test_codex_home"/backups/titstack-*/AGENTS.md)
shopt -u nullglob
[[ ${#instruction_backups[@]} -eq 1 ]] ||
  fail "expected one AGENTS.md backup, found ${#instruction_backups[@]}"
[[ "$(sed -n '1p' "${instruction_backups[0]}")" == "original global instructions" ]] ||
  fail "AGENTS.md backup content changed"
shopt -s nullglob
config_backups=("$test_codex_home"/backups/titstack-*/config.toml)
shopt -u nullglob
[[ ${#config_backups[@]} -eq 1 ]] ||
  fail "expected one config.toml backup, found ${#config_backups[@]}"

link_fixture_dir="$task_test_root/link fixtures"
mkdir -p "$link_fixture_dir"
ln -s "$repo_root/codex-home/AGENTS.md" "$link_fixture_dir/managed instructions"
rm -- "$test_codex_home/AGENTS.md"
ln -s "../link fixtures/managed instructions" "$test_codex_home/AGENTS.md"
raw_instruction_target="$(readlink "$test_codex_home/AGENTS.md")"

HOME="$test_user_home" CODEX_HOME="$test_codex_home" AGENTS_HOME="$test_agents_home" \
  "$repo_root/scripts/install.sh" >/dev/null
[[ "$(readlink "$test_codex_home/AGENTS.md")" == "$raw_instruction_target" ]] ||
  fail "idempotent install replaced an equivalent relative link"

shopt -s nullglob
instruction_backups=("$test_codex_home"/backups/titstack-*/AGENTS.md)
shopt -u nullglob
[[ ${#instruction_backups[@]} -eq 1 ]] ||
  fail "idempotent install created another AGENTS.md backup"
shopt -s nullglob
config_backups=("$test_codex_home"/backups/titstack-*/config.toml)
shopt -u nullglob
[[ ${#config_backups[@]} -eq 1 ]] ||
  fail "idempotent install created another config.toml backup"
for preserved_line in \
  'notify = [' \
  '[plugins."example@personal"]' \
  '[marketplaces.personal]' \
  '[hooks.state."example"]' \
  '[notice]' \
  '[mcp_servers.node_repl]' \
  '[shell_environment_policy.set]'; do
  [[ "$(grep -Fxc "$preserved_line" "$test_codex_home/config.toml")" -eq 1 ]] ||
    fail "idempotent install duplicated machine-local state: $preserved_line"
done

rm -- "$test_codex_home/rules"
ln -s "$repo_root/codex-home/rules/." "$test_codex_home/rules"
raw_rules_target="$(readlink "$test_codex_home/rules")"
HOME="$test_user_home" CODEX_HOME="$test_codex_home" AGENTS_HOME="$test_agents_home" \
  "$repo_root/scripts/install.sh" >/dev/null
[[ "$(readlink "$test_codex_home/rules")" == "$raw_rules_target" ]] ||
  fail "idempotent install replaced an equivalent normalized link"

cycle_fixture_dir="$task_test_root/cycle fixtures"
mkdir -p "$cycle_fixture_dir"
ln -s "cycle-b" "$cycle_fixture_dir/cycle-a"
ln -s "cycle-a" "$cycle_fixture_dir/cycle-b"
rm -- "$test_codex_home/ollama.config.toml"
ln -s "../cycle fixtures/cycle-a" "$test_codex_home/ollama.config.toml"
cycle_error_log="$task_test_root/cycle-error.log"

HOME="$test_user_home" CODEX_HOME="$test_codex_home" AGENTS_HOME="$test_agents_home" \
  "$repo_root/scripts/install.sh" >/dev/null 2>"$cycle_error_log"
grep -q '^error: too many symbolic-link hops:' "$cycle_error_log" ||
  fail "cyclic link did not report a bounded-resolution error"
assert_link "$test_codex_home/ollama.config.toml" "$repo_root/codex-home/ollama.config.toml"

fake_bin="$task_test_root/fake bin"
plugin_log="$task_test_root/plugin-calls.log"
mkdir -p "$fake_bin"
cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_PLUGIN_TEST_LOG"
EOF
chmod +x "$fake_bin/codex"

plugin_codex_home="$task_test_root/plugin codex"
plugin_agents_home="$task_test_root/plugin agents"
HOME="$test_user_home" PATH="$fake_bin:$PATH" CODEX_PLUGIN_TEST_LOG="$plugin_log" \
  CODEX_HOME="$plugin_codex_home" AGENTS_HOME="$plugin_agents_home" \
  "$repo_root/scripts/install.sh" --plugins >/dev/null

expected_plugin_calls="$(sed 's/^/plugin add /' "$repo_root/codex-plugins.txt")"
actual_plugin_calls="$(sed -n '1,$p' "$plugin_log")"
[[ "$actual_plugin_calls" == "$expected_plugin_calls" ]] ||
  fail "installer did not install the expected Codex plugins"

dry_run_codex_home="$task_test_root/dry run codex"
dry_run_agents_home="$task_test_root/dry run agents"
dry_run_plugin_log="$task_test_root/dry-run-plugin-calls.log"
HOME="$test_user_home" PATH="$fake_bin:$PATH" CODEX_PLUGIN_TEST_LOG="$dry_run_plugin_log" \
  CODEX_HOME="$dry_run_codex_home" AGENTS_HOME="$dry_run_agents_home" \
  "$repo_root/scripts/install.sh" --dry-run --plugins >/dev/null
[[ ! -e "$dry_run_codex_home" && ! -L "$dry_run_codex_home" ]] ||
  fail "dry-run created CODEX_HOME"
[[ ! -e "$dry_run_agents_home" && ! -L "$dry_run_agents_home" ]] ||
  fail "dry-run created AGENTS_HOME"
[[ ! -e "$dry_run_plugin_log" ]] || fail "dry-run invoked Codex plugin installation"

control_user_home="$task_test_root/control user home"
control_repo="$control_user_home/github/bad"$'\n'"project"
control_codex_home="$task_test_root/control codex"
control_agents_home="$task_test_root/control agents"
control_error_log="$task_test_root/control-error.log"
mkdir -p "$control_repo/.git"

if HOME="$control_user_home" CODEX_HOME="$control_codex_home" AGENTS_HOME="$control_agents_home" \
  "$repo_root/scripts/install.sh" --dry-run >/dev/null 2>"$control_error_log"; then
  fail "installer accepted a project path containing a control character"
fi
grep -q '^error: project path contains unsupported control characters:' "$control_error_log" ||
  fail "installer did not report the invalid project path"
[[ ! -e "$control_codex_home" && ! -L "$control_codex_home" ]] ||
  fail "invalid project path changed CODEX_HOME"

printf 'installer integration test passed\n'
