# envs/global — the state backend itself

Shared, environment-independent infrastructure: the storage account that
`envs/staging` and `envs/production` keep their Terraform state in, and the
subscription's monthly budget (KAT-648 T-005), which mails at 50, 80 and 100 per cent
of actual spend and at 100 per cent forecast. It is applied first, so nothing that
costs money exists without it. Its amount is the founder's ceiling (§8 Q7); the
committed `0` is refused.

**This is the one root with no `backend.tf`, and that is not an oversight.** It
creates the account the other roots store state in, so it cannot store its own
state there before it exists. It runs on **local state**, which makes
`terraform.tfstate` in this directory a real artefact rather than a scratch file —
lose it and Terraform no longer knows it owns the state account.

Two ways to handle that, in order of preference:

1. **Migrate it after the first apply.** Once the account exists, add a
   `backend.tf` pointing at `global/terraform.tfstate` inside the very container
   this root created, and run `terraform init -migrate-state`. The chicken-and-egg
   only applies to the *first* apply.
2. **Keep it.** If you would rather not, store the file somewhere durable and
   deliberate. The repo `.gitignore` refuses `*.tfstate`, so it will not be
   committed by accident — this state holds resource ids (the account's keys are off).

## Order of operations

Applied once **in each subscription** (KAT-648 §8 Q1: AZ2-NonProd for staging, AZ1-TCM
for production), each with its own workspace, so each subscription's state is its own.
The committed values are `<subscription>.tfvars`; the subscription's id is in
`<subscription>.local.tfvars`, which `.gitignore` keeps off this public repository.
The root refuses to plan when the subscription the id names is not called
`subscription_name` (KAT-648 T-005). tcm's `docs/runbooks/staging.md` has every step.

```bash
terraform -chdir=envs/global init
terraform -chdir=envs/global workspace select -or-create az2-nonprod
terraform -chdir=envs/global plan -var-file=az2-nonprod.tfvars -var-file=az2-nonprod.local.tfvars -out=az2-nonprod.tfplan
terraform -chdir=envs/global apply az2-nonprod.tfplan
```

The three outputs are what each env root's `backend.tf` hardcodes. A backend block
cannot take variables, so those values are literal in `envs/*/backend.tf` and must
match what this root created — change the name here and you change it there too.
Production's state account needs a name of its own (storage account names are unique
across Azure), so its `backend.tf` changes with it.

Authentication is your `az login` identity: the env backends set
`use_azuread_auth = true`, the account takes no shared key, and this root gives whoever
applies it *Storage Blob Data Contributor* on the account (owning a subscription grants no
right to an account's data). No storage account key is ever written to a file or
exported into a shell.
