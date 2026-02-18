#!/usr/bin/env bash
set -euo pipefail

MODE="both"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

SANDBOX_DIR=""
SANDBOX_HOME=""
SANDBOX_XDG=""
SANDBOX_ZDOTDIR=""

PASS_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'EOF'
Usage: check-zsh-completion.sh [options]

Options:
  --mode <m>   Check mode: live | sandbox | both (default: both)
  -h, --help   Show this help
EOF
}

setup_sandbox() {
  SANDBOX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zsh-check.XXXXXX")"
  SANDBOX_HOME="${SANDBOX_DIR}/home"
  SANDBOX_XDG="${SANDBOX_HOME}/.config"
  SANDBOX_ZDOTDIR="${SANDBOX_XDG}/zsh"

  mkdir -p "${SANDBOX_ZDOTDIR}"
  mkdir -p "${SANDBOX_HOME}"
  cp "${REPO_ROOT}/modules/dotfiles/zsh/.zshrc.marigold" "${SANDBOX_ZDOTDIR}/.zshrc"

  cat > "${SANDBOX_ZDOTDIR}/.zshenv" <<EOF
# sandbox-only zshenv for smoke checks against repo config
export XDG_CONFIG_HOME="${SANDBOX_XDG}"
export ZDOTDIR="${SANDBOX_ZDOTDIR}"
export EDITOR="nvim"
export VISUAL="nvim"
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
EOF

  ln -s "${REPO_ROOT}/modules/dotfiles/zsh/modules" "${SANDBOX_ZDOTDIR}/modules"
  ln -s "${REPO_ROOT}/modules/dotfiles/zsh/functions" "${SANDBOX_ZDOTDIR}/functions"
  ln -s "${REPO_ROOT}/modules/dotfiles/zsh/plugins" "${SANDBOX_ZDOTDIR}/plugins"
  ln -s "${REPO_ROOT}/modules/dotfiles/zsh/scripts" "${SANDBOX_ZDOTDIR}/scripts"
  ln -s "${REPO_ROOT}/modules/dotfiles/television" "${SANDBOX_XDG}/television"
}

cleanup() {
  if [[ -n "${SANDBOX_DIR}" && -d "${SANDBOX_DIR}" ]]; then
    rm -rf "${SANDBOX_DIR}"
  fi
}
trap cleanup EXIT

run_zsh_live() {
  local cmd="$1"
  zsh -i -c "${cmd}"
}

run_zsh_sandbox() {
  local cmd="$1"
  HOME="${SANDBOX_HOME}" ZDOTDIR="${SANDBOX_ZDOTDIR}" XDG_CONFIG_HOME="${SANDBOX_XDG}" zsh -i -c "${cmd}"
}

run_check() {
  local mode="$1"
  local label="$2"
  local cmd="$3"
  local output=""

  if [[ "${mode}" == "live" ]]; then
    if output="$(run_zsh_live "${cmd}" 2>&1)"; then
      printf '[PASS] [%s] %s\n' "${mode}" "${label}"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      printf '[FAIL] [%s] %s\n' "${mode}" "${label}"
      [[ -n "${output}" ]] && printf '  -> %s\n' "${output}"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    if output="$(run_zsh_sandbox "${cmd}" 2>&1)"; then
      printf '[PASS] [%s] %s\n' "${mode}" "${label}"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      printf '[FAIL] [%s] %s\n' "${mode}" "${label}"
      [[ -n "${output}" ]] && printf '  -> %s\n' "${output}"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  fi
}

run_suite_for_mode() {
  local mode="$1"
  run_check "${mode}" "Shell interactive startup" 'true'
  run_check "${mode}" "fzf command available" 'command -v fzf >/dev/null'
  run_check "${mode}" "fd command available" 'command -v fd >/dev/null'
  run_check "${mode}" "Tab widget fzf-tab-complete exists" '(( $+widgets[fzf-tab-complete] ))'
  run_check "${mode}" "Tab is bound to fzf-tab-complete" 'bindkey -M emacs "^I" | grep -q "fzf-tab-complete"'
  run_check "${mode}" "Alt-m is bound to carapace-force-completion" 'bindkey -M emacs "^[m" | grep -q "carapace-force-completion"'
  run_check "${mode}" "Alias v points to nvim" 'alias v 2>/dev/null | grep -Eq "^v=.*nvim"'
  run_check "${mode}" "Custom nvim completion function exists" 'typeset -f _custom_completion_for_nvim >/dev/null'
  run_check "${mode}" "nvim has a completion backend registered" '[[ -n "${_comps[nvim]-}" ]]'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${MODE}" != "live" && "${MODE}" != "sandbox" && "${MODE}" != "both" ]]; then
  echo "Invalid mode: ${MODE} (expected: live|sandbox|both)" >&2
  exit 1
fi

if [[ "${MODE}" == "sandbox" || "${MODE}" == "both" ]]; then
  setup_sandbox
fi

echo "Running zsh completion smoke checks (mode=${MODE})..."

if [[ "${MODE}" == "live" || "${MODE}" == "both" ]]; then
  run_suite_for_mode "live"
fi

if [[ "${MODE}" == "sandbox" || "${MODE}" == "both" ]]; then
  run_suite_for_mode "sandbox"
fi

echo
echo "Smoke summary: PASS=${PASS_COUNT}, FAIL=${FAIL_COUNT}"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  exit 1
fi
