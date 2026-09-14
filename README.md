# IaC

Infrastructure for Katachi that is **committed configuration rather than portal
state**. Anything clicked into a portal is invisible to review, undiscoverable at
3 a.m., and gone when the subscription is rebuilt.

## Layout

```
modules/          Reusable components. No provider block, no backend, no state.
  storage-detection/    Storage diagnostic logging + three security alert rules
                        main.tf · variables.tf · outputs.tf · versions.tf · queries/

envs/             Root configurations. One directory per environment = one state file.
  global/               Shared, environment-independent: the Terraform state backend
                        itself. The one root with no backend.tf — see its README.
  staging/              main.tf · variables.tf · outputs.tf · versions.tf
                        backend.tf · terraform.tfvars
  production/           the same files, different values
```

**The split is what keeps two environments honest.** A module holds *how* something
is built and is called twice; an env root holds *which* subscription, *which*
storage account and *which* state file. Staging and production therefore differ by
`terraform.tfvars` — not by two copies of the same configuration that drift.

Environment names mirror the product's own `ENVIRONMENT` values (KAT-S10:
`staging` and `production`, where a dev AKS cluster is `staging`), rather than
introducing a third vocabulary for the same idea.

## Order of operations

```bash
# 1. Once per subscription: create the state backend the other roots use.
cd envs/global && terraform init && terraform apply

# 2. Then any environment.
cd ../staging && terraform init && terraform plan && terraform apply
```

`envs/global` must come first: `envs/*/backend.tf` names the storage account it
creates, and a backend block cannot take variables, so those values are literal and
must match.

Authentication is your `az login` session throughout. The env backends set
`use_azuread_auth = true`, so no storage account key is written to a file or
exported into a shell.

## Three rules for this repo

**`envs/*/terraform.tfvars` is committed; secrets are not.** Those files hold
resource ids, regions, retention and CIDRs — the values that make one environment
differ from another, none of them secret. The one secret these modules take, an
alert webhook, arrives as `TF_VAR_alert_webhook_url` or a gitignored
`*.auto.tfvars`.

**A placeholder must fail, not merely look wrong.** `terraform.tfvars` ships with
`REPLACE` markers, and the variables *refuse* them — a well-formed-but-fake
resource id otherwise plans clean, which is how a file full of placeholders gets
applied by accident. (Same lesson as Katachi's KAT-S10, where a 47-character
`CHANGE_ME_IN_PRODUCTION` placeholder passed both existing boot checks.)

**`.terraform.lock.hcl` is committed, `*.tfstate` is not.** The lock pins provider
versions across machines; state can hold secrets in plaintext.

## Where the reasoning lives

This repo says what exists. The product docs say why:

- `k8s/observability/storage-diagnostics.md` — what is collected, and the two ways to misconfigure it
- `docs/runbooks/storage-alerts.md` — what each alert means, what to check, and how to fire it on purpose
