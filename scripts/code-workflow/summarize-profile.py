#!/usr/bin/env python3
"""Summarize a Qt QML profiler XML trace without loading all events into RAM."""
import argparse
from hashlib import file_digest
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def summarize(path):
    events, totals, bounds = {}, {}, {}
    for phase, element in ET.iterparse(path, events=('start','end')):
        if phase == 'start':
            if element.tag == 'trace':
                bounds = dict(element.attrib)
            continue
        if element.tag == 'event':
            index = element.attrib['index']
            events[index] = {child.tag:child.text for child in element}
            element.clear()
        elif element.tag == 'range':
            index = element.attrib['eventIndex']
            duration = int(element.attrib.get('duration',0))
            value = totals.setdefault(index,{'calls':0,'inclusive_ns':0,'max_ns':0})
            value['calls'] += 1
            value['inclusive_ns'] += duration
            value['max_ns'] = max(value['max_ns'],duration)
            element.clear()
    values = [dict(event=events[index],**value) for index,value in totals.items()]
    values.sort(key=lambda value:value['inclusive_ns'],reverse=True)
    with path.open('rb') as stream:
        digest = file_digest(stream,'sha256').hexdigest()
    return {'trace_sha256':digest,'trace_bytes':path.stat().st_size,'bounds':bounds,
            'duration_unit':'nanoseconds; inclusive nested durations overlap',
            'top_events':values[:25],
            'routing_events':[v for v in values if v['event'].get('details') in
                ('endpoint','setNodePosition','updateEndpoints','rebuildPaths','resetGraph')],
            'total_ranges':sum(v['calls'] for v in values)}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('trace',type=Path)
    print(json.dumps(summarize(ap.parse_args().trace),indent=2))
