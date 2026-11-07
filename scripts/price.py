#!/usr/bin/env python3
"""What a Terraform plan costs a month, read before anything is applied.

KAT-648 T-005 Step 5. Nothing in Azure is created until the founder has read the
plan and this figure (KAT-648 FR10).

    terraform -chdir=envs/staging plan -out tfplan
    terraform -chdir=envs/staging show -json tfplan > plan.json
    python3 scripts/price.py plan.json --ceiling 400

Prices are Azure's public Retail Prices API (https://prices.azure.com/api/retail/prices),
pay-as-you-go, in the API's currency (USD). A month is 730 hours.

Every resource in the plan lands in exactly one of three groups:

- **priced**: a rule below turns it into a monthly figure. The cluster's nodes
  are priced at the autoscaler's minimum and at its maximum, and the ceiling is
  held against the maximum.
- **usage-priced**: billed by what is done with it (requests, gigabytes stored),
  so it has no figure here and is listed by name instead of being counted as zero.
- **free**: no charge of its own.

A resource type in none of the three is refused by name, and so is a charge
whose price is missing or ambiguous, because a total that quietly leaves
something out is worse than no total.

Exit codes: 0 priced and within the ceiling (or no ceiling given); 1 over the
ceiling; 2 refused.

--prices FILE reads recorded responses instead of the network (the tests do);
--record FILE writes the live responses in that shape.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

API = "https://prices.azure.com/api/retail/prices"
HOURS_PER_MONTH = 730
DAYS_PER_MONTH = HOURS_PER_MONTH / 24

FREE = frozenset({
    "azurerm_consumption_budget_subscription",
    "azurerm_dns_a_record",
    # KAT-648 T-005: staging's mail. The services, the domain, its records, the sender
    # and the SMTP application cost nothing of their own; sending does (USAGE).
    "azurerm_dns_txt_record",
    "azurerm_dns_cname_record",
    "azurerm_email_communication_service",
    "azurerm_email_communication_service_domain",
    "azurerm_communication_service_email_domain_association",
    "azurerm_email_communication_service_domain_sender_username",
    "azuread_application",
    "azuread_service_principal",
    "azurerm_federated_identity_credential",
    "azurerm_key_vault_secret",
    "azurerm_monitor_action_group",
    "azurerm_monitor_diagnostic_setting",
    "azurerm_postgresql_flexible_server_configuration",
    "azurerm_private_dns_zone_virtual_network_link",
    "azurerm_resource_group",
    "azurerm_role_assignment",
    "azurerm_storage_container",
    "azurerm_subnet",
    "azurerm_user_assigned_identity",
    "azurerm_virtual_network",
    "random_string",
    "time_sleep",
})

USAGE = {
    # Azure's Retail Prices API, product "Email", 2026-11-06: 0.00025 USD per message
    # and 0.00012 USD per megabyte sent, no monthly fee.
    "azurerm_communication_service": "mail: 0.00025 USD per message and 0.00012 per megabyte",
    "azurerm_key_vault": "operations: a few cents per 10,000",
    "azurerm_storage_account": "gigabytes stored and operations",
    "azurerm_monitor_scheduled_query_rules_alert_v2": "each rule, by how often it runs",
}


class Refused(Exception):
    """A total that would be wrong. The message says what to fix."""


@dataclass
class Resource:
    address: str
    type: str
    after: dict


@dataclass
class Charge:
    address: str
    type: str
    label: str
    unit_price: float
    unit: str
    quantity_min: float
    quantity_max: float
    bound: str = "fixed"  # "fixed", or "up to" for a cost a cap bounds

    @property
    def monthly_min(self) -> float:
        return self.unit_price * self.quantity_min

    @property
    def monthly_max(self) -> float:
        return self.unit_price * self.quantity_max


@dataclass
class PriceBook:
    """Retail prices, from a recording or the live API, one response per filter."""

    recorded: dict | None = None
    fetched: dict = field(default_factory=dict)
    currencies: set = field(default_factory=set)

    def items(self, query: str) -> list:
        if self.recorded is not None:
            if query not in self.recorded:
                raise Refused(f"no recorded prices for: {query}")
            return self.recorded[query]
        if query not in self.fetched:
            self.fetched[query] = fetch(query)
        return self.fetched[query]

    def one(self, query: str, select, what: str, tiered: bool = False):
        """The single price `select` picks. With tiered=True, several tiers of one
        meter are expected and the highest is taken, so the figure is never low."""
        matches = [i for i in self.items(query) if select(i)]
        if not matches:
            raise Refused(f"no price for {what} (query: {query})")
        units = {(i["unitOfMeasure"], i["currencyCode"]) for i in matches}
        if len(units) > 1:
            raise Refused(f"{what} is priced in more than one unit or currency: {sorted(units)}")
        prices = sorted({float(i["retailPrice"]) for i in matches})
        if len(prices) > 1 and not tiered:
            raise Refused(f"{what} has {len(prices)} different prices ({prices}); a rule must say which one applies")
        unit, currency = units.pop()
        self.currencies.add(currency)
        return prices[-1], unit


def fetch(query: str) -> list:
    """Every page of one query. Retries a rate limit a bounded number of times."""
    url = f"{API}?{urllib.parse.urlencode({'$filter': query})}"
    items = []
    while url:
        for attempt in range(6):
            try:
                with urllib.request.urlopen(url, timeout=30) as response:
                    page = json.load(response)
                break
            except urllib.error.HTTPError as error:
                if error.code != 429 or attempt == 5:
                    raise
                time.sleep(4 * (attempt + 1))
        items.extend(page.get("Items", []))
        url = page.get("NextPageLink")
    return items


def quote(value: str) -> str:
    return value.replace("'", "''")


def region_of(resource: Resource) -> str:
    location = resource.after.get("location")
    if not location:
        raise Refused(f"{resource.address} has no region in the plan, so it cannot be priced")
    return location.replace(" ", "").lower()


# ── The rules: one per priced type ────────────────────────────────────────────

def price_cluster(resource: Resource, book: PriceBook) -> list:
    region = region_of(resource)
    pool = resource.after["default_node_pool"][0]
    size = pool["vm_size"]
    if pool.get("auto_scaling_enabled"):
        fewest, most = pool["min_count"], pool["max_count"]
    else:
        fewest = most = pool["node_count"]
    node, unit = book.one(
        f"serviceName eq 'Virtual Machines' and armRegionName eq '{region}' and armSkuName eq '{quote(size)}' and priceType eq 'Consumption'",
        lambda i: "Windows" not in i["productName"] and "Cloud Services" not in i["productName"]
        and "Spot" not in i["skuName"] and "Low Priority" not in i["skuName"],
        f"a {size} node (Linux, pay as you go)",
    )
    charges = [Charge(resource.address, resource.type, f"{fewest}–{most} × {size} node", node, unit,
                      fewest * HOURS_PER_MONTH, most * HOURS_PER_MONTH)]

    tier = resource.after.get("sku_tier") or "Free"
    meter = {"Free": "FreeTierInfrastructureCost Uptime SLA", "Standard": "Standard Uptime SLA"}.get(tier)
    if meter is None:
        raise Refused(f"no rule prices the AKS {tier} tier")
    control, unit = book.one(
        f"serviceName eq 'Azure Kubernetes Service' and armRegionName eq '{region}' and priceType eq 'Consumption'",
        lambda i: i["meterName"] == meter,
        f"the AKS control plane, {tier} tier ({meter})",
    )
    charges.append(Charge(resource.address, resource.type, f"AKS control plane, {tier} tier", control, unit,
                          HOURS_PER_MONTH, HOURS_PER_MONTH))
    return charges


POSTGRES_PRODUCTS = {"B": "Azure Database for PostgreSQL Flexible Server Burstable BS Series Compute"}


def price_postgres(resource: Resource, book: PriceBook) -> list:
    region = region_of(resource)
    sku = resource.after["sku_name"]
    tier, _, size = sku.split("_", 2)
    product = POSTGRES_PRODUCTS.get(tier)
    if product is None:
        raise Refused(f"no rule prices the PostgreSQL tier {sku}")
    query = f"serviceName eq 'Azure Database for PostgreSQL' and armRegionName eq '{region}' and priceType eq 'Consumption'"
    compute, unit = book.one(query, lambda i: i["productName"] == product and i["skuName"].lower() == size.lower(),
                             f"PostgreSQL {size}")
    storage, storage_unit = book.one(
        query,
        lambda i: i["productName"] == "Azure Database for PostgreSQL Flex Server Storage" and i["meterName"] == "Storage Data Stored",
        "PostgreSQL storage",
    )
    gigabytes = resource.after.get("storage_mb", 32768) / 1024
    return [
        Charge(resource.address, resource.type, f"PostgreSQL {size}", compute, unit, HOURS_PER_MONTH, HOURS_PER_MONTH),
        Charge(resource.address, resource.type, f"PostgreSQL storage, {gigabytes:g} GB", storage, storage_unit, gigabytes, gigabytes),
    ]


def price_registry(resource: Resource, book: PriceBook) -> list:
    region = region_of(resource)
    sku = resource.after["sku"]
    daily, unit = book.one(
        f"serviceName eq 'Container Registry' and armRegionName eq '{region}' and priceType eq 'Consumption'",
        lambda i: i["meterName"] == f"{sku} Registry Unit",
        f"a {sku} registry",
    )
    return [Charge(resource.address, resource.type, f"Container registry, {sku}", daily, unit, DAYS_PER_MONTH, DAYS_PER_MONTH)]


def price_public_ip(resource: Resource, book: PriceBook) -> list:
    region = region_of(resource)
    meter = f"{resource.after['sku']} IPv4 {resource.after['allocation_method']} Public IP"
    hourly, unit = book.one(
        f"serviceName eq 'Virtual Network' and armRegionName eq '{region}' and productName eq 'IP Addresses' and priceType eq 'Consumption'",
        lambda i: i["meterName"] == meter,
        meter,
    )
    return [Charge(resource.address, resource.type, meter, hourly, unit, HOURS_PER_MONTH, HOURS_PER_MONTH)]


def price_log_workspace(resource: Resource, book: PriceBook) -> list:
    region = region_of(resource)
    cap = resource.after.get("daily_quota_gb")
    if cap is None or cap < 0:
        raise Refused(f"{resource.address} has no daily cap, so its cost has no upper bound")
    per_gb, unit = book.one(
        f"serviceName eq 'Log Analytics' and armRegionName eq '{region}' and priceType eq 'Consumption'",
        lambda i: i["meterName"] == "Analytics Logs Data Ingestion",
        "Log Analytics ingestion",
        tiered=True,
    )
    gigabytes = cap * DAYS_PER_MONTH
    return [Charge(resource.address, resource.type, f"Log Analytics ingestion at the {cap:g} GB daily cap", per_gb, unit,
                   gigabytes, gigabytes, bound="up to")]


def price_dns_zone(meter: str):
    def rule(resource: Resource, book: PriceBook) -> list:
        # Every commercial billing zone charges the same; the US Government cloud
        # does not, and is not where this runs.
        monthly, unit = book.one("serviceName eq 'Azure DNS' and priceType eq 'Consumption'",
                                 lambda i: i["meterName"] == meter and not i["armRegionName"].startswith("US Gov"),
                                 f"a DNS {meter.lower()}", tiered=True)
        return [Charge(resource.address, resource.type, f"DNS {meter.lower()}", monthly, unit, 1, 1)]
    return rule


RULES = {
    "azurerm_kubernetes_cluster": price_cluster,
    "azurerm_postgresql_flexible_server": price_postgres,
    "azurerm_container_registry": price_registry,
    "azurerm_public_ip": price_public_ip,
    "azurerm_log_analytics_workspace": price_log_workspace,
    "azurerm_private_dns_zone": price_dns_zone("Private Zone"),
    "azurerm_dns_zone": price_dns_zone("Public Zone"),
}


# ── Reading the plan, and the report ──────────────────────────────────────────

def resources_after_apply(plan: dict) -> list:
    """Every managed resource that exists once the plan is applied."""
    found = []
    for change in plan.get("resource_changes", []):
        if change.get("mode") != "managed":
            continue
        actions = change["change"]["actions"]
        if actions == ["delete"]:
            continue
        found.append(Resource(change["address"], change["type"], change["change"].get("after") or {}))
    return found


def price(plan: dict, book: PriceBook) -> dict:
    resources = resources_after_apply(plan)
    unknown = sorted({r.type for r in resources if r.type not in RULES and r.type not in USAGE and r.type not in FREE})
    if unknown:
        raise Refused("no rule says how these are billed: " + ", ".join(unknown)
                      + ". Add each to RULES, USAGE or FREE in scripts/price.py, with its reason.")
    charges = [c for r in resources if r.type in RULES for c in RULES[r.type](r, book)]
    if len(book.currencies) > 1:
        raise Refused(f"prices came in more than one currency: {sorted(book.currencies)}")
    return {
        "currency": book.currencies.pop() if book.currencies else "USD",
        "monthly_minimum": round(sum(c.monthly_min for c in charges), 2),
        "monthly_maximum": round(sum(c.monthly_max for c in charges), 2),
        "charges": [
            {"address": c.address, "type": c.type, "label": c.label, "bound": c.bound, "unit_price": c.unit_price,
             "unit": c.unit, "monthly": round(c.monthly_min, 2), "monthly_max": round(c.monthly_max, 2)}
            for c in charges
        ],
        "usage_priced": [{"address": r.address, "type": r.type, "billed_by": USAGE[r.type]}
                         for r in resources if r.type in USAGE],
        "free": sum(1 for r in resources if r.type in FREE),
    }


def human(report: dict, ceiling: float | None) -> str:
    cur = report["currency"]
    lines = [f"What this plan costs a month ({cur}, pay as you go, {HOURS_PER_MONTH} hours):", ""]
    for c in report["charges"]:
        span = f"{c['monthly']:>9,.2f}" if c["monthly"] == c["monthly_max"] else f"{c['monthly']:,.2f}–{c['monthly_max']:,.2f}"
        prefix = "up to " if c["bound"] == "up to" else ""
        lines.append(f"  {prefix + span:>22}  {c['label']}  ({c['unit_price']:g} per {c['unit']})")
    lines += ["", f"  {report['monthly_minimum']:,.2f} {cur} a month with the fewest nodes, "
                  f"{report['monthly_maximum']:,.2f} {cur} with the most."]
    if report["usage_priced"]:
        lines += ["", "Billed by use, so not in the total:"]
        lines += [f"  {u['address']}: {u['billed_by']}" for u in report["usage_priced"]]
    lines += ["", f"Free: {report['free']} resources."]
    if ceiling is None:
        lines.append("Ceiling: none given. It is the founder's to set (KAT-648 §8 Q7).")
    elif report["monthly_maximum"] > ceiling:
        lines.append(f"This plan is over the ceiling: {report['monthly_maximum']:,.2f} {cur} at the most nodes, against {ceiling:,.2f}.")
    else:
        lines.append(f"Within the ceiling of {ceiling:,.2f} {cur}, even at the most nodes.")
    return "\n".join(lines)


def main(argv: list | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("plan", help="`terraform show -json tfplan` output")
    parser.add_argument("--ceiling", type=float, help="the monthly ceiling (KAT-648 §8 Q7); held against the most nodes")
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--prices", help="recorded responses instead of the network")
    source.add_argument("--record", help="write the live responses used, in --prices's shape")
    args = parser.parse_args(argv)

    with open(args.plan, encoding="utf-8") as handle:
        plan = json.load(handle)
    recorded = None
    if args.prices:
        with open(args.prices, encoding="utf-8") as handle:
            recorded = json.load(handle)["responses"]
    book = PriceBook(recorded=recorded)

    try:
        report = price(plan, book)
    except Refused as refusal:
        print(f"Refused: {refusal}")
        return 2

    if args.record:
        with open(args.record, "w", encoding="utf-8") as handle:
            json.dump({"recorded": time.strftime("%Y-%m-%d") + f" from {API}", "responses": book.fetched},
                      handle, indent=1, sort_keys=True)

    over = args.ceiling is not None and report["monthly_maximum"] > args.ceiling
    if args.json:
        print(json.dumps({**report, "ceiling": args.ceiling, "over_ceiling": over}, indent=1))
    else:
        print(human(report, args.ceiling))
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
