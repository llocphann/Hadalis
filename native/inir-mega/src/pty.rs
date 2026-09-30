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
use std::process::{Command, Stdio};

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

    loop {
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
                        let _ = child.wait();
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
