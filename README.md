# n8n on Google Cloud Run

> Minimalistic setup to deploy [n8n](https://n8n.io) workflow automation on Google Cloud Run with external PostgreSQL.

## Quick Start

### 1. Prerequisites

- [Terraform](https://terraform.io) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured
- A PostgreSQL database (free tier works):
  - [NeonDB](https://neon.tech) - Recommended, generous free tier
  - [Supabase](https://supabase.com) - Also works great

### 2. Database Setup

Create a free PostgreSQL database at [NeonDB](https://neon.tech) or [Supabase](https://supabase.com).

Copy your connection string. It should look like:
```
postgresql://user:password@host.neon.tech:5432/n8n?sslmode=require
```

### 3. Local Deployment

```bash
cd terraform

# Copy and edit the example config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Deploy
terraform init
terraform apply
```

### 4. GitHub Actions Deployment

#### Setup Workload Identity Federation

This allows GitHub Actions to authenticate to GCP without storing service account keys.

```bash
# Set your project
export PROJECT_ID="your-project-id"
export GITHUB_REPO="your-username/n8n-gcloud"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"


gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Allow GitHub to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_REPO}"
```

#### Configure Repository Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `GCP_SERVICE_ACCOUNT` | `github-actions@PROJECT_ID.iam.gserviceaccount.com` |
| `DB_HOST` | Database host (e.g., `ep-xy.eu-central-1.aws.neon.tech`) |
| `DB_NAME` | Database name (e.g., `neondb`) |
| `DB_USER` | Database username |
| `DB_PASSWORD` | Database password |
| `N8N_ENCRYPTION_KEY` | Generate with `openssl rand -hex 32` |

#### Deploy

Go to **Actions → Deploy n8n → Run workflow** and select "apply".

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│  Cloud Run      │────▶│  PostgreSQL     │
│  (n8n)          │     │  (NeonDB/       │
│                 │     │   Supabase)     │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Secret Manager  │
│ - DB URL        │
│ - Encryption Key│
└─────────────────┘
```

## Cost Estimate

| Component | Cost |
|-----------|------|
| Cloud Run | ~$0-5/month (pay per use, scale to zero) |
| PostgreSQL | $0 (free tier) |
| Secret Manager | $0.06/month |
| **Total** | **~$0-5/month** |

## Troubleshooting

### "Permission denied" on terraform apply

Ensure your GCP service account has the required roles:
- `roles/run.admin`
- `roles/secretmanager.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/serviceusage.serviceUsageAdmin`

### n8n can't connect to database

1. Check your `DATABASE_URL` format includes `?sslmode=require`
2. Verify the database is accessible from the internet
3. Check Cloud Run logs: `gcloud run services logs read n8n`

### Workflows not persisting

Ensure `N8N_ENCRYPTION_KEY` is set correctly. If you change this key, you'll need to reconfigure all credentials in n8n.

## License

MIT
