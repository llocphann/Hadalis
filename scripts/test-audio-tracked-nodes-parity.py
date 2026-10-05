#!/usr/bin/env python3
"""Parity contract for Audio PwObjectTracker one-buffer construction."""
from itertools import product
from pathlib import Path

SOURCE = Path("services/Audio.qml").read_text(encoding="utf-8")


def js_truthy(value):
    return value not in (None, False, 0, 0.0, "", "NaN-SENTINEL")


def before(base, output_nodes, input_nodes):
    # Models JS [base...].concat(output).concat(input).filter(node => node).
    return [
        value for value in list(base) + list(output_nodes) + list(input_nodes)
        if js_truthy(value)
    ]


def after(base, output_nodes, input_nodes):
    nodes = list(base)
    nodes.extend(output_nodes)
    nodes.extend(input_nodes)
    write = 0
    for value in list(nodes):
        if js_truthy(value):
            nodes[write] = value
            write += 1
    del nodes[write:]
    return nodes


values = [None, False, 0, "", "sink", "source", "stream-a", "stream-a", "stream-b"]
cases = 0
for base_mask in product(range(3), repeat=3):
    base = [values[index] for index in base_mask]
    for output_len in range(3):
        output = values[4:4 + output_len]
        for input_len in range(3):
            input_nodes = values[6:6 + input_len]
            assert before(base, output, input_nodes) == after(base, output, input_nodes)
            cases += 1

for token in (
    'const nodes = [rawSink, sink, source]',
    'const outputNodes = root.outputAppNodes ?? []',
    'const inputNodes = root.inputAppNodes ?? []',
    'nodes.push(outputNodes[i])',
    'nodes.push(inputNodes[i])',
    'if (node)',
    'nodes[writeCount++] = node',
    'nodes.length = writeCount',
    'return nodes',
):
    assert token in SOURCE, token

assert '.concat(root.outputAppNodes ?? [])' not in SOURCE
assert '.concat(root.inputAppNodes ?? [])' not in SOURCE
assert '.filter(node => node)' not in SOURCE

# The public reactive partitions must remain independent and source-identical.
assert 'readonly property list<var> outputAppNodes: root.appNodes(true)' in SOURCE
assert 'readonly property list<var> inputAppNodes: root.appNodes(false)' in SOURCE
assert 'readonly property list<var> outputDevices: root.devices(true)' in SOURCE
assert 'readonly property list<var> inputDevices: root.devices(false)' in SOURCE

print(f"ok - Audio tracked-node parity across {cases} deterministic cases")
