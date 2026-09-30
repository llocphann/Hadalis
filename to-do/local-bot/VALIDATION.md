# Local Bot — validation and mechanical evidence

Tasks here are actionable **only upon Cloud Bot dispatch** via a valid `automation/queue/pending/JOB-*.json` with exact `argv`, cwd, timeout and parent-matched `base_sha`. No independent local reasoning.

- [ ] Execute the exact SHA-pinned `bash scripts/validate-maintainer-local.sh` only when it appears as an explicit job; capture tested SHA, full canonical log and PASS/FAIL/SKIP.
- [ ] Execute other focused tests, benchmarks or bounded diagnostic commands only if explicitly named in the job. Publish raw result under `automation/results/` using normal non-force push.
- [ ] On stale SHA, unsafe arguments, timeout or failure, fail closed with raw evidence; never fix code or guess a substitute command.

## Original local validator contract

## 7. Local release validation — P0 gate

The maintainer's local pass is authoritative. At minimum, validate the exact candidate SHA with:

```bash
bash scripts/validate-maintainer-local.sh
```

The qualified Rust workspace is now the **production native backend**. The canonical selector defaults to Rust, supported source/package/Nix install paths ship the native binaries, and migration `050-rust-native-default` promotes existing installs. Python implementations remain an explicit rollback/fail-soft path. Native production/parity checks and benchmark history are documented in [native/README.md](../../native/README.md), but they do not replace this repository-wide gate or live desktop validation.



## MAINTAINER-ONLY live desktop acceptance (not executable worker tasks)

Cloud Bot may request and interpret these checks, but the deterministic Local Bot must not simulate or declare them accepted.

- [ ] Screen Edge visible when idle and maximized; width setting updates correctly.
- [ ] Connected popups from top, bottom, left and right positions have no visible gap; attached edges are square and shadow-free, while only unattached outer corners remain rounded and shadowed.
- [ ] Left/right Sidebars connect to the correct Screen Edge.
- [ ] Settings > Bar renders; Thinkfan and Screen Edge controls are reachable.
- [ ] System Monitor contains Thinkfan functionality and no duplicate Thinkfan popup remains in normal UX.
- [ ] Media Popup equalizer works through play/pause, player switch, close/reopen and keyboard open.
- [ ] Calendar/Weather composition matches the intended left/center structure while keeping Hadalis detailed weather on the right.
- [ ] Only **Material** is available as a Global Theme; an old persisted non-Material value resolves safely to Material.
- [ ] Material renders correctly across Bar, Screen Edge, popups, Sidebars, Overview, Settings and Waffle.
- [ ] Tray/context menus work on a non-primary output.
- [ ] Multi-monitor, fractional scaling, transformed outputs and vertical bars are usable.
- [ ] Niri full pass; Hyprland compatibility smoke test.
- [ ] Fullscreen, lock/unlock and suspend/resume do not leave broken shell surfaces.

Additional live evidence: sidebars with custom/compact content, Dashboard/Search/Settings/OSK edge joining, popup pointer transfer, all four Edge placements, output hotplug/fractional scaling, fullscreen and real-device ThinkFan/TLP/connectivity/media states. Retain the exact tested runtime SHA and recording/log provenance.

