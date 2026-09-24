use std::collections::{BTreeMap, BTreeSet, VecDeque};
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use anyhow::{anyhow, Result};
use regex::Regex;
use serde_json::{json, Map, Value};

static STOP: AtomicBool = AtomicBool::new(false);

const KIB_FIELDS: &[&str] = &[
    "Rss",
    "Pss",
    "Pss_Anon",
    "Pss_File",
    "Pss_Shmem",
    "Private_Clean",
    "Private_Dirty",
    "Shared_Clean",
    "Shared_Dirty",
    "Swap",
    "SwapPss",
];

#[derive(Clone, Debug, Default)]
struct NetworkCounter {
    rx_bytes: u64,
    tx_bytes: u64,
}

#[derive(Clone, Debug, Default)]
struct ChildState {
    runtime_ns: Option<u64>,
    command: String,
    start_ticks: Option<u64>,
}

#[derive(Clone, Debug, Default)]
struct DrmState {
    available: bool,
    client_count: usize,
    engines_ns: BTreeMap<String, u64>,
    memory_kib: BTreeMap<String, u64>,
}

#[derive(Clone, Debug, Default)]
struct SlowState {
    at_ns: Option<u64>,
    memory: Option<Value>,
    drm: Option<DrmState>,
    engine_busy: BTreeMap<String, Option<f64>>,
    children_rows: Vec<Value>,
    children_state: BTreeMap<i32, ChildState>,
}

#[derive(Clone, Debug, Default)]
struct SampleState {
    monotonic_ns: Option<u64>,
    runtime_ns: Option<u64>,
    system_cpu: BTreeMap<String, (u64, u64)>,
    io: BTreeMap<String, u64>,
    network: BTreeMap<String, NetworkCounter>,
    slow: SlowState,
}

extern "C" fn stop_handler(_: libc::c_int) {
    STOP.store(true, Ordering::Relaxed);
}

fn install_signal_handlers() {
    unsafe {
        libc::signal(
            libc::SIGTERM,
            stop_handler as *const () as libc::sighandler_t,
        );
        libc::signal(
            libc::SIGINT,
            stop_handler as *const () as libc::sighandler_t,
        );
    }
}

fn monotonic_ns() -> u64 {
    let mut value = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    let result = unsafe { libc::clock_gettime(libc::CLOCK_MONOTONIC, &mut value) };
    if result == 0 {
        value.tv_sec.max(0) as u64 * 1_000_000_000 + value.tv_nsec.max(0) as u64
    } else {
        0
    }
}

fn epoch_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

fn read_text(path: impl AsRef<Path>) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

fn parse_kib_fields(text: &str) -> BTreeMap<String, u64> {
    let pattern = Regex::new(r"^([A-Za-z_]+):\s+(\d+)\s+kB\s*$").unwrap();
    let wanted = KIB_FIELDS.iter().copied().collect::<BTreeSet<_>>();
    let mut values = BTreeMap::new();
    for line in text.lines() {
        let Some(caps) = pattern.captures(line) else {
            continue;
        };
        let key = &caps[1];
        if !wanted.contains(key) {
            continue;
        }
        if let Ok(value) = caps[2].parse::<u64>() {
            values.insert(key.to_owned(), value);
        }
    }
    values
}

fn read_memory(pid: i32) -> Value {
    let proc = PathBuf::from("/proc").join(pid.to_string());
    let rollup = parse_kib_fields(&read_text(proc.join("smaps_rollup")));
    if !rollup.is_empty() {
        return json!({
            "scope": "shell-process",
            "method": "smaps-rollup",
            "confidence": "kernel",
            "valuesKiB": rollup,
        });
    }

    let status = read_text(proc.join("status"));
    let mut fallback = BTreeMap::new();
    for (source, target) in [("VmRSS", "Rss"), ("VmSwap", "Swap")] {
        let pattern = Regex::new(&format!(
            r"(?m)^{}:\s+(\d+)\s+kB\s*$",
            regex::escape(source)
        ))
        .unwrap();
        if let Some(caps) = pattern.captures(&status)
            && let Ok(value) = caps[1].parse::<u64>()
        {
            fallback.insert(target.to_owned(), value);
        }
    }
    json!({
        "scope": "shell-process",
        "method": "proc-status",
        "confidence": "kernel",
        "valuesKiB": fallback,
    })
}

fn read_system_cpu_ticks() -> BTreeMap<String, (u64, u64)> {
    let mut result = BTreeMap::new();
    for line in read_text("/proc/stat").lines() {
        let fields = line.split_whitespace().collect::<Vec<_>>();
        let Some(name) = fields.first().copied() else {
            continue;
        };
        if name != "cpu"
            && !name
                .strip_prefix("cpu")
                .is_some_and(|suffix| !suffix.is_empty() && suffix.chars().all(|c| c.is_ascii_digit()))
        {
            continue;
        }
        if fields.len() < 5 {
            continue;
        }
        let values = fields[1..]
            .iter()
            .filter_map(|value| value.parse::<u64>().ok())
            .collect::<Vec<_>>();
        if values.len() < 4 {
            continue;
        }
        let total = values.iter().take(8).sum();
        let idle = values[3] + values.get(4).copied().unwrap_or(0);
        result.insert(name.to_owned(), (total, idle));
    }
    result
}

fn cpu_percent_from_ticks(
    current: Option<&(u64, u64)>,
    previous: Option<&(u64, u64)>,
) -> Option<f64> {
    let (current, previous) = (current?, previous?);
    let total_delta = current.0.checked_sub(previous.0)?;
    let idle_delta = current.1.checked_sub(previous.1)?;
    if total_delta == 0 {
        return None;
    }
    Some(
        ((1.0 - idle_delta as f64 / total_delta as f64) * 100.0)
            .clamp(0.0, 100.0),
    )
}

fn read_load_average() -> Vec<f64> {
    read_text("/proc/loadavg")
        .split_whitespace()
        .take(3)
        .filter_map(|value| value.parse::<f64>().ok())
        .collect()
}

fn read_uptime_seconds() -> Option<f64> {
    read_text("/proc/uptime")
        .split_whitespace()
        .next()
        .and_then(|value| value.parse::<f64>().ok())
        .map(|value| value.max(0.0))
}

fn read_system_memory() -> Value {
    let text = read_text("/proc/meminfo");
    let mut values = BTreeMap::new();
    for key in [
        "MemTotal",
        "MemAvailable",
        "Cached",
        "Buffers",
        "SwapTotal",
        "SwapFree",
    ] {
        let pattern = Regex::new(&format!(
            r"(?m)^{}:\s+(\d+)\s+kB\s*$",
            regex::escape(key)
        ))
        .unwrap();
        if let Some(caps) = pattern.captures(&text)
            && let Ok(value) = caps[1].parse::<u64>()
        {
            values.insert(key.to_owned(), value);
        }
    }
    let mem_total = values.get("MemTotal").copied();
    let mem_available = values.get("MemAvailable").copied();
    let swap_total = values.get("SwapTotal").copied();
    let swap_free = values.get("SwapFree").copied();
    let mem_used = mem_total
        .zip(mem_available)
        .map(|(total, available)| total.saturating_sub(available));
    let swap_used = swap_total
        .zip(swap_free)
        .map(|(total, free)| total.saturating_sub(free));

    json!({
        "scope": "system",
        "method": "proc-meminfo",
        "confidence": "kernel",
        "valuesKiB": {
            "MemTotal": mem_total,
            "MemAvailable": mem_available,
            "MemUsed": mem_used,
            "Cached": values.get("Cached").copied(),
            "Buffers": values.get("Buffers").copied(),
            "SwapTotal": swap_total,
            "SwapFree": swap_free,
            "SwapUsed": swap_used,
        }
    })
}

fn task_ids(pid: i32) -> Vec<PathBuf> {
    fs::read_dir(format!("/proc/{pid}/task"))
        .into_iter()
        .flatten()
        .flatten()
        .map(|entry| entry.path())
        .collect()
}

fn read_sched_runtime_ns(pid: i32) -> Option<u64> {
    let mut total = 0u64;
    let mut found = false;
    for task in task_ids(pid) {
        let text = read_text(task.join("schedstat"));
        if let Some(value) = text
            .split_whitespace()
            .next()
            .and_then(|value| value.parse::<u64>().ok())
        {
            total = total.saturating_add(value);
            found = true;
        }
    }
    if found {
        return Some(total);
    }
    read_text(format!("/proc/{pid}/schedstat"))
        .split_whitespace()
        .next()
        .and_then(|value| value.parse::<u64>().ok())
}

fn read_io(pid: i32) -> BTreeMap<String, u64> {
    let wanted = [
        "read_bytes",
        "write_bytes",
        "rchar",
        "wchar",
        "syscr",
        "syscw",
    ]
    .into_iter()
    .collect::<BTreeSet<_>>();
    let mut result = BTreeMap::new();
    for line in read_text(format!("/proc/{pid}/io")).lines() {
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };
        let key = key.trim();
        if !wanted.contains(key) {
            continue;
        }
        if let Ok(value) = value.trim().parse::<u64>() {
            result.insert(key.to_owned(), value);
        }
    }
    result
}

fn read_process_status(pid: i32) -> BTreeMap<String, u64> {
    let text = read_text(format!("/proc/{pid}/status"));
    let mut result = BTreeMap::new();
    for (source, target) in [("VmRSS", "Rss"), ("VmSwap", "Swap")] {
        let pattern = Regex::new(&format!(
            r"(?m)^{}:\s+(\d+)\s+kB\s*$",
            regex::escape(source)
        ))
        .unwrap();
        if let Some(caps) = pattern.captures(&text)
            && let Ok(value) = caps[1].parse::<u64>()
        {
            result.insert(target.to_owned(), value);
        }
    }
    result
}

fn read_process_command(pid: i32) -> String {
    let command = read_text(format!("/proc/{pid}/comm"))
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ");
    if command.is_empty() {
        format!("pid-{pid}")
    } else {
        command
    }
}

fn read_process_start_ticks(pid: i32) -> Option<u64> {
    let text = read_text(format!("/proc/{pid}/stat"));
    let closing = text.rfind(')')?;
    let fields = text[closing + 1..].split_whitespace().collect::<Vec<_>>();
    fields.get(19)?.parse::<u64>().ok()
}

fn read_process_children(pid: i32) -> Vec<i32> {
    let mut children = BTreeSet::new();
    for task in task_ids(pid) {
        for raw in read_text(task.join("children")).split_whitespace() {
            if let Ok(value) = raw.parse::<i32>()
                && value > 0
            {
                children.insert(value);
            }
        }
    }
    children.into_iter().collect()
}

fn read_descendants(pid: i32) -> Vec<(i32, i32)> {
    let mut result = Vec::new();
    let mut queue = VecDeque::from([pid]);
    let mut seen = BTreeSet::from([pid]);
    while let Some(parent) = queue.pop_front() {
        for child in read_process_children(parent) {
            if seen.insert(child) {
                result.push((child, parent));
                queue.push_back(child);
            }
        }
    }
    result
}

fn sample_children(
    shell_pid: i32,
    previous: &BTreeMap<i32, ChildState>,
    elapsed_ns: u64,
) -> (Vec<Value>, BTreeMap<i32, ChildState>) {
    let mut rows = Vec::new();
    let mut next = BTreeMap::new();

    for (child_pid, parent_pid) in read_descendants(shell_pid) {
        if !Path::new(&format!("/proc/{child_pid}")).exists() {
            continue;
        }
        let command = read_process_command(child_pid);
        let start_ticks = read_process_start_ticks(child_pid);
        let runtime_ns = read_sched_runtime_ns(child_pid);
        let cpu = previous.get(&child_pid).and_then(|old| {
            if old.command != command
                || old.start_ticks != start_ticks
                || start_ticks.is_none()
                || elapsed_ns == 0
            {
                return None;
            }
            let current = runtime_ns?;
            let previous = old.runtime_ns?;
            current
                .checked_sub(previous)
                .map(|delta| delta as f64 / elapsed_ns as f64 * 100.0)
        });

        let memory = read_process_status(child_pid);
        if start_ticks.is_none() || read_process_start_ticks(child_pid) != start_ticks {
            continue;
        }
        rows.push(json!({
            "pid": child_pid,
            "parentPid": parent_pid,
            "command": command,
            "cpu": {
                "scope": "child-process",
                "method": "schedstat",
                "confidence": "kernel",
                "percent": cpu,
            },
            "memory": {
                "scope": "child-process",
                "method": "proc-status",
                "confidence": "kernel",
                "valuesKiB": memory,
            }
        }));
        next.insert(
            child_pid,
            ChildState {
                runtime_ns,
                command,
                start_ticks,
            },
        );
    }

    rows.sort_by(|left, right| {
        let left_cpu = left["cpu"]["percent"].as_f64().unwrap_or(0.0);
        let right_cpu = right["cpu"]["percent"].as_f64().unwrap_or(0.0);
        let left_rss = left["memory"]["valuesKiB"]["Rss"].as_u64().unwrap_or(0);
        let right_rss = right["memory"]["valuesKiB"]["Rss"].as_u64().unwrap_or(0);
        let left_pid = left["pid"].as_i64().unwrap_or(0);
        let right_pid = right["pid"].as_i64().unwrap_or(0);
        right_cpu
            .total_cmp(&left_cpu)
            .then_with(|| right_rss.cmp(&left_rss))
            .then_with(|| left_pid.cmp(&right_pid))
    });
    (rows, next)
}

fn read_network() -> BTreeMap<String, NetworkCounter> {
    let mut result = BTreeMap::new();
    for line in read_text("/proc/net/dev").lines().skip(2) {
        let Some((name, payload)) = line.split_once(':') else {
            continue;
        };
        let fields = payload.split_whitespace().collect::<Vec<_>>();
        if fields.len() < 16 {
            continue;
        }
        let (Ok(rx), Ok(tx)) = (fields[0].parse::<u64>(), fields[8].parse::<u64>()) else {
            continue;
        };
        result.insert(
            name.trim().to_owned(),
            NetworkCounter {
                rx_bytes: rx,
                tx_bytes: tx,
            },
        );
    }
    result
}

fn to_kib(value: u64, unit: &str) -> u64 {
    match unit.trim().to_ascii_lowercase().as_str() {
        "kb" | "kib" => value,
        "mb" | "mib" => value.saturating_mul(1024),
        "gb" | "gib" => value.saturating_mul(1024 * 1024),
        "b" | "bytes" | "byte" => value / 1024,
        _ => value,
    }
}

type CounterMap = BTreeMap<String, u64>;
type DrmFdInfo = (String, CounterMap, CounterMap);
type DrmClients = BTreeMap<String, (CounterMap, CounterMap)>;

fn parse_drm_fdinfo(text: &str) -> Option<DrmFdInfo> {
    let client_re = Regex::new(r"(?m)^drm-client-id:\s*(\S+)\s*$").ok()?;
    let client = client_re
        .captures(text)?
        .get(1)?
        .as_str()
        .to_owned();
    let engine_re = Regex::new(r"^drm-engine-([^:]+):\s*(\d+)\s*ns\s*$").ok()?;
    let memory_re = Regex::new(
        r"^drm-(memory|total|shared|resident|active|purgeable)-([^:]+):\s*(\d+)\s*([A-Za-z]+)?\s*$",
    )
    .ok()?;
    let mut engines = BTreeMap::new();
    let mut memory = BTreeMap::new();
    for line in text.lines() {
        if let Some(caps) = engine_re.captures(line)
            && let Ok(value) = caps[2].parse::<u64>()
        {
            engines.insert(caps[1].to_owned(), value);
            continue;
        }
        if let Some(caps) = memory_re.captures(line)
            && let Ok(value) = caps[3].parse::<u64>()
        {
            let key = format!("{}-{}", &caps[1], &caps[2]);
            memory.insert(
                key,
                to_kib(
                    value,
                    caps.get(4).map(|value| value.as_str()).unwrap_or("KiB"),
                ),
            );
        }
    }
    Some((client, engines, memory))
}

fn read_drm(pid: i32) -> DrmState {
    let mut clients: DrmClients = BTreeMap::new();
    let fdinfo = format!("/proc/{pid}/fdinfo");
    for path in fs::read_dir(fdinfo).into_iter().flatten().flatten() {
        let Some((client, engines, memory)) = parse_drm_fdinfo(&read_text(path.path())) else {
            continue;
        };
        let current = clients.entry(client).or_default();
        for (key, value) in engines {
            current
                .0
                .entry(key)
                .and_modify(|existing| *existing = (*existing).max(value))
                .or_insert(value);
        }
        for (key, value) in memory {
            current
                .1
                .entry(key)
                .and_modify(|existing| *existing = (*existing).max(value))
                .or_insert(value);
        }
    }

    let mut engines = BTreeMap::new();
    let mut memory = BTreeMap::new();
    for (client_engines, client_memory) in clients.values() {
        for (key, value) in client_engines {
            *engines.entry(key.clone()).or_insert(0u64) = engines
                .get(key)
                .copied()
                .unwrap_or(0)
                .saturating_add(*value);
        }
        for (key, value) in client_memory {
            *memory.entry(key.clone()).or_insert(0u64) = memory
                .get(key)
                .copied()
                .unwrap_or(0)
                .saturating_add(*value);
        }
    }

    DrmState {
        available: !clients.is_empty(),
        client_count: clients.len(),
        engines_ns: engines,
        memory_kib: memory,
    }
}

fn rate(current: u64, previous: Option<u64>, elapsed_s: f64) -> Option<f64> {
    let previous = previous?;
    if elapsed_s <= 0.0 || current < previous {
        return None;
    }
    Some((current - previous) as f64 / elapsed_s)
}

fn option_map_f64(values: &BTreeMap<String, Option<f64>>) -> Value {
    Value::Object(
        values
            .iter()
            .map(|(key, value)| (key.clone(), json!(value)))
            .collect(),
    )
}

fn drm_memory_value(drm: &DrmState) -> Value {
    Value::Object(
        drm.memory_kib
            .iter()
            .map(|(key, value)| (key.clone(), json!(value)))
            .collect(),
    )
}

fn sample(pid: i32, previous: Option<&SampleState>) -> Result<(Value, SampleState)> {
    if !Path::new(&format!("/proc/{pid}")).exists() {
        return Err(anyhow!("shell-process-gone"));
    }

    let now_ns = monotonic_ns();
    let now_ms = epoch_ms();
    let runtime_ns = read_sched_runtime_ns(pid);
    let system_cpu_now = read_system_cpu_ticks();
    let load_average = read_load_average();
    let uptime_seconds = read_uptime_seconds();
    let io_now = read_io(pid);
    let net_now = read_network();
    let default_previous = SampleState::default();
    let previous = previous.unwrap_or(&default_previous);

    let slow_elapsed_ns = previous
        .slow
        .at_ns
        .and_then(|at| now_ns.checked_sub(at))
        .unwrap_or(0);
    let refresh_slow = previous.slow.at_ns.is_none() || slow_elapsed_ns >= 2_000_000_000;

    let (memory_now, drm_now, child_rows, child_state, engine_busy, slow_state) =
        if refresh_slow {
            let memory = read_memory(pid);
            let drm = read_drm(pid);
            let (children, child_state) =
                sample_children(pid, &previous.slow.children_state, slow_elapsed_ns);
            let mut busy = BTreeMap::new();
            let previous_drm = previous.slow.drm.as_ref();
            for (name, counter) in &drm.engines_ns {
                let value = previous_drm
                    .and_then(|old| old.engines_ns.get(name))
                    .and_then(|old| {
                        if slow_elapsed_ns == 0 || counter < old {
                            None
                        } else {
                            Some(
                                ((*counter - *old) as f64 / slow_elapsed_ns as f64 * 100.0)
                                    .clamp(0.0, 100.0),
                            )
                        }
                    });
                busy.insert(name.clone(), value);
            }
            let slow = SlowState {
                at_ns: Some(now_ns),
                memory: Some(memory.clone()),
                drm: Some(drm.clone()),
                engine_busy: busy.clone(),
                children_rows: children.clone(),
                children_state: child_state.clone(),
            };
            (memory, drm, children, child_state, busy, slow)
        } else {
            (
                previous
                    .slow
                    .memory
                    .clone()
                    .unwrap_or_else(|| read_memory(pid)),
                previous.slow.drm.clone().unwrap_or_else(|| read_drm(pid)),
                previous.slow.children_rows.clone(),
                previous.slow.children_state.clone(),
                previous.slow.engine_busy.clone(),
                previous.slow.clone(),
            )
        };

    let elapsed_ns = previous
        .monotonic_ns
        .and_then(|old| now_ns.checked_sub(old))
        .unwrap_or(0);
    let elapsed_s = elapsed_ns as f64 / 1_000_000_000.0;
    let cpu_percent = runtime_ns
        .zip(previous.runtime_ns)
        .and_then(|(current, old)| current.checked_sub(old))
        .filter(|_| elapsed_ns > 0)
        .map(|delta| delta as f64 / elapsed_ns as f64 * 100.0);

    let system_cpu_percent = cpu_percent_from_ticks(
        system_cpu_now.get("cpu"),
        previous.system_cpu.get("cpu"),
    );
    let mut core_names = system_cpu_now
        .keys()
        .filter(|name| name.as_str() != "cpu")
        .cloned()
        .collect::<Vec<_>>();
    core_names.sort_by_key(|name| {
        name.strip_prefix("cpu")
            .and_then(|value| value.parse::<u32>().ok())
            .unwrap_or(u32::MAX)
    });
    let cores_percent = core_names
        .iter()
        .map(|name| {
            cpu_percent_from_ticks(system_cpu_now.get(name), previous.system_cpu.get(name))
        })
        .collect::<Vec<_>>();

    let io_rates = json!({
        "readBytesPerSec": rate(
            io_now.get("read_bytes").copied().unwrap_or(0),
            previous.io.get("read_bytes").copied(),
            elapsed_s
        ),
        "writeBytesPerSec": rate(
            io_now.get("write_bytes").copied().unwrap_or(0),
            previous.io.get("write_bytes").copied(),
            elapsed_s
        )
    });

    let mut network_interfaces = Map::new();
    let mut aggregate_rx = 0u64;
    let mut aggregate_tx = 0u64;
    let mut aggregate_rx_rate = 0.0;
    let mut aggregate_tx_rate = 0.0;
    let mut interface_count = 0usize;
    let mut all_rx_rates = true;
    let mut all_tx_rates = true;

    for (name, counters) in &net_now {
        let old = previous.network.get(name);
        let rx_rate = rate(
            counters.rx_bytes,
            old.map(|value| value.rx_bytes),
            elapsed_s,
        );
        let tx_rate = rate(
            counters.tx_bytes,
            old.map(|value| value.tx_bytes),
            elapsed_s,
        );
        network_interfaces.insert(
            name.clone(),
            json!({
                "rxBytes": counters.rx_bytes,
                "txBytes": counters.tx_bytes,
                "rxBytesPerSec": rx_rate,
                "txBytesPerSec": tx_rate,
            }),
        );
        if name != "lo" {
            interface_count += 1;
            aggregate_rx = aggregate_rx.saturating_add(counters.rx_bytes);
            aggregate_tx = aggregate_tx.saturating_add(counters.tx_bytes);
            if let Some(value) = rx_rate {
                aggregate_rx_rate += value;
            } else {
                all_rx_rates = false;
            }
            if let Some(value) = tx_rate {
                aggregate_tx_rate += value;
            } else {
                all_tx_rates = false;
            }
        }
    }

    let payload = json!({
        "atMs": now_ms,
        "system": {
            "cpu": {
                "scope": "system",
                "method": "proc-stat",
                "confidence": "kernel",
                "percent": system_cpu_percent,
                "coresPercent": cores_percent,
                "coreNames": core_names,
                "loadAverage": load_average,
            },
            "memory": read_system_memory(),
            "uptimeSeconds": uptime_seconds,
        },
        "shell": {
            "pid": pid,
            "cpu": {
                "scope": "shell-process",
                "method": "schedstat",
                "confidence": "kernel",
                "percent": cpu_percent,
            },
            "memory": memory_now,
            "io": {
                "scope": "shell-process",
                "method": "proc-io",
                "confidence": "kernel",
                "counters": io_now,
                "rates": io_rates,
            },
            "children": child_rows,
            "gpu": {
                "scope": "shell-process",
                "method": "drm-fdinfo",
                "confidence": "kernel",
                "available": drm_now.available,
                "clientCount": drm_now.client_count,
                "engineBusyPercent": option_map_f64(&engine_busy),
                "memoryKiB": drm_memory_value(&drm_now),
            }
        },
        "network": {
            "scope": "system",
            "method": "proc-net-dev",
            "confidence": "kernel",
            "interfaces": network_interfaces,
            "aggregateNonLoopback": {
                "rxBytes": aggregate_rx,
                "txBytes": aggregate_tx,
                "rxBytesPerSec": if interface_count > 0 && all_rx_rates { Some(aggregate_rx_rate) } else { None },
                "txBytesPerSec": if interface_count > 0 && all_tx_rates { Some(aggregate_tx_rate) } else { None },
            }
        }
    });

    let state = SampleState {
        monotonic_ns: Some(now_ns),
        runtime_ns,
        system_cpu: system_cpu_now,
        io: io_now,
        network: net_now,
        slow: SlowState {
            children_state: child_state,
            ..slow_state
        },
    };
    Ok((payload, state))
}

fn emit(value: &Value) {
    let stdout = io::stdout();
    let mut out = stdout.lock();
    let _ = serde_json::to_writer(&mut out, value);
    let _ = out.write_all(b"\n");
    let _ = out.flush();
}

pub fn run(pid: i32, interval_ms: u64) -> Result<i32> {
    if pid <= 0 {
        return Err(anyhow!("--pid must be positive"));
    }
    let interval = Duration::from_millis(interval_ms.clamp(250, 10_000));
    STOP.store(false, Ordering::Relaxed);
    install_signal_handlers();

    let target_start_ticks = read_process_start_ticks(pid);
    if target_start_ticks.is_none() {
        emit(&json!({"error":"shell-process-gone","pid":pid,"atMs":epoch_ms()}));
        return Ok(2);
    }

    let mut previous: Option<SampleState> = None;
    while !STOP.load(Ordering::Relaxed) {
        let started = Instant::now();
        if read_process_start_ticks(pid) != target_start_ticks {
            emit(&json!({"error":"shell-process-gone","pid":pid,"atMs":epoch_ms()}));
            return Ok(2);
        }

        match sample(pid, previous.as_ref()) {
            Ok((payload, state)) => {
                if read_process_start_ticks(pid) != target_start_ticks {
                    emit(&json!({"error":"shell-process-gone","pid":pid,"atMs":epoch_ms()}));
                    return Ok(2);
                }
                emit(&payload);
                previous = Some(state);
            }
            Err(error) if error.to_string() == "shell-process-gone" => {
                emit(&json!({"error":"shell-process-gone","pid":pid,"atMs":epoch_ms()}));
                return Ok(2);
            }
            Err(error) => {
                emit(&json!({
                    "error":"sample-failed",
                    "detail":error.to_string(),
                    "pid":pid,
                    "atMs":epoch_ms()
                }));
            }
        }

        let elapsed = started.elapsed();
        if elapsed < interval {
            thread::sleep(interval - elapsed);
        }
    }
    Ok(0)
}

#[cfg(test)]
mod tests {
    use super::{parse_drm_fdinfo, parse_kib_fields, to_kib};

    #[test]
    fn parses_smaps_rollup_fields() {
        let values = parse_kib_fields(
            "Rss: 123 kB\nPss: 100 kB\nVmSize: 999 kB\nPrivate_Dirty: 7 kB\n",
        );
        assert_eq!(values.get("Rss"), Some(&123));
        assert_eq!(values.get("Pss"), Some(&100));
        assert_eq!(values.get("Private_Dirty"), Some(&7));
        assert!(!values.contains_key("VmSize"));
    }

    #[test]
    fn parses_drm_fdinfo_and_converts_units() {
        let (_, engines, memory) = parse_drm_fdinfo(
            "drm-client-id: 7\ndrm-engine-render: 12345 ns\ndrm-resident-vram0: 2 MiB\n",
        )
        .unwrap();
        assert_eq!(engines.get("render"), Some(&12345));
        assert_eq!(memory.get("resident-vram0"), Some(&(2 * 1024)));
    }

    #[test]
    fn converts_drm_units() {
        assert_eq!(to_kib(2048, "B"), 2);
        assert_eq!(to_kib(3, "MiB"), 3072);
        assert_eq!(to_kib(2, "GiB"), 2 * 1024 * 1024);
    }
}
