//! Cross-process kernel lock substrate for future Cloud Storage mutations.
//!
//! The lock is not wired to any mutation operation yet.  It is deliberately
//! lower-level: callers must supply an already private per-user directory.
//! Reads never need this lock.  Future mutation code must hold the guard from
//! final preflight through durable journal update and reconciliation.
#![allow(dead_code)]

#[cfg(unix)]
use std::fs::{self, File, OpenOptions};
#[cfg(unix)]
use std::io;
#[cfg(unix)]
use std::os::fd::{AsRawFd, FromRawFd};
#[cfg(unix)]
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
#[cfg(unix)]
use std::path::{Path, PathBuf};

#[cfg(unix)]
const LOCK_NAME: &[u8] = b"mutation.lock\0";

#[cfg(unix)]
#[derive(Debug)]
pub enum LockError {
    UnsafeDirectory,
    UnsafeLockFile,
    Busy,
    Io(io::Error),
}

#[cfg(unix)]
impl PartialEq for LockError {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::UnsafeDirectory, Self::UnsafeDirectory)
            | (Self::UnsafeLockFile, Self::UnsafeLockFile)
            | (Self::Busy, Self::Busy) => true,
            (Self::Io(a), Self::Io(b)) => a.kind() == b.kind(),
            _ => false,
        }
    }
}
#[cfg(unix)]
impl Eq for LockError {}

#[cfg(unix)]
pub struct MutationLock {
    file: File,
    path: PathBuf,
}

#[cfg(unix)]
impl MutationLock {
    /// Try to acquire the one global Hadalis Cloud Storage mutation lock.
    ///
    /// The directory must already exist, be absolute, be a real directory
    /// owned by the effective UID, and not be group/other writable.  The lock
    /// file is opened relative to a trusted directory FD with O_NOFOLLOW and
    /// O_CLOEXEC, then validated before a non-blocking flock is attempted.
    pub fn try_acquire_at(private_dir: &Path) -> Result<Self, LockError> {
        if !private_dir.is_absolute() {
            return Err(LockError::UnsafeDirectory);
        }

        let link_meta = fs::symlink_metadata(private_dir).map_err(LockError::Io)?;
        if link_meta.file_type().is_symlink() || !link_meta.is_dir() {
            return Err(LockError::UnsafeDirectory);
        }

        let dir = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW)
            .open(private_dir)
            .map_err(LockError::Io)?;
        let dir_meta = dir.metadata().map_err(LockError::Io)?;
        if !dir_meta.is_dir()
            || dir_meta.uid() != unsafe { libc::geteuid() }
            || dir_meta.mode() & 0o022 != 0
        {
            return Err(LockError::UnsafeDirectory);
        }

        let fd = unsafe {
            libc::openat(
                dir.as_raw_fd(),
                LOCK_NAME.as_ptr().cast(),
                libc::O_RDWR | libc::O_CREAT | libc::O_CLOEXEC | libc::O_NOFOLLOW,
                0o600,
            )
        };
        if fd < 0 {
            return Err(LockError::Io(io::Error::last_os_error()));
        }
        let file = unsafe { File::from_raw_fd(fd) };
        let meta = file.metadata().map_err(LockError::Io)?;
        if !meta.is_file()
            || meta.uid() != unsafe { libc::geteuid() }
            || meta.mode() & 0o077 != 0
            || meta.nlink() != 1
        {
            return Err(LockError::UnsafeLockFile);
        }

        let rc = unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) };
        if rc != 0 {
            let error = io::Error::last_os_error();
            if matches!(error.raw_os_error(), Some(code) if code == libc::EWOULDBLOCK || code == libc::EAGAIN) {
                return Err(LockError::Busy);
            }
            return Err(LockError::Io(error));
        }

        Ok(Self {
            file,
            path: private_dir.join("mutation.lock"),
        })
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}

#[cfg(unix)]
impl Drop for MutationLock {
    fn drop(&mut self) {
        let _ = unsafe { libc::flock(self.file.as_raw_fd(), libc::LOCK_UN) };
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::os::unix::fs::{PermissionsExt, symlink};
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(1);

    struct Fixture {
        root: PathBuf,
    }

    impl Fixture {
        fn private() -> Self {
            let serial = NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed);
            let root = std::env::temp_dir().join(format!(
                "megaqml-mutation-lock-{}-{serial}",
                std::process::id()
            ));
            let _ = fs::remove_dir_all(&root);
            fs::create_dir_all(&root).unwrap();
            let mut permissions = fs::metadata(&root).unwrap().permissions();
            permissions.set_mode(0o700);
            fs::set_permissions(&root, permissions).unwrap();
            Self { root }
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn private_lock_is_nonblocking_close_on_exec_and_released_on_drop() {
        let fx = Fixture::private();
        let first = MutationLock::try_acquire_at(&fx.root).unwrap();
        assert_eq!(first.path(), fx.root.join("mutation.lock").as_path());

        let flags = unsafe { libc::fcntl(first.file.as_raw_fd(), libc::F_GETFD) };
        assert!(flags >= 0);
        assert_ne!(flags & libc::FD_CLOEXEC, 0);

        assert_eq!(
            MutationLock::try_acquire_at(&fx.root).unwrap_err(),
            LockError::Busy
        );
        drop(first);
        let second = MutationLock::try_acquire_at(&fx.root).unwrap();
        drop(second);
    }

    #[test]
    fn separate_process_cannot_take_lock_until_owner_releases_it() {
        let fx = Fixture::private();
        let guard = MutationLock::try_acquire_at(&fx.root).unwrap();

        let pid = unsafe { libc::fork() };
        assert!(pid >= 0);
        if pid == 0 {
            unsafe {
                libc::close(guard.file.as_raw_fd());
            }
            let code = match MutationLock::try_acquire_at(&fx.root) {
                Err(LockError::Busy) => 0,
                _ => 1,
            };
            unsafe { libc::_exit(code) };
        }

        let mut status = 0;
        assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
        assert!(libc::WIFEXITED(status));
        assert_eq!(libc::WEXITSTATUS(status), 0);

        drop(guard);
        MutationLock::try_acquire_at(&fx.root).unwrap();
    }

    #[test]
    fn unsafe_directory_and_lock_file_are_rejected() {
        let fx = Fixture::private();
        let mut permissions = fs::metadata(&fx.root).unwrap().permissions();
        permissions.set_mode(0o777);
        fs::set_permissions(&fx.root, permissions).unwrap();
        assert_eq!(
            MutationLock::try_acquire_at(&fx.root).unwrap_err(),
            LockError::UnsafeDirectory
        );

        permissions = fs::metadata(&fx.root).unwrap().permissions();
        permissions.set_mode(0o700);
        fs::set_permissions(&fx.root, permissions).unwrap();
        let lock_path = fx.root.join("mutation.lock");
        fs::write(&lock_path, b"").unwrap();
        let mut file_permissions = fs::metadata(&lock_path).unwrap().permissions();
        file_permissions.set_mode(0o666);
        fs::set_permissions(&lock_path, file_permissions).unwrap();
        assert_eq!(
            MutationLock::try_acquire_at(&fx.root).unwrap_err(),
            LockError::UnsafeLockFile
        );
    }

    #[test]
    fn symlink_lock_file_is_never_followed() {
        let fx = Fixture::private();
        let target = fx.root.join("target");
        fs::write(&target, b"do-not-lock-through-symlink").unwrap();
        symlink(&target, fx.root.join("mutation.lock")).unwrap();
        assert!(matches!(
            MutationLock::try_acquire_at(&fx.root),
            Err(LockError::Io(_))
        ));
    }
}
