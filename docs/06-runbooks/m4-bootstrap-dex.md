# M4 bootstrap Dex GitHub OAuth Secret

This runbook creates the one Dex bootstrap secret that must exist before
OpenBao and External Secrets Operator can take over steady-state delivery.

## Preconditions

- `kubectl` reaches the cluster through OpenZiti and points at
  `https://k8s.lab.internal:6443`.
- The GitHub OAuth application for Dex already exists with callback:
  `https://auth.platform.lamcloud.net/callback`
- You have the GitHub OAuth client ID and client secret available from the
  approved operator secret source.
- You are not pasting the secret values into Git, shell startup files, or any
  repository file.

## Apply

Export the values in your current shell only:

```bash
export DEX_GITHUB_CLIENT_ID='...'
export DEX_GITHUB_CLIENT_SECRET='...'
```

Create or update the bootstrap Secret:

```bash
kubectl create namespace dex --dry-run=client -o yaml | kubectl apply -f -
kubectl -n dex create secret generic dex-github-connector \
  --from-literal=client-id="$DEX_GITHUB_CLIENT_ID" \
  --from-literal=client-secret="$DEX_GITHUB_CLIENT_SECRET" \
  --dry-run=client -o yaml | kubectl apply --server-side -f -
```

## Validate

```bash
kubectl -n dex get secret dex-github-connector
kubectl -n dex get secret dex-github-connector \
  -o go-template='{{if and (index .data "client-id") (index .data "client-secret")}}keys-present{{end}}'
```

The validation step should confirm the Secret exists and both keys are
present. Do not decode or print the values during routine checks.

## Notes

- This is a bootstrap-only exception, like the out-of-band Flux Git Secret.
- The OpenBao Dex client is intentionally not bootstrapped here; it belongs
  to the later auth-wiring phase after OpenBao and ESO are running.
