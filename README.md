# IaC

Infrastructure for Katachi that is **committed configuration rather than portal
state**. Anything clicked into a portal is invisible to review, undiscoverable at
3 a.m., and gone when the subscription is rebuilt.

**Terraform creates; Ansible sets up; the pipeline deploys** (KAT-648, ARD-059 §8, the
founder's line of 2026-11-05). This repository holds the first two. Each release is
`tcm/deploy/release.py`, which the pipeline runs and a person can run too.

## Layout

```
modules/            Reusable components. No provider block, no backend, no state.
  network/            the virtual network, the nodes' subnet, the database's delegated subnet
  logs/               one Log Analytics workspace, capped per day
  cluster/            AKS: Entra ID and Azure RBAC, workload identity, the Key Vault CSI driver
  identities/         one identity per unit, the pipeline's, and their federated sign-ins
  registry/           the container registry: the kubelet pulls, the pipeline pushes
  vault/              a Key Vault (used twice: the app vault, and the admin vault)
  database/           PostgreSQL Flexible Server 15, private, TLS 1.3 only
  storage/            tenant files, in KAT-417's shape, and the one role the units that do
                      storage work hold on its container (KAT-418)
  foundry/            the plan's AI: a keyless Foundry resource that answers only the nodes'
                      subnet, its model deployments, and the role the backend calls it with (KAT-650)
  edge/               the gateway's static address, and its DNS when the zone is served here
  environment/        all of the above for one environment, plus storage-detection
  storage-detection/  KAT-417's storage logging and its three security alerts

envs/               Root configurations. One directory per environment = one state file.
  global/             the state backend and the monthly budget, applied first
  staging/            calls modules/environment with staging's values
  production/         the same call with production's values

scripts/            price.py (what a plan costs a month), overlay_values.py (tcm's environment.env)
ansible/            platform.yml: Envoy Gateway, cert-manager, the Gateway and the public certificate
```

**The split is what keeps two environments honest.** A module holds *how* something
is built; `modules/environment` composes them once; an env root holds *which*
subscription, *which* names and *which* state file. Staging and production therefore
differ by `terraform.tfvars`, not by two copies of the same configuration that drift.

Environment names mirror the product's own `ENVIRONMENT` values (KAT-S10:
`staging` and `production`, where a dev AKS cluster is `staging`), rather than
introducing a third vocabulary for the same idea.

## Order of operations

Nothing is applied until the founder has read the plan and its monthly price
(KAT-648 FR10).

```bash
# 1. Once per subscription: the state backend and the budget.
cd envs/global && terraform init && terraform plan -out tfplan
terraform show -json tfplan > plan.json && python3 ../../scripts/price.py plan.json
terraform apply tfplan

# 2. An environment, priced against the ceiling before it is applied.
cd ../staging && terraform init && terraform plan -out tfplan
terraform show -json tfplan > plan.json && python3 ../../scripts/price.py plan.json --ceiling <the founder's>
terraform apply tfplan          # only after he has read both

# 3. tcm's overlay values, from the outputs (no identifier is typed twice).
terraform output -json > outputs.json
python3 ../../scripts/overlay_values.py staging --outputs outputs.json

# 4. The platform, by a person, dry run first.
cd ../../ansible && ./bootstrap.sh
./.venv/bin/ansible-playbook -i inventories/staging platform.yml --check --diff
./.venv/bin/ansible-playbook -i inventories/staging platform.yml
```

Then, in tcm: `deploy/ansible/setup.yml` (the namespace and its rights) and
`secrets.yml` (the vault's values), first boot with `first_boot_open = true` and
then back to `false`, and the first release through the pipeline.

`envs/global` must come first: `envs/*/backend.tf` names the storage account it
creates, and a backend block cannot take variables, so those values are literal and
must match. Authentication is your `az login` session throughout; the env backends set
`use_azuread_auth = true`, so no storage account key is written to a file or exported
into a shell.

## What is still a placeholder

Every one is a `REPLACE` (or a `0`) that `terraform plan`, or the playbook's first
task, refuses. It is not a value that merely looks wrong.

| Value | Where | Whose answer |
|---|---|---|
| `subscription_id` | **never committed**: `<root>/<name>.local.tfvars`, which `.gitignore` keeps local, read from Azure by the subscription's name | §8 Q1: staging in AZ2-NonProd, production in AZ1-TCM; each root checks `subscription_name` against it |
| `app_host`, `mcp_host`, `admin_host` | staging (answered: `staging.katachi.io` and its `mcp.` and `admin.`) and production tfvars, `ansible/inventories/*` | the founder, §8 Q2 |
| `operator_ip_ranges` | **never committed**: the same `.local.tfvars`, as a bare IP (Azure Storage refuses `/32`) | the address Terraform and `secrets.yml` run from |
| `monthly_budget` | `envs/global/<subscription>.tfvars` (staging's: 450 USD) | the founder, §8 Q7 |
| `acme_email`, the gateway's address | `ansible/inventories/{staging,production}` | the contact for Let's Encrypt; Terraform's outputs |

The database tier (B2s) and Azure's managed PostgreSQL are §8 Q3's recommendation,
built as the default and changeable in tfvars.

## Four rules for this repo

**This repository is public** (KAT-648 T-005, measured 2026-11-07): what it must not publish, the subscription's id and the operator's address, lives in git-ignored `*.local.tfvars`, given with `-var-file`. tcm's `docs/runbooks/staging.md` has every command, in order.

**`envs/*/terraform.tfvars` is committed; secrets are not.** Those files hold names,
regions, sizes and CIDRs, none of them secret. The one secret a root takes, an alert
webhook, arrives as `TF_VAR_alert_webhook_url`. The database administrator's password
is an ephemeral value that reaches the server and the admin vault only through
write-only arguments, so it is in neither the plan nor the state.

**A placeholder must fail, not merely look wrong.** A well-formed but fake value
otherwise plans clean, which is how a file full of placeholders gets applied by
accident. (Same lesson as Katachi's KAT-S10, where a 47-character
`CHANGE_ME_IN_PRODUCTION` placeholder passed both existing boot checks.) Each env root
has a test that reads its committed tfvars and fails unless they are refused.

**Nothing newer than a week, and nothing unpinned** (ARD-059 §2):
- **Providers:** constraints admit patches only (`~> 5.12.0`), and `.terraform.lock.hcl`, committed in every module and root, holds the macOS and Linux hashes.
- **Charts:** pinned by version and by their archive's SHA-256, checked before install.
- **Ansible:** ansible-core and its Python dependencies come from `requirements.lock`, with every hash; the collection comes from `collections.lock`.
- **GitHub Actions:** pinned by commit SHA, with a test that refuses a tag.

**`*.tfstate` is never committed.** State can hold secrets in plaintext.

## Tests

```bash
for d in modules/* envs/*; do terraform -chdir=$d init -backend=false -lockfile=readonly && terraform -chdir=$d test; done
python3 -m unittest discover -s scripts/tests
cd ansible && ansible-lint --profile production platform.yml roles
```

Every module test runs against a mocked provider, so none needs a subscription.
`.github/workflows/terraform.yml` runs the first two on every push, and never applies.

## Where the reasoning lives

This repo says what exists. The product docs say why:

- `tcm/docs/ard/ARD-059-one-path-from-a-commit-to-a-cluster.md` — the path, and the line between Terraform, Ansible and the pipeline
- `tcm/docs/features/PRD-015-runtime-substrate-and-scale/KAT-648-the-product-runs-somewhere/` — the feature, its plan and its open questions
- `k8s/observability/storage-diagnostics.md` and `docs/runbooks/storage-alerts.md` (in tcm) — the storage alerts
