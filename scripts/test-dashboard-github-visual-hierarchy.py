#!/usr/bin/env python3
"""Guard the Dashboard GitHub card's heatmap-first visual hierarchy."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
qml = (ROOT / "modules" / "dashboard" / "DashGithub.qml").read_text(encoding="utf-8")
failures = []

def require(token: str, reason: str) -> None:
    if token not in qml:
        failures.append(f"{reason}: missing {token!r}")

def forbid(token: str, reason: str) -> None:
    if token in qml:
        failures.append(f"{reason}: forbidden {token!r}")

require('Translation.tr("contributions · last 6 months")',
        "metadata must describe the six-month window")
require('text: "6M"', "period badge must match the six-month window")
require('days.length - 26 * 7',
        "headline total and heatmap must use only the latest 26 weeks")
require('const cols = Math.min(wk.length, 26)',
        "heatmap must render no more than six months")
forbid('Translation.tr("contributions in the last year")',
       "verbose metadata must not return")
forbid('Translation.tr("contributions · last year")',
       "one-year metadata must not return")
forbid('const cols = Math.min(wk.length, 53)',
       "full-year heatmap must not return")

require('* (contributionContent.roomy ? 1.20 : 1.05)',
        "contribution total must stay visually subordinate to the map")
require('Layout.minimumHeight: 48',
        "heatmap must retain useful vertical space")
require('Layout.preferredHeight: contributionContent.roomy ? 112 : 72',
        "heatmap must receive the card's dominant vertical allocation")
require('anchors.margins: contributionContent.roomy ? 6 : 4',
        "heatmap must avoid wasting graph area on inner padding")
require('const gap = Math.max(0.75, Math.min(1.5, pitch * 0.18))',
        "heatmap cells must use the denser graph spacing")
require('contributionContent.roomy ? 14 : 11',
        "six-month heatmap must use the freed width for larger cells")

if failures:
    print("Dashboard GitHub visual hierarchy regression(s):")
    for failure in failures:
        print("  - " + failure)
    raise SystemExit(1)

print("Dashboard GitHub visual hierarchy: PASS")
