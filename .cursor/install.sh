#!/usr/bin/env bash
# Cloud Agent bootstrap for oracle-free-tier-platform.
#
# This repo has no application runtime; its "development experience" is two
# validation pipelines the CI workflows enforce:
#   1. Docs toolchain  -> Node (mmdc / threat-model validator) + markdownlint
#   2. IaC toolchain    -> OpenTofu, Terragrunt, TFLint, Checkov
# orchestrated locally by pre-commit (.pre-commit-config.yaml).
#
# The base image already provides Node 22, Python 3.12, Google Chrome, git and
# curl. This script adds the pinned CLIs the toolchain needs and prepares the
# repo-local dependency state. It is idempotent: pinned tools are re-downloaded
# only when missing or version-mismatched, so a second run is a fast no-op.
set -euo pipefail

# --- Pinned versions -------------------------------------------------------
# tofu:       matches .github/workflows/plan.yml (1.12.5) and satisfies
#             infrastructure/live/common/versions.hcl (>= 1.12.0).
# terragrunt: matches plan.yml's tg_version and provides `terragrunt hcl fmt`
#             / `hcl validate` used by AGENTS.md and .pre-commit-config.yaml.
# tflint:     current release.
# gitleaks:   matches the rev pinned in .pre-commit-config.yaml.
TOFU_VERSION="1.12.5"
TERRAGRUNT_VERSION="1.1.3"
TFLINT_VERSION="0.64.0"
GITLEAKS_VERSION="8.30.1"

BIN_DIR="/usr/local/bin"
ARCH="$(uname -m)" # x86_64
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

log() { printf '\n=== %s ===\n' "$*"; }

# have_version <cmd> <expected> <version-flag...>: true if cmd exists and its
# output contains the expected version string. Output is captured via command
# substitution (not a pipe) so a multi-line version banner can't SIGPIPE the
# tool and trip `pipefail` into a false "not installed".
have_version() {
  local cmd="$1" expected="$2"
  shift 2
  command -v "$cmd" >/dev/null 2>&1 || return 1
  local out
  out="$("$cmd" "$@" 2>&1 || true)"
  case "$out" in
  *"$expected"*) return 0 ;;
  *) return 1 ;;
  esac
}

install_tofu() {
  if have_version tofu "$TOFU_VERSION" version; then
    echo "tofu $TOFU_VERSION already installed"
    return
  fi
  log "Installing OpenTofu $TOFU_VERSION"
  curl -fsSL -o "$TMP/tofu.zip" \
    "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip"
  unzip -o -q "$TMP/tofu.zip" -d "$TMP/tofu"
  sudo install -m 0755 "$TMP/tofu/tofu" "$BIN_DIR/tofu"
}

install_terragrunt() {
  if have_version terragrunt "$TERRAGRUNT_VERSION" --version; then
    echo "terragrunt $TERRAGRUNT_VERSION already installed"
    return
  fi
  log "Installing Terragrunt $TERRAGRUNT_VERSION"
  curl -fsSL -o "$TMP/terragrunt" \
    "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
  sudo install -m 0755 "$TMP/terragrunt" "$BIN_DIR/terragrunt"
}

install_tflint() {
  if have_version tflint "$TFLINT_VERSION" --version; then
    echo "tflint $TFLINT_VERSION already installed"
    return
  fi
  log "Installing TFLint $TFLINT_VERSION"
  curl -fsSL -o "$TMP/tflint.zip" \
    "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
  unzip -o -q "$TMP/tflint.zip" -d "$TMP/tflint"
  sudo install -m 0755 "$TMP/tflint/tflint" "$BIN_DIR/tflint"
}

install_gitleaks() {
  if have_version gitleaks "$GITLEAKS_VERSION" version; then
    echo "gitleaks $GITLEAKS_VERSION already installed"
    return
  fi
  log "Installing gitleaks $GITLEAKS_VERSION"
  curl -fsSL -o "$TMP/gitleaks.tar.gz" \
    "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
  tar -xzf "$TMP/gitleaks.tar.gz" -C "$TMP"
  sudo install -m 0755 "$TMP/gitleaks" "$BIN_DIR/gitleaks"
}

VENV_DIR="/opt/toolchain-venv"

install_python_tools() {
  # pre-commit orchestrates the local gate; checkov is invoked both directly
  # (AGENTS.md: `checkov -d infrastructure`) and by the pre-commit-terraform
  # checkov hook, which shells out to a checkov on PATH.
  #
  # These are installed into a dedicated virtualenv rather than the system
  # dist-packages: checkov pins packaging<24, which collides with the
  # Debian-managed packaging in the base image (pip cannot uninstall it).
  # The venv is isolated (no system site-packages) and its entrypoints are
  # symlinked onto PATH.
  if command -v pre-commit >/dev/null 2>&1 && command -v checkov >/dev/null 2>&1; then
    echo "pre-commit and checkov already installed"
    return
  fi
  log "Ensuring python venv support (python3.12-venv)"
  if ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3.12-venv
  fi
  log "Installing pre-commit and checkov into $VENV_DIR"
  sudo python3 -m venv "$VENV_DIR"
  sudo "$VENV_DIR/bin/pip" install --no-input --disable-pip-version-check --upgrade pip
  sudo "$VENV_DIR/bin/pip" install --no-input --disable-pip-version-check pre-commit checkov
  sudo ln -sf "$VENV_DIR/bin/pre-commit" "$BIN_DIR/pre-commit"
  sudo ln -sf "$VENV_DIR/bin/checkov" "$BIN_DIR/checkov"
}

log "Toolchain versions before install"
node --version && python3 --version

install_tofu
install_terragrunt
install_tflint
install_gitleaks
install_python_tools

log "Installing Node docs tooling (npm ci)"
npm ci

log "Warming pre-commit hook environments"
# Pre-build hook environments so the first `pre-commit run` is fast. This does
# not enable git's hooks path -- enabling enforced local hooks
# (`git config core.hooksPath .githooks`) is an explicit developer opt-in per
# AGENTS.md, deliberately left out of automated setup so it never interferes
# with an agent's own commit workflow. Tolerate transient bootstrap hiccups
# here; the gate is exercised at run time via `pre-commit run`.
pre-commit install-hooks || echo "WARN: pre-commit install-hooks reported an issue; hooks will bootstrap on first run"

log "Installed toolchain"
printf 'tofu:       %s\n' "$(tofu version | head -1)"
printf 'terragrunt: %s\n' "$(terragrunt --version | head -1)"
printf 'tflint:     %s\n' "$(tflint --version | head -1)"
printf 'gitleaks:   %s\n' "$(gitleaks version)"
printf 'pre-commit: %s\n' "$(pre-commit --version)"
printf 'checkov:    %s\n' "$(checkov --version)"
printf 'mmdc:       %s\n' "$(node_modules/.bin/mmdc --version 2>/dev/null || echo 'n/a')"

log "Install complete"
