#!/usr/bin/env bash
# Managed by repo-guardrails (guillermolam/dotfiles-backup) - local edits are overwritten.
#
# Aggressive in-place dependency updates, committed straight to the default
# branch through the GitHub API (so GitHub signs the commit). Every updater is
# independent: a failure is reported and fails the job (-> notification), but
# whatever did update is still committed.
set -uo pipefail
: "${GH_TOKEN:?Set the AUTO_UPDATE_TOKEN secret (fine-grained PAT: Contents + Workflows read/write)}"
export GITHUB_TOKEN="$GH_TOKEN"
: "${GITHUB_REPOSITORY:?run inside GitHub Actions}"

ACTIONS_UP_VERSION=2.0.0 # bumped by update_tooling
TPL=repo-guardrails/templates # present only in the repo that hosts the templates
ok=() failed=()

step() {
  local name=$1; shift
  echo "::group::$name"
  if "$@"; then ok+=("$name"); else echo "::error::$name failed"; failed+=("$name"); fi
  echo "::endgroup::"
}

dirs_with() { git ls-files -- "*$1" "$1" | xargs -r -n1 dirname | sort -u; }

# --- updaters ------------------------------------------------------------------
update_actions() {
  local dirs=(--dir .github)
  [ -d "$TPL/managed/.github" ] && dirs+=(--dir "$TPL/managed/.github")
  npx --yes "actions-up@${ACTIONS_UP_VERSION}" --yes --quiet --style sha --min-age 1 "${dirs[@]}"
}

update_tooling() {
  local v
  v=$(npm view actions-up version) || return 1
  local f scripts=(.github/scripts/auto-update.sh .github/scripts/actions-up-report.sh) wf=(.github/workflows/secret-scan.yml)
  for f in "$TPL"/managed/.github/scripts/{auto-update,actions-up-report}.sh; do [ -f "$f" ] && scripts+=("$f"); done
  [ -f "$TPL/managed/.github/workflows/secret-scan.yml" ] && wf+=("$TPL/managed/.github/workflows/secret-scan.yml")
  sed -i -E "s/^ACTIONS_UP_VERSION=[^ ]*/ACTIONS_UP_VERSION=$v/" "${scripts[@]}"
  local g t
  g=$(gh api repos/gitleaks/gitleaks/releases/latest --jq .tag_name) || return 1
  t=$(gh api repos/trufflesecurity/trufflehog/releases/latest --jq .tag_name) || return 1
  sed -i -E "s/^(  GITLEAKS_VERSION: ).*/\1${g#v}/; s/^(  TRUFFLEHOG_VERSION: ).*/\1${t#v}/" \
    "${wf[@]}"
}

update_precommit() {
  local rc=0
  [ -f .pre-commit-config.yaml ] && { pipx run pre-commit autoupdate --freeze || rc=1; }
  [ -f "$TPL/pre-commit-managed.yaml" ] && { pipx run pre-commit autoupdate --freeze -c "$TPL/pre-commit-managed.yaml" || rc=1; }
  return $rc
}

update_go() {
  local d rc=0
  for d in $(dirs_with go.mod); do
    (cd "$d" && go get -u ./... && go mod tidy) || { echo "::warning::go update failed in $d"; rc=1; }
  done
  return $rc
}

update_cargo() {
  local d rc=0
  for d in $(dirs_with Cargo.lock); do
    (cd "$d" && cargo update) || { echo "::warning::cargo update failed in $d"; rc=1; }
  done
  return $rc
}

update_npm() {
  local d rc=0
  for d in $(dirs_with package-lock.json); do
    (cd "$d" && npm update --package-lock-only --ignore-scripts --no-audit --no-fund) ||
      { echo "::warning::npm update failed in $d"; rc=1; }
  done
  return $rc
}

install_iac() { # terraform|tofu -> installs latest, checksum-verified
  local tool=$1 v url tmp
  command -v "$tool" >/dev/null && return 0
  tmp=$(mktemp -d)
  if [ "$tool" = tofu ]; then
    v=$(gh api repos/opentofu/opentofu/releases/latest --jq .tag_name) && v=${v#v} || return 1
    url="https://github.com/opentofu/opentofu/releases/download/v$v"
    (cd "$tmp" && curl -fsSLO "$url/tofu_${v}_linux_amd64.tar.gz" &&
      curl -fsSL "$url/tofu_${v}_SHA256SUMS" | grep " tofu_${v}_linux_amd64.tar.gz\$" | sha256sum -c - &&
      tar -xzf "tofu_${v}_linux_amd64.tar.gz" tofu) || return 1
  else
    v=$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version) || return 1
    url="https://releases.hashicorp.com/terraform/$v"
    (cd "$tmp" && curl -fsSLO "$url/terraform_${v}_linux_amd64.zip" &&
      curl -fsSL "$url/terraform_${v}_SHA256SUMS" | grep " terraform_${v}_linux_amd64.zip\$" | sha256sum -c - &&
      unzip -q "terraform_${v}_linux_amd64.zip" terraform) || return 1
  fi
  sudo install -m 0755 "$tmp/$tool" /usr/local/bin/"$tool"
}

update_iac() {
  local d tool rc=0
  for d in $(dirs_with .terraform.lock.hcl); do
    if ! compgen -G "$d/*.tf" >/dev/null; then
      echo "skip $d (no *.tf here; terragrunt-generated lock)"; continue
    fi
    tool=terraform
    grep -q 'registry.opentofu.org' "$d/.terraform.lock.hcl" && tool=tofu
    install_iac "$tool" || { rc=1; continue; }
    (cd "$d" && "$tool" init -upgrade -backend=false -input=false -no-color >/dev/null &&
      "$tool" providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64 -no-color >/dev/null) ||
      { echo "::warning::$tool update failed in $d"; rc=1; }
  done
  return $rc
}

# --- commit through the API (GitHub-signed, DCO signed-off) ----------------------
commit_changes() {
  local files=() f
  while IFS= read -r f; do [ -f "$f" ] && files+=("$f"); done < <(git diff --name-only)
  # new lockfiles only; never stray build output
  while IFS= read -r f; do
    case "$(basename "$f")" in go.sum | Cargo.lock | package-lock.json | .terraform.lock.hcl) files+=("$f") ;; esac
  done < <(git ls-files --others --exclude-standard)
  if [ ${#files[@]} -eq 0 ]; then echo "No updates."; return 0; fi

  local tmp; tmp=$(mktemp -d)
  for f in "${files[@]}"; do
    jq -n --arg p "$f" --rawfile c <(base64 -w0 "$f") '{path: $p, contents: $c}'
  done | jq -s . >"$tmp/additions.json"

  local who; who=$(gh api user --jq '"\(.name // .login) <\(.id)+\(.login)@users.noreply.github.com>"')
  local body
  body=$(printf 'Updated by the auto-update workflow (repo-guardrails).\n\nSteps ok: %s\nSteps failed: %s\n\n%s\n\nSigned-off-by: %s' \
    "${ok[*]:-none}" "${failed[*]:-none}" "$(git diff --stat | tail -n 30)" "$who")

  jq -n --arg repo "$GITHUB_REPOSITORY" --arg branch "$(git rev-parse --abbrev-ref HEAD)" \
    --arg head "$(git rev-parse HEAD)" --arg body "$body" --slurpfile adds "$tmp/additions.json" '{
      query: "mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url } } }",
      variables: { input: {
        branch: { repositoryNameWithOwner: $repo, branchName: $branch },
        expectedHeadOid: $head,
        message: { headline: "chore(deps): automated dependency updates", body: $body },
        fileChanges: { additions: $adds[0] } } } }' >"$tmp/payload.json"
  gh api graphql --input "$tmp/payload.json" --jq '"Committed " + .data.createCommitOnBranch.commit.url'
}

validate() {
  pipx install pre-commit >/dev/null
  local rc=0 hook
  for hook in yamlfmt actionlint zizmor; do
    pre-commit run --all-files "$hook" || rc=1
  done
  return $rc
}

step "actions (actions-up)" update_actions
step "tooling versions" update_tooling
step "pre-commit hooks" update_precommit
step "go modules" update_go
step "cargo" update_cargo
step "npm" update_npm
step "terraform/opentofu providers" update_iac

echo "::group::commit"
commit_changes || failed+=("commit")
echo "::endgroup::"
step "validate .github (fmt, lint, zizmor)" validate

{
  echo "## auto-update"
  echo "- ok: ${ok[*]:-none}"
  echo "- failed: ${failed[*]:-none}"
} >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"
[ ${#failed[@]} -eq 0 ]
