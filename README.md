# Agnes Infrastructure Template

Template for deploying [Agnes](https://github.com/keboola/agnes-the-ai-analyst) — an open-source AI Data Analyst platform — into your own GCP project.

**Use this template to create your own private deployment repo:**

```bash
gh repo create <your-org>/agnes-infra --template keboola/agnes-infra-template --private
```

Then follow the steps below.

---

## Prerequisites

- **GCP project** with billing enabled (you own it, you pay)
- **`gcloud` CLI** authenticated as Owner of that project
- **`terraform`** ≥ 1.5
- **GitHub account** (for private repo + Actions)

## Step 1 — Bootstrap GCP

Download and run the bootstrap script from the public Agnes repo:

```bash
curl -fsSL https://raw.githubusercontent.com/keboola/agnes-the-ai-analyst/main/scripts/bootstrap-gcp.sh -o bootstrap-gcp.sh
chmod +x bootstrap-gcp.sh
./bootstrap-gcp.sh <YOUR_GCP_PROJECT_ID>
```

This creates:
- Service Account `agnes-deploy@<project>.iam.gserviceaccount.com` with Terraform-scoped roles
- GCS bucket `agnes-<project>-tfstate` with versioning
- Enables required APIs (compute, iam, secretmanager, storage, iamcredentials)
- **Generates a SA JSON key** — you'll need this in Step 3.

## Step 2 — Create Keboola token secret (if data_source = keboola)

```bash
echo -n "<YOUR_KEBOOLA_STORAGE_TOKEN>" | gcloud secrets create keboola-storage-token \
    --data-file=- --replication-policy=automatic --project=<YOUR_GCP_PROJECT_ID>
```

## Step 3 — Configure this repo

```bash
gh secret set GCP_SA_KEY < path/to/agnes-deploy-<project>-key.json
rm path/to/agnes-deploy-<project>-key.json   # ⚠ NEVER COMMIT
```

Edit `terraform/main.tf`:
- `backend.bucket` = `agnes-<your-project>-tfstate`
- `backend.prefix` = `<your-customer-name>`

Copy `terraform/terraform.tfvars.example` → `terraform/terraform.tfvars`, fill in values.

## Step 4 — Configure GitHub environments

Go to: Settings → Environments → New environment.

**Create `dev`:** no protection rules.

**Create `prod`:**
- Required reviewers: add yourself or your ops team
- Wait timer: 5 minutes
- Deployment branches: `Selected branches and tags → main`

## Step 5 — First apply

```bash
cd terraform
export GOOGLE_APPLICATION_CREDENTIALS=path/to/agnes-deploy-key.json
terraform init
terraform plan
terraform apply
```

Or push the tfvars to main and let GitHub Actions do it (after step 4).

Output will show `prod_ip`.

## Step 6 — Bootstrap admin user

```bash
PROD_IP=$(terraform output -raw prod_ip)
curl -X POST http://$PROD_IP:8000/auth/bootstrap \
    -H "Content-Type: application/json" \
    -d '{"email": "you@example.com", "password": "YOUR_STRONG_PASSWORD"}'
```

Then open `http://<prod_ip>:8000/login` and sign in.

## Upgrade flows

### App image (code changes in upstream Agnes)

Automatic via cron (every 5 minutes) if `upgrade_mode = "auto"` in tfvars. Otherwise, manual:

```bash
gcloud compute ssh agnes-prod --zone=... --project=... --command="sudo /usr/local/bin/agnes-auto-upgrade.sh"
```

### Infra module (changes in `keboola/agnes-the-ai-analyst//infra/modules/customer-instance`)

Update the module ref in `terraform/main.tf`:

```hcl
source = "github.com/keboola/agnes-the-ai-analyst//infra/modules/customer-instance?ref=infra-v1.X.Y"
```

Open a PR → `terraform plan` runs → review → merge → `terraform apply` runs (dev auto, prod gated).

### Scaling dev VMs (add a branch-pinned dev env)

Edit `terraform.tfvars`:

```hcl
dev_instances = [
  { name = "agnes-dev",           image_tag = "dev" },
  { name = "agnes-alice-feature", image_tag = "dev-feature-alice-xyz" },
]
```

PR → plan → merge → new dev VM spawned. No GitHub env / SA changes needed.

## Directory structure

```
.
├── terraform/
│   ├── main.tf                  # Module reference; don't customize (PR upstream module changes instead)
│   ├── variables.tf             # Input schema
│   ├── terraform.tfvars.example # Copy to terraform.tfvars (gitignored)
│   └── .gitignore
├── .github/workflows/
│   ├── plan.yml                 # PR trigger: terraform plan, comment on PR
│   └── apply.yml                # main push: apply-dev → apply-prod (gated)
├── config/                      # Customer-specific overrides (instance.yaml, branding)
└── README.md
```

## Secrets checklist

- `GCP_SA_KEY` (GitHub secret) — SA JSON key with Terraform-scoped roles
- `keboola-storage-token` (GCP Secret Manager, manual create) — only if `data_source = keboola`
- `agnes-<customer>-jwt-secret` (GCP Secret Manager, TF-managed) — auto-generated

## Security notes

- JWT secret rotates on `terraform apply -replace=module.agnes.google_secret_manager_secret_version.jwt` (invalidates all sessions).
- Keboola token rotation: `gcloud secrets versions add keboola-storage-token` + `sudo docker compose restart` on each VM.
- SA key rotation: generate new key, update `GCP_SA_KEY` secret, delete old key in GCP IAM.

## Support

File issues in [keboola/agnes-the-ai-analyst](https://github.com/keboola/agnes-the-ai-analyst/issues).
