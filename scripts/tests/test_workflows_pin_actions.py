"""Every GitHub Action this repository runs is pinned by its full commit SHA.

A tag is a name somebody can move: in March 2026 most of aquasecurity/trivy-action's
version tags were force-pushed to code that stole CI secrets (CVE-2026-33634).
ARD-059 §2; the same rule KAT-648 T-005 holds tcm's workflows to.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
USES = re.compile(r"^\s*-?\s*uses:\s*(\S+)", re.M)
PINNED = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")


def uses_lines(text: str) -> list:
    return USES.findall(text)


class EveryActionIsPinned(unittest.TestCase):
    def test_there_is_a_workflow_to_check(self):
        self.assertTrue(list((ROOT / ".github" / "workflows").glob("*.yml")))

    def test_every_uses_is_a_full_commit_sha(self):
        loose = []
        for workflow in sorted((ROOT / ".github" / "workflows").glob("*.y*ml")):
            for ref in uses_lines(workflow.read_text()):
                if ref.startswith("./"):
                    continue
                if not PINNED.match(ref):
                    loose.append(f"{workflow.name}: {ref}")
        self.assertEqual(loose, [], "pin each Action by its 40-character commit SHA, with the tag as a comment")

    def test_the_check_can_fail(self):
        self.assertFalse(PINNED.match("actions/checkout@v7.0.1"))
        self.assertFalse(PINNED.match("actions/checkout@3d3c42e"))
        self.assertTrue(PINNED.match("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"))


if __name__ == "__main__":
    unittest.main()
