# Terraform/OpenTofu Infrastructure Workflow Reference

> Adapted from Zero Trust DevSecOps best practices (emiresh/zero-trust-devsecops)
> Applied to the Oracle Free Tier Platform's OpenTofu + Terragrunt setup.

## 📋 Core Principles

### 1. Left-Shift Security

Security validation happens **BEFORE** any deployment:

1. **Format check**: `tofu fmt -check` (syntax + style)
2. **Static validation**: `tofu validate` (configuration correctness)
3. **Security scan**: Checkov (IaC vulnerabilities, 800+ OCI checks)
4. **Policy compliance**: TFLint (provider-specific best practices)

### 2. Zero-Trust Credential Management

- **Never** store credentials in workflow files or logs
- All secrets live in GitHub Secrets / OCI Vault
- `terraform_wrapper: false` prevents accidental credential exposure
- Local operations use the `tg` wrapper script (never raw `terragrunt`/`tofu`)

### 3. Environment-Based Deployment Flow

| Event | Action | Approval |
| ------- | -------- | ---------- |
| PR to main | Plan only (preview) | ✅ Comment with plan summary |
| Push to develop | Plan only (test env) | ✅ Automatic |
| Push to main | Plan + Apply | 🛡️ **Manual approval required** |
| workflow_dispatch | Emergency deploy | 🛡️ Manual approval + warning |

## 🔐 OCI Security Checks (CKV_OCI_*)

| Check | What it validates | Our Status |
| ------- | ------------------- | ------------ |
| CKV_OCI_1 | No hardcoded OCI private keys | ✅ PASS |
| CKV_OCI_5 | Legacy IMDS endpoints disabled | ✅ PASS |
| CKV_OCI_7 | Object Storage bucket events | ✅ PASS |
| CKV_OCI_8 | Object Storage versioning | ✅ PASS |
| CKV_OCI_10 | Object Storage not public | ✅ PASS |
| CKV_OCI_17 | Stateless security rules | ✅ PASS |
| CKV_OCI_19 | SSH restricted to IPs | ✅ PASS |
| CKV_OCI_20 | No overly permissive rules | ✅ PASS |
| CKV_OCI_21 | Stateless ingress rules | ✅ PASS (14/14) |
| CKV_OCI_22 | No 0.0.0.0/0 SSH access | ✅ PASS |

## 🛡️ State Management Best Practices

### Remote State Backend

```hcl
backend "s3" {  # OCI Object Storage (S3-compatible)
  bucket                      = "terraform-state-bucket"
  key                         = "zero-trust-platform/terraform.tfstate"
  region                      = "eu-madrid-1"
  endpoint                    = "https://namespace.compat.objectstorage.eu-madrid-1.oraclecloud.com"
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_metadata_api_check     = true
  use_path_style              = true
}
```

### State Locking

- **OCI Object Storage** provides the state backend
- **State locking** prevents concurrent modifications
- **Never** run `tofu`/`terragrunt` directly — always via `tg` wrapper

## 📊 Plan Analysis & PR Comments

### Automatic Resource Analysis

```bash
# Generate plan JSON
tofu show -json tfplan > plan.json

# Count resources
to_add=$(jq -r '.resource_changes | map(select(.change.actions == ["create"])) | length' plan.json)
to_change=$(jq -r '.resource_changes | map(select(.change.actions == ["update"])) | length' plan.json)
to_destroy=$(jq -r '.resource_changes | map(select(.change.actions == ["delete"])) | length' plan.json)
```

### PR Comment Template

```markdown
## 📊 Terraform Plan Summary
**Resources:**
- ✅ **N** to add
- 🔄 **N** to change
- 🗑️ **N** to destroy

### 📋 Resource Changes
- ➕ **oci_core_instance.worker-3**
- 🔄 **oci_core_security_list.k8s_ports**
- 🗑️ **oci_core_instance.worker-1** (replaced)

💡 View full plan in workflow logs
```

## 🚨 Troubleshooting

### "State Locked" Error

```bash
# Find lock info
tofu force-unlock <LOCK_ID>

# Or via OCI Console
# Object Storage → state bucket → .terraform.lock.info
# Delete stale lock file
```

### Checkov Blocks Deployment

```hcl
# Option 1: Fix the issue (preferred)
source = "203.0.113.0/24"  # Specific CIDR instead of 0.0.0.0/0

# Option 2: Skip with justification (only when required)
#checkov:skip=CKV_OCI_20:Proxy requires all traffic access
```

### OCI Authentication Fails

```bash
# Verify credentials work
oci iam user get --user-id $OCI_USER_OCID

# Check:
# 1. Secrets correctly set in GitHub
# 2. API key uploaded to OCI Console
# 3. Fingerprint matches uploaded key
# 4. User has required IAM permissions
```

### Unexpected Plan Changes

```bash
# Detect drift
tofu plan -detailed-exitcode

# Refresh state
tofu refresh

# Compare state vs config
tofu show
```

## 🔧 Deployment Checklist

- [ ] `git status` clean
- [ ] `tofu fmt -check` passes
- [ ] `tofu validate` passes
- [ ] Checkov security scan passes (no CRITICAL/HIGH)
- [ ] TFLint passes
- [ ] Plan generated and reviewed
- [ ] Destructive changes identified and approved
- [ ] Manual approval granted for production deploy
- [ ] State verified consistent
- [ ] Post-deploy verification completed

## 📁 Artifacts Retention

| Artifact | Contents | Retention |
| ---------- | ---------- | ----------- |
| `terraform-plan` | Plan output (JSON + text) | 90 days |
| `checkov-results` | IaC security scan results | 90 days |
| `terraform-outputs` | Deployed resource outputs | 90 days |
| `deployment-results` | Post-deploy state + logs | 90 days |

---
*Reference: [Zero Trust DevSecOps Terraform Workflow](https://github.com/emiresh/zero-trust-devsecops/blob/main/docs/workflows/TERRAFORM-WORKFLOW.md)*
