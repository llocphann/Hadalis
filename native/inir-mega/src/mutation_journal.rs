//! Private durable no-replay journal substrate for future Cloud Storage writes.
//!
//! This module is intentionally not wired to vendor dispatch. It persists only
//! bounded opaque identifiers and hashes; no password, link key, vendor output,
//! full local path, or full remote path has a field in this schema.
#![allow(dead_code)]

#[cfg(unix)]
use std::ffi::CString;
#[cfg(unix)]
use std::fs::{self, File, OpenOptions};
#[cfg(unix)]
use std::io::{self, Read, Write};
#[cfg(unix)]
use std::os::fd::{AsRawFd, FromRawFd};
#[cfg(unix)]
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
#[cfg(unix)]
use std::path::{Path, PathBuf};
#[cfg(unix)]
use std::sync::atomic::{AtomicU64, Ordering};

#[cfg(unix)]
use serde::{Deserialize, Serialize};

#[cfg(unix)]
use crate::PROTOCOL_VERSION;

#[cfg(unix)]
const JOURNAL_SCHEMA: u32 = 1;
#[cfg(unix)]
const JOURNAL_NAME: &[u8] = b"mutations.json\0";
#[cfg(unix)]
const MAX_JOURNAL_BYTES: usize = 64 * 1024;
#[cfg(unix)]
static NEXT_TEMP: AtomicU64 = AtomicU64::new(1);

#[cfg(unix)]
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Phase {
    Prepared,
    DispatchStarted,
    Reconciling,
    Terminal,
}

#[cfg(unix)]
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct StableTarget {
    pub kind: String,
    pub id: String,
}

#[cfg(unix)]
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(deny_unknown_fields)]
pub struct JournalRecord {
    pub journal_schema: u32,
    pub protocol: u32,
    pub action_id: String,
    pub request_id: String,
    pub operation: String,
    pub started_at_unix_ms: u64,
    /// Opaque non-email session/account identity. Never a plain email hash.
    pub account_fingerprint: String,
    /// Backend/protocol/capability epoch represented as an opaque token.
    pub backend_epoch: String,
    pub target: Option<StableTarget>,
    pub phase: Phase,
    /// Lowercase SHA-256 of canonical expected postcondition metadata.
    pub expected_postcondition_hash: String,
    pub terminal_result_code: Option<String>,
}

#[cfg(unix)]
impl JournalRecord {
    pub fn new_prepared(
        action_id: String,
        request_id: String,
        operation: String,
        started_at_unix_ms: u64,
        account_fingerprint: String,
        backend_epoch: String,
        target: Option<StableTarget>,
        expected_postcondition_hash: String,
    ) -> Self {
        Self {
            journal_schema: JOURNAL_SCHEMA,
            protocol: PROTOCOL_VERSION,
            action_id,
            request_id,
            operation,
            started_at_unix_ms,
            account_fingerprint,
            backend_epoch,
            target,
            phase: Phase::Prepared,
            expected_postcondition_hash,
            terminal_result_code: None,
        }
    }

    pub fn validate(&self) -> Result<(), JournalError> {
        if self.journal_schema != JOURNAL_SCHEMA
            || self.protocol != PROTOCOL_VERSION
            || self.started_at_unix_ms == 0
            || !safe_token(&self.action_id, 128)
            || !safe_token(&self.request_id, 128)
            || !safe_operation(&self.operation)
            || !safe_token(&self.account_fingerprint, 192)
            || !safe_token(&self.backend_epoch, 192)
            || !is_sha256_hex(&self.expected_postcondition_hash)
        {
            return Err(JournalError::InvalidRecord);
        }

        if let Some(target) = &self.target {
            if !safe_kind(&target.kind) || !safe_token(&target.id, 192) {
                return Err(JournalError::InvalidRecord);
            }
        }

        match (&self.phase, &self.terminal_result_code) {
            (Phase::Terminal, Some(code)) if safe_result_code(code) => Ok(()),
            (Phase::Terminal, _) => Err(JournalError::InvalidRecord),
            (_, None) => Ok(()),
            (_, Some(_)) => Err(JournalError::InvalidRecord),
        }
    }

    pub fn with_phase(mut self, phase: Phase, terminal_result_code: Option<String>) -> Self {
        self.phase = phase;
        self.terminal_result_code = terminal_result_code;
        self
    }

    fn immutable_eq(&self, other: &Self) -> bool {
        self.journal_schema == other.journal_schema
            && self.protocol == other.protocol
            && self.action_id == other.action_id
            && self.request_id == other.request_id
            && self.operation == other.operation
            && self.started_at_unix_ms == other.started_at_unix_ms
            && self.account_fingerprint == other.account_fingerprint
            && self.backend_epoch == other.backend_epoch
            && self.target == other.target
            && self.expected_postcondition_hash == other.expected_postcondition_hash
    }
}

#[cfg(unix)]
fn safe_token(value: &str, max: usize) -> bool {
    !value.is_empty()
        && value.len() <= max
        && value.is_ascii()
        && value.bytes().all(|b| {
            b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b':')
        })
}

#[cfg(unix)]
fn safe_operation(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 96
        && value.bytes().all(|b| {
            b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'.' | b'_')
        })
}

#[cfg(unix)]
fn safe_kind(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 32
        && value.bytes().all(|b| {
            b.is_ascii_lowercase() || b.is_ascii_digit() || matches!(b, b'.' | b'_')
        })
}

#[cfg(unix)]
fn safe_result_code(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 96
        && value.bytes().all(|b| {
            b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'_'
        })
}

#[cfg(unix)]
fn is_sha256_hex(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

#[cfg(unix)]
#[derive(Debug)]
pub enum JournalError {
    UnsafeDirectory,
    UnsafeFile,
    Missing,
    Corrupt,
    InvalidRecord,
    InvalidTransition,
    Oversized,
    Io(io::Error),
}

#[cfg(unix)]
impl PartialEq for JournalError {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::UnsafeDirectory, Self::UnsafeDirectory)
            | (Self::UnsafeFile, Self::UnsafeFile)
            | (Self::Missing, Self::Missing)
            | (Self::Corrupt, Self::Corrupt)
            | (Self::InvalidRecord, Self::InvalidRecord)
            | (Self::InvalidTransition, Self::InvalidTransition)
            | (Self::Oversized, Self::Oversized) => true,
            (Self::Io(a), Self::Io(b)) => a.kind() == b.kind(),
            _ => false,
        }
    }
}
#[cfg(unix)]
impl Eq for JournalError {}

#[cfg(unix)]
#[derive(Debug)]
pub struct JournalStore {
    dir: File,
    path: PathBuf,
}

#[cfg(unix)]
impl JournalStore {
    pub fn open(private_dir: &Path) -> Result<Self, JournalError> {
        if !private_dir.is_absolute() {
            return Err(JournalError::UnsafeDirectory);
        }
        let link_meta = fs::symlink_metadata(private_dir).map_err(JournalError::Io)?;
        if link_meta.file_type().is_symlink() || !link_meta.is_dir() {
            return Err(JournalError::UnsafeDirectory);
        }
        let dir = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC | libc::O_NOFOLLOW)
            .open(private_dir)
            .map_err(JournalError::Io)?;
        let meta = dir.metadata().map_err(JournalError::Io)?;
        if !meta.is_dir()
            || meta.uid() != unsafe { libc::geteuid() }
            || meta.mode() & 0o077 != 0
        {
            return Err(JournalError::UnsafeDirectory);
        }
        Ok(Self {
            dir,
            path: private_dir.join("mutations.json"),
        })
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    pub fn read(&self) -> Result<Option<JournalRecord>, JournalError> {
        let fd = unsafe {
            libc::openat(
                self.dir.as_raw_fd(),
                JOURNAL_NAME.as_ptr().cast(),
                libc::O_RDONLY | libc::O_CLOEXEC | libc::O_NOFOLLOW,
            )
        };
        if fd < 0 {
            let error = io::Error::last_os_error();
            if error.raw_os_error() == Some(libc::ENOENT) {
                return Ok(None);
            }
            return Err(JournalError::Io(error));
        }

        let file = unsafe { File::from_raw_fd(fd) };
        validate_private_file(&file)?;
        let mut bytes = Vec::new();
        file.take((MAX_JOURNAL_BYTES + 1) as u64)
            .read_to_end(&mut bytes)
            .map_err(JournalError::Io)?;
        if bytes.len() > MAX_JOURNAL_BYTES {
            return Err(JournalError::Oversized);
        }
        let record: JournalRecord =
            serde_json::from_slice(&bytes).map_err(|_| JournalError::Corrupt)?;
        record.validate()?;
        Ok(Some(record))
    }

    /// Atomically persist a new valid phase. Existing nonterminal state may
    /// only move forward for the exact same action identity. Terminal records
    /// are immutable. No method here dispatches or retries a vendor action.
    pub fn write_next(&self, next: &JournalRecord) -> Result<(), JournalError> {
        next.validate()?;
        match self.read()? {
            None => {
                if !matches!(next.phase, Phase::Prepared | Phase::DispatchStarted) {
                    return Err(JournalError::InvalidTransition);
                }
            }
            Some(previous) => {
                if !previous.immutable_eq(next)
                    || !valid_phase_transition(previous.phase, next.phase)
                {
                    return Err(JournalError::InvalidTransition);
                }
            }
        }

        let bytes = serde_json::to_vec(next).map_err(|_| JournalError::InvalidRecord)?;
        if bytes.len() > MAX_JOURNAL_BYTES {
            return Err(JournalError::Oversized);
        }

        let (mut temp, temp_name) = self.create_temp()?;
        if let Err(error) = (|| -> Result<(), JournalError> {
            temp.write_all(&bytes).map_err(JournalError::Io)?;
            temp.write_all(b"\n").map_err(JournalError::Io)?;
            temp.sync_all().map_err(JournalError::Io)?;
            validate_private_file(&temp)?;
            Ok(())
        })() {
            self.unlink_temp(&temp_name);
            return Err(error);
        }
        drop(temp);

        let rename_rc = unsafe {
            libc::renameat(
                self.dir.as_raw_fd(),
                temp_name.as_ptr(),
                self.dir.as_raw_fd(),
                JOURNAL_NAME.as_ptr().cast(),
            )
        };
        if rename_rc != 0 {
            let error = io::Error::last_os_error();
            self.unlink_temp(&temp_name);
            return Err(JournalError::Io(error));
        }

        if unsafe { libc::fsync(self.dir.as_raw_fd()) } != 0 {
            return Err(JournalError::Io(io::Error::last_os_error()));
        }
        Ok(())
    }

    fn create_temp(&self) -> Result<(File, CString), JournalError> {
        for _ in 0..16 {
            let serial = NEXT_TEMP.fetch_add(1, Ordering::Relaxed);
            let name = CString::new(format!(
                ".mutations.json.tmp.{}.{}",
                std::process::id(),
                serial
            ))
            .map_err(|_| JournalError::InvalidRecord)?;
            let fd = unsafe {
                libc::openat(
                    self.dir.as_raw_fd(),
                    name.as_ptr(),
                    libc::O_WRONLY
                        | libc::O_CREAT
                        | libc::O_EXCL
                        | libc::O_CLOEXEC
                        | libc::O_NOFOLLOW,
                    0o600,
                )
            };
            if fd >= 0 {
                return Ok((unsafe { File::from_raw_fd(fd) }, name));
            }
            let error = io::Error::last_os_error();
            if error.raw_os_error() != Some(libc::EEXIST) {
                return Err(JournalError::Io(error));
            }
        }
        Err(JournalError::Io(io::Error::new(
            io::ErrorKind::AlreadyExists,
            "could not allocate private journal temp file",
        )))
    }

    fn unlink_temp(&self, name: &CString) {
        let _ = unsafe { libc::unlinkat(self.dir.as_raw_fd(), name.as_ptr(), 0) };
    }
}

#[cfg(unix)]
fn validate_private_file(file: &File) -> Result<(), JournalError> {
    let meta = file.metadata().map_err(JournalError::Io)?;
    if !meta.is_file()
        || meta.uid() != unsafe { libc::geteuid() }
        || meta.mode() & 0o077 != 0
        || meta.nlink() != 1
    {
        return Err(JournalError::UnsafeFile);
    }
    Ok(())
}

#[cfg(unix)]
fn valid_phase_transition(previous: Phase, next: Phase) -> bool {
    matches!(
        (previous, next),
        (Phase::Prepared, Phase::Prepared)
            | (Phase::Prepared, Phase::DispatchStarted)
            | (Phase::DispatchStarted, Phase::DispatchStarted)
            | (Phase::DispatchStarted, Phase::Reconciling)
            | (Phase::DispatchStarted, Phase::Terminal)
            | (Phase::Reconciling, Phase::Reconciling)
            | (Phase::Reconciling, Phase::Terminal)
            | (Phase::Terminal, Phase::Terminal)
    )
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::os::unix::fs::{PermissionsExt, symlink};

    struct Fixture {
        root: PathBuf,
    }

    impl Fixture {
        fn private() -> Self {
            let serial = NEXT_TEMP.fetch_add(1, Ordering::Relaxed);
            let root = std::env::temp_dir().join(format!(
                "megaqml-journal-{}-{serial}",
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

    fn prepared() -> JournalRecord {
        JournalRecord::new_prepared(
            "act-fake-001".into(),
            "req-fake-001".into(),
            "sync.pause".into(),
            1_800_000_000_000,
            "acct_epoch_fixture_01".into(),
            "backend_epoch_fixture_01".into(),
            Some(StableTarget {
                kind: "sync_id".into(),
                id: "AbcDef12_-x".into(),
            }),
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef".into(),
        )
    }

    #[test]
    fn durable_phase_sequence_roundtrips_private_file() {
        let fx = Fixture::private();
        let store = JournalStore::open(&fx.root).unwrap();
        assert!(store.read().unwrap().is_none());

        let prepared = prepared();
        store.write_next(&prepared).unwrap();
        assert_eq!(store.read().unwrap(), Some(prepared.clone()));

        let dispatch = prepared.clone().with_phase(Phase::DispatchStarted, None);
        store.write_next(&dispatch).unwrap();
        let reconciling = dispatch.clone().with_phase(Phase::Reconciling, None);
        store.write_next(&reconciling).unwrap();
        let terminal = reconciling
            .clone()
            .with_phase(Phase::Terminal, Some("ACTION_CONFIRMED".into()));
        store.write_next(&terminal).unwrap();
        assert_eq!(store.read().unwrap(), Some(terminal));

        let meta = fs::metadata(store.path()).unwrap();
        assert_eq!(meta.permissions().mode() & 0o077, 0);
        assert_eq!(meta.uid(), unsafe { libc::geteuid() });
    }

    #[test]
    fn transition_and_identity_changes_fail_closed() {
        let fx = Fixture::private();
        let store = JournalStore::open(&fx.root).unwrap();
        let prepared = prepared();
        store.write_next(&prepared).unwrap();

        let illegal = prepared.clone().with_phase(Phase::Reconciling, None);
        assert_eq!(store.write_next(&illegal), Err(JournalError::InvalidTransition));

        let mut changed = prepared.clone().with_phase(Phase::DispatchStarted, None);
        changed.target.as_mut().unwrap().id = "OtherSync99".into();
        assert_eq!(store.write_next(&changed), Err(JournalError::InvalidTransition));

        let terminal = prepared
            .clone()
            .with_phase(Phase::DispatchStarted, None)
            .with_phase(Phase::Terminal, Some("ACTION_CONFIRMED".into()));
        store.write_next(
            &prepared.clone().with_phase(Phase::DispatchStarted, None)
        ).unwrap();
        store.write_next(&terminal).unwrap();

        let rewrite = terminal
            .clone()
            .with_phase(Phase::Terminal, Some("ACTION_OUTCOME_UNKNOWN".into()));
        assert_eq!(store.write_next(&rewrite), Err(JournalError::InvalidTransition));
    }

    #[test]
    fn corrupt_or_unsafe_existing_journal_is_not_treated_as_empty() {
        let fx = Fixture::private();
        let path = fx.root.join("mutations.json");
        fs::write(&path, b"{not-json").unwrap();
        let mut permissions = fs::metadata(&path).unwrap().permissions();
        permissions.set_mode(0o600);
        fs::set_permissions(&path, permissions).unwrap();

        let store = JournalStore::open(&fx.root).unwrap();
        assert_eq!(store.read(), Err(JournalError::Corrupt));
        assert_eq!(store.write_next(&prepared()), Err(JournalError::Corrupt));

        fs::remove_file(&path).unwrap();
        let target = fx.root.join("target");
        fs::write(&target, b"{}").unwrap();
        symlink(&target, &path).unwrap();
        assert!(matches!(store.read(), Err(JournalError::Io(_))));
    }

    #[test]
    fn unsafe_directory_and_sensitive_shaped_fields_are_rejected() {
        let fx = Fixture::private();
        let mut record = prepared();
        record.account_fingerprint = "person@example.invalid".into();
        assert_eq!(record.validate(), Err(JournalError::InvalidRecord));
        record = prepared();
        record.target.as_mut().unwrap().id = "/home/private/path".into();
        assert_eq!(record.validate(), Err(JournalError::InvalidRecord));

        let mut permissions = fs::metadata(&fx.root).unwrap().permissions();
        permissions.set_mode(0o750);
        fs::set_permissions(&fx.root, permissions).unwrap();
        assert_eq!(
            JournalStore::open(&fx.root).unwrap_err(),
            JournalError::UnsafeDirectory
        );
    }

    #[test]
    fn terminal_result_is_required_only_for_terminal_phase() {
        let mut record = prepared();
        record.terminal_result_code = Some("ACTION_CONFIRMED".into());
        assert_eq!(record.validate(), Err(JournalError::InvalidRecord));

        record = prepared().with_phase(Phase::Terminal, None);
        assert_eq!(record.validate(), Err(JournalError::InvalidRecord));

        record = prepared()
            .with_phase(Phase::Terminal, Some("ACTION_OUTCOME_UNKNOWN".into()));
        assert_eq!(record.validate(), Ok(()));
    }
}
