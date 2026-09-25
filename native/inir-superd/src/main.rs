use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex, MutexGuard};
use std::thread;
use std::time::{Duration, Instant};

use evdev::{Device, EventSummary, KeyCode};

const INPUT_DIR: &str = "/dev/input";
const RESCAN_INTERVAL: Duration = Duration::from_secs(5);
const DEBOUNCE: Duration = Duration::from_millis(250);
const IMPORTED_ENV_KEYS: &[&str] = &[
    "WAYLAND_DISPLAY",
    "XDG_RUNTIME_DIR",
    "QT_QPA_PLATFORM",
    "NIRI_SOCKET",
];

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct DeviceKey {
    path: PathBuf,
    token: u64,
}

#[derive(Debug, Default)]
struct TapState {
    super_down_devices: HashSet<DeviceKey>,
    interaction_since_super_down: bool,
    tap_handled: bool,
    last_toggle: Option<Instant>,
}

#[derive(Debug, Default, PartialEq, Eq)]
struct ReleaseAction {
    toggle: bool,
    notify_release: bool,
}

impl TapState {
    fn super_press(&mut self, device: &DeviceKey) -> bool {
        let was_down = !self.super_down_devices.is_empty();
        self.super_down_devices.insert(device.clone());
        if was_down {
            return false;
        }

        self.interaction_since_super_down = false;
        self.tap_handled = false;
        true
    }

    fn other_key_press(&mut self) {
        if !self.super_down_devices.is_empty() {
            self.interaction_since_super_down = true;
        }
    }

    fn pointer_press(&mut self) {
        self.other_key_press();
    }

    fn super_release(
        &mut self,
        device: &DeviceKey,
        local_chord: bool,
        now: Instant,
    ) -> ReleaseAction {
        if !self.super_down_devices.contains(device) {
            return ReleaseAction::default();
        }

        let mut toggle = false;
        if !local_chord && !self.interaction_since_super_down && !self.tap_handled {
            let outside_debounce = self
                .last_toggle
                .is_none_or(|last| now.duration_since(last) >= DEBOUNCE);
            if outside_debounce {
                self.last_toggle = Some(now);
                self.tap_handled = true;
                toggle = true;
            }
        }

        self.super_down_devices.remove(device);
        let notify_release = self.super_down_devices.is_empty();
        if notify_release {
            self.interaction_since_super_down = false;
        }

        ReleaseAction {
            toggle,
            notify_release,
        }
    }

    fn device_gone(&mut self, device: &DeviceKey) -> bool {
        if !self.super_down_devices.remove(device) {
            return false;
        }
        let notify_release = self.super_down_devices.is_empty();
        if notify_release {
            self.interaction_since_super_down = false;
        }
        notify_release
    }
}

#[derive(Debug, Clone, Copy)]
struct DeviceRoles {
    keyboard: bool,
    pointer: bool,
}

#[derive(Debug)]
enum InternalEvent {
    DeviceGone(DeviceKey),
}

#[derive(Debug, Default)]
struct EnvCache {
    pid: Option<u32>,
    vars: Vec<(String, String)>,
}

impl EnvCache {
    fn session_env(&mut self) -> Option<Vec<(String, String)>> {
        if let Some(pid) = self.pid
            && pid_matches_inir(pid)
            && !self.vars.is_empty()
        {
            return Some(self.vars.clone());
        }

        let Some(pid) = find_inir_pid() else {
            self.pid = None;
            self.vars.clear();
            return None;
        };
        let vars = read_inir_env(pid);
        self.pid = Some(pid);
        self.vars = vars;
        (!self.vars.is_empty()).then(|| self.vars.clone())
    }
}

fn lock_recover<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn is_super(code: KeyCode) -> bool {
    code == KeyCode::KEY_LEFTMETA || code == KeyCode::KEY_RIGHTMETA
}

fn is_pointer_button(code: KeyCode) -> bool {
    [
        KeyCode::BTN_LEFT,
        KeyCode::BTN_RIGHT,
        KeyCode::BTN_MIDDLE,
        KeyCode::BTN_SIDE,
        KeyCode::BTN_EXTRA,
        KeyCode::BTN_FORWARD,
        KeyCode::BTN_BACK,
    ]
    .contains(&code)
}

fn ignored_device(device: &Device) -> bool {
    let name = device.name().unwrap_or_default().to_ascii_lowercase();
    name.contains("ydotool") || name.contains("virtual")
}

fn classify_device(device: &Device) -> Option<DeviceRoles> {
    if ignored_device(device) {
        return None;
    }
    let keys = device.supported_keys()?;
    let keyboard =
        keys.contains(KeyCode::KEY_LEFTMETA) || keys.contains(KeyCode::KEY_RIGHTMETA);
    let pointer = [
        KeyCode::BTN_LEFT,
        KeyCode::BTN_RIGHT,
        KeyCode::BTN_MIDDLE,
        KeyCode::BTN_SIDE,
        KeyCode::BTN_EXTRA,
        KeyCode::BTN_FORWARD,
        KeyCode::BTN_BACK,
    ]
    .into_iter()
    .any(|code| keys.contains(code));

    (keyboard || pointer).then_some(DeviceRoles { keyboard, pointer })
}

fn event_paths() -> Vec<PathBuf> {
    let mut paths = fs::read_dir(INPUT_DIR)
        .into_iter()
        .flatten()
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("event"))
        })
        .collect::<Vec<_>>();
    paths.sort();
    paths
}

fn cmdline_matches_inir(raw: &[u8]) -> bool {
    let args = raw
        .split(|byte| *byte == 0)
        .filter(|arg| !arg.is_empty())
        .collect::<Vec<_>>();
    let Some(executable) = args.first() else {
        return false;
    };
    let executable_name = executable.rsplit(|byte| *byte == b'/').next();
    if executable_name != Some(b"qs".as_slice()) {
        return false;
    }

    if args.len() >= 3 && args[1] == b"-c" && args[2] == b"inir" {
        return true;
    }

    for index in 1..args.len() {
        if args[index] != b"-p" || index + 1 >= args.len() {
            continue;
        }
        let path = String::from_utf8_lossy(args[index + 1]);
        let trimmed = path.trim_end_matches('/');
        return trimmed.ends_with("/inir") || path.contains("/inir/");
    }
    false
}

fn pid_matches_inir(pid: u32) -> bool {
    fs::read(format!("/proc/{pid}/cmdline"))
        .ok()
        .is_some_and(|raw| cmdline_matches_inir(&raw))
}

fn find_inir_pid() -> Option<u32> {
    let entries = fs::read_dir("/proc").ok()?;
    for entry in entries.flatten() {
        let Ok(pid) = entry.file_name().to_string_lossy().parse::<u32>() else {
            continue;
        };
        if pid_matches_inir(pid) {
            return Some(pid);
        }
    }
    None
}

fn read_inir_env(pid: u32) -> Vec<(String, String)> {
    let Ok(raw) = fs::read(format!("/proc/{pid}/environ")) else {
        return Vec::new();
    };
    raw.split(|byte| *byte == 0)
        .filter_map(|entry| {
            let text = String::from_utf8_lossy(entry);
            let (key, value) = text.split_once('=')?;
            IMPORTED_ENV_KEYS
                .contains(&key)
                .then(|| (key.to_owned(), value.to_owned()))
        })
        .collect()
}

fn executable_file(path: &Path) -> bool {
    fs::metadata(path)
        .ok()
        .is_some_and(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
}

fn which_in_path(name: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|path| {
        env::split_paths(&path)
            .map(|dir| dir.join(name))
            .find(|candidate| executable_file(candidate))
    })
}

fn run_inir_command(cache: &Arc<Mutex<EnvCache>>, args: &[&str]) -> bool {
    let imported = {
        let mut cache = lock_recover(cache);
        cache.session_env()
    };
    let Some(imported) = imported else {
        eprintln!("[inir-superd] inir session environment unavailable");
        return false;
    };

    let program = env::var_os("INIR_LAUNCHER_PATH")
        .map(PathBuf::from)
        .filter(|path| executable_file(path))
        .or_else(|| which_in_path("inir"))
        .unwrap_or_else(|| PathBuf::from("inir"));

    match Command::new(program)
        .args(args)
        .envs(imported)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
    {
        Ok(_) => true,
        Err(error) => {
            eprintln!("[inir-superd] failed to launch inir {args:?}: {error}");
            false
        }
    }
}

fn notify_super_state(cache: &Arc<Mutex<EnvCache>>, pressed: bool) {
    let function = if pressed { "superPress" } else { "superRelease" };
    let _ = run_inir_command(cache, &["ipc", "overview", function]);
}

fn toggle_overview(cache: &Arc<Mutex<EnvCache>>) {
    let _ = run_inir_command(cache, &["overview", "toggle"]);
}

fn spawn_device_thread(
    key: DeviceKey,
    mut device: Device,
    roles: DeviceRoles,
    state: Arc<Mutex<TapState>>,
    env_cache: Arc<Mutex<EnvCache>>,
    tx: Sender<InternalEvent>,
) {
    thread::spawn(move || {
        let mut super_down = false;
        let mut chord = false;

        loop {
            let events = match device.fetch_events() {
                Ok(events) => events,
                Err(_) => break,
            };

            for event in events {
                let EventSummary::Key(_, code, value) = event.destructure() else {
                    continue;
                };

                if roles.keyboard && is_super(code) {
                    if value == 1 && !super_down {
                        super_down = true;
                        chord = false;
                        let notify = {
                            let mut state = lock_recover(&state);
                            state.super_press(&key)
                        };
                        if notify {
                            notify_super_state(&env_cache, true);
                        }
                    } else if value == 0 && super_down {
                        let action = {
                            let mut state = lock_recover(&state);
                            state.super_release(&key, chord, Instant::now())
                        };
                        if action.toggle {
                            toggle_overview(&env_cache);
                        }
                        if action.notify_release {
                            notify_super_state(&env_cache, false);
                        }
                        super_down = false;
                        chord = false;
                    }
                    continue;
                }

                if value != 1 {
                    continue;
                }

                if roles.keyboard {
                    if super_down {
                        chord = true;
                    }
                    let mut state = lock_recover(&state);
                    state.other_key_press();
                }
                if roles.pointer && is_pointer_button(code) {
                    let mut state = lock_recover(&state);
                    state.pointer_press();
                }
            }
        }

        if super_down {
            let notify = {
                let mut state = lock_recover(&state);
                state.device_gone(&key)
            };
            if notify {
                notify_super_state(&env_cache, false);
            }
        }
        let _ = tx.send(InternalEvent::DeviceGone(key));
    });
}

fn refresh_devices(
    monitored: &mut HashMap<PathBuf, u64>,
    next_token: &mut u64,
    state: &Arc<Mutex<TapState>>,
    env_cache: &Arc<Mutex<EnvCache>>,
    tx: &Sender<InternalEvent>,
) {
    let paths = event_paths();
    let discovered = paths.iter().cloned().collect::<HashSet<_>>();
    monitored.retain(|path, _| discovered.contains(path));

    for path in paths {
        if monitored.contains_key(&path) {
            continue;
        }
        let Ok(device) = Device::open(&path) else {
            continue;
        };
        let Some(roles) = classify_device(&device) else {
            continue;
        };

        *next_token = next_token.wrapping_add(1).max(1);
        let token = *next_token;
        monitored.insert(path.clone(), token);
        let key = DeviceKey { path, token };
        spawn_device_thread(
            key,
            device,
            roles,
            Arc::clone(state),
            Arc::clone(env_cache),
            tx.clone(),
        );
    }
}

fn run() {
    let (tx, rx): (Sender<InternalEvent>, Receiver<InternalEvent>) = mpsc::channel();
    let state = Arc::new(Mutex::new(TapState::default()));
    let env_cache = Arc::new(Mutex::new(EnvCache::default()));
    let mut monitored = HashMap::<PathBuf, u64>::new();
    let mut next_token = 0u64;

    loop {
        refresh_devices(
            &mut monitored,
            &mut next_token,
            &state,
            &env_cache,
            &tx,
        );

        match rx.recv_timeout(RESCAN_INTERVAL) {
            Ok(InternalEvent::DeviceGone(key)) => {
                if monitored.get(&key.path) == Some(&key.token) {
                    monitored.remove(&key.path);
                }
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => break,
        }
    }
}

fn main() {
    run();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(name: &str, token: u64) -> DeviceKey {
        DeviceKey {
            path: PathBuf::from(name),
            token,
        }
    }

    #[test]
    fn plain_super_tap_toggles_and_notifies_once() {
        let mut state = TapState::default();
        let device = key("/dev/input/event1", 1);
        let now = Instant::now();

        assert!(state.super_press(&device));
        assert_eq!(
            state.super_release(&device, false, now),
            ReleaseAction {
                toggle: true,
                notify_release: true,
            }
        );
    }

    #[test]
    fn chord_or_pointer_interaction_blocks_tap() {
        let now = Instant::now();
        let device = key("/dev/input/event1", 1);

        let mut chord = TapState::default();
        assert!(chord.super_press(&device));
        chord.other_key_press();
        assert!(!chord.super_release(&device, true, now).toggle);

        let mut pointer = TapState::default();
        assert!(pointer.super_press(&device));
        pointer.pointer_press();
        assert!(!pointer.super_release(&device, false, now).toggle);
    }

    #[test]
    fn duplicate_devices_share_global_press_release_and_tap_guard() {
        let mut state = TapState::default();
        let first = key("/dev/input/event1", 1);
        let second = key("/dev/input/event2", 2);
        let now = Instant::now();

        assert!(state.super_press(&first));
        assert!(!state.super_press(&second));

        let first_release = state.super_release(&first, false, now);
        assert!(first_release.toggle);
        assert!(!first_release.notify_release);

        let second_release = state.super_release(&second, false, now + Duration::from_secs(1));
        assert!(!second_release.toggle);
        assert!(second_release.notify_release);
    }

    #[test]
    fn debounce_matches_python_quarter_second_window() {
        let mut state = TapState::default();
        let device = key("/dev/input/event1", 1);
        let start = Instant::now();

        assert!(state.super_press(&device));
        assert!(state.super_release(&device, false, start).toggle);

        assert!(state.super_press(&device));
        assert!(
            !state
                .super_release(&device, false, start + Duration::from_millis(100))
                .toggle
        );

        assert!(state.super_press(&device));
        assert!(
            state
                .super_release(&device, false, start + Duration::from_millis(300))
                .toggle
        );
    }

    #[test]
    fn disappearing_pressed_device_releases_global_state() {
        let mut state = TapState::default();
        let device = key("/dev/input/event1", 1);
        assert!(state.super_press(&device));
        assert!(state.device_gone(&device));
        assert!(state.super_down_devices.is_empty());
    }

    #[test]
    fn process_matcher_preserves_legacy_and_path_launch_forms() {
        assert!(cmdline_matches_inir(b"/usr/bin/qs\0-c\0inir\0"));
        assert!(cmdline_matches_inir(
            b"/usr/bin/qs\0-n\0-p\0/home/user/.config/quickshell/inir\0"
        ));
        assert!(cmdline_matches_inir(
            b"/usr/bin/qs\0-p\0/home/user/.config/quickshell/inir/shell.qml\0"
        ));
        assert!(!cmdline_matches_inir(b"/usr/bin/qs\0-c\0other\0"));
        assert!(!cmdline_matches_inir(b"/usr/bin/quickshell\0-c\0inir\0"));
    }
}
