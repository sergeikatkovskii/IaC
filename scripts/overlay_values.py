#!/usr/bin/env python3
"""Write an overlay's environment.env from Terraform's outputs.

KAT-648 T-005 Step 6 (ARD-059 §3 and §8). Values cross from this repository to
tcm one way, as a generated file, so no identifier is typed twice:

    terraform -chdir=envs/staging output -json > outputs.json
    python3 scripts/overlay_values.py staging --outputs outputs.json

It writes ../tcm/k8s/overlays/<env>/environment.env, which kustomize injects
with `replacements`; the founder commits it in tcm. --check compares instead of
writing, and exits 1 naming each key that went stale.

Refused, with exit 2 and a sentence: an environment other than staging or
production; an overlay T-002 has not made yet; an output missing, empty, marked
sensitive, still a REPLACE placeholder, or holding a character that would break
the file.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ENVIRONMENTS = ("staging", "production")
UNITS = ("backend", "worker", "scheduler", "mcp", "migrate", "redis", "db-bootstrap")

# environment.env key -> (Terraform output, key inside a map output or None).
# The order is tcm's too: its backend/tests/test_k8s_manifests.py fails a generated
# file whose keys come in any other, so a key added here is added there, in the same
# place (KAT-418 T-003).
KEYS = [
    ("REGISTRY", "registry_login_server", None),
    ("APP_HOST", "app_host", None),
    ("MCP_HOST", "mcp_host", None),
    # KAT-648 T-007: the operator console's own host (§8 Q2), which the routes name.
    ("ADMIN_HOST", "admin_host", None),
    ("TRUSTED_PROXY_CIDR", "pod_cidr", None),
    ("KEY_VAULT_NAME", "key_vault_name", None),
    ("ADMIN_KEY_VAULT_NAME", "admin_key_vault_name", None),
    ("AZURE_TENANT_ID", "tenant_id", None),
    *[(f"CLIENT_ID_{u.upper().replace('-', '_')}", "unit_client_ids", u) for u in UNITS],
    ("DB_MAX_USER_CONNECTIONS", "postgres_max_user_connections", None),
    # KAT-648 T-004: the server administrator first boot's db-bootstrap signs in as.
    ("DB_ADMIN_USER", "postgres_admin_login", None),
    # KAT-418 T-003: the storage account's blob address, where the units reach storage
    # as their own identities from T-004 on (backend-config's AZURE_STORAGE_ACCOUNT_URL).
    # Nothing reads it before T-004, which gives local's file a stand-in in this place.
    ("STORAGE_ACCOUNT_URL", "storage_blob_endpoint", None),
    # KAT-648 T-005: what the pipeline (deploy.yml, first-boot.yml) signs in with and
    # reaches, and the identity setup.yml binds the release Role to. kustomize reads
    # none of these. tcm is private; IaC, which is public, never holds them.
    ("AZURE_SUBSCRIPTION_ID", "subscription_id", None),
    ("CLUSTER_NAME", "cluster_name", None),
    ("CLUSTER_RESOURCE_GROUP", "cluster_resource_group", None),
    ("PIPELINE_CLIENT_ID", "pipeline_client_id", None),
    ("PIPELINE_PRINCIPAL_ID", "pipeline_principal_id", None),
    # KAT-648 T-005: what staging's schedule starts and stops, beside CLUSTER_NAME.
    # Among the pipeline's keys, where tcm's test expects it (KAT-418 T-003 moved it
    # up from after the mail keys).
    ("POSTGRES_SERVER_NAME", "postgres_server_name", None),
    # KAT-648 T-005: where and as whom the product sends mail (Azure Communication
    # Services over SMTP); tcm's k8s/components/mail puts them in backend-config. The
    # password is the vault's, never an output.
    ("SMTP_HOST", "smtp_host", None),
    ("SMTP_USERNAME", "smtp_username", None),
    ("MAIL_FROM", "mail_from", None),
]

# Written only where Terraform made the thing: an environment with no schedule has no
# switch to sign in as, and its file names none rather than an empty one.
OPTIONAL_KEYS = [
    ("POWER_CLIENT_ID", "power_client_id", None),
]

SAFE = re.compile(r"^[A-Za-z0-9._:/@-]+$")
PLACEHOLDER = re.compile(r"(^|[/_.-])REPLACE([/_.-]|$)")


class Refused(Exception):
    pass


def value_for(outputs: dict, output: str, member: str | None) -> str:
    if output not in outputs:
        raise Refused(f"Terraform has no output {output!r}; apply the environment first")
    entry = outputs[output]
    if entry.get("sensitive"):
        raise Refused(f"{output} is marked sensitive, and environment.env is committed: a secret goes in the vault (ARD-018)")
    value = entry.get("value")
    if member is not None:
        if not isinstance(value, dict) or member not in value:
            raise Refused(f"{output} has no {member!r}")
        value, output = value[member], f"{output}[{member}]"
    if output == "postgres_max_user_connections":
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            raise Refused(f"{output} must be a positive count, not {value!r}")
        return str(value)
    if not isinstance(value, str) or value == "":
        raise Refused(f"{output} is empty")
    if PLACEHOLDER.search(value):
        raise Refused(f"{output} is still a REPLACE placeholder: {value!r}")
    if not SAFE.match(value):
        raise Refused(f"{output} holds a character environment.env cannot carry safely: {value!r}")
    return value


def render(env: str, outputs: dict) -> str:
    lines = [
        f"# Generated by IaC/scripts/overlay_values.py from `terraform output` of envs/{env}.",
        "# Do not edit: change Terraform, apply it, and run the script again (ARD-059 §3, §8).",
    ]
    lines += [f"{key}={value_for(outputs, output, member)}" for key, output, member in KEYS]
    lines += [f"{key}={value_for(outputs, output, member)}" for key, output, member in OPTIONAL_KEYS
              if (outputs.get(output) or {}).get("value") is not None]
    return "\n".join(lines) + "\n"


def stale_keys(current: str, wanted: str) -> list:
    def pairs(text):
        return dict(line.split("=", 1) for line in text.splitlines() if line and not line.startswith("#") and "=" in line)
    have, want = pairs(current), pairs(wanted)
    return sorted(k for k in set(have) | set(want) if have.get(k) != want.get(k))


def main(argv: list | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("environment")
    parser.add_argument("--outputs", required=True, help="`terraform output -json`, saved to a file")
    parser.add_argument("--tcm", default=str(pathlib.Path(__file__).resolve().parents[2] / "tcm"),
                        help="the tcm repository (default: next to this one)")
    parser.add_argument("--check", action="store_true", help="compare instead of writing")
    args = parser.parse_args(argv)

    try:
        if args.environment not in ENVIRONMENTS:
            raise Refused(f"environment must be one of {', '.join(ENVIRONMENTS)}")
        overlay = pathlib.Path(args.tcm) / "k8s" / "overlays" / args.environment
        if not overlay.is_dir():
            raise Refused(f"{overlay} does not exist; KAT-648 T-002 makes the overlays")
        with open(args.outputs, encoding="utf-8") as handle:
            wanted = render(args.environment, json.load(handle))
    except Refused as refusal:
        print(f"Refused: {refusal}")
        return 2

    target = overlay / "environment.env"
    if args.check:
        current = target.read_text(encoding="utf-8") if target.exists() else ""
        stale = stale_keys(current, wanted)
        if stale:
            print(f"{target} is stale: {', '.join(stale)}")
            return 1
        print(f"{target} matches Terraform's outputs")
        return 0

    target.write_text(wanted, encoding="utf-8")
    print(f"Wrote {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
