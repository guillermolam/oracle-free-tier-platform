#!/usr/bin/env bash
# Deterministic tests for tg. Never touches the real Proton Pass session
# or real OCI credentials -- each case builds an isolated PATH with stub
# `pass-cli`/`oci`/`terragrunt` executables (mirroring
# scripts/check-gpg-signing.test.sh's isolate-don't-mock pattern) so the
# wrapper's resolution/fail-closed logic is exercised for real, without
# ever handling a real secret value. The stub pass-cli simulates just
# enough of `pass-cli info` and `pass-cli run -- <cmd>` (resolving
# pass:// env-var references itself, same as the real binary) to drive
# every branch in tg.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TG="$SCRIPT_DIR/tg"

PASS=0
FAIL=0
LAST_OUT=""
LAST_STATUS=0

# Builds an isolated stub bin/ dir. PASS_CLI_STUB_MODE controls the stub
# pass-cli's behavior (exported into the invoked env, read by the stub):
#   ok                 -- info succeeds, run resolves both fields to
#                         PASS_CLI_STUB_USERNAME/PASSWORD_VALUE
#   not_authenticated  -- `pass-cli info` fails
#   item_missing       -- `pass-cli run` fails resolving (item not found)
#   username_missing   -- `pass-cli run` fails resolving the username field
#   password_missing   -- `pass-cli run` fails resolving the password field
#   username_empty     -- resolves username to an empty string
#   password_empty     -- resolves password to an empty string
# oci_mode controls the stub oci CLI: ok | fail | empty | absent (absent
# = no oci stub installed at all).
make_stub_bin() {
  local dir="$1" oci_mode="$2"
  mkdir -p "$dir"

  cat >"$dir/terragrunt" <<'EOF'
#!/usr/bin/env bash
echo "TERRAGRUNT_INVOKED $*"
echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY"
echo "OCI_OBJECT_STORAGE_NAMESPACE=$OCI_OBJECT_STORAGE_NAMESPACE"
EOF
  chmod +x "$dir/terragrunt"

  cat >"$dir/pass-cli" <<'STUBEOF'
#!/usr/bin/env bash
case "$1" in
  info)
    [[ "${PASS_CLI_STUB_MODE:-ok}" != "not_authenticated" ]]
    exit $?
    ;;
  run)
    shift
    [[ "$1" == "--" ]] && shift
    mode="${PASS_CLI_STUB_MODE:-ok}"

    resolve_field() {
      local field="$1"
      case "$mode" in
        item_missing)
          echo "Error: Failed to resolve secrets" >&2
          echo "Caused by: Could not find item with name X" >&2
          return 1
          ;;
        username_missing)
          if [[ "$field" == "username" ]]; then
            echo "Error: Field 'username' not found in item" >&2
            return 1
          fi
          echo -n "$PASS_CLI_STUB_VALUE"
          ;;
        password_missing)
          if [[ "$field" == "password" ]]; then
            echo "Error: Field 'password' not found in item" >&2
            return 1
          fi
          echo -n "$PASS_CLI_STUB_VALUE"
          ;;
        username_empty)
          if [[ "$field" == "username" ]]; then echo -n ""; else echo -n "$PASS_CLI_STUB_VALUE"; fi
          ;;
        password_empty)
          if [[ "$field" == "password" ]]; then echo -n ""; else echo -n "$PASS_CLI_STUB_VALUE"; fi
          ;;
        *)
          echo -n "$PASS_CLI_STUB_VALUE"
          ;;
      esac
    }

    if [[ "${AWS_ACCESS_KEY_ID:-}" == pass://* ]]; then
      resolved="$(resolve_field username)" || exit 1
      export AWS_ACCESS_KEY_ID="$resolved"
    fi
    if [[ "${AWS_SECRET_ACCESS_KEY:-}" == pass://* ]]; then
      resolved="$(resolve_field password)" || exit 1
      export AWS_SECRET_ACCESS_KEY="$resolved"
    fi
    exec "$@"
    ;;
  *)
    exit 1
    ;;
esac
STUBEOF
  chmod +x "$dir/pass-cli"

  case "$oci_mode" in
    ok)
      cat >"$dir/oci" <<'EOF'
#!/usr/bin/env bash
printf '%s' "ax4ugzw7dvvm"
EOF
      ;;
    fail)
      cat >"$dir/oci" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
      ;;
    empty)
      cat >"$dir/oci" <<'EOF'
#!/usr/bin/env bash
printf ''
EOF
      ;;
    absent) ;; # no stub installed -- command not found
  esac
  [[ "$oci_mode" == "absent" ]] || chmod +x "$dir/oci"
}

# Runs tg in an isolated env; sets LAST_OUT/LAST_STATUS.
invoke_tg() {
  local dir="$1"
  shift
  LAST_OUT="$(env -i PATH="$dir:/usr/bin:/bin" HOME="$HOME" "$@" "$TG" plan 2>&1)"
  LAST_STATUS=$?
}

pass() {
  echo "PASS: $1"
  PASS=$((PASS + 1))
}

fail_case() {
  echo "FAIL: $1"
  echo "$LAST_OUT"
  FAIL=$((FAIL + 1))
}

# 1. Everything resolves -> success, values flow through to terragrunt.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"TERRAGRUNT_INVOKED plan"* && "$LAST_OUT" == *"AWS_ACCESS_KEY_ID=resolved-value"* && "$LAST_OUT" == *"OCI_OBJECT_STORAGE_NAMESPACE=ax4ugzw7dvvm"* ]]; then
  pass "Proton Pass item exists -> success, both fields + namespace flow through"
else
  fail_case "Proton Pass item exists -> success (status=$LAST_STATUS)"
fi

# 2. pass-cli not authenticated -> fail closed, never invokes terragrunt.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=not_authenticated
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* && "$LAST_OUT" == *"not authenticated"* ]]; then
  pass "pass-cli not authenticated -> fail closed"
else
  fail_case "pass-cli not authenticated -> fail closed (status=$LAST_STATUS)"
fi

# 3. Proton Pass item missing -> fail closed, never invokes terragrunt.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=item_missing
rm -rf "$dir"
if [[ $LAST_STATUS -ne 0 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "Proton Pass item missing -> fail closed"
else
  fail_case "Proton Pass item missing -> fail closed (status=$LAST_STATUS)"
fi

# 4. username field missing -> fail closed.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=username_missing PASS_CLI_STUB_VALUE=x
rm -rf "$dir"
if [[ $LAST_STATUS -ne 0 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "username field missing -> fail closed"
else
  fail_case "username field missing -> fail closed (status=$LAST_STATUS)"
fi

# 5. password field missing -> fail closed.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=password_missing PASS_CLI_STUB_VALUE=x
rm -rf "$dir"
if [[ $LAST_STATUS -ne 0 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "password field missing -> fail closed"
else
  fail_case "password field missing -> fail closed (status=$LAST_STATUS)"
fi

# 6. username resolves empty -> terragrunt sees an empty value, not a
#    fabricated one (tg does not itself validate non-emptiness of
#    resolved secret fields -- that's pass-cli/OCI's own concern; this
#    documents actual behavior rather than asserting an unenforced
#    invariant).
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=username_empty PASS_CLI_STUB_VALUE=x
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"AWS_ACCESS_KEY_ID="$'\n'* ]]; then
  pass "username resolves empty -> passed through empty, not fabricated"
else
  fail_case "username resolves empty -> passed through empty (status=$LAST_STATUS)"
fi

# 7. password resolves empty -> same as above for the secret half.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=password_empty PASS_CLI_STUB_VALUE=x
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"AWS_SECRET_ACCESS_KEY="$'\n'* ]]; then
  pass "password resolves empty -> passed through empty, not fabricated"
else
  fail_case "password resolves empty -> passed through empty (status=$LAST_STATUS)"
fi

# 8. Unrelated AWS_PROFILE present -> tg ignores it entirely, still
#    resolves via Proton Pass normally.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value AWS_PROFILE=some-unrelated-sso-profile
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"AWS_ACCESS_KEY_ID=resolved-value"* ]]; then
  pass "unrelated AWS_PROFILE present -> ignored, Proton Pass resolution unaffected"
else
  fail_case "unrelated AWS_PROFILE present -> ignored (status=$LAST_STATUS)"
fi

# 9. Pre-set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY (simulating a stale
#    AWS SSO-style manual export) -> tg overwrites them via Proton Pass
#    rather than honoring the pre-set values (no bypass escape hatch).
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value AWS_ACCESS_KEY_ID=stale-sso-value AWS_SECRET_ACCESS_KEY=stale-sso-secret
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"AWS_ACCESS_KEY_ID=resolved-value"* && "$LAST_OUT" != *"stale-sso"* ]]; then
  pass "pre-set/expired-SSO-style env vars are overwritten by Proton Pass, not honored"
else
  fail_case "pre-set env vars overwritten by Proton Pass (status=$LAST_STATUS)"
fi

# 10. No AWS-related stub or command exists anywhere on PATH (no aws
#     CLI, no ~/.aws-reading tool stubbed) -- tg still succeeds purely
#     via pass-cli + oci, proving it never shells out to anything
#     AWS-specific.
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
rm -f "$dir/aws" 2>/dev/null
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 ]]; then
  pass "wrapper never depends on an aws CLI or AWS-specific tooling"
else
  fail_case "wrapper never depends on an aws CLI or AWS-specific tooling (status=$LAST_STATUS)"
fi

# 11. Namespace already in env -> wrapper must NOT call oci CLI at all.
dir="$(mktemp -d)"
make_stub_bin "$dir" absent
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value OCI_OBJECT_STORAGE_NAMESPACE=preset-ns
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"OCI_OBJECT_STORAGE_NAMESPACE=preset-ns"* ]]; then
  pass "namespace already set -> oci CLI never consulted (absent from PATH, still succeeds)"
else
  fail_case "namespace already set -> oci CLI never consulted (status=$LAST_STATUS)"
fi

# 12. oci CLI resolves the namespace live (auto-resolution succeeds).
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value
rm -rf "$dir"
if [[ $LAST_STATUS -eq 0 && "$LAST_OUT" == *"OCI_OBJECT_STORAGE_NAMESPACE=ax4ugzw7dvvm"* ]]; then
  pass "namespace auto-resolution succeeds via oci CLI"
else
  fail_case "namespace auto-resolution succeeds via oci CLI (status=$LAST_STATUS)"
fi

# 13. oci CLI fails -> namespace resolution fails closed.
dir="$(mktemp -d)"
make_stub_bin "$dir" fail
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "oci CLI failure -> namespace resolution fails closed"
else
  fail_case "oci CLI failure -> namespace resolution fails closed (status=$LAST_STATUS)"
fi

# 14. oci CLI returns empty namespace -> fails closed.
dir="$(mktemp -d)"
make_stub_bin "$dir" empty
invoke_tg "$dir" env PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=resolved-value
rm -rf "$dir"
if [[ $LAST_STATUS -eq 1 && "$LAST_OUT" != *"TERRAGRUNT_INVOKED"* ]]; then
  pass "oci CLI empty namespace -> fails closed"
else
  fail_case "oci CLI empty namespace -> fails closed (status=$LAST_STATUS)"
fi

# 15. Secret value itself never appears in tg's own stderr output (only
#     the child terragrunt process legitimately sees it -- checked here
#     via tg's stderr specifically, captured separately from the child's
#     stdout).
dir="$(mktemp -d)"
make_stub_bin "$dir" ok
LAST_OUT="$(env -i PATH="$dir:/usr/bin:/bin" HOME="$HOME" PASS_CLI_STUB_MODE=ok PASS_CLI_STUB_VALUE=super-secret-marker-value "$TG" plan 2>&1 >/dev/null)"
rm -rf "$dir"
if [[ "$LAST_OUT" != *"super-secret-marker-value"* ]]; then
  pass "secret value never printed to tg's own stderr"
else
  fail_case "secret value leaked to tg's own stderr"
fi

# 16. Provider-boundary separation (source-level invariant, not
#     runtime-plannable): run_with_backend_credentials must not itself
#     reference PASS_VAULT/PASS_ITEM -- only
#     resolve_backend_credentials_proton_pass may, so a future
#     resolve_backend_credentials_openbao() can replace the resolver
#     without touching the injection/exec logic at all.
if ! sed -n '/^run_with_backend_credentials()/,/^}/p' "$TG" | grep -qE 'PASS_VAULT|PASS_ITEM'; then
  pass "provider boundary: run_with_backend_credentials does not reference Proton-Pass-specific variables"
else
  echo "FAIL: provider boundary: run_with_backend_credentials references PASS_VAULT/PASS_ITEM directly"
  FAIL=$((FAIL + 1))
fi

# What these tests do NOT and cannot cover:
# - "backend HCL contains no credential values" -- generated by
#   Terragrunt against real root.hcl, not by this stubbed terragrunt.
#   Verified instead by the real fresh-shell audit (grep the generated
#   backend.tf / .terraform / .terragrunt-cache for access_key=/
#   secret_key= literals and gitleaks) -- see the B1-closeout gate
#   report's Secret Persistence Audit section.
# - "OpenBao provider seam can be substituted later without changing the
#   downstream backend contract" -- a design property proven by
#   construction (run_with_backend_credentials only consumes
#   BACKEND_ACCESS_KEY_ID_REF/BACKEND_SECRET_KEY_REF, never anything
#   Proton-Pass-specific -- see test 16 above) and by this script's own
#   header comment, not something a black-box stub test can verify
#   without literally writing a second provider.

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
