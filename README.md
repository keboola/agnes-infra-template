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

## Finding your instance URLs and IPs

Terraform is the source of truth. Do **not** hardcode IPs anywhere — they persist across VM replacement (static addresses), but documenting them manually goes stale when anyone recreates the infra.

```bash
cd terraform
export GOOGLE_APPLICATION_CREDENTIALS=path/to/agnes-deploy-key.json

# Single prod IP
terraform output -raw prod_ip
# 34.77.102.61

# Map of all instances (prod + every dev_instances entry)
terraform output -json instance_ips | jq
# {
#   "agnes-prod": "34.77.102.61",
#   "agnes-dev":  "34.77.94.14"
# }

# JWT secret reference (for app restarts after rotation)
terraform output -raw jwt_secret_name

# Daily backup policy (for 'gcloud compute snapshots list' filtering)
terraform output -raw backup_policy_id
```

Alternative (without Terraform, direct from GCP):

```bash
gcloud compute addresses list \
    --project=<YOUR_GCP_PROJECT_ID> \
    --filter="name~agnes-" \
    --format="table(name, address, status, users)"
```

Or via GCP Console: https://console.cloud.google.com/networking/addresses/list?project=&lt;YOUR_GCP_PROJECT_ID&gt;

**When a VM is recreated** (e.g. `terraform apply -replace=module.agnes.google_compute_instance.vm["agnes-prod"]`), the static IP is preserved — the same address is reattached to the new VM. URLs do not change.

If you have a custom domain, point a DNS A-record at the static IP once; all future VM replacements keep the same address.

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

## Content directories

In addition to Terraform-managed infrastructure, this template ships **content** that an Agnes server pulls from your fork: the initial analyst workspace, your curated marketplace, and the install-prompt template. Each lives in its own sub-tree and is registered with the Agnes server via a different admin endpoint. The three contracts are independent — the workspace parser only reads `workspace/`, the marketplace parser only reads `.claude-plugin/` + `plugins/`, and the install-prompt loader only reads `install-prompt/`.

| Path it owns | Registered in Agnes via | OSS contract |
|---|---|---|
| `workspace/` | `/admin/server-config` → Initial Workspace Template, URL = this repo | [`docs/initial-workspace-override.md`](https://github.com/keboola/agnes-the-ai-analyst/blob/main/docs/initial-workspace-override.md) |
| `.claude-plugin/marketplace.json` + `plugins/*` | `/admin/marketplaces`, URL = this repo | [`docs/marketplace.md`](https://github.com/keboola/agnes-the-ai-analyst/blob/main/docs/marketplace.md) |
| `install-prompt/template.md.tmpl` | `/admin/server-config` → Install-prompt template, URL = this repo | [`docs/seed-repo-contract.md`](https://github.com/keboola/agnes-the-ai-analyst/blob/main/docs/seed-repo-contract.md) |

### `workspace/` — Initial Workspace Template

Shipped to analyst laptops on `agnes init`. The template ships a **vendor-agnostic baseline** — copy this fork into your own private infra repo and customize the placeholder content (CLAUDE.md rules, AGNES_WORKSPACE.md commands) to match your deployment.

| File | Purpose | Customize? |
|---|---|---|
| `workspace/CLAUDE.md` | Project instructions Claude Code loads at session start | Yes — replace the placeholder section with your team's metrics workflow, query patterns, on-call playbooks |
| `workspace/AGNES_WORKSPACE.md` | Human-readable doc — what `agnes init` installed | Optional — the default text is generic |
| `workspace/.claude/settings.json` | Hooks (`agnes pull`/`agnes push`/`agnes self-upgrade`), permissions, `statusLine`, model | Optional — defaults work for most deployments |
| `workspace/.claude/commands/` | `/agnes-private` + `/update-agnes-plugins` slash commands | No — these are baseline Agnes commands |
| `workspace/.claude/CLAUDE.local.md` | Stub for analyst personal notes (preserved across `agnes init --force`) | No — analysts edit this themselves |
| `workspace/.claude/skills/connector-*/SKILL.md` | Connector-specific skills (Asana, Atlassian, Google Workspace) loaded by Claude when the analyst grants matching credentials | Add new connectors as you wire them up |

Sync workflow: after editing under `workspace/`, an admin clicks **Sync now** at `/admin/server-config` on Agnes. Analysts pick up new content on their next `agnes init --force`.

### `.claude-plugin/` + `plugins/` — Curated Marketplace

| File | Purpose |
|---|---|
| `.claude-plugin/marketplace.json` | Manifest — list your curated plugins here (skeleton ships empty) |
| `plugins/<slug>/` | The actual plugins, each with its own `plugin.json` per the Claude Code plugin format |

Sync workflow: Agnes scheduler clones nightly at 03:00 UTC. Manual re-sync via **Sync now** at `/admin/marketplaces`.

### `install-prompt/` — Install-prompt Template

The Mustache-style template Agnes renders into the one-page **install prompt** an analyst sees after admin onboarding. Variables (`{{server_url}}`, `{{credential_email}}`, …) are filled in server-side per tenant. Customize the wording to match your onboarding tone; the template references the connector skills directly so the analyst's first Claude Code session knows which connectors to enable.

## Directory structure

```
.
├── terraform/                   # Infra-as-code
│   ├── main.tf                  #   Module reference; don't customize (PR upstream module changes instead)
│   ├── variables.tf             #   Input schema
│   ├── terraform.tfvars.example #   Copy to terraform.tfvars (gitignored)
│   └── .gitignore
├── .github/workflows/
│   ├── plan.yml                 # PR trigger: terraform plan, comment on PR
│   └── apply.yml                # main push: apply-dev → apply-prod (gated)
├── workspace/                   # Initial Workspace Template — shipped on `agnes init`
│   ├── CLAUDE.md                #   Project rules (customize for your team)
│   ├── AGNES_WORKSPACE.md       #   Human-readable workspace docs
│   └── .claude/
│       ├── settings.json        #   Hooks + permissions + statusLine
│       ├── CLAUDE.local.md      #   Stub for analyst personal notes
│       ├── commands/            #   /agnes-private + /update-agnes-plugins
│       └── skills/              #   Connector skills (asana, atlassian, gws)
├── .claude-plugin/
│   └── marketplace.json         # Curated marketplace manifest (skeleton ships empty)
├── plugins/                     # Curated Claude Code plugins (skeleton ships empty)
├── install-prompt/
│   └── template.md.tmpl         # Install-prompt template rendered per tenant
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
