"""KAT-648 T-005 Step 5 — price.py, against a recorded plan and recorded prices.

No test here touches the network: the prices are the Retail Prices API's answers
recorded on 2026-11-05, and the load balancer's on 2026-11-07
(fixtures/prices-centralus.json), and urlopen is replaced by one that fails the
test if it is called.
"""
import copy
import io
import json
import pathlib
import sys
import unittest
from contextlib import redirect_stdout
from unittest import mock

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import price  # noqa: E402

PLAN = HERE / "fixtures" / "plan-staging.json"
PRICES = HERE / "fixtures" / "prices-centralus.json"

HOURS = 730
DAYS = 730 / 24

# Each figure is the recorded retail price, written out so the arithmetic can be read.
NODE = 0.0972          # Standard_D2as_v5, Linux, pay as you go
AKS_FREE = 0.05        # FreeTierInfrastructureCost Uptime SLA, effective 2026-10-01
PG_B2S = 0.07684       # Flexible Server Burstable BS Series, B2S
PG_GB = 0.13           # Flex Server Storage, Storage Data Stored
ACR_BASIC = 0.1666     # Basic Registry Unit, per day
IP = 0.005             # Standard IPv4 Static Public IP
LOGS_GB = 2.76         # Analytics Logs Data Ingestion, the paid tier
PRIVATE_ZONE = 0.5     # Private Zone, the first-25 tier
LB = 0.025             # Standard Included LB Rules and Outbound Rules (Global), recorded 2026-11-07

# KAT-648 T-005: what AKS makes in its own resource group, which no plan shows: a
# Standard load balancer and one outbound address (outbound_type = "loadBalancer").
AKS_OWN = HOURS * LB + HOURS * IP
FIXED = HOURS * AKS_FREE + HOURS * PG_B2S + 32 * PG_GB + DAYS * ACR_BASIC + HOURS * IP + PRIVATE_ZONE + AKS_OWN
UP_TO = 1 * DAYS * LOGS_GB  # the workspace's daily cap, every day of the month
MINIMUM = round(2 * HOURS * NODE + FIXED + UP_TO, 2)
MAXIMUM = round(3 * HOURS * NODE + FIXED + UP_TO, 2)


def no_network(*_args, **_kwargs):
    raise AssertionError("price.py tried to reach the network in a test")


def run(args, plan=None):
    """Runs price.main with a plan (a path or a dict), returns (exit code, output)."""
    path = PLAN
    if plan is not None:
        path = pathlib.Path(HERE / "fixtures" / "_plan.tmp.json")
        path.write_text(json.dumps(plan))
    out = io.StringIO()
    try:
        with mock.patch("urllib.request.urlopen", no_network), redirect_stdout(out):
            code = price.main([str(path), "--prices", str(PRICES), *args])
    finally:
        if plan is not None:
            path.unlink()
    return code, out.getvalue()


def recorded_plan():
    return json.loads(PLAN.read_text())


class PricesTheRecordedPlan(unittest.TestCase):
    def test_the_monthly_figure_at_the_fewest_and_the_most_nodes(self):
        code, out = run(["--json"])
        self.assertEqual(code, 0, out)
        report = json.loads(out)
        self.assertEqual(report["monthly_minimum"], MINIMUM)
        self.assertEqual(report["monthly_maximum"], MAXIMUM)
        self.assertEqual(report["currency"], "USD")

    def test_a_cost_bounded_by_a_cap_says_up_to(self):
        report = json.loads(run(["--json"])[1])
        logs = [c for c in report["charges"] if c["type"] == "azurerm_log_analytics_workspace"]
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0]["bound"], "up to")
        self.assertAlmostEqual(logs[0]["monthly"], round(UP_TO, 2), places=2)

    def test_usage_priced_resources_are_named_and_kept_out_of_the_total(self):
        report = json.loads(run(["--json"])[1])
        usage = {u["type"] for u in report["usage_priced"]}
        self.assertEqual(usage, {"azurerm_key_vault", "azurerm_storage_account", "azurerm_monitor_scheduled_query_rules_alert_v2"})

    def test_a_resource_being_deleted_is_not_priced(self):
        report = json.loads(run(["--json"])[1])
        self.assertNotIn("azurerm_public_ip.left_over", [c["address"] for c in report["charges"]])

    def test_the_human_report_names_the_total(self):
        code, out = run([])
        self.assertEqual(code, 0)
        self.assertIn(f"{MINIMUM:,.2f}", out)
        self.assertIn(f"{MAXIMUM:,.2f}", out)


def cluster_of(plan):
    return next(c for c in plan["resource_changes"] if c["type"] == "azurerm_kubernetes_cluster")


class WhatAksMakesItself(unittest.TestCase):
    """KAT-648 T-005: with outbound_type "loadBalancer", AKS makes a Standard load
    balancer and an outbound address in its own resource group. Neither is in the
    plan, and both bill every hour, a stopped cluster included. price.py left them
    out until 2026-11-07, 21.90 USD a month low."""

    def made(self, plan=None):
        code, out = run(["--json"], plan)
        self.assertEqual(code, 0, out)
        charges = [c for c in json.loads(out)["charges"] if c["type"] == "azurerm_kubernetes_cluster"]
        return ([c for c in charges if "load balancer" in c["label"]],
                [c for c in charges if "outbound address" in c["label"]])

    def test_its_load_balancer_and_its_outbound_address_are_priced(self):
        balancer, address = self.made()
        self.assertEqual([c["monthly"] for c in balancer], [round(HOURS * LB, 2)])  # 18.25
        self.assertEqual([c["monthly"] for c in address], [round(HOURS * IP, 2)])   # 3.65

    def test_a_cluster_with_no_network_block_is_priced_at_azures_defaults(self):
        plan = recorded_plan()
        del cluster_of(plan)["change"]["after"]["network_profile"]
        balancer, address = self.made(plan)
        self.assertEqual(len(balancer), 1)
        self.assertEqual(len(address), 1)

    def test_each_outbound_address_aks_makes_is_priced_and_none_the_plan_makes(self):
        for profile, count in (({"managed_outbound_ip_count": 2}, 2),
                               ({"outbound_ip_address_ids": ["/subscriptions/0/publicIPAddresses/out"]}, 0)):
            with self.subTest(profile=profile):
                plan = recorded_plan()
                cluster_of(plan)["change"]["after"]["network_profile"][0]["load_balancer_profile"] = [profile]
                balancer, address = self.made(plan)
                self.assertEqual(len(balancer), 1)
                self.assertEqual([c["monthly"] for c in address], [round(count * HOURS * IP, 2)] if count else [])

    def test_a_load_balancer_or_a_way_out_no_rule_prices_is_refused(self):
        for key, value in (("outbound_type", "managedNATGateway"), ("load_balancer_sku", "basic")):
            with self.subTest(value=value):
                plan = recorded_plan()
                cluster_of(plan)["change"]["after"]["network_profile"][0][key] = value
                code, out = run([], plan)
                self.assertEqual(code, 2, out)
                self.assertIn(value, out)


class TheCeiling(unittest.TestCase):
    def test_over_the_ceiling_fails(self):
        code, out = run(["--ceiling", "100"])
        self.assertEqual(code, 1)
        self.assertIn("over the ceiling", out)

    def test_the_ceiling_is_held_against_the_most_nodes(self):
        code, _ = run(["--ceiling", str(MINIMUM + 1)])
        self.assertEqual(code, 1, "a ceiling between the minimum and the maximum must fail")

    def test_under_the_ceiling_passes(self):
        code, out = run(["--ceiling", str(MAXIMUM + 1)])
        self.assertEqual(code, 0, out)

    def test_no_ceiling_says_whose_it_is(self):
        code, out = run([])
        self.assertEqual(code, 0)
        self.assertIn("KAT-648 §8 Q7", out)


class Refusals(unittest.TestCase):
    def test_staging_mail_is_priced_by_use_and_its_records_cost_nothing(self):
        """KAT-648 T-005: Azure Communication Services has no monthly fee; it charges per
        message sent, and the domain, its records, the sender and the SMTP application
        cost nothing of their own."""
        free = {"azurerm_email_communication_service", "azurerm_email_communication_service_domain",
                "azurerm_communication_service_email_domain_association",
                "azurerm_email_communication_service_domain_sender_username",
                "azurerm_dns_txt_record", "azurerm_dns_cname_record",
                "azuread_application", "azuread_service_principal"}
        self.assertEqual(free - price.FREE, set())
        self.assertIn("per message", price.USAGE["azurerm_communication_service"])

    def test_staging_s_switch_costs_nothing(self):
        """KAT-648 T-005: the identity, its sign-in and its custom role cost nothing."""
        self.assertIn("azurerm_role_definition", price.FREE)

    def test_an_unknown_resource_type_is_refused_by_name(self):
        plan = recorded_plan()
        plan["resource_changes"].append({"address": "azurerm_redis_cache.surprise", "mode": "managed", "type": "azurerm_redis_cache",
                                         "name": "surprise", "change": {"actions": ["create"], "after": {"location": "centralus"}}})
        code, out = run([], plan)
        self.assertEqual(code, 2)
        self.assertIn("azurerm_redis_cache", out)

    def test_a_price_nobody_recorded_is_refused(self):
        plan = recorded_plan()
        cluster = next(c for c in plan["resource_changes"] if c["type"] == "azurerm_kubernetes_cluster")
        cluster["change"]["after"]["default_node_pool"][0]["vm_size"] = "Standard_D4as_v5"
        code, out = run([], plan)
        self.assertEqual(code, 2)
        self.assertIn("Standard_D4as_v5", out)

    def test_a_resource_with_no_region_is_refused(self):
        plan = recorded_plan()
        db = next(c for c in plan["resource_changes"] if c["type"] == "azurerm_postgresql_flexible_server")
        del db["change"]["after"]["location"]
        code, out = run([], plan)
        self.assertEqual(code, 2)
        self.assertIn("region", out)

    def test_two_different_prices_for_one_charge_are_refused(self):
        prices = json.loads(PRICES.read_text())
        key = next(k for k in prices["responses"] if k.startswith("serviceName eq 'Virtual Network'"))
        twin = copy.deepcopy(next(i for i in prices["responses"][key] if i["meterName"] == "Standard IPv4 Static Public IP"))
        twin["retailPrice"] = 0.5
        prices["responses"][key].append(twin)
        path = HERE / "fixtures" / "_prices.tmp.json"
        path.write_text(json.dumps(prices))
        out = io.StringIO()
        try:
            with mock.patch("urllib.request.urlopen", no_network), redirect_stdout(out):
                code = price.main([str(PLAN), "--prices", str(path)])
        finally:
            path.unlink()
        self.assertEqual(code, 2)
        self.assertIn("Standard IPv4 Static Public IP", out.getvalue())


if __name__ == "__main__":
    unittest.main()
