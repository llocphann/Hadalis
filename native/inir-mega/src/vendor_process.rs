//! Bounded, non-interactive process substrate for future qualified MEGAcmd reads.
//!
//! This module is intentionally NOT wired to any request operation yet.  Its
//! tests use only local fake processes.  A vendor operation must first prove
//! its installed-version argv/output contract before this substrate may run it.
#![allow(dead_code)]

#[cfg(unix)]
use std::collections::BTreeMap;
#[cfg(unix)]
use std::env;
#[cfg(unix)]
use std::ffi::{OsStr, OsString};
#[cfg(unix)]
use std::io::{self, Read};
#[cfg(unix)]
use std::os::unix::process::CommandExt;
#[cfg(unix)]
use std::path::{Path, PathBuf};
#[cfg(unix)]
use std::process::{Command, ExitStatus, Stdio};
#[cfg(unix)]
use std::thread;
#[cfg(unix)]
use std::time::Duration;

#[cfg(unix)]
const POLL_INTERVAL: Duration = Duration::from_millis(10);

#[cfg(unix)]
const PRESERVED_EXACT: &[&str] = &[
    "HOME",
    "USER",
    "LOGNAME",
    "XDG_RUNTIME_DIR",
    "TMPDIR",
    "LANG",
    "TZ",
    "SSL_CERT_FILE",
    "SSL_CERT_DIR",
    "http_proxy",
    "https_proxy",
    "no_proxy",
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "NO_PROXY",
];

#[cfg(unix)]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EnvironmentPolicy {
    vars: BTreeMap<OsString, OsString>,
}

#[cfg(unix)]
impl EnvironmentPolicy {
    pub fn from_current(vendor_dir: &Path, socket_name: Option<&OsStr>) -> io::Result<Self> {
        Self::from_entries(env::vars_os(), vendor_dir, socket_name)
    }

    pub fn from_entries<I, K, V>(
        entries: I,
        vendor_dir: &Path,
        socket_name: Option<&OsStr>,
    ) -> io::Result<Self>
    where
        I: IntoIterator<Item = (K, V)>,
        K: Into<OsString>,
        V: Into<OsString>,
    {
        if !vendor_dir.is_absolute() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "vendor directory must be absolute",
            ));
        }

        let source: BTreeMap<OsString, OsString> = entries
            .into_iter()
            .map(|(key, value)| (key.into(), value.into()))
            .collect();
        let mut vars = BTreeMap::new();

        for (key, value) in &source {
            let Some(name) = key.to_str() else {
                continue;
            };
            if PRESERVED_EXACT.contains(&name) || name.starts_with("LC_") {
                vars.insert(key.clone(), value.clone());
            }
        }

        let mut path_parts = vec![PathBuf::from(vendor_dir)];
        if let Some(original) = source.get(OsStr::new("PATH")) {
            for item in env::split_paths(original) {
                if item != vendor_dir && !item.as_os_str().is_empty() {
                    path_parts.push(item);
                }
            }
        }
        let controlled_path = env::join_paths(path_parts).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "invalid controlled PATH")
        })?;
        vars.insert(OsString::from("PATH"), controlled_path);

        // Never inherit MEGACMD_* switches implicitly.  The sole exception is
        // an already-validated socket identity supplied separately by the
        // caller; debug/redaction/UTF-8/logging overrides are therefore absent.
        if let Some(socket) = socket_name {
            if socket.is_empty() {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidInput,
                    "empty socket identity",
                ));
            }
            vars.insert(OsString::from("MEGACMD_SOCKET_NAME"), socket.to_os_string());
        }

        Ok(Self { vars })
    }

    fn apply(&self, command: &mut Command) {
        command.env_clear();
        command.envs(self.vars.iter());
    }

    #[cfg(test)]
    fn get(&self, key: &str) -> Option<&OsStr> {
        self.vars.get(OsStr::new(key)).map(OsString::as_os_str)
    }
}

#[cfg(unix)]
#[derive(Debug, Eq, PartialEq)]
pub struct Capture {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_code: Option<i32>,
    pub timed_out: bool,
    pub stdout_capped: bool,
    pub stderr_capped: bool,
}

#[cfg(unix)]
impl Capture {
    pub fn clean_success(&self) -> bool {
        !self.timed_out
            && !self.stdout_capped
            && !self.stderr_capped
            && self.stderr.is_empty()
            && self.exit_code == Some(0)
    }
}

#[cfg(unix)]
#[derive(Clone, Debug)]
pub struct VendorCommand {
    pub program: PathBuf,
    pub args: Vec<OsString>,
    pub environment: EnvironmentPolicy,
    pub timeout: Duration,
    pub stdout_cap: usize,
    pub stderr_cap: usize,
}

#[cfg(unix)]
fn boottime_now() -> io::Result<Duration> {
    #[cfg(target_os = "linux")]
    {
        let mut value = libc::timespec {
            tv_sec: 0,
            tv_nsec: 0,
        };
        if unsafe { libc::clock_gettime(libc::CLOCK_BOOTTIME, &mut value) } != 0 {
            return Err(io::Error::last_os_error());
        }
        if value.tv_sec < 0 || value.tv_nsec < 0 {
            return Err(io::Error::new(
                io::ErrorKind::Other,
                "invalid CLOCK_BOOTTIME value",
            ));
        }
        return Ok(Duration::new(value.tv_sec as u64, value.tv_nsec as u32));
    }

    #[cfg(not(target_os = "linux"))]
    {
        use std::sync::OnceLock;
        use std::time::Instant;
        static START: OnceLock<Instant> = OnceLock::new();
        Ok(START.get_or_init(Instant::now).elapsed())
    }
}

#[cfg(unix)]
fn drain_bounded<R: Read + Send + 'static>(
    mut stream: R,
    cap: usize,
) -> thread::JoinHandle<io::Result<(Vec<u8>, bool)>> {
    thread::spawn(move || {
        let mut kept = Vec::with_capacity(cap.min(8192));
        let mut capped = false;
        let mut chunk = [0u8; 4096];
        loop {
            let count = stream.read(&mut chunk)?;
            if count == 0 {
                break;
            }
            let remaining = cap.saturating_sub(kept.len());
            let take = remaining.min(count);
            kept.extend_from_slice(&chunk[..take]);
            if take != count {
                capped = true;
            }
        }
        Ok((kept, capped))
    })
}

#[cfg(unix)]
fn kill_private_group(pid: u32) -> io::Result<()> {
    if pid > i32::MAX as u32 {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "invalid child pid"));
    }
    let rc = unsafe { libc::kill(-(pid as i32), libc::SIGKILL) };
    if rc == 0 {
        return Ok(());
    }
    let error = io::Error::last_os_error();
    if error.raw_os_error() == Some(libc::ESRCH) {
        Ok(())
    } else {
        Err(error)
    }
}

#[cfg(unix)]
fn join_drain(
    handle: thread::JoinHandle<io::Result<(Vec<u8>, bool)>>,
) -> io::Result<(Vec<u8>, bool)> {
    handle.join().map_err(|_| {
        io::Error::new(io::ErrorKind::Other, "process output drain thread panicked")
    })?
}

#[cfg(unix)]
pub fn run_bounded(spec: &VendorCommand) -> io::Result<Capture> {
    if !spec.program.is_absolute()
        || spec.timeout.is_zero()
        || spec.stdout_cap == 0
        || spec.stderr_cap == 0
    {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "invalid bounded vendor process specification",
        ));
    }

    let mut command = Command::new(&spec.program);
    command.args(&spec.args);
    spec.environment.apply(&mut command);
    command
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    // Each Hadalis-owned client is its own session/process group.  Timeout
    // cleanup can therefore terminate descendants that inherited its pipes
    // without touching an externally owned mega-cmd-server.
    unsafe {
        command.pre_exec(|| {
            if libc::setsid() == -1 {
                return Err(io::Error::last_os_error());
            }
            Ok(())
        });
    }

    let mut child = command.spawn()?;
    let stdout = child.stdout.take().ok_or_else(|| {
        io::Error::new(io::ErrorKind::Other, "missing child stdout pipe")
    })?;
    let stderr = child.stderr.take().ok_or_else(|| {
        io::Error::new(io::ErrorKind::Other, "missing child stderr pipe")
    })?;
    let stdout_thread = drain_bounded(stdout, spec.stdout_cap);
    let stderr_thread = drain_bounded(stderr, spec.stderr_cap);

    let started = boottime_now()?;
    let deadline = started.checked_add(spec.timeout).ok_or_else(|| {
        io::Error::new(io::ErrorKind::InvalidInput, "process timeout overflow")
    })?;

    let mut timed_out = false;
    let status: ExitStatus = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if boottime_now()? >= deadline {
            timed_out = true;
            // Best-effort group kill first, then direct-child fallback.  Always
            // wait/reap before returning a result or allowing another process.
            let group_result = kill_private_group(child.id());
            let _ = child.kill();
            let status = child.wait()?;
            if let Err(error) = group_result {
                let _ = join_drain(stdout_thread);
                let _ = join_drain(stderr_thread);
                return Err(error);
            }
            break status;
        }
        thread::sleep(POLL_INTERVAL);
    };

    let (stdout, stdout_capped) = join_drain(stdout_thread)?;
    let (stderr, stderr_capped) = join_drain(stderr_thread)?;
    Ok(Capture {
        stdout,
        stderr,
        exit_code: status.code(),
        timed_out,
        stdout_capped,
        stderr_capped,
    })
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::fs;

    fn policy() -> EnvironmentPolicy {
        EnvironmentPolicy::from_entries(
            [
                ("HOME", "/tmp/hadalis-megaqml-fake-home"),
                ("USER", "fixture-user"),
                ("LANG", "C.UTF-8"),
                ("PATH", "/usr/bin:/bin"),
            ],
            Path::new("/usr/bin"),
            None,
        )
        .unwrap()
    }

    fn shell(script: &str, timeout: Duration, stdout_cap: usize, stderr_cap: usize)
        -> VendorCommand
    {
        VendorCommand {
            program: PathBuf::from("/bin/sh"),
            args: vec![OsString::from("-c"), OsString::from(script)],
            environment: policy(),
            timeout,
            stdout_cap,
            stderr_cap,
        }
    }

    #[test]
    fn environment_policy_is_allowlisted_and_vendor_debug_overrides_are_removed() {
        let env = EnvironmentPolicy::from_entries(
            [
                ("HOME", "/home/tester"),
                ("LANG", "en_US.UTF-8"),
                ("LC_TIME", "C.UTF-8"),
                ("http_proxy", "http://proxy.invalid"),
                ("https_proxy", "https://proxy.invalid"),
                ("PATH", "/bin:/opt/other/bin"),
                ("MEGACMD_DO_NOT_REDACT_LINES", "1"),
                ("MEGACMD_DISABLE_UTF8_VALIDATIONS", "1"),
                ("MEGACMD_LOGLEVEL", "max"),
                ("MEGACMD_JSON_LOGS", "1"),
                ("MEGACMD_SOCKET_NAME", "untrusted-inherited"),
                ("PRIVATE_UNRELATED_SECRET", "do-not-inherit"),
            ],
            Path::new("/opt/mega/bin"),
            Some(OsStr::new("validated-existing-socket")),
        )
        .unwrap();

        assert_eq!(env.get("HOME"), Some(OsStr::new("/home/tester")));
        assert_eq!(env.get("LANG"), Some(OsStr::new("en_US.UTF-8")));
        assert_eq!(env.get("LC_TIME"), Some(OsStr::new("C.UTF-8")));
        assert_eq!(
            env.get("http_proxy"),
            Some(OsStr::new("http://proxy.invalid"))
        );
        assert_eq!(
            env.get("https_proxy"),
            Some(OsStr::new("https://proxy.invalid"))
        );
        assert_eq!(
            env.get("MEGACMD_SOCKET_NAME"),
            Some(OsStr::new("validated-existing-socket"))
        );
        for removed in [
            "MEGACMD_DO_NOT_REDACT_LINES",
            "MEGACMD_DISABLE_UTF8_VALIDATIONS",
            "MEGACMD_LOGLEVEL",
            "MEGACMD_JSON_LOGS",
            "PRIVATE_UNRELATED_SECRET",
        ] {
            assert!(env.get(removed).is_none(), "{removed} unexpectedly inherited");
        }
        let path = env.get("PATH").unwrap().to_string_lossy();
        assert!(path.starts_with("/opt/mega/bin:"));
        assert!(path.contains("/bin"));
        assert!(path.contains("/opt/other/bin"));
    }

    #[test]
    fn fake_child_has_null_stdin_and_clean_bounded_success() {
        let result = run_bounded(&shell(
            "if IFS= read -r unexpected; then exit 91; fi; printf 'ok\\n'",
            Duration::from_secs(1),
            1024,
            1024,
        ))
        .unwrap();
        assert_eq!(result.stdout, b"ok\n");
        assert!(result.stderr.is_empty());
        assert_eq!(result.exit_code, Some(0));
        assert!(!result.timed_out);
        assert!(result.clean_success());
    }

    #[test]
    fn concurrent_pipe_drain_caps_bytes_without_deadlock() {
        let result = run_bounded(&shell(
            r#"i=0; while [ "$i" -lt 5000 ]; do printf '0123456789abcdef0123456789abcdef\\n'; printf 'fedcba9876543210fedcba9876543210\\n' >&2; i=$((i+1)); done"#,
            Duration::from_secs(3),
            1024,
            1536,
        ))
        .unwrap();
        assert_eq!(result.exit_code, Some(0));
        assert_eq!(result.stdout.len(), 1024);
        assert_eq!(result.stderr.len(), 1536);
        assert!(result.stdout_capped);
        assert!(result.stderr_capped);
        assert!(!result.clean_success());
    }

    #[test]
    fn timeout_kills_private_process_group_before_reap() {
        let marker = env::temp_dir().join(format!(
            "megaqml-process-group-{}-marker",
            std::process::id()
        ));
        let _ = fs::remove_file(&marker);
        let script = r#"(sleep 0.25; printf late > "$1") & wait"#;
        let mut spec = shell(script, Duration::from_millis(50), 1024, 1024);
        spec.args.push(OsString::from("fixture-sh"));
        spec.args.push(marker.as_os_str().to_os_string());

        let result = run_bounded(&spec).unwrap();
        assert!(result.timed_out);
        assert!(!result.clean_success());
        thread::sleep(Duration::from_millis(350));
        assert!(!marker.exists(), "timed-out descendant survived group cleanup");
        let _ = fs::remove_file(marker);
    }

    #[test]
    fn invalid_spec_fails_before_process_dispatch() {
        let bad = VendorCommand {
            program: PathBuf::from("sh"),
            args: vec![],
            environment: policy(),
            timeout: Duration::from_secs(1),
            stdout_cap: 1024,
            stderr_cap: 1024,
        };
        assert_eq!(
            run_bounded(&bad).unwrap_err().kind(),
            io::ErrorKind::InvalidInput
        );
    }
}
