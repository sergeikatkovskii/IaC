# Shared values. Committed on purpose: none of them is a secret.
#
# ⚠ Placeholders, refused until they are real (this repository's second rule):
#   subscription_id   KAT-648 §8 Q1 — the founder gives the subscriptions later
#   monthly_budget    KAT-648 §8 Q7 — his monthly ceiling; 0 is refused

subscription_id    = "REPLACE-WITH-SUBSCRIPTION-GUID"
location           = "centralus"
state_account_name = "katachitfstate"

monthly_budget        = 0
budget_contact_emails = ["sergei.katkovskii@gmail.com"]

# Never a real value here (this repository is public): <subscription>.local.tfvars
# gives the founder's address, and this placeholder is refused until it does.
operator_ip_ranges = ["REPLACE"]
