# envs/global in the subscription Azure names AZ1-TCM, where production lives
# (KAT-648 §8 Q1), with its own workspace (README.md):
#
#   terraform -chdir=envs/global workspace select -or-create az1-tcm
#   terraform -chdir=envs/global plan -var-file=az1-tcm.tfvars \
#     -var-file=az1-tcm.local.tfvars -out=az1-tcm.tfplan
#
# Committed: none of it is a secret. The subscription's id and the operator's address
# are in az1-tcm.local.tfvars, which .gitignore keeps on the founder's machine.

subscription_name = "AZ1-TCM"

# Storage account names are unique across Azure, so production's state account is not
# staging's (envs/production/backend.tf names it). Free on 2026-11-07.
state_account_name = "katachitfstateprd"

# The founder's limit for production (2026-11-07: "im limited at $200"), in the billing
# profile's currency, USD. Mail at 50, 80 and 100 per cent of actual spend and at 100
# per cent forecast.
monthly_budget = 200
