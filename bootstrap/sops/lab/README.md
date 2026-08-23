# M4 bootstrap SOPS material

This directory exists for the **temporary bootstrap** secret material that
must exist before OpenBao can issue and rotate its own listener
certificate.

## Required artifact

Create the encrypted file below locally and keep it encrypted in Git at all
times:

```text
bootstrap/sops/lab/openbao-bootstrap-tls.enc.yaml
```

It must be a SOPS-encrypted Kubernetes TLS Secret with this fixed metadata:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: openbao-bootstrap-tls
  namespace: openbao
type: kubernetes.io/tls
data:
  tls.crt: ENC[...]
  tls.key: ENC[...]
```

The private Age identity used for decryption is retrieved only at bootstrap
time from Proton Pass:

```text
vault: Personal
item:  M4 SOPS Age Identity
field: password
```

`scripts/apply-openbao-bootstrap-tls.sh` is the only supported local entry
point. It:

1. forces `PROTON_PASS_KEY_PROVIDER=fs`
2. retrieves the Age identity through `pass-cli run`
3. verifies the encrypted file is still encrypted and has the expected
   OpenBao TLS Secret metadata
4. decrypts to stdout only and pipes directly into `kubectl apply`

Never commit a decrypted `.yaml` next to this file, never write the Age key
to disk, and never pass TLS key material via command-line arguments.

This Secret is transitional. Once ESO rotates OpenBao onto an OpenBao-issued
certificate, the bootstrap Secret remains a recovery/bootstrap artifact, not
the steady-state certificate delivery path.
