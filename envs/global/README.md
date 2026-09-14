# envs/global — the state backend itself

Shared, environment-independent infrastructure: the storage account that
`envs/staging` and `envs/production` keep their Terraform state in.

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
   committed by accident — this state can contain the account's keys.

## Order of operations

```bash
cd envs/global
terraform init
terraform apply -var 'subscription_id=<guid>' -var 'state_account_name=katachitfstate'
```

The three outputs are what each env root's `backend.tf` hardcodes. A backend block
cannot take variables, so those values are literal in `envs/*/backend.tf` and must
match what this root created — change the name here and you change it there too.

Authentication is your `az login` identity: the env backends set
`use_azuread_auth = true`, so no storage account key is ever written to a file or
exported into a shell.
