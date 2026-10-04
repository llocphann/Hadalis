//! Fixed-argv, fake-qualified read-only Sync snapshot integration.
//!
//! This module deliberately has no QML/JSON operation and grants no live
//! vendor capability. It only connects the bounded process substrate to the
//! already strict scalar Sync parser so the combined boundary can be tested
//! with local fake executables before installed-version qualification.
#![allow(dead_code)]

#[cfg(unix)]
use std::ffi::OsString;
#[cfg(unix)]
use std::io;
#[cfg(unix)]
use std::path::Path;
#[cfg(unix)]
use std::time::Duration;

#[cfg(unix)]
use crate::column_fixtures::{
    CandidateCapture, CaptureError, SyncSnapshotProfile, SyncSnapshotRow,
    parse_sync_snapshot_capture,
};
#[cfg(unix)]
use crate::vendor_process::{
    EnvironmentPolicy, VendorCommand, run_bounded,
};

#[cfg(unix)]
const SYNC_READ_TIMEOUT: Duration = Duration::from_secs(5);
#[cfg(unix)]
const SYNC_STDOUT_CAP: usize = 16 * 1024;
#[cfg(unix)]
const SYNC_STDERR_CAP: usize = 4 * 1024;

#[cfg(unix)]
#[derive(Debug)]
pub enum SyncReadError {
    InvalidExecutable,
    Process(io::Error),
    Capture(CaptureError),
}

#[cfg(unix)]
impl PartialEq for SyncReadError {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::InvalidExecutable, Self::InvalidExecutable) => true,
            (Self::Process(a), Self::Process(b)) => a.kind() == b.kind(),
            (Self::Capture(a), Self::Capture(b)) => a == b,
            _ => false,
        }
    }
}
#[cfg(unix)]
impl Eq for SyncReadError {}

/// Candidate-only fixed Sync snapshot read.
///
/// The executable must already be an absolute, independently selected
/// `mega-sync` path. No path lookup, user-controlled vendor arguments,
/// mutation operand, QML exposure, retry or capability promotion occurs here.
#[cfg(unix)]
pub fn run_candidate_sync_snapshot(
    program: &Path,
    environment: EnvironmentPolicy,
) -> Result<Vec<SyncSnapshotRow>, SyncReadError> {
    if !program.is_absolute()
        || program.file_name().and_then(|name| name.to_str()) != Some("mega-sync")
    {
        return Err(SyncReadError::InvalidExecutable);
    }

    let spec = VendorCommand {
        program: program.to_path_buf(),
        args: SyncSnapshotProfile::args()
            .into_iter()
            .map(OsString::from)
            .collect(),
        environment,
        timeout: SYNC_READ_TIMEOUT,
        stdout_cap: SYNC_STDOUT_CAP,
        stderr_cap: SYNC_STDERR_CAP,
    };

    let capture = run_bounded(&spec).map_err(SyncReadError::Process)?;
    let candidate = CandidateCapture {
        stdout: &capture.stdout,
        stderr: &capture.stderr,
        exit_code: capture.exit_code,
        timed_out: capture.timed_out,
        output_capped: capture.stdout_capped || capture.stderr_capped,
    };
    parse_sync_snapshot_capture(&candidate).map_err(SyncReadError::Capture)
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use crate::column_fixtures::{Error, RunState, Status};
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    static NEXT_FIXTURE: AtomicU64 = AtomicU64::new(1);

    struct Fixture {
        root: PathBuf,
        program: PathBuf,
    }

    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.root);
        }
    }

    fn fixture(script_body: &str) -> Fixture {
        let serial = NEXT_FIXTURE.fetch_add(1, Ordering::Relaxed);
        let root = std::env::temp_dir().join(format!(
            "megaqml-sync-read-{}-{serial}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let program = root.join("mega-sync");
        fs::write(
            &program,
            format!("#!/bin/sh\nset -eu\n{script_body}\n"),
        )
        .unwrap();
        let mut permissions = fs::metadata(&program).unwrap().permissions();
        permissions.set_mode(0o700);
        fs::set_permissions(&program, permissions).unwrap();
        Fixture { root, program }
    }

    fn environment(vendor_dir: &Path) -> EnvironmentPolicy {
        EnvironmentPolicy::from_entries(
            [
                ("HOME", "/tmp/hadalis-megaqml-fake-home"),
                ("USER", "fixture-user"),
                ("LANG", "C.UTF-8"),
                ("PATH", "/usr/bin:/bin"),
                ("MEGACMD_DO_NOT_REDACT_LINES", "1"),
                ("PRIVATE_TEST_SECRET", "must-not-inherit"),
            ],
            vendor_dir,
            None,
        )
        .unwrap()
    }

    #[test]
    fn fixed_read_runs_exact_candidate_argv_with_null_stdin_and_parses_rows() {
        let fx = fixture(
            r#"
[ "$#" -eq 3 ] || exit 90
[ "$1" = "sync" ] || exit 91
[ "$2" = "--output-cols=ID,RUN_STATE,STATUS" ] || exit 92
[ "$3" = "--col-separator=|" ] || exit 93
if IFS= read -r unexpected; then exit 94; fi
[ -z "${MEGACMD_DO_NOT_REDACT_LINES+x}" ] || exit 95
[ -z "${PRIVATE_TEST_SECRET+x}" ] || exit 96
printf '%s\n' 'ID|RUN_STATE|STATUS' 'AbcDef12_-x|Running|Synced'
"#,
        );
        let rows = run_candidate_sync_snapshot(
            &fx.program,
            environment(&fx.root),
        )
        .unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].id, "AbcDef12_-x");
        assert_eq!(rows[0].run_state, RunState::Running);
        assert_eq!(rows[0].status, Status::Synced);
    }

    #[test]
    fn malformed_or_dirty_fake_vendor_output_fails_closed() {
        let malformed = fixture(
            "printf '%s\\n' 'ID|RUN_STATE|STATUS' 'AbcDef12_-x|Running|UNKNOWN'",
        );
        assert_eq!(
            run_candidate_sync_snapshot(
                &malformed.program,
                environment(&malformed.root),
            ),
            Err(SyncReadError::Capture(CaptureError::InvalidTable(
                Error::InvalidRow
            )))
        );

        let dirty = fixture(
            "printf '%s\\n' 'PRIVATE_FAKE_DIAGNOSTIC' >&2; printf '%s\\n' 'ID|RUN_STATE|STATUS' 'AbcDef12_-x|Running|Synced'",
        );
        assert_eq!(
            run_candidate_sync_snapshot(
                &dirty.program,
                environment(&dirty.root),
            ),
            Err(SyncReadError::Capture(CaptureError::StandardErrorPresent))
        );
    }

    #[test]
    fn header_only_and_wrong_executable_identity_are_rejected() {
        let empty = fixture("printf '%s\\n' 'ID|RUN_STATE|STATUS'");
        assert_eq!(
            run_candidate_sync_snapshot(
                &empty.program,
                environment(&empty.root),
            ),
            Err(SyncReadError::Capture(CaptureError::InvalidTable(
                Error::EmptyRows
            )))
        );

        let wrong = empty.root.join("mega-whoami");
        fs::copy(&empty.program, &wrong).unwrap();
        let mut permissions = fs::metadata(&wrong).unwrap().permissions();
        permissions.set_mode(0o700);
        fs::set_permissions(&wrong, permissions).unwrap();
        assert_eq!(
            run_candidate_sync_snapshot(&wrong, environment(&empty.root)),
            Err(SyncReadError::InvalidExecutable)
        );
    }
}
