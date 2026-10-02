#[cfg(unix)]
use std::fs::File;
#[cfg(unix)]
use std::io::{Read, Write};
#[cfg(unix)]
use std::os::fd::{FromRawFd, RawFd};
#[cfg(unix)]
use std::os::unix::process::CommandExt;
#[cfg(unix)]
use std::path::Path;
#[cfg(unix)]
use std::process::{Child, Command, Stdio};
#[cfg(unix)]
use std::time::{Duration, Instant};

#[cfg(unix)]
use anyhow::{Context, Result, bail};

#[cfg(unix)]
use crate::{AuthState, AuthStep, SecretWrite, advance_auth, classify_auth_prompt};

#[cfg(unix)]
const BLOCKED_VENDOR_ENV: [&str; 4] = [
    "MEGACMD_DO_NOT_REDACT_LINES",
    "MEGACMD_DISABLE_UTF8_VALIDATIONS",
    "MEGACMD_LOGLEVEL",
    "MEGACMD_JSON_LOGS",
];

#[cfg(unix)]
fn sanitize_vendor_environment(command: &mut Command) {
    for name in BLOCKED_VENDOR_ENV {
        command.env_remove(name);
    }
}

#[cfg(unix)]
struct PtyPair {
    master: RawFd,
    slave: RawFd,
}

#[cfg(unix)]
fn set_close_on_exec(fd: RawFd) -> std::io::Result<()> {
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFD) };
    if flags < 0 {
        return Err(std::io::Error::last_os_error());
    }
    if unsafe { libc::fcntl(fd, libc::F_SETFD, flags | libc::FD_CLOEXEC) } < 0 {
        return Err(std::io::Error::last_os_error());
    }
    Ok(())
}

#[cfg(unix)]
fn open_private_pty() -> Result<PtyPair> {
    let mut master = -1;
    let mut slave = -1;
    let rc = unsafe {
        libc::openpty(
            &mut master,
            &mut slave,
            std::ptr::null_mut(),
            std::ptr::null(),
            std::ptr::null(),
        )
    };
    if rc != 0 {
        return Err(std::io::Error::last_os_error()).context("open auth PTY");
    }
    // The raw PTY master and slave must not leak across vendor exec, even if
    // the caller opens this dialog from a multi-threaded shell process.
    if let Err(error) = set_close_on_exec(master).and_then(|_| set_close_on_exec(slave)) {
        unsafe {
            libc::close(master);
            libc::close(slave);
        }
        return Err(error).context("protect auth PTY descriptors against exec inheritance");
    }

    let mut termios = unsafe { std::mem::zeroed::<libc::termios>() };
    if unsafe { libc::tcgetattr(slave, &mut termios) } != 0 {
        unsafe {
            libc::close(master);
            libc::close(slave);
        }
        return Err(std::io::Error::last_os_error()).context("read PTY attributes");
    }
    termios.c_lflag &= !(libc::ECHO | libc::ECHONL);
    if unsafe { libc::tcsetattr(slave, libc::TCSANOW, &termios) } != 0 {
        unsafe {
            libc::close(master);
            libc::close(slave);
        }
        return Err(std::io::Error::last_os_error()).context("disable PTY echo");
    }

    Ok(PtyPair { master, slave })
}

#[cfg(unix)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum AuthDialogOutcome {
    Authenticated,
    MfaRequired,
    Failed,
    Unexpected,
}

#[cfg(unix)]
#[derive(Debug)]
pub(crate) struct AuthDialogResult {
    pub(crate) outcome: AuthDialogOutcome,
}

#[cfg(unix)]
fn stop_child(child: &mut Child) {
    // configure_child makes the vendor a new session/process-group leader.
    // Kill its entire private group, not just the launcher: an interactive
    // vendor may spawn children that retain session state or inherited PTYs.
    // Signal BEFORE wait/try_wait: until the direct child is reaped, its PID
    // cannot be reused for an unrelated process group.
    if let Ok(pid) = libc::pid_t::try_from(child.id()) {
        let _ = unsafe { libc::kill(-pid, libc::SIGKILL) };
    }
    // If setsid or the group signal did not take effect, also kill the
    // direct child. Reap only after both signals have been attempted.
    let _ = child.kill();
    let _ = child.wait();
}

#[cfg(unix)]
fn write_private_line(writer: &mut File, value: &str) -> Result<()> {
    writer.write_all(value.as_bytes())?;
    writer.write_all(b"\n")?;
    writer.flush()?;
    Ok(())
}

#[cfg(unix)]
fn configure_child(program: &Path, slave: RawFd) -> Result<Command> {
    let stdin_fd = unsafe { libc::dup(slave) };
    let stdout_fd = unsafe { libc::dup(slave) };
    if stdin_fd < 0 || stdout_fd < 0 {
        unsafe {
            if stdin_fd >= 0 {
                libc::close(stdin_fd);
            }
            if stdout_fd >= 0 {
                libc::close(stdout_fd);
            }
            libc::close(slave);
        }
        return Err(std::io::Error::last_os_error()).context("duplicate PTY slave");
    }
    // dup() clears FD_CLOEXEC. Keep source handles private while Command
    // duplicates them onto the child's actual stdin/stdout/stderr.
    if let Err(error) =
        set_close_on_exec(stdin_fd).and_then(|_| set_close_on_exec(stdout_fd))
    {
        unsafe {
            libc::close(stdin_fd);
            libc::close(stdout_fd);
            libc::close(slave);
        }
        return Err(error).context("protect auth PTY stdio sources against exec inheritance");
    }

    let mut command = Command::new(program);
    command
        .stdin(unsafe { Stdio::from_raw_fd(stdin_fd) })
        .stdout(unsafe { Stdio::from_raw_fd(stdout_fd) })
        .stderr(unsafe { Stdio::from_raw_fd(slave) });
    sanitize_vendor_environment(&mut command);

    unsafe {
        command.pre_exec(|| {
            if libc::setsid() < 0 {
                return Err(std::io::Error::last_os_error());
            }
            if libc::ioctl(libc::STDIN_FILENO, libc::TIOCSCTTY, 0) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            let limit = libc::rlimit {
                rlim_cur: 0,
                rlim_max: 0,
            };
            if libc::setrlimit(libc::RLIMIT_CORE, &limit) != 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    Ok(command)
}

#[cfg(unix)]
pub(crate) fn run_auth_dialog(
    program: &Path,
    email: &str,
    password: &str,
    mfa: Option<&str>,
    timeout: Duration,
    output_cap: usize,
) -> Result<AuthDialogResult> {
    let PtyPair { master, slave } = open_private_pty()?;
    // Own the master BEFORE fallible setup or spawn. Dropping reader closes
    // this private PTY even if executable startup fails.
    let mut reader = unsafe { File::from_raw_fd(master) };
    let mut command = configure_child(program, slave)?;
    let mut child = command.spawn().context("spawn MEGAcmd interactive shell")?;
    // Command retains its configured Stdio handles after spawn. Release the
    // parent-owned PTY slave copies now: otherwise a vendor that closes all
    // child-side streams cannot signal EOF/EIO to our master before timeout.
    drop(command);
    let mut writer = match reader.try_clone() {
        Ok(writer) => writer,
        Err(error) => {
            stop_child(&mut child);
            return Err(error).context("clone auth PTY master");
        }
    };

    if let Err(error) = write_private_line(&mut writer, &format!("login {email}")) {
        stop_child(&mut child);
        return Err(error).context("write login command to auth PTY");
    }

    let mut state = AuthState::AwaitPassword;
    // Do not retain a vendor transcript: the vendor may deliberately echo
    // secrets even when kernel PTY ECHO is disabled.
    let mut consumed_output_bytes = 0usize;
    let mut pending = Vec::new();
    let deadline = Instant::now() + timeout;

    loop {
        if Instant::now() >= deadline {
            stop_child(&mut child);
            bail!("auth vendor deadline exceeded");
        }
        let remaining = deadline.saturating_duration_since(Instant::now());
        let timeout_ms = remaining.as_millis().min(100).max(1) as i32;
        let mut pollfd = libc::pollfd {
            fd: master,
            events: libc::POLLIN,
            revents: 0,
        };
        let poll_rc = unsafe { libc::poll(&mut pollfd, 1, timeout_ms) };
        if poll_rc < 0 {
            stop_child(&mut child);
            return Err(std::io::Error::last_os_error()).context("poll auth PTY");
        }
        if poll_rc == 0 {
            continue;
        }

        let mut byte = [0_u8; 1];
        match reader.read(&mut byte) {
            Ok(0) => break,
            Ok(_) => {
                pending.push(byte[0]);
                if consumed_output_bytes.saturating_add(pending.len()) > output_cap {
                    stop_child(&mut child);
                    bail!("auth vendor output cap exceeded");
                }
                if byte[0] != b'\n' && byte[0] != b':' {
                    continue;
                }
                let text = match String::from_utf8(std::mem::take(&mut pending)) {
                    Ok(text) => text,
                    Err(error) => {
                        stop_child(&mut child);
                        return Err(error).context("auth prompt UTF-8");
                    }
                };
                consumed_output_bytes += text.len();
                match advance_auth(&mut state, classify_auth_prompt(&text)) {
                    AuthStep::Write(SecretWrite::Password) => {
                        if let Err(error) = write_private_line(&mut writer, password) {
                            stop_child(&mut child);
                            return Err(error).context("write password to auth PTY");
                        }
                    }
                    AuthStep::Write(SecretWrite::Mfa) => {
                        let Some(code) = mfa else {
                            stop_child(&mut child);
                            return Ok(AuthDialogResult {
                                outcome: AuthDialogOutcome::MfaRequired,
                            });
                        };
                        if let Err(error) = write_private_line(&mut writer, code) {
                            stop_child(&mut child);
                            return Err(error).context("write MFA code to auth PTY");
                        }
                    }
                    AuthStep::Complete => {
                        stop_child(&mut child);
                        return Ok(AuthDialogResult {
                            outcome: AuthDialogOutcome::Authenticated,
                        });
                    }
                    AuthStep::Failed => {
                        stop_child(&mut child);
                        return Ok(AuthDialogResult {
                            outcome: AuthDialogOutcome::Failed,
                        });
                    }
                    AuthStep::RejectUnexpected => {
                        stop_child(&mut child);
                        return Ok(AuthDialogResult {
                            outcome: AuthDialogOutcome::Unexpected,
                        });
                    }
                }
            }
            Err(error) if error.raw_os_error() == Some(libc::EIO) => break,
            Err(error) => {
                stop_child(&mut child);
                return Err(error).context("read auth PTY");
            }
        }
    }

    // A vendor can close every PTY slave descriptor yet keep its parent
    // process alive (for example, after redirecting all stdio). Waiting for
    // natural exit here would bypass the auth deadline. EOF is always an
    // unsuccessful dialog without a recognized terminal prompt: terminate
    // the entire private process group before reaping the launcher.
    stop_child(&mut child);
    Ok(AuthDialogResult {
        outcome: AuthDialogOutcome::Unexpected,
    })
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(1);

    fn fake_vendor(script: &str) -> std::path::PathBuf {
        let root = std::env::temp_dir().join(format!(
            "inir-mega-pty-{}-{}",
            std::process::id(),
            NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir_all(&root).unwrap();
        let path = root.join("fake-vendor");
        fs::write(&path, script).unwrap();
        let mut permissions = fs::metadata(&path).unwrap().permissions();
        permissions.set_mode(0o700);
        fs::set_permissions(&path, permissions).unwrap();
        path
    }

    #[test]
    fn pty_master_and_slave_are_close_on_exec() {
        let PtyPair { master, slave } = open_private_pty().unwrap();
        for fd in [master, slave] {
            let flags = unsafe { libc::fcntl(fd, libc::F_GETFD) };
            assert!(flags >= 0);
            assert_ne!(flags & libc::FD_CLOEXEC, 0);
            unsafe { libc::close(fd) };
        }
    }

    fn qualified_script() -> &'static str {
        "#!/bin/sh\nIFS= read -r command\n[ \"$command\" = \"login fixture@example.invalid\" ] || exit 40\nprintf 'Password:'\nIFS= read -r password\nprintf 'Multi-factor authentication code:'\nIFS= read -r mfa\nprintf 'Login successful\\n'\n"
    }

    #[test]
    fn vendor_environment_strips_debug_overrides_and_preserves_session_context() {
        let mut command = Command::new("/bin/sh");
        command
            .arg("-c")
            .arg(
                r#"
test -z "${MEGACMD_DO_NOT_REDACT_LINES+x}" || exit 41
test -z "${MEGACMD_DISABLE_UTF8_VALIDATIONS+x}" || exit 42
test -z "${MEGACMD_LOGLEVEL+x}" || exit 43
test -z "${MEGACMD_JSON_LOGS+x}" || exit 44
test "$MEGACMD_SOCKET_NAME" = "fixture-socket" || exit 45
test "$HOME" = "/fixture/home" || exit 46
test "$http_proxy" = "http://proxy.invalid:8080" || exit 47
test "$https_proxy" = "https://proxy.invalid:8443" || exit 48
test "$LANG" = "en_US.UTF-8" || exit 49
"#,
            )
            .env("MEGACMD_DO_NOT_REDACT_LINES", "1")
            .env("MEGACMD_DISABLE_UTF8_VALIDATIONS", "1")
            .env("MEGACMD_LOGLEVEL", "debug")
            .env("MEGACMD_JSON_LOGS", "1")
            .env("MEGACMD_SOCKET_NAME", "fixture-socket")
            .env("HOME", "/fixture/home")
            .env("http_proxy", "http://proxy.invalid:8080")
            .env("https_proxy", "https://proxy.invalid:8443")
            .env("LANG", "en_US.UTF-8");
        sanitize_vendor_environment(&mut command);
        assert!(command.status().unwrap().success());
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn pty_failed_fake_vendor_spawn_does_not_leak_master_descriptors() {
        // Never contacts MEGA: remove an inert fake executable before spawn.
        let vendor = fake_vendor("#!/bin/sh\nexit 50\n");
        fs::remove_file(&vendor).unwrap();
        let count_fds = || fs::read_dir("/proc/self/fd").unwrap().count();
        let baseline = count_fds();
        for _ in 0..24 {
            let result = run_auth_dialog(
                &vendor,
                "fixture@example.invalid",
                "FAKE_PRIVATE_CANARY",
                None,
                Duration::from_millis(500),
                512,
            );
            let err = result.expect_err("missing inert fake vendor must fail");
            assert!(!format!("{err:?}").contains("FAKE_PRIVATE_CANARY"));
        }
        // Parallel unit tests may briefly own descriptors. A repeated 24-FD
        // master leak exceeds this bounded concurrent-FD allowance.
        assert!(count_fds() <= baseline + 4, "failed launches leaked PTY descriptors");
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_password_mfa_flow_is_qualified_without_echoing_secrets() {
        let vendor = fake_vendor(qualified_script());
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            Some("123456"),
            Duration::from_secs(2),
            4096,
        )
        .unwrap();
        assert_eq!(result.outcome, AuthDialogOutcome::Authenticated);
        let debug = format!("{result:?}");
        assert!(!debug.contains("fixture@example.invalid"));
        assert!(!debug.contains("fixture-password-never-log"));
        assert!(!debug.contains("123456"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_missing_mfa_returns_required_without_persisting_dialog() {
        let vendor = fake_vendor(qualified_script());
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            None,
            Duration::from_secs(2),
            4096,
        )
        .unwrap();
        assert_eq!(result.outcome, AuthDialogOutcome::MfaRequired);
        assert!(!format!("{result:?}").contains("fixture-password-never-log"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_unknown_prompt_fails_closed_without_hanging() {
        let vendor = fake_vendor(
            "#!/bin/sh\nIFS= read -r command\nprintf 'Enter account recovery key:'\nsleep 30\n",
        );
        let started = Instant::now();
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            Some("123456"),
            Duration::from_secs(2),
            4096,
        )
        .unwrap();
        assert_eq!(result.outcome, AuthDialogOutcome::Unexpected);
        assert!(started.elapsed() < Duration::from_secs(5));
        let debug = format!("{result:?}");
        assert!(!debug.contains("fixture-password-never-log"));
        assert!(!debug.contains("123456"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_deliberately_echoed_password_never_enters_result() {
        // PTY ECHO=off cannot prevent the vendor itself from echoing
        // secrets. Do not retain the raw vendor transcript in metadata.
        let vendor = fake_vendor(
            "#!/bin/sh\nIFS= read -r command\nprintf 'Password:'\nIFS= read -r secret\nprintf '%s\\n' \"$secret\"\n",
        );
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "private-echo-canary-never-expose",
            None,
            Duration::from_secs(2),
            4096,
        )
        .unwrap();
        assert_eq!(result.outcome, AuthDialogOutcome::Unexpected);
        let public_result = format!("{result:?}");
        assert!(!public_result.contains("private-echo-canary-never-expose"));
        assert!(!public_result.contains("fixture@example.invalid"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_unknown_prompt_kills_child_process_group_not_just_launcher() {
        // This is a pure fake vendor; a live MEGA session is never started.
        // Its background child would write a marker after the launcher exits
        // if stop_child killed only the shell instead of its private group.
        let vendor = fake_vendor("#!/bin/sh\nexit 50\n");
        let base = vendor.parent().unwrap();
        let ready = base.join("background-ready");
        let survived = base.join("background-survived");
        let script = format!(
            "#!/bin/sh\n(sleep 1; printf SURVIVED > '{}') &\nprintf READY > '{}'\nprintf 'Enter account recovery key:'\nwait\n",
            survived.display(), ready.display(),
        );
        fs::write(&vendor, script).unwrap();
        let started = Instant::now();
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            None,
            Duration::from_secs(5),
            4096,
        ).unwrap();
        assert_eq!(result.outcome, AuthDialogOutcome::Unexpected);
        assert!(ready.is_file(), "fake vendor did not start its background child");
        assert!(started.elapsed() < Duration::from_secs(3));
        std::thread::sleep(Duration::from_millis(1250));
        assert!(!survived.exists(), "orphaned fake vendor child survived cleanup");
        let _ = fs::remove_dir_all(base);
    }

    #[test]
    fn pty_closed_slave_does_not_bypass_deadline_by_waiting_for_parent() {
        // Fake vendor disconnects all PTY streams but remains alive. The
        // former blocking child.wait() could outlive the caller's deadline.
        let vendor = fake_vendor(
            "#!/bin/sh\nIFS= read -r command\nexec </dev/null >/dev/null 2>&1\nsleep 30\n",
        );
        let started = Instant::now();
        let result = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "FAKE_SECRET_NEVER_EXPOSE",
            None,
            Duration::from_millis(700),
            4096,
        );
        assert!(started.elapsed() < Duration::from_secs(3));
        assert_eq!(result.unwrap().outcome, AuthDialogOutcome::Unexpected);
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_silent_vendor_is_bounded() {
        let vendor = fake_vendor("#!/bin/sh\nIFS= read -r command\nsleep 30\n");
        let started = Instant::now();
        let error = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            Some("123456"),
            Duration::from_millis(250),
            4096,
        )
        .unwrap_err();
        assert!(started.elapsed() < Duration::from_secs(5));
        assert!(error.to_string().contains("deadline exceeded"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_vendor_output_is_capped() {
        let vendor = fake_vendor(
            "#!/bin/sh\nIFS= read -r command\ni=0\nwhile [ $i -lt 256 ]; do printf x; i=$((i+1)); done\nprintf ':'\nsleep 30\n",
        );
        let error = run_auth_dialog(
            &vendor,
            "fixture@example.invalid",
            "fixture-password-never-log",
            Some("123456"),
            Duration::from_secs(2),
            64,
        )
        .unwrap_err();
        assert!(error.to_string().contains("output cap exceeded"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }
}
