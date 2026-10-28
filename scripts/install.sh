#!/usr/bin/env bash
set -euo pipefail

dry_run=false
install_plugins=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --plugins)
      install_plugins=true
      ;;
    *)
      printf 'usage: %s [--dry-run] [--plugins]\n' "$0" >&2
      exit 2
      ;;
  esac
  shift
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
agents_home="${AGENTS_HOME:-$HOME/.agents}"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$codex_home/backups/titstack-$timestamp-$$"
plugin_manifest="$repo_root/codex-plugins.txt"
config_source="$repo_root/codex-home/config.toml"
github_root="$HOME/github"
rendered_config=""

if "$install_plugins"; then
  if [[ ! -f "$plugin_manifest" ]]; then
    printf 'error: plugin manifest does not exist: %s\n' "$plugin_manifest" >&2
    exit 1
  fi
  if ! "$dry_run" && ! command -v codex >/dev/null 2>&1; then
    printf 'error: codex is required when using --plugins\n' >&2
    exit 1
  fi
fi

run() {
  if "$dry_run"; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

cleanup() {
  if [[ -n "$rendered_config" && -f "$rendered_config" ]]; then
    rm -f -- "$rendered_config" "${rendered_config}.merged" "${rendered_config}.notify"
  fi
}
trap cleanup EXIT

ensure_parent() {
  run mkdir -p "$(dirname "$1")"
}

resolve_path() {
  local path="$1"
  local directory
  local hops=0
  local link_target

  while [[ -L "$path" ]]; do
    hops=$((hops + 1))
    if ((hops > 64)); then
      printf 'error: too many symbolic-link hops: %s\n' "$1" >&2
      return 2
    fi

    if ! directory="$(cd -P "$(dirname "$path")" && pwd)"; then
      return 1
    fi
    if ! link_target="$(readlink "$path")"; then
      return 1
    fi
    if [[ "$link_target" == /* ]]; then
      path="$link_target"
    else
      path="$directory/$link_target"
    fi
  done

  if [[ -d "$path" ]]; then
    if ! directory="$(cd -P "$path" && pwd)"; then
      return 1
    fi
    printf '%s\n' "$directory"
    return
  fi

  if ! directory="$(cd -P "$(dirname "$path")" && pwd)"; then
    return 1
  fi
  printf '%s/%s\n' "$directory" "$(basename "$path")"
}

link_managed_path() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    printf 'error: managed source does not exist: %s\n' "$source" >&2
    exit 1
  fi

  ensure_parent "$target"

  if [[ -L "$target" ]]; then
    local resolved_source
    local resolved_target=""
    local resolve_status=0

    if ! resolved_source="$(resolve_path "$source")"; then
      return 1
    fi

    if resolved_target="$(resolve_path "$target")"; then
      resolve_status=0
    else
      resolve_status=$?
    fi

    if ((resolve_status != 0 && resolve_status != 2)); then
      return "$resolve_status"
    fi

    if ((resolve_status == 0)) && [[ "$resolved_target" == "$resolved_source" ]]; then
      printf 'already linked: %s\n' "$target"
      return
    fi
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    local relative="${target#"$codex_home"/}"
    local backup="$backup_root/$relative"

    if [[ "$target" != "$codex_home/"* ]]; then
      relative="${target#"$agents_home"/}"
      backup="$backup_root/agents/$relative"
    fi

    ensure_parent "$backup"
    run mv "$target" "$backup"
    printf 'backed up: %s -> %s\n' "$target" "$backup"
  fi

  run ln -s "$source" "$target"
  printf 'linked: %s -> %s\n' "$target" "$source"
}

append_trusted_project() {
  local config_file="$1"
  local project_path="$2"
  local escaped_path="$project_path"
  local table_header

  if [[ "$project_path" =~ [[:cntrl:]] ]]; then
    printf 'error: project path contains unsupported control characters: %q\n' \
      "$project_path" >&2
    exit 1
  fi

  escaped_path="${escaped_path//\\/\\\\}"
  escaped_path="${escaped_path//\"/\\\"}"
  table_header="[projects.\"$escaped_path\"]"

  if grep -Fqx "$table_header" "$config_file"; then
    return
  fi

  printf '\n%s\ntrust_level = "trusted"\n' "$table_header" >>"$config_file"
}

append_preserved_config_sections() {
  local existing_config="$1"
  local config_file="$2"
  local merged_config="${config_file}.merged"
  local preserved_notify="${config_file}.notify"
  local preserved_sections

  [[ -f "$existing_config" ]] || return 0

  awk '
    /^[[:space:]]*\[\[?/ { exit }
    capture_notify && /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/ { exit }
    capture_notify && /^[[:space:]]*$/ { trailing_blanks++; next }
    capture_notify {
      while (trailing_blanks > 0) {
        print ""
        trailing_blanks--
      }
      print
      next
    }
    /^[[:space:]]*notify[[:space:]]*=/ { capture_notify = 1; print }
  ' "$existing_config" >"$preserved_notify"

  if [[ -s "$preserved_notify" ]]; then
    awk -v notify_file="$preserved_notify" '
      !inserted && /^[[:space:]]*\[/ {
        while ((getline line < notify_file) > 0) {
          print line
        }
        close(notify_file)
        print ""
        inserted = 1
      }
      { print }
    ' "$config_file" >"$merged_config"
    mv "$merged_config" "$config_file"
  fi
  rm -f -- "$preserved_notify"

  preserved_sections="$(
    awk '
      /^[[:space:]]*\[\[?/ {
        preserve = ($0 ~ /^[[:space:]]*\[\[?(marketplaces|plugins|notice)(\.|\]\]?)/ || $0 ~ /^[[:space:]]*\[\[?hooks\.state(\.|\]\]?)/ || $0 ~ /^[[:space:]]*\[\[?mcp_servers\.node_repl(\.|\]\]?)/ || $0 ~ /^[[:space:]]*\[\[?shell_environment_policy\.set(\.|\]\]?)/)
      }
      preserve { print }
    ' "$existing_config"
  )"

  if [[ -n "$preserved_sections" ]]; then
    printf '\n# Preserved machine-local Codex state.\n%s\n' \
      "$preserved_sections" >>"$config_file"
  fi
}

render_managed_config() {
  local git_marker
  local project_path

  rendered_config="$(mktemp "${TMPDIR:-/tmp}/titstack-config.XXXXXX")"
  cp "$config_source" "$rendered_config"
  printf '\n# Generated by the titstack installer. Rerun it after adding repositories.\n' \
    >>"$rendered_config"
  append_trusted_project "$rendered_config" "$github_root"

  if [[ -d "$github_root" ]]; then
    while IFS= read -r -d '' git_marker; do
      project_path="${git_marker%/.git}"
      append_trusted_project "$rendered_config" "$project_path"
    done < <(
      find "$github_root" \
        \( -name .git -o -name node_modules -o -name .venv -o -name venv \
        -o -name target -o -name build -o -name dist \) -prune \
        -name .git -print0
    )
  fi

  append_preserved_config_sections "$codex_home/config.toml" "$rendered_config"
}

install_managed_config() {
  local target="$1"

  ensure_parent "$target"

  if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$rendered_config" "$target"; then
    printf 'already installed: %s\n' "$target"
    return
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    local relative="${target#"$codex_home"/}"
    local backup="$backup_root/$relative"

    ensure_parent "$backup"
    run mv "$target" "$backup"
    printf 'backed up: %s -> %s\n' "$target" "$backup"
  fi

  run cp "$rendered_config" "$target"
  printf 'installed: %s\n' "$target"
}

install_recommended_plugins() {
  local plugin

  while IFS= read -r plugin || [[ -n "$plugin" ]]; do
    [[ -n "$plugin" ]] || continue
    run codex plugin add "$plugin"
  done <"$plugin_manifest"
}

render_managed_config
link_managed_path "$repo_root/codex-home/AGENTS.md" "$codex_home/AGENTS.md"
install_managed_config "$codex_home/config.toml"
link_managed_path "$repo_root/codex-home/rules" "$codex_home/rules"

for profile in "$repo_root"/codex-home/*.config.toml; do
  [[ -f "$profile" ]] || continue
  link_managed_path "$profile" "$codex_home/$(basename "$profile")"
done

for skill_dir in "$repo_root"/.agents/skills/*; do
  [[ -d "$skill_dir" ]] || continue
  link_managed_path "$skill_dir" "$agents_home/skills/$(basename "$skill_dir")"
done

if "$install_plugins"; then
  install_recommended_plugins
fi

if "$dry_run"; then
  printf 'dry run complete\n'
else
  printf 'installation complete. Restart Codex to reload configuration.\n'
fi
