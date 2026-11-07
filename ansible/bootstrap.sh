#!/usr/bin/env bash
# Builds ./.venv and ./collections from the hashed locks (KAT-648 T-007). Run once
# per checkout, then use ./.venv/bin/ansible-playbook. Only a person runs these
# playbooks; no pipeline installs Ansible (KAT-648 §8 Q10).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
python="${PYTHON:-python3.12}"

"$python" -m venv "$here/.venv"
"$here/.venv/bin/python" -m pip install --quiet --require-hashes --no-deps -r "$here/requirements.lock"

download="$(mktemp -d)"
trap 'rm -rf "$download"' EXIT
"$here/.venv/bin/ansible-galaxy" collection download --no-deps -r "$here/requirements.yml" -p "$download" > /dev/null
(cd "$download" && shasum -a 256 -c "$here/collections.lock")
"$here/.venv/bin/ansible-galaxy" collection install --no-deps --force -p "$here/collections" "$download"/*.tar.gz > /dev/null

echo "Ready: $here/.venv/bin/ansible-playbook"
