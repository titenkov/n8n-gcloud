# AGENTS.md - AI Agent Instructions

This file helps AI agents understand and work with this repository effectively.

## Repository Overview

This repository deploys [n8n](https://n8n.io) workflow automation platform on **Google Cloud Run** using **Terraform**. It uses an external PostgreSQL database for simplicity and cost savings.

## Directory Structure

```
.
├── .github/workflows/
│   ├── terraform-validate.yml  # PR validation (fmt, validate)
│   └── deploy.yml              # Manual deployment workflow
├── terraform/
│   ├── providers.tf            # GCP provider configuration
│   ├── variables.tf            # Input variables
│   ├── main.tf                 # Core infrastructure
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars.example
├── AGENTS.md                   # This file
└── README.md                   # User documentation
```

## Common Operations

### Validate Terraform Changes
```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

### Deploy Locally
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
terraform init
terraform apply
```

### Check Deployment Status
```bash
gcloud run services describe n8n --region=europe-west1
gcloud run services logs read n8n --region=europe-west1 --limit=50
```

### Destroy Infrastructure
```bash
cd terraform
terraform destroy
```

## Key Configuration

### Required Variables
| Variable | Description |
|----------|-------------|
| `gcp_project_id` | Google Cloud project ID |
| `database_url` | PostgreSQL connection URL |
| `n8n_encryption_key` | 32-byte hex key for encrypting credentials |

### GitHub Secrets (for CI/CD)
| Secret | Description |
|--------|-------------|
| `GCP_PROJECT_ID` | Same as `gcp_project_id` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity provider path |
| `GCP_SERVICE_ACCOUNT` | Service account for GitHub Actions |
| `DATABASE_URL` | Same as `database_url` |
| `N8N_ENCRYPTION_KEY` | Same as `n8n_encryption_key` |

## n8n Environment Variables

The following n8n environment variables are configured in `main.tf`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `DB_TYPE` | `postgresdb` | Use PostgreSQL |
| `DATABASE_URL` | (from secret) | Connection string |
| `N8N_ENCRYPTION_KEY` | (from secret) | Credential encryption |
| `N8N_PORT` | `5678` | Internal port |
| `N8N_PROTOCOL` | `https` | Cloud Run provides HTTPS |
| `N8N_RUNNERS_ENABLED` | `true` | Enable workflow runners |
| `GENERIC_TIMEZONE` | configurable | Timezone for schedules |

## Testing Approach

This is infrastructure-as-code, so testing is primarily:

1. **Terraform Validate** - Syntax and configuration checks
2. **Terraform Plan** - Dry-run to preview changes
3. **Manual Verification** - Deploy and test n8n functionality

There are no unit tests - validation happens through Terraform's built-in tools.

## Important Files

| File | When to Modify |
|------|----------------|
| `terraform/main.tf` | Adding/removing GCP resources, changing n8n config |
| `terraform/variables.tf` | Adding new configuration options |
| `.github/workflows/deploy.yml` | Changing deployment process |
| `README.md` | Updating user documentation |

## Gotchas

1. **DATABASE_URL format**: Must include `?sslmode=require` for external Postgres
2. **Encryption key**: Changing it breaks existing n8n credentials
3. **Scale to zero**: Default `min_instances = 0` means cold starts (~10-30s)
4. **Region**: Default is `europe-west1`, change via `gcp_region` variable
