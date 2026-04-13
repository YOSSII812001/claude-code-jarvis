#!/usr/bin/env bash
# post_tool_use_format_lint.sh
# -----------------------------------------------
# Auto-run formatters & linters for JS/TS & Python
# whenever Claude Code writes/edits files.
#
# Placement (Windows Git Bash):
#   C:\Users\<YOU>\.claude\hooks\post_tool_use_format_lint.sh
#   (= $HOME/.claude/hooks/post_tool_use_format_lint.sh )
#
# Requirements (install in your project envs):
#   - Node: prettier, eslint (devDependencies)
#   - Python: ruff  (or black + ruff)
#   - jq (optional but recommended for robust JSON parsing; Git for Windows users can `choco install jq` or download binary)
#
# Safety: Runs only on changed file paths from Claude; filters by extension.
# -----------------------------------------------

set -euo pipefail

# capture incoming JSON payload (Claude sends tool invocation details on STDIN)
json_file="$(mktemp)"
cat >"$json_file" || true

# prefer environment var provided by Claude if present
# (space-delimited paths, quoted-safe)
if [[ -n "${CLAUDE_FILE_PATHS:-}" ]]; then
  # shellcheck disable=SC2086
  readarray -t paths <<<"$(printf '%s\n' ${CLAUDE_FILE_PATHS})"
else
  if command -v jq >/dev/null 2>&1; then
    readarray -t paths < <(jq -r '.. | .file_path? // empty' "$json_file")
  else
    echo "[Hook] warning: jq not found; cannot parse JSON payload reliably; exiting." >&2
    exit 0
  fi
fi

rm -f "$json_file" 2>/dev/null || true

# de-dup + non-empty
readarray -t unique_paths < <(printf '%s\n' "${paths[@]}" | awk 'NF' | sort -u)

[[ ${#unique_paths[@]} -eq 0 ]] && exit 0

# helper: convert Windows path to POSIX if cygpath exists (Git Bash)
to_posix_path () {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

js_files=()
ts_files=()
py_files=()

for f in "${unique_paths[@]}"; do
  # normalize
  posix_f="$(to_posix_path "$f")"
  # gatekeeper: skip deleted/non-existent files (avoid linter errors on removed files)
  [[ ! -f "$posix_f" ]] && continue
  case "$posix_f" in
    *.js|*.jsx) js_files+=("$posix_f") ;;
    *.ts|*.tsx) ts_files+=("$posix_f") ;;
    *.py)       py_files+=("$posix_f") ;;
  esac
done

run_prettier_eslint() {
  local files=("$@")
  [[ ${#files[@]} -eq 0 ]] && return 0

  echo "[Hook] Prettier format JS/TS (${#files[@]} files)" >&2
  npx prettier --write "${files[@]}"

  echo "[Hook] ESLint --fix JS/TS (${#files[@]} files)" >&2
  # --max-warnings=0 will fail CI if warnings; remove if too strict
  npx eslint --fix --max-warnings=0 "${files[@]}" || true
}

run_python_tools() {
  local files=("$@")
  [[ ${#files[@]} -eq 0 ]] && return 0

  if command -v ruff >/dev/null 2>&1; then
    echo "[Hook] Ruff format Python (${#files[@]} files)" >&2
    ruff format "${files[@]}"

    echo "[Hook] Ruff check --fix Python (${#files[@]} files)" >&2
    ruff check --fix "${files[@]}"
  elif command -v black >/dev/null 2>&1; then
    echo "[Hook] Black format Python (${#files[@]} files)" >&2
    black "${files[@]}"
    if command -v ruff >/dev/null 2>&1; then
      echo "[Hook] Ruff check --fix Python (${#files[@]} files)" >&2
      ruff check --fix "${files[@]}"
    fi
  else
    echo "[Hook] warning: no python formatter (ruff/black) found in PATH; skipping." >&2
  fi
}

run_prettier_eslint "${js_files[@]}" "${ts_files[@]}"
run_python_tools "${py_files[@]}"

exit 0
