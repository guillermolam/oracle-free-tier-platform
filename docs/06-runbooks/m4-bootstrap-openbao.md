# M4 bootstrap OpenBao TLS

This runbook applies the temporary OpenBao listener certificate before the
platform can rotate itself onto OpenBao-issued PKI.

## Preconditions

- `pass-cli` is authenticated with `PROTON_PASS_KEY_PROVIDER=fs`.
- `kubectl` reaches the cluster through OpenZiti and points at
  `https://k8s.lab.internal:6443`.
- `sops` is installed locally.
- `bootstrap/sops/lab/openbao-bootstrap-tls.enc.yaml` exists and remains
  encrypted.
- The Proton Pass item `Personal / M4 SOPS Age Identity / password` exists.

## Apply

Run:

```bash
scripts/apply-openbao-bootstrap-tls.sh
```

What it does:

1. Checks the encrypted artifact exists and matches the expected
   `openbao/openbao-bootstrap-tls` TLS Secret shape.
2. Verifies the active `kubectl` server is `https://k8s.lab.internal:6443`.
3. Resolves the Age key from Proton Pass without printing it.
4. Streams the decrypted Secret directly into `kubectl apply --server-side`.
5. Verifies the resulting Secret still has both `tls.crt` and `tls.key`.

## Validate locally

```bash
scripts/verify-m4.sh ci
scripts/verify-m4.sh readiness
```

`ci` runs deterministic stubbed tests. `readiness` checks that the expected
encrypted bootstrap artifact exists and still contains encryption markers.

## Notes

- This is a bootstrap-only path. The steady-state certificate should later be
  rotated by ESO/OpenBao, not repeatedly re-applied from this artifact.
- If the wrapper reports the wrong Kubernetes API endpoint, stop and fix the
  Ziti-routed kube context before retrying.
