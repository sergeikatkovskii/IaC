# envs/global in the subscription Azure names AZ2-NonProd, where staging lives
# (KAT-648 §8 Q1). Applied with its own workspace, so each subscription's state is its
# own (README.md):
#
#   terraform -chdir=envs/global workspace select -or-create az2-nonprod
#   terraform -chdir=envs/global plan -var-file=az2-nonprod.tfvars \
#     -var-file=az2-nonprod.local.tfvars -out=az2-nonprod.tfplan
#
# Committed: none of it is a secret. The subscription's id is not here, because this
# repository is public: az2-nonprod.local.tfvars holds it, and .gitignore keeps that
# file on the founder's machine. subscription_name is checked against it.

subscription_name  = "AZ2-NonProd"
state_account_name = "katachitfstate"

# KAT-648 §8 Q7: 450 a month for staging, in the billing profile's currency, which is
# USD (read 2026-11-07). Mail at 50, 80 and 100 per cent of actual spend and at 100
# per cent forecast.
monthly_budget = 450
