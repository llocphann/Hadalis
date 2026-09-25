#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = ROOT / "services/Weather.qml"
text = SERVICE.read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"weather process lifecycle guard failed: {message}")


def block(start: str, end: str) -> str:
    begin = text.find(start)
    require(begin >= 0, f"missing block start: {start}")
    finish = text.find(end, begin)
    require(finish >= 0, f"missing block end: {end}")
    return text[begin:finish]


fetch_fn = block("function fetchWeather(): void", "function hasRunningRequests(): bool")
require('fetcher.command = ["/usr/bin/curl", "-s", "--max-time", "15", url]' in fetch_fn,
        "primary wttr fetch must invoke curl directly")
require('"/usr/bin/bash"' not in fetch_fn,
        "primary wttr fetch must not restore a shell wrapper")

fetcher = block("id: fetcher", "id: openMeteoFetcher")
require('command: ["/usr/bin/curl", "-s", "--max-time", "15", ""]' in fetcher,
        "weather fetcher default command must match the direct curl lifecycle")

gps = block("id: gpsLocator", "id: ipLocator")
require('command: ["where-am-i", "-t", "10"]' in gps,
        "GPS lookup must invoke where-am-i directly")
require('stderr: StdioCollector {}' in gps,
        "GPS lookup must keep helper stderr suppressed")
require('const coordinatePattern = /(?:Latitude|Longitude):\\s*([\\d.-]+)/g;' in gps,
        "GPS coordinates must retain the previous Latitude/Longitude numeric match contract")
for helper in ('"/usr/bin/bash"', "grep -oP", "head -2", "paste -sd"):
    require(helper not in gps, f"GPS lookup must not restore helper pipeline: {helper}")

print("weather process lifecycle guards: ok")
