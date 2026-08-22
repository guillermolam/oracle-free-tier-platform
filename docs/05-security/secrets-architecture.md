# Secrets architecture

M4 introduces the first concrete secret-handling paths in this repository.
One of them is Git-committed but SOPS-encrypted; the other stays fully
out of Git:

- OpenBao's **bootstrap** listener certificate
- Dex's **bootstrap** GitHub OAuth client secret

Both are intentionally bootstrap-only bridges that let the cluster reach the
point where OpenBao, External Secrets Operator, and PKI can take over.

## Bootstrap boundary

The bootstrap TLS Secret is stored as:

```text
bootstrap/sops/lab/openbao-bootstrap-tls.enc.yaml
```

Controls:

- The file stays SOPS-encrypted in Git at all times.
- The Age private identity is sourced from Proton Pass only:
  `pass://Personal/M4 SOPS Age Identity/password`.
- Decryption happens only in-memory through
  `scripts/apply-openbao-bootstrap-tls.sh`.
- The decrypted manifest is streamed directly into `kubectl apply`; no temp
  file is written.
- The Secret metadata is fixed to `openbao/openbao-bootstrap-tls` and the
  script refuses any other target.
- The wrapper refuses to run unless the current `kubectl` context points to
  `https://k8s.lab.internal:6443`.

Dex's GitHub OAuth secret is different on purpose:

- It is never committed, even encrypted.
- It is created out of band as `dex/dex-github-connector`.
- It exists only to let Dex come up before OpenBao and ESO can become the
  steady-state secret path.
- Once OpenBao and ESO own that value, the bootstrap creation step becomes a
  migration/rotation concern rather than a normal operating path.

## Ownership line

- Proton Pass is the bootstrap secret source.
- SOPS is the encrypted transport/container for Git.
- `kubectl` performs a one-time server-side apply into the cluster.
- OpenBao later becomes the steady-state owner for TLS issuance and other
  platform secrets.
- ESO becomes the steady-state delivery plane to workloads.

That split keeps bootstrap mechanics out of the long-term secret contract and
matches the repository rule that Flux must not be the path by which private
secret values enter the cluster.

## Non-goals of this slice

- No decrypted TLS artifact is committed.
- No Flux SOPS decryption path is introduced here.
- No OpenBao configuration is stored in Terraform state.
- No Proton Pass secret is printed, logged, or written to disk.
