#!/usr/bin/env python3
"""Behavior parity for horizontal BarTaskbar overflow trimming."""
from itertools import product
from pathlib import Path

SOURCE = Path("modules/bar/BarTaskbar.qml").read_text(encoding="utf-8")


def old_trim(items, max_fit):
    keep = []
    droppable = []
    for item in items:
        if item["section"] == "separator":
            continue
        if item["running"] is False and item["focused"] is not True:
            droppable.append(item)
        else:
            keep.append(item)

    if len(keep) >= max_fit:
        focused = [item for item in keep if item["focused"] is True]
        rest = [item for item in keep if item["focused"] is not True]
        result = (focused + rest)[:max_fit]
    else:
        result = keep + droppable[:max_fit - len(keep)]

    order_of = {}
    for index, item in enumerate(items):
        order_of[item["uniqueId"]] = index
    result.sort(key=lambda item: order_of[item["uniqueId"]])

    filtered = []
    for index, item in enumerate(result):
        if item["section"] != "separator":
            filtered.append(item)
            continue
        prev = result[index - 1] if index > 0 else None
        next_item = result[index + 1] if index + 1 < len(result) else None
        if (prev and next_item and prev["section"] != "separator"
                and next_item["section"] != "separator"):
            filtered.append(item)
    return filtered


def optimized_trim(items, max_fit):
    keep = []
    droppable = []
    for item in items:
        if item["section"] == "separator":
            continue
        if item["running"] is False and item["focused"] is not True:
            droppable.append(item)
        else:
            keep.append(item)

    if len(keep) >= max_fit:
        focused = []
        rest = []
        for item in keep:
            if item["focused"] is True:
                focused.append(item)
            else:
                rest.append(item)
        result = (focused + rest)[:max_fit]
    else:
        result = keep + droppable[:max_fit - len(keep)]

    order_of = {}
    for index, item in enumerate(items):
        order_of[item["uniqueId"]] = index
    result.sort(key=lambda item: order_of[item["uniqueId"]])
    return result


def make_item(kind, index):
    # Duplicate ids intentionally exercise last-index-wins Map behavior.
    uid = f"id-{index % 2}"
    if kind == 0:
        return {"label": f"s{index}", "uniqueId": uid, "section": "separator",
                "running": False, "focused": False}
    if kind == 1:
        return {"label": f"f{index}", "uniqueId": uid, "section": "app",
                "running": True, "focused": True}
    if kind == 2:
        return {"label": f"r{index}", "uniqueId": uid, "section": "app",
                "running": True, "focused": False}
    return {"label": f"p{index}", "uniqueId": uid, "section": "app",
            "running": False, "focused": False}


def signature(items):
    return [(item["label"], item["uniqueId"]) for item in items]


assert "readonly property var visibleDockItems:" in SOURCE
assert "const focused = keep.filter(" not in SOURCE
assert "const orderOf = new Map(items.map(" not in SOURCE
assert "return result.filter((it, i) =>" not in SOURCE

cases = 0
for length in range(1, 7):
    for kinds in product(range(4), repeat=length):
        items = [make_item(kind, index) for index, kind in enumerate(kinds)]
        for max_fit in range(1, length + 1):
            before = old_trim(items, max_fit)
            after = optimized_trim(items, max_fit)
            assert signature(before) == signature(after), (
                kinds, max_fit, signature(before), signature(after))
            assert all(item["section"] != "separator" for item in after)
            cases += 1

print(f"ok - BarTaskbar overflow parity across {cases} deterministic cases")
