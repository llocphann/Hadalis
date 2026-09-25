use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::Path;

use anyhow::{Context, Result, anyhow};
use regex::Regex;
use serde_json::{Map, Value, json};

const WORK_TYPES: &[&str] = &[
    "Binding",
    "HandlingSignal",
    "Javascript",
    "Creating",
    "Compiling",
];

#[derive(Clone, Debug, Default)]
struct EventType {
    kind: String,
    filename: String,
    line: Option<u64>,
    details: String,
}

#[derive(Clone, Debug)]
struct WorkRange {
    start_ns: i64,
    end_ns: i64,
    source_path: Option<String>,
}

#[derive(Clone, Debug)]
struct MemoryPoint {
    at_ns: i64,
    amount: i64,
}

#[derive(Clone, Debug, Default)]
struct OwnerStats {
    qml_work_ns: u64,
    range_count: u64,
    ranges_by_type: BTreeMap<String, u64>,
    allocated_bytes: u64,
    freed_bytes: u64,
    allocation_events: u64,
}

impl OwnerStats {
    fn merge(&mut self, other: &OwnerStats) {
        self.qml_work_ns = self.qml_work_ns.saturating_add(other.qml_work_ns);
        self.range_count = self.range_count.saturating_add(other.range_count);
        self.allocated_bytes = self.allocated_bytes.saturating_add(other.allocated_bytes);
        self.freed_bytes = self.freed_bytes.saturating_add(other.freed_bytes);
        self.allocation_events = self.allocation_events.saturating_add(other.allocation_events);
        for (kind, count) in &other.ranges_by_type {
            *self.ranges_by_type.entry(kind.clone()).or_default() += count;
        }
    }

    fn record_allocation(&mut self, amount: i64) {
        self.allocation_events = self.allocation_events.saturating_add(1);
        if amount >= 0 {
            self.allocated_bytes = self.allocated_bytes.saturating_add(amount as u64);
        } else {
            self.freed_bytes = self.freed_bytes.saturating_add(amount.unsigned_abs());
        }
    }
}

fn decode_xml(value: &str) -> String {
    html_escape::decode_html_entities(value).into_owned()
}

fn tag_text(block: &str, tag: &str) -> String {
    let start_tag = format!("<{tag}>");
    let end_tag = format!("</{tag}>");
    let Some(start) = block.find(&start_tag) else {
        return String::new();
    };
    let payload_start = start + start_tag.len();
    let Some(relative_end) = block[payload_start..].find(&end_tag) else {
        return String::new();
    };
    decode_xml(&block[payload_start..payload_start + relative_end])
}

fn parse_attributes(raw: &str, attr_re: &Regex) -> BTreeMap<String, String> {
    attr_re
        .captures_iter(raw)
        .filter_map(|capture| {
            Some((
                capture.get(1)?.as_str().to_owned(),
                decode_xml(capture.get(2)?.as_str()),
            ))
        })
        .collect()
}

fn parse_event_types(xml: &str) -> Result<BTreeMap<usize, EventType>> {
    let event_re = Regex::new(r#"(?s)<event\s+index="(\d+)"[^>]*>(.*?)</event>"#)?;
    let mut result = BTreeMap::new();
    for capture in event_re.captures_iter(xml) {
        let index = capture[1].parse::<usize>()?;
        let block = &capture[2];
        result.insert(
            index,
            EventType {
                kind: tag_text(block, "type"),
                filename: tag_text(block, "filename"),
                line: tag_text(block, "line").parse::<u64>().ok(),
                details: tag_text(block, "details"),
            },
        );
    }
    if result.is_empty() {
        return Err(anyhow!("qmlprofiler trace contains no event metadata"));
    }
    Ok(result)
}

fn parse_trace_bounds(xml: &str, attr_re: &Regex) -> Result<(i64, i64)> {
    let trace_re = Regex::new(r#"<trace\b([^>]*)>"#)?;
    let capture = trace_re
        .captures(xml)
        .ok_or_else(|| anyhow!("qmlprofiler trace root is missing"))?;
    let attrs = parse_attributes(&capture[1], attr_re);
    let start = attrs
        .get("traceStart")
        .ok_or_else(|| anyhow!("qmlprofiler traceStart is missing"))?
        .parse::<i64>()?;
    let end = attrs
        .get("traceEnd")
        .ok_or_else(|| anyhow!("qmlprofiler traceEnd is missing"))?
        .parse::<i64>()?;
    if end < start {
        return Err(anyhow!("qmlprofiler traceEnd precedes traceStart"));
    }
    Ok((start, end))
}

fn percent_decode_path(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut output = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hi = (bytes[index + 1] as char).to_digit(16);
            let lo = (bytes[index + 2] as char).to_digit(16);
            if let (Some(hi), Some(lo)) = (hi, lo) {
                output.push(((hi << 4) | lo) as u8);
                index += 3;
                continue;
            }
        }
        output.push(bytes[index]);
        index += 1;
    }
    String::from_utf8_lossy(&output).into_owned()
}

fn normalized_source(filename: &str, shell_root: &Path) -> Option<String> {
    if filename.is_empty() {
        return None;
    }
    let decoded = percent_decode_path(filename);
    let raw_path = decoded
        .strip_prefix("file://")
        .or_else(|| decoded.strip_prefix("file:"))
        .unwrap_or(&decoded);
    if raw_path.starts_with("qrc:") || raw_path.starts_with(":/") {
        return None;
    }

    let root = shell_root.to_string_lossy();
    let root = root.trim_end_matches('/');
    let path = raw_path.replace('\\', "/");
    let root = root.replace('\\', "/");
    if path == root {
        return None;
    }
    let prefix = format!("{root}/");
    let relative = path.strip_prefix(&prefix)?;
    if relative.is_empty() || relative.starts_with("../") {
        return None;
    }
    Some(relative.to_owned())
}

fn module_for_source(source: &str) -> String {
    let parts: Vec<&str> = source.split('/').filter(|part| !part.is_empty()).collect();
    match parts.as_slice() {
        ["modules", family, ..] => format!("modules/{family}"),
        ["services", ..] => "services".to_owned(),
        [first, ..] => (*first).to_owned(),
        [] => "root".to_owned(),
    }
}

fn component_label(source: &str) -> String {
    Path::new(source)
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or(source)
        .to_owned()
}

fn innermost_range(active: &BTreeSet<usize>, ranges: &[WorkRange]) -> Option<usize> {
    active.iter().copied().max_by(|left, right| {
        let left_range = &ranges[*left];
        let right_range = &ranges[*right];
        left_range
            .start_ns
            .cmp(&right_range.start_ns)
            .then_with(|| right_range.end_ns.cmp(&left_range.end_ns))
            .then_with(|| left.cmp(right))
    })
}

fn allocate_exclusive_work(
    ranges: &[WorkRange],
    components: &mut BTreeMap<String, OwnerStats>,
) -> u64 {
    #[derive(Clone, Copy)]
    struct Boundary {
        at_ns: i64,
        starts: bool,
        range_index: usize,
    }

    let mut boundaries = Vec::with_capacity(ranges.len() * 2);
    for (index, range) in ranges.iter().enumerate() {
        if range.end_ns <= range.start_ns {
            continue;
        }
        boundaries.push(Boundary {
            at_ns: range.start_ns,
            starts: true,
            range_index: index,
        });
        boundaries.push(Boundary {
            at_ns: range.end_ns,
            starts: false,
            range_index: index,
        });
    }
    boundaries.sort_by(|left, right| {
        left.at_ns
            .cmp(&right.at_ns)
            .then_with(|| left.starts.cmp(&right.starts))
    });

    let mut active = BTreeSet::new();
    let mut previous_time = boundaries.first().map(|item| item.at_ns);
    let mut attributed = 0_u64;
    let mut cursor = 0;
    while cursor < boundaries.len() {
        let at_ns = boundaries[cursor].at_ns;
        if let Some(previous) = previous_time
            && at_ns > previous
            && let Some(index) = innermost_range(&active, ranges)
            && let Some(source) = ranges[index].source_path.as_ref()
        {
            let duration = (at_ns - previous) as u64;
            components.entry(source.clone()).or_default().qml_work_ns += duration;
            attributed = attributed.saturating_add(duration);
        }

        while cursor < boundaries.len() && boundaries[cursor].at_ns == at_ns {
            let boundary = boundaries[cursor];
            if boundary.starts {
                active.insert(boundary.range_index);
            } else {
                active.remove(&boundary.range_index);
            }
            cursor += 1;
        }
        previous_time = Some(at_ns);
    }
    attributed
}

fn attribute_memory(
    points: &[MemoryPoint],
    ranges: &[WorkRange],
    components: &mut BTreeMap<String, OwnerStats>,
) -> (u64, u64) {
    let mut order: Vec<usize> = (0..ranges.len()).collect();
    order.sort_by_key(|index| ranges[*index].start_ns);
    let mut points = points.to_vec();
    points.sort_by_key(|point| point.at_ns);

    let mut active = BTreeSet::new();
    let mut next_range = 0;
    let mut attributed_events = 0_u64;
    let mut attributed_allocated_bytes = 0_u64;

    for point in points {
        while next_range < order.len()
            && ranges[order[next_range]].start_ns <= point.at_ns
        {
            active.insert(order[next_range]);
            next_range += 1;
        }
        active.retain(|index| ranges[*index].end_ns >= point.at_ns);
        let Some(index) = innermost_range(&active, ranges) else {
            continue;
        };
        let Some(source) = ranges[index].source_path.as_ref() else {
            continue;
        };
        let stats = components.entry(source.clone()).or_default();
        stats.record_allocation(point.amount);
        attributed_events = attributed_events.saturating_add(1);
        if point.amount > 0 {
            attributed_allocated_bytes =
                attributed_allocated_bytes.saturating_add(point.amount as u64);
        }
    }

    (attributed_events, attributed_allocated_bytes)
}

fn stats_json(
    id: &str,
    label: &str,
    kind: &str,
    stats: &OwnerStats,
    trace_duration_ns: u64,
) -> Value {
    let duration_seconds = trace_duration_ns as f64 / 1_000_000_000.0;
    let work_ms = stats.qml_work_ns as f64 / 1_000_000.0;
    let work_ms_per_second = if duration_seconds > 0.0 {
        work_ms / duration_seconds
    } else {
        0.0
    };
    let work_share = if trace_duration_ns > 0 {
        stats.qml_work_ns as f64 * 100.0 / trace_duration_ns as f64
    } else {
        0.0
    };
    let net_bytes = stats.allocated_bytes as i128 - stats.freed_bytes as i128;

    json!({
        "id": id,
        "label": label,
        "kind": kind,
        "qmlWorkNs": stats.qml_work_ns,
        "qmlWorkMsPerSecond": work_ms_per_second,
        "qmlWorkSharePercent": work_share,
        "rangeCount": stats.range_count,
        "rangesByType": stats.ranges_by_type,
        "allocations": {
            "eventCount": stats.allocation_events,
            "allocatedBytes": stats.allocated_bytes,
            "freedBytes": stats.freed_bytes,
            "netBytes": net_bytes,
            "semantics": "QV4 allocation/deallocation events while this owner was the innermost active QML range; not retained RSS/PSS"
        }
    })
}

fn sorted_rows(
    stats: &BTreeMap<String, OwnerStats>,
    kind: &str,
    trace_duration_ns: u64,
) -> Vec<Value> {
    let mut rows: Vec<(&String, &OwnerStats)> = stats.iter().collect();
    rows.sort_by(|(left_id, left), (right_id, right)| {
        right
            .qml_work_ns
            .cmp(&left.qml_work_ns)
            .then_with(|| right.allocated_bytes.cmp(&left.allocated_bytes))
            .then_with(|| left_id.cmp(right_id))
    });
    rows.into_iter()
        .map(|(id, stats)| {
            let label = if kind == "component" || kind == "service" {
                component_label(id)
            } else {
                id.clone()
            };
            stats_json(id, &label, kind, stats, trace_duration_ns)
        })
        .collect()
}

pub fn summarize(trace_path: &Path, shell_root: &Path) -> Result<Value> {
    let xml = fs::read_to_string(trace_path)
        .with_context(|| format!("failed to read qmlprofiler trace {}", trace_path.display()))?;
    let attr_re = Regex::new(r#"([A-Za-z][A-Za-z0-9_-]*)="([^"]*)""#)?;
    let event_types = parse_event_types(&xml)?;
    let (trace_start, trace_end) = parse_trace_bounds(&xml, &attr_re)?;
    let trace_duration_ns = trace_end.saturating_sub(trace_start) as u64;

    let range_re = Regex::new(r#"<range\b([^>]*)/>"#)?;
    let mut work_ranges = Vec::new();
    let mut memory_points = Vec::new();
    let mut components: BTreeMap<String, OwnerStats> = BTreeMap::new();
    let mut total_work_range_ns = 0_u64;
    let mut total_memory_events = 0_u64;
    let mut total_allocated_bytes = 0_u64;

    for capture in range_re.captures_iter(&xml) {
        let attrs = parse_attributes(&capture[1], &attr_re);
        let Some(event_index) = attrs
            .get("eventIndex")
            .and_then(|value| value.parse::<usize>().ok())
        else {
            continue;
        };
        let Some(event_type) = event_types.get(&event_index) else {
            continue;
        };
        let start_ns = attrs
            .get("startTime")
            .and_then(|value| value.parse::<i64>().ok())
            .unwrap_or(0);

        if WORK_TYPES.contains(&event_type.kind.as_str()) {
            let duration = attrs
                .get("duration")
                .and_then(|value| value.parse::<i64>().ok())
                .unwrap_or(0)
                .max(0);
            if duration == 0 {
                continue;
            }
            let source_path = normalized_source(&event_type.filename, shell_root);
            if let Some(source) = source_path.as_ref() {
                let stats = components.entry(source.clone()).or_default();
                stats.range_count = stats.range_count.saturating_add(1);
                *stats
                    .ranges_by_type
                    .entry(event_type.kind.clone())
                    .or_default() += 1;
            }
            total_work_range_ns = total_work_range_ns.saturating_add(duration as u64);
            work_ranges.push(WorkRange {
                start_ns,
                end_ns: start_ns.saturating_add(duration),
                event_index,
                source_path,
            });
            continue;
        }

        if event_type.kind == "MemoryAllocation" {
            let Some(amount) = attrs
                .get("amount")
                .and_then(|value| value.parse::<i64>().ok())
            else {
                continue;
            };
            total_memory_events = total_memory_events.saturating_add(1);
            if amount > 0 {
                total_allocated_bytes = total_allocated_bytes.saturating_add(amount as u64);
            }
            memory_points.push(MemoryPoint {
                at_ns: start_ns,
                amount,
            });
        }
    }

    let attributed_work_ns = allocate_exclusive_work(&work_ranges, &mut components);
    let (attributed_memory_events, attributed_allocated_bytes) =
        attribute_memory(&memory_points, &work_ranges, &mut components);

    let mut modules: BTreeMap<String, OwnerStats> = BTreeMap::new();
    let mut services: BTreeMap<String, OwnerStats> = BTreeMap::new();
    for (source, stats) in &components {
        modules
            .entry(module_for_source(source))
            .or_default()
            .merge(stats);
        if source.starts_with("services/") {
            services.entry(source.clone()).or_default().merge(stats);
        }
    }

    let coverage_percent = if trace_duration_ns > 0 {
        attributed_work_ns as f64 * 100.0 / trace_duration_ns as f64
    } else {
        0.0
    };
    let memory_coverage_percent = if total_memory_events > 0 {
        attributed_memory_events as f64 * 100.0 / total_memory_events as f64
    } else {
        0.0
    };

    let mut event_catalog = Map::new();
    for (index, event_type) in &event_types {
        if !WORK_TYPES.contains(&event_type.kind.as_str()) {
            continue;
        }
        event_catalog.insert(
            index.to_string(),
            json!({
                "type": event_type.kind,
                "filename": event_type.filename,
                "line": event_type.line,
                "details": event_type.details,
            }),
        );
    }

    Ok(json!({
        "schema": 1,
        "source": "qt-qml-profiler-xml",
        "trace": {
            "path": trace_path,
            "root": shell_root,
            "startNs": trace_start,
            "endNs": trace_end,
            "durationNs": trace_duration_ns,
        },
        "semantics": {
            "qmlWork": "exclusive wall-clock duration of QML/JS Binding, HandlingSignal, Javascript, Creating and Compiling ranges, attributed by source file; this is not per-owner CPU percent",
            "memory": "QV4 allocation/deallocation activity temporally attributed to the innermost active QML range; this is not retained RSS/PSS",
            "cpu": "process CPU remains kernel-exact only at Quickshell/helper process scope; no fake per-QML CPU split is produced",
            "gpu": "Qt Quick scene-graph/GPU events are process/window scoped and do not retain a reliable QML item owner; per-owner GPU usage is intentionally unavailable"
        },
        "coverage": {
            "traceDurationNs": trace_duration_ns,
            "summedRangeNsBeforeExclusiveNesting": total_work_range_ns,
            "shellAttributedExclusiveQmlWorkNs": attributed_work_ns,
            "shellAttributedQmlWorkSharePercent": coverage_percent,
            "memoryEventCount": total_memory_events,
            "temporallyAttributedMemoryEventCount": attributed_memory_events,
            "temporallyAttributedMemoryEventPercent": memory_coverage_percent,
            "allocatedBytesAllQv4Events": total_allocated_bytes,
            "allocatedBytesAttributedToShellOwners": attributed_allocated_bytes,
        },
        "components": sorted_rows(&components, "component", trace_duration_ns),
        "modules": sorted_rows(&modules, "module", trace_duration_ns),
        "services": sorted_rows(&services, "service", trace_duration_ns),
        "eventCatalog": event_catalog,
    }))
}

#[cfg(test)]
mod tests {
    use super::summarize;
    use serde_json::Value;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn value_at<'a>(value: &'a Value, path: &[&str]) -> &'a Value {
        let mut current = value;
        for key in path {
            current = &current[*key];
        }
        current
    }

    #[test]
    fn attributes_nested_qml_work_exclusively_and_memory_temporally() {
        let xml = r#"<?xml version="1.0"?>
<trace version="1.02" traceStart="0" traceEnd="1000000000">
  <eventData totalTime="400000000">
    <event index="0">
      <displayname>Bar.qml:10</displayname>
      <type>Binding</type>
      <filename>file:///repo/modules/bar/Bar.qml</filename>
      <line>10</line>
      <column>5</column>
      <details>outer binding</details>
    </event>
    <event index="1">
      <displayname>Clock.qml:20</displayname>
      <type>Javascript</type>
      <filename>file:///repo/modules/bar/Clock.qml</filename>
      <line>20</line>
      <column>3</column>
      <details>tick</details>
    </event>
    <event index="2">
      <displayname>MemoryAllocation:2</displayname>
      <type>MemoryAllocation</type>
      <memoryEventType>2</memoryEventType>
    </event>
    <event index="3">
      <displayname>RuntimeDiagnostics.qml:30</displayname>
      <type>HandlingSignal</type>
      <filename>file:///repo/services/RuntimeDiagnostics.qml</filename>
      <line>30</line>
      <column>2</column>
      <details>onTriggered</details>
    </event>
  </eventData>
  <profilerDataModel>
    <range startTime="100000000" duration="300000000" eventIndex="0"/>
    <range startTime="200000000" duration="100000000" eventIndex="1"/>
    <range startTime="250000000" eventIndex="2" amount="4096"/>
    <range startTime="500000000" duration="100000000" eventIndex="3"/>
    <range startTime="550000000" eventIndex="2" amount="2048"/>
  </profilerDataModel>
</trace>"#;

        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "inir-qml-profile-{}-{unique}.xml",
            std::process::id()
        ));
        fs::write(&path, xml).unwrap();
        let summary = summarize(&path, std::path::Path::new("/repo")).unwrap();
        let _ = fs::remove_file(path);

        let components = summary["components"].as_array().unwrap();
        let bar = components
            .iter()
            .find(|row| row["id"] == "modules/bar/Bar.qml")
            .unwrap();
        let clock = components
            .iter()
            .find(|row| row["id"] == "modules/bar/Clock.qml")
            .unwrap();
        let service = components
            .iter()
            .find(|row| row["id"] == "services/RuntimeDiagnostics.qml")
            .unwrap();

        assert_eq!(bar["qmlWorkNs"], 200_000_000);
        assert_eq!(clock["qmlWorkNs"], 100_000_000);
        assert_eq!(service["qmlWorkNs"], 100_000_000);
        assert_eq!(
            value_at(clock, &["allocations", "allocatedBytes"]),
            4096
        );
        assert_eq!(
            value_at(service, &["allocations", "allocatedBytes"]),
            2048
        );

        let modules = summary["modules"].as_array().unwrap();
        let bar_module = modules
            .iter()
            .find(|row| row["id"] == "modules/bar")
            .unwrap();
        assert_eq!(bar_module["qmlWorkNs"], 300_000_000);

        let services = summary["services"].as_array().unwrap();
        assert_eq!(services.len(), 1);
        assert_eq!(services[0]["id"], "services/RuntimeDiagnostics.qml");
        assert_eq!(
            summary["coverage"]["shellAttributedExclusiveQmlWorkNs"],
            400_000_000
        );
    }
}
