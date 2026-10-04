//! Offline backend/capability identity substrate.
//!
//! This module performs no vendor execution and grants no capability. It
//! produces opaque epochs from validated local environment/install identity so
//! later Connect/read/mutation code can invalidate stale reviews when the
//! effective backend changes.
#![allow(dead_code)]

#[cfg(unix)]
use std::collections::BTreeSet;
#[cfg(unix)]
use std::ffi::OsStr;
#[cfg(unix)]
use std::fs;
#[cfg(unix)]
use std::io;
#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;
#[cfg(unix)]
use std::os::unix::fs::{MetadataExt, PermissionsExt};
#[cfg(unix)]
use std::path::{Path, PathBuf};

#[cfg(unix)]
use sha2::{Digest, Sha256};

#[cfg(unix)]
const STATIC_EPOCH_SCHEMA: &[u8] = b"megaqml-static-backend-v1";
#[cfg(unix)]
const CAPABILITY_EPOCH_SCHEMA: &[u8] = b"megaqml-capability-v1";
#[cfg(unix)]
const ALLOWED_BINARIES: &[&str] = &[
    "mega-cmd",
    "mega-cmd-server",
    "mega-exec",
    "mega-login",
    "mega-sync",
    "mega-transfers",
    "mega-whoami",
    "mega-version",
];

#[cfg(unix)]
#[derive(Clone, Copy, Debug)]
pub struct SelectedBinary<'a> {
    pub name: &'a str,
    pub path: &'a Path,
}

#[cfg(unix)]
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StaticBackendIdentity {
    /// Opaque SHA-256 over local environment/install identity only.
    pub static_epoch: String,
    /// Validated common vendor directory used to construct controlled PATH.
    pub vendor_dir: PathBuf,
    pub socket_identity_present: bool,
}

#[cfg(unix)]
#[derive(Debug)]
pub enum IdentityError {
    RootForbidden,
    HomeUnavailable,
    HomeUnsafe,
    SocketInvalid,
    BinaryMissing,
    BinaryInvalid,
    MixedInstallation,
    CapabilityInputInvalid,
    Io(io::Error),
}

#[cfg(unix)]
impl PartialEq for IdentityError {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::RootForbidden, Self::RootForbidden)
            | (Self::HomeUnavailable, Self::HomeUnavailable)
            | (Self::HomeUnsafe, Self::HomeUnsafe)
            | (Self::SocketInvalid, Self::SocketInvalid)
            | (Self::BinaryMissing, Self::BinaryMissing)
            | (Self::BinaryInvalid, Self::BinaryInvalid)
            | (Self::MixedInstallation, Self::MixedInstallation)
            | (Self::CapabilityInputInvalid, Self::CapabilityInputInvalid) => true,
            (Self::Io(a), Self::Io(b)) => a.kind() == b.kind(),
            _ => false,
        }
    }
}
#[cfg(unix)]
impl Eq for IdentityError {}

#[cfg(unix)]
fn hash_bytes(hasher: &mut Sha256, bytes: &[u8]) {
    hasher.update((bytes.len() as u64).to_le_bytes());
    hasher.update(bytes);
}

#[cfg(unix)]
fn hash_u64(hasher: &mut Sha256, value: u64) {
    hasher.update(value.to_le_bytes());
}

#[cfg(unix)]
fn hash_i64(hasher: &mut Sha256, value: i64) {
    hasher.update(value.to_le_bytes());
}

#[cfg(unix)]
fn finish_hex(hasher: Sha256) -> String {
    format!("{:x}", hasher.finalize())
}

#[cfg(unix)]
fn safe_socket(value: &OsStr) -> bool {
    let bytes = value.as_bytes();
    !bytes.is_empty()
        && bytes.len() <= 128
        && bytes.iter().all(|b| {
            b.is_ascii_alphanumeric() || matches!(*b, b'.' | b'_' | b'-')
        })
}

#[cfg(unix)]
fn safe_server_version(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value.is_ascii()
        && value.bytes().all(|b| {
            b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b'+')
        })
}

#[cfg(unix)]
fn is_sha256_hex(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Build a static, pre-Connect backend identity without executing MEGAcmd.
///
/// The selected files must be absolute, executable, canonicalizable regular
/// files from one directory. The interactive shell, server and scriptable
/// mega-exec dispatcher must all be present so wrapper commands cannot resolve
/// through an untracked or mixed-install executable. HOME is canonicalized and
/// must belong to the effective user.
#[cfg(unix)]
pub fn build_static_identity(
    effective_uid: u32,
    home: &Path,
    socket_name: Option<&OsStr>,
    selected: &[SelectedBinary<'_>],
) -> Result<StaticBackendIdentity, IdentityError> {
    if effective_uid == 0 {
        return Err(IdentityError::RootForbidden);
    }
    if !home.is_absolute() {
        return Err(IdentityError::HomeUnavailable);
    }
    let canonical_home = fs::canonicalize(home).map_err(|_| IdentityError::HomeUnavailable)?;
    let home_meta = fs::metadata(&canonical_home).map_err(IdentityError::Io)?;
    if !home_meta.is_dir()
        || home_meta.uid() != effective_uid
        || home_meta.permissions().mode() & 0o022 != 0
    {
        return Err(IdentityError::HomeUnsafe);
    }

    if let Some(socket) = socket_name {
        if !safe_socket(socket) {
            return Err(IdentityError::SocketInvalid);
        }
    }
    if selected.is_empty() {
        return Err(IdentityError::BinaryMissing);
    }

    let mut names = BTreeSet::new();
    let mut canonical = Vec::with_capacity(selected.len());
    let mut vendor_dir: Option<PathBuf> = None;
    for item in selected {
        if !ALLOWED_BINARIES.contains(&item.name)
            || !names.insert(item.name)
            || !item.path.is_absolute()
            || item.path.file_name() != Some(OsStr::new(item.name))
        {
            return Err(IdentityError::BinaryInvalid);
        }
        let path = fs::canonicalize(item.path).map_err(|_| IdentityError::BinaryInvalid)?;
        let meta = fs::metadata(&path).map_err(IdentityError::Io)?;
        if !meta.is_file() || meta.permissions().mode() & 0o111 == 0 {
            return Err(IdentityError::BinaryInvalid);
        }
        let parent = path.parent().ok_or(IdentityError::BinaryInvalid)?;
        match &vendor_dir {
            Some(existing) if existing != parent => return Err(IdentityError::MixedInstallation),
            None => vendor_dir = Some(parent.to_path_buf()),
            _ => {}
        }
        canonical.push((item.name, path, meta));
    }

    if !names.contains("mega-cmd")
        || !names.contains("mega-cmd-server")
        || !names.contains("mega-exec")
    {
        return Err(IdentityError::BinaryMissing);
    }
    canonical.sort_by(|a, b| a.0.cmp(b.0));

    let mut hasher = Sha256::new();
    hash_bytes(&mut hasher, STATIC_EPOCH_SCHEMA);
    hash_u64(&mut hasher, effective_uid as u64);
    hash_bytes(&mut hasher, canonical_home.as_os_str().as_bytes());
    match socket_name {
        Some(socket) => {
            hasher.update([1]);
            hash_bytes(&mut hasher, socket.as_bytes());
        }
        None => hasher.update([0]),
    }
    for (name, path, meta) in canonical {
        hash_bytes(&mut hasher, name.as_bytes());
        hash_bytes(&mut hasher, path.as_os_str().as_bytes());
        hash_u64(&mut hasher, meta.dev());
        hash_u64(&mut hasher, meta.ino());
        hash_u64(&mut hasher, meta.size());
        hash_i64(&mut hasher, meta.mtime());
        hash_i64(&mut hasher, meta.mtime_nsec());
    }

    Ok(StaticBackendIdentity {
        static_epoch: finish_hex(hasher),
        vendor_dir: vendor_dir.expect("nonempty validated binary selection"),
        socket_identity_present: socket_name.is_some(),
    })
}

/// Extend a validated static epoch with installed-version fixture evidence.
///
/// This still grants nothing: the caller must separately decide which exact
/// parser/operation a qualified fixture enables. The fixture digest is a
/// SHA-256 of sanitized qualification evidence, never raw account data.
#[cfg(unix)]
pub fn qualified_capability_epoch(
    static_epoch: &str,
    server_version: &str,
    fixture_digest: &str,
) -> Result<String, IdentityError> {
    if !is_sha256_hex(static_epoch)
        || !safe_server_version(server_version)
        || !is_sha256_hex(fixture_digest)
    {
        return Err(IdentityError::CapabilityInputInvalid);
    }
    let mut hasher = Sha256::new();
    hash_bytes(&mut hasher, CAPABILITY_EPOCH_SCHEMA);
    hash_bytes(&mut hasher, static_epoch.as_bytes());
    hash_bytes(&mut hasher, server_version.as_bytes());
    hash_bytes(&mut hasher, fixture_digest.as_bytes());
    Ok(finish_hex(hasher))
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(1);

    struct Fixture {
        root: PathBuf,
        home: PathBuf,
        bin: PathBuf,
        cmd: PathBuf,
        server: PathBuf,
        dispatcher: PathBuf,
        sync: PathBuf,
    }

    impl Fixture {
        fn new() -> Self {
            let serial = NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed);
            let root = std::env::temp_dir().join(format!(
                "megaqml-backend-identity-{}-{serial}",
                std::process::id()
            ));
            let _ = fs::remove_dir_all(&root);
            let home = root.join("home");
            let bin = root.join("vendor-bin");
            fs::create_dir_all(&home).unwrap();
            fs::create_dir_all(&bin).unwrap();
            let mut home_mode = fs::metadata(&home).unwrap().permissions();
            home_mode.set_mode(0o700);
            fs::set_permissions(&home, home_mode).unwrap();
            let cmd = bin.join("mega-cmd");
            let server = bin.join("mega-cmd-server");
            let dispatcher = bin.join("mega-exec");
            let sync = bin.join("mega-sync");
            for (name, path) in [
                ("mega-cmd", &cmd),
                ("mega-cmd-server", &server),
                ("mega-exec", &dispatcher),
                ("mega-sync", &sync),
            ] {
                fs::write(path, format!("#!/bin/sh\n# {name}\n")).unwrap();
                let mut mode = fs::metadata(path).unwrap().permissions();
                mode.set_mode(0o700);
                fs::set_permissions(path, mode).unwrap();
            }
            Self { root, home, bin, cmd, server, dispatcher, sync }
        }

        fn selection(&self) -> Vec<SelectedBinary<'_>> {
            vec![
                SelectedBinary { name: "mega-cmd", path: &self.cmd },
                SelectedBinary { name: "mega-cmd-server", path: &self.server },
                SelectedBinary { name: "mega-exec", path: &self.dispatcher },
                SelectedBinary { name: "mega-sync", path: &self.sync },
            ]
        }
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    #[test]
    fn static_epoch_is_stable_and_changes_with_socket_or_binary_identity() {
        let fx = Fixture::new();
        let uid = unsafe { libc::geteuid() };
        assert_ne!(uid, 0, "worker fake qualification must not run as root");

        let first = build_static_identity(uid, &fx.home, None, &fx.selection()).unwrap();
        let again = build_static_identity(uid, &fx.home, None, &fx.selection()).unwrap();
        assert_eq!(first, again);
        assert!(is_sha256_hex(&first.static_epoch));
        assert!(!first.static_epoch.contains(fx.home.to_string_lossy().as_ref()));

        let socketed = build_static_identity(
            uid,
            &fx.home,
            Some(OsStr::new("hadalis-qualified-socket")),
            &fx.selection(),
        )
        .unwrap();
        assert_ne!(socketed.static_epoch, first.static_epoch);
        assert!(socketed.socket_identity_present);

        fs::write(fx.bin.join("mega-exec"), b"#!/bin/sh\n# changed-dispatcher-fixture\n").unwrap();
        let mut mode = fs::metadata(fx.bin.join("mega-exec")).unwrap().permissions();
        mode.set_mode(0o700);
        fs::set_permissions(fx.bin.join("mega-exec"), mode).unwrap();
        let changed = build_static_identity(uid, &fx.home, None, &fx.selection()).unwrap();
        assert_ne!(changed.static_epoch, first.static_epoch);
    }

    #[test]
    fn root_unsafe_home_and_invalid_socket_fail_closed() {
        let fx = Fixture::new();
        let uid = unsafe { libc::geteuid() };
        assert_eq!(
            build_static_identity(0, &fx.home, None, &fx.selection()),
            Err(IdentityError::RootForbidden)
        );

        let mut mode = fs::metadata(&fx.home).unwrap().permissions();
        mode.set_mode(0o777);
        fs::set_permissions(&fx.home, mode).unwrap();
        assert_eq!(
            build_static_identity(uid, &fx.home, None, &fx.selection()),
            Err(IdentityError::HomeUnsafe)
        );
        mode = fs::metadata(&fx.home).unwrap().permissions();
        mode.set_mode(0o700);
        fs::set_permissions(&fx.home, mode).unwrap();

        assert_eq!(
            build_static_identity(
                uid,
                &fx.home,
                Some(OsStr::new("bad/socket")),
                &fx.selection()
            ),
            Err(IdentityError::SocketInvalid)
        );
    }

    #[test]
    fn mixed_installation_and_missing_core_dependencies_are_rejected() {
        let fx = Fixture::new();
        let uid = unsafe { libc::geteuid() };
        let other = fx.root.join("other-bin");
        fs::create_dir_all(&other).unwrap();
        let other_sync = other.join("mega-sync");
        fs::write(&other_sync, b"#!/bin/sh\n").unwrap();
        let mut mode = fs::metadata(&other_sync).unwrap().permissions();
        mode.set_mode(0o700);
        fs::set_permissions(&other_sync, mode).unwrap();

        let mixed = [
            SelectedBinary { name: "mega-cmd", path: &fx.cmd },
            SelectedBinary { name: "mega-cmd-server", path: &fx.server },
            SelectedBinary { name: "mega-exec", path: &fx.dispatcher },
            SelectedBinary { name: "mega-sync", path: &other_sync },
        ];
        assert_eq!(
            build_static_identity(uid, &fx.home, None, &mixed),
            Err(IdentityError::MixedInstallation)
        );

        let missing_server = [
            SelectedBinary { name: "mega-cmd", path: &fx.cmd },
            SelectedBinary { name: "mega-exec", path: &fx.dispatcher },
        ];
        assert_eq!(
            build_static_identity(uid, &fx.home, None, &missing_server),
            Err(IdentityError::BinaryMissing)
        );

        let missing_dispatcher = [
            SelectedBinary { name: "mega-cmd", path: &fx.cmd },
            SelectedBinary { name: "mega-cmd-server", path: &fx.server },
        ];
        assert_eq!(
            build_static_identity(uid, &fx.home, None, &missing_dispatcher),
            Err(IdentityError::BinaryMissing)
        );
    }

    #[test]
    fn capability_epoch_requires_qualified_hash_inputs_and_invalidates_on_change() {
        let static_epoch =
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        let fixture =
            "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";
        let first = qualified_capability_epoch(static_epoch, "2.6.0", fixture).unwrap();
        let second = qualified_capability_epoch(static_epoch, "2.6.1", fixture).unwrap();
        assert!(is_sha256_hex(&first));
        assert_ne!(first, second);
        assert_eq!(
            qualified_capability_epoch(static_epoch, "2.6.0 with spaces", fixture),
            Err(IdentityError::CapabilityInputInvalid)
        );
        assert_eq!(
            qualified_capability_epoch("not-a-hash", "2.6.0", fixture),
            Err(IdentityError::CapabilityInputInvalid)
        );
    }
}
