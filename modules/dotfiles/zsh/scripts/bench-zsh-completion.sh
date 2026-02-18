#!/usr/bin/env bash
set -euo pipefail

RUNS=7
MODE="both"
TARGET_DIR="$PWD"
OUT_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

SANDBOX_DIR=""
SANDBOX_HOME=""
SANDBOX_XDG=""
SANDBOX_ZDOTDIR=""

usage() {
  cat <<'EOF'
Usage: bench-zsh-completion.sh [options]

Options:
  --runs <n>          Number of runs per metric (default: 7)
  --mode <m>          Benchmark mode: live | sandbox | both (default: both)
  --target-dir <dir>  Directory used for fd/git candidate scans (default: current dir)
  --out <file>        CSV output path (default: /tmp/zsh-completion-bench-<ts>.csv)
  -h, --help          Show this help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

now_ms() {
  perl -MTime::HiRes=time -e 'printf "%.0f\n", time()*1000'
}

setup_sandbox() {
  SANDBOX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zsh-bench.XXXXXX")"
  SANDBOX_HOME="${SANDBOX_DIR}/home"
  SANDBOX_XDG="${SANDBOX_HOME}/.config"
  SANDBOX_ZDOTDIR="${SANDBOX_XDG}/zsh"

  mkdir -p "${SANDBOX_ZDOTDIR}"
  mkdir -p "${SANDBOX_HOME}"

  cp "${REPO_ROOT}/modules/dotfiles/zsh/.zshrc.marigold" "${SANDBOX_ZDOTDIR}/.zshrc"

  cat > "${SANDBOX_ZDOTDIR}/.zshenv" <<EOF
# sandbox-only zshenv for benchmarking repo config
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

run_startup_live() {
  (
    cd "${TARGET_DIR}"
    zsh -i -c exit
  )
}

run_tab_probe_live() {
  (
    cd "${TARGET_DIR}"
    zsh -i -c 'bindkey -M emacs "^I" >/dev/null'
  )
}

run_startup_sandbox() {
  (
    cd "${TARGET_DIR}"
    HOME="${SANDBOX_HOME}" ZDOTDIR="${SANDBOX_ZDOTDIR}" XDG_CONFIG_HOME="${SANDBOX_XDG}" zsh -i -c exit
  )
}

run_tab_probe_sandbox() {
  (
    cd "${TARGET_DIR}"
    HOME="${SANDBOX_HOME}" ZDOTDIR="${SANDBOX_ZDOTDIR}" XDG_CONFIG_HOME="${SANDBOX_XDG}" zsh -i -c 'bindkey -M emacs "^I" >/dev/null'
  )
}

run_fd_scan_live() {
  (
    cd "${TARGET_DIR}"
    fd --hidden --follow --exclude .git --exclude .DS_Store --type f . >/dev/null
  )
}

run_fd_scan_sandbox() {
  (
    cd "${TARGET_DIR}"
    HOME="${SANDBOX_HOME}" ZDOTDIR="${SANDBOX_ZDOTDIR}" XDG_CONFIG_HOME="${SANDBOX_XDG}" fd --hidden --follow --exclude .git --exclude .DS_Store --type f . >/dev/null
  )
}

run_git_scan_live() {
  (
    cd "${TARGET_DIR}"
    {
      git ls-files
      git ls-files --others --exclude-standard
    } >/dev/null
  )
}

run_git_scan_sandbox() {
  (
    cd "${TARGET_DIR}"
    export HOME="${SANDBOX_HOME}"
    export ZDOTDIR="${SANDBOX_ZDOTDIR}"
    export XDG_CONFIG_HOME="${SANDBOX_XDG}"
    {
      git ls-files
      git ls-files --others --exclude-standard
    } >/dev/null
  )
}

benchmark_metric() {
  local mode="$1"
  local metric="$2"
  local runner="$3"
  local i=1
  local start=0
  local end=0
  local ms=0
  local rc=0

  while [[ "${i}" -le "${RUNS}" ]]; do
    start="$(now_ms)"
    if "${runner}" >/dev/null 2>&1; then
      rc=0
    else
      rc=$?
    fi
    end="$(now_ms)"
    ms=$((end - start))
    printf '%s,%s,%s,%s,%s\n' "${mode}" "${metric}" "${i}" "${ms}" "${rc}" >> "${OUT_FILE}"
    i=$((i + 1))
  done
}

print_summary() {
  local key=""
  local mode=""
  local metric=""
  local values_tmp=""
  local count=0
  local mean=0
  local min=0
  local max=0
  local failures=0
  local p50_line=0
  local p95_line=0
  local p50=0
  local p95=0

  echo
  echo "Summary:"
  printf '%-10s %-22s %5s %9s %9s %9s %9s %9s %7s\n' "Mode" "Metric" "Runs" "Mean(ms)" "P50(ms)" "P95(ms)" "Min(ms)" "Max(ms)" "Fail"

  while IFS= read -r key; do
    mode="${key%%,*}"
    metric="${key##*,}"
    values_tmp="$(mktemp "${TMPDIR:-/tmp}/zsh-bench-values.XXXXXX")"
    awk -F, -v m="${mode}" -v k="${metric}" '$1==m && $2==k {print $4}' "${OUT_FILE}" | awk 'NF' > "${values_tmp}"

    count="$(awk 'END{print NR+0}' "${values_tmp}")"
    mean="$(awk '{s+=$1} END{if (NR==0) print "0.0"; else printf "%.1f", s/NR}' "${values_tmp}")"
    min="$(awk 'NR==1{min=$1} $1<min{min=$1} END{if (NR==0) print 0; else print min}' "${values_tmp}")"
    max="$(awk 'NR==1{max=$1} $1>max{max=$1} END{if (NR==0) print 0; else print max}' "${values_tmp}")"
    failures="$(awk -F, -v m="${mode}" -v k="${metric}" '$1==m && $2==k && $5!=0 {f++} END{print f+0}' "${OUT_FILE}")"

    if [[ "${count}" -gt 0 ]]; then
      p50_line=$(( (count + 1) / 2 ))
      p95_line=$(( (95 * count + 99) / 100 ))
      p50="$(sort -n "${values_tmp}" | sed -n "${p50_line}p")"
      p95="$(sort -n "${values_tmp}" | sed -n "${p95_line}p")"
    else
      p50=0
      p95=0
    fi

    printf '%-10s %-22s %5s %9s %9s %9s %9s %9s %7s\n' \
      "${mode}" "${metric}" "${count}" "${mean}" "${p50}" "${p95}" "${min}" "${max}" "${failures}"

    rm -f "${values_tmp}"
  done < <(tail -n +2 "${OUT_FILE}" | cut -d, -f1,2 | sort -u)
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs)
      RUNS="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --target-dir)
      TARGET_DIR="$2"
      shift 2
      ;;
    --out)
      OUT_FILE="$2"
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

need_cmd zsh
need_cmd fd
need_cmd git
need_cmd perl

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "target-dir does not exist: ${TARGET_DIR}" >&2
  exit 1
fi

if [[ "${MODE}" != "live" && "${MODE}" != "sandbox" && "${MODE}" != "both" ]]; then
  echo "Invalid mode: ${MODE} (expected: live|sandbox|both)" >&2
  exit 1
fi

if [[ -z "${OUT_FILE}" ]]; then
  ts="$(date +"%Y%m%d-%H%M%S")"
  OUT_FILE="/tmp/zsh-completion-bench-${ts}.csv"
fi

mkdir -p "$(dirname "${OUT_FILE}")"
printf 'mode,metric,run,ms,rc\n' > "${OUT_FILE}"

echo "Running benchmarks..."
echo "  runs: ${RUNS}"
echo "  mode: ${MODE}"
echo "  target-dir: ${TARGET_DIR}"
echo "  output: ${OUT_FILE}"

is_git_repo=0
if git -C "${TARGET_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git_repo=1
fi

if [[ "${MODE}" == "live" || "${MODE}" == "both" ]]; then
  benchmark_metric "live" "startup_interactive" "run_startup_live"
  benchmark_metric "live" "tab_probe" "run_tab_probe_live"
  benchmark_metric "live" "fd_scan" "run_fd_scan_live"
  if [[ "${is_git_repo}" -eq 1 ]]; then
    benchmark_metric "live" "git_scan" "run_git_scan_live"
  fi
fi

if [[ "${MODE}" == "sandbox" || "${MODE}" == "both" ]]; then
  setup_sandbox
  benchmark_metric "sandbox" "startup_interactive" "run_startup_sandbox"
  benchmark_metric "sandbox" "tab_probe" "run_tab_probe_sandbox"
  benchmark_metric "sandbox" "fd_scan" "run_fd_scan_sandbox"
  if [[ "${is_git_repo}" -eq 1 ]]; then
    benchmark_metric "sandbox" "git_scan" "run_git_scan_sandbox"
  fi
fi

print_summary

echo
echo "Done. Raw results saved to: ${OUT_FILE}"
