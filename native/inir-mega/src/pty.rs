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
use crate::{AuthPrompt, AuthState, AuthStep, SecretWrite, advance_auth, classify_auth_prompt};

#[cfg(unix)]
struct PtyPair {
    master: RawFd,
    slave: RawFd,
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
pub(crate) struct FakeAuthResult {
    pub(crate) terminal: AuthStep,
    pub(crate) transcript: String,
}

#[cfg(unix)]
fn stop_child(child: &mut Child) {
    if child.try_wait().ok().flatten().is_none() {
        let _ = child.kill();
    }
    let _ = child.wait();
}

#[cfg(unix)]
pub(crate) fn run_fake_auth_dialog(
    program: &Path,
    password: &str,
    mfa: &str,
) -> Result<FakeAuthResult> {
    let PtyPair { master, slave } = open_private_pty()?;
    let stdin_fd = unsafe { libc::dup(slave) };
    let stdout_fd = unsafe { libc::dup(slave) };
    if stdin_fd < 0 || stdout_fd < 0 {
        unsafe {
            if stdin_fd >= 0 { libc::close(stdin_fd); }
            if stdout_fd >= 0 { libc::close(stdout_fd); }
            libc::close(master);
            libc::close(slave);
        }
        return Err(std::io::Error::last_os_error()).context("duplicate PTY slave");
    }

    let mut command = Command::new(program);
    command
        .stdin(unsafe { Stdio::from_raw_fd(stdin_fd) })
        .stdout(unsafe { Stdio::from_raw_fd(stdout_fd) })
        .stderr(unsafe { Stdio::from_raw_fd(slave) });

    unsafe {
        command.pre_exec(|| {
            if libc::setsid() < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }

    let mut child = command.spawn().context("spawn fake auth vendor")?;
    let mut reader = unsafe { File::from_raw_fd(master) };
    let mut writer = reader.try_clone().context("clone PTY master")?;
    let mut state = AuthState::AwaitPassword;
    let mut transcript = String::new();
    let mut pending = Vec::new();
    let deadline = Instant::now() + Duration::from_secs(2);

    loop {
        if Instant::now() >= deadline {
            stop_child(&mut child);
            bail!("fake auth vendor deadline exceeded");
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
            return Err(std::io::Error::last_os_error()).context("poll fake auth PTY");
        }
        if poll_rc == 0 {
            continue;
        }

        let mut byte = [0_u8; 1];
        match reader.read(&mut byte) {
            Ok(0) => break,
            Ok(_) => {
                pending.push(byte[0]);
                if byte[0] != b'\n' && byte[0] != b':' {
                    continue;
                }
                let text = String::from_utf8(pending.clone()).context("fake auth prompt UTF-8")?;
                transcript.push_str(&text);
                pending.clear();
                match advance_auth(&mut state, classify_auth_prompt(&text)) {
                    AuthStep::Write(SecretWrite::Password) => {
                        writer.write_all(password.as_bytes())?;
                        writer.write_all(b"\n")?;
                        writer.flush()?;
                    }
                    AuthStep::Write(SecretWrite::Mfa) => {
                        writer.write_all(mfa.as_bytes())?;
                        writer.write_all(b"\n")?;
                        writer.flush()?;
                    }
                    terminal @ (AuthStep::Complete | AuthStep::Failed | AuthStep::RejectUnexpected) => {
                        stop_child(&mut child);
                        return Ok(FakeAuthResult { terminal, transcript });
                    }
                }
            }
            Err(error) if error.raw_os_error() == Some(libc::EIO) => break,
            Err(error) => return Err(error).context("read fake auth PTY"),
        }
    }

    let status = child.wait().context("wait fake auth vendor")?;
    if !status.success() {
        bail!("fake auth vendor exited unsuccessfully");
    }
    Ok(FakeAuthResult {
        terminal: AuthStep::RejectUnexpected,
        transcript,
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
    fn pty_password_mfa_flow_is_qualified_without_echoing_secrets() {
        let vendor = fake_vendor(
            "#!/bin/sh\nprintf 'Password:'\nIFS= read -r password\nprintf 'Multi-factor authentication code:'\nIFS= read -r mfa\nprintf 'Login successful\\n'\n",
        );
        let result = run_fake_auth_dialog(&vendor, "fixture-password-never-log", "123456").unwrap();
        assert_eq!(result.terminal, AuthStep::Complete);
        assert!(!result.transcript.contains("fixture-password-never-log"));
        assert!(!result.transcript.contains("123456"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_unknown_prompt_fails_closed_without_hanging() {
        let vendor = fake_vendor("#!/bin/sh\nprintf 'Enter account recovery key:'\nsleep 30\n");
        let started = Instant::now();
        let result = run_fake_auth_dialog(&vendor, "fixture-password-never-log", "123456").unwrap();
        assert_eq!(result.terminal, AuthStep::RejectUnexpected);
        assert!(started.elapsed() < Duration::from_secs(5));
        assert!(!result.transcript.contains("fixture-password-never-log"));
        assert!(!result.transcript.contains("123456"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }

    #[test]
    fn pty_silent_vendor_is_bounded() {
        let vendor = fake_vendor("#!/bin/sh\nsleep 30\n");
        let started = Instant::now();
        let error = run_fake_auth_dialog(&vendor, "fixture-password-never-log", "123456").unwrap_err();
        assert!(started.elapsed() < Duration::from_secs(5));
        assert!(error.to_string().contains("deadline exceeded"));
        let _ = fs::remove_dir_all(vendor.parent().unwrap());
    }
}
