## Summary

_What does this change and why? Reference the issue/ADR if any._

## Validation

- [ ] `pre-commit run --all-files` passes
- [ ] `tofu fmt -recursive` passes
- [ ] `tofu validate` passes
- [ ] `tflint` passes
- [ ] `checkov` passes (no new HIGH/CRITICAL misconfigurations)
- [ ] CI status checks green: `validate`, `security`, `docs`, `plan`, `dco`
- [ ] Commits are GPG signed and include DCO sign-off (`git commit -s -S`)

## Impact

- [ ] Architecture decision changed (new/updated ADR)
- [ ] Threat model / trust boundaries / DFD / risk register affected
- [ ] New infrastructure state boundary introduced
- [ ] Credential, secret, or access policy touched (rotation required)
- [ ] README / docs / runbooks updated

## Plan / apply

- [ ] `plan` artifact attached and reviewed
- [ ] Deploy owner is Flux (not this workflow), if Kubernetes changes

## Test evidence

_Summarize test / plan output._
