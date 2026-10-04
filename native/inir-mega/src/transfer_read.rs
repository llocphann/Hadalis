//! Fixed-argv, fake-qualified read-only Transfers integration.
//!
//! This module is deliberately NOT exposed through JSON/QML. It connects the
//! bounded process substrate to a finite TYPE|TAG|STATE parser using only local
//! fake executables until the installed MEGAcmd wrapper/output contract is
//! independently qualified.
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
    CandidateCapture, CaptureError, TransferSnapshot, TransferSnapshotProfile,
    parse_transfer_snapshot_capture,
};
#[cfg(unix)]
use crate::vendor_process::{
    EnvironmentPolicy, VendorCommand, run_bounded,
};

#[cfg(unix)]
const TRANSFER_READ_TIMEOUT: Duration = Duration::from_secs(5);
#[cfg(unix)]
const TRANSFER_STDOUT_CAP: usize = 16 * 1024;
#[cfg(unix)]
const TRANSFER_STDERR_CAP: usize = 4 * 1024;

#[cfg(unix)]
#[derive(Debug)]
pub enum TransferReadError {
    InvalidExecutable,
    Process(io::Error),
    Capture(CaptureError),
}

#[cfg(unix)]
impl PartialEq for TransferReadError {
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
impl Eq for TransferReadError {}

/// Candidate-only fixed Transfers read.
///
/// Program must already be an absolute independently selected mega-transfers
/// path. No PATH lookup, caller-supplied vendor argument, mutation operand,
/// retry, JSON/QML exposure or capability promotion occurs here.
#[cfg(unix)]
pub fn run_candidate_transfer_snapshot(
    program: &Path,
    environment: EnvironmentPolicy,
) -> Result<TransferSnapshot, TransferReadError> {
    if !program.is_absolute()
        || program.file_name().and_then(|name| name.to_str()) != Some("mega-transfers")
    {
        return Err(TransferReadError::InvalidExecutable);
    }

    let spec = VendorCommand {
        program: program.to_path_buf(),
        args: TransferSnapshotProfile::args()
            .into_iter()
            .map(OsString::from)
            .collect(),
        environment,
        timeout: TRANSFER_READ_TIMEOUT,
        stdout_cap: TRANSFER_STDOUT_CAP,
        stderr_cap: TRANSFER_STDERR_CAP,
    };

    let capture = run_bounded(&spec).map_err(TransferReadError::Process)?;
    let candidate = CandidateCapture {
        stdout: &capture.stdout,
        stderr: &capture.stderr,
        exit_code: capture.exit_code,
        timed_out: capture.timed_out,
        output_capped: capture.stdout_capped || capture.stderr_capped,
    };
    parse_transfer_snapshot_capture(&candidate).map_err(TransferReadError::Capture)
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use crate::column_fixtures::{
        Error, TransferContext, TransferDirection, TransferPause, TransferState,
    };
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
            "megaqml-transfer-read-{}-{serial}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let program = root.join("mega-transfers");
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
    fn fixed_read_runs_exact_wrapper_argv_and_parses_rows() {
        let fx = fixture(
            r#"
[ "$#" -eq 5 ] || exit 90
[ "$1" = "--show-completed" ] || exit 91
[ "$2" = "--show-syncs" ] || exit 92
[ "$3" = "--limit=128" ] || exit 93
[ "$4" = "--output-cols=TYPE,TAG,STATE" ] || exit 94
[ "$5" = "--col-separator=|" ] || exit 95
if IFS= read -r unexpected; then exit 96; fi
env | grep -q '^MEGACMD_DO_NOT_REDACT_LINES=' && exit 97 || :
env | grep -q '^PRIVATE_TEST_SECRET=' && exit 98 || :
printf '%s\n' 'TYPE|TAG|STATE' '⇓|7|ACTIVE' '⇑⇵|42|PAUSED'
"#,
        );
        let snapshot = run_candidate_transfer_snapshot(
            &fx.program,
            environment(&fx.root),
        )
        .unwrap();
        assert_eq!(snapshot.pause, TransferPause::None);
        assert_eq!(snapshot.rows.len(), 2);
        assert_eq!(snapshot.rows[0].direction, TransferDirection::Download);
        assert_eq!(snapshot.rows[0].context, TransferContext::Normal);
        assert_eq!(snapshot.rows[0].tag, 7);
        assert_eq!(snapshot.rows[0].state, TransferState::Active);
        assert_eq!(snapshot.rows[1].context, TransferContext::Sync);
    }

    #[test]
    fn blank_vendor_result_is_source_grounded_empty_candidate() {
        let fx = fixture("printf '\\n'");
        let snapshot = run_candidate_transfer_snapshot(
            &fx.program,
            environment(&fx.root),
        )
        .unwrap();
        assert_eq!(snapshot.pause, TransferPause::None);
        assert!(snapshot.rows.is_empty());
    }

    #[test]
    fn malformed_dirty_and_wrong_executable_fail_closed() {
        let malformed = fixture(
            "printf '%s\\n' 'TYPE|TAG|STATE' '⇓|7|UNKNOWN'",
        );
        assert_eq!(
            run_candidate_transfer_snapshot(
                &malformed.program,
                environment(&malformed.root),
            ),
            Err(TransferReadError::Capture(CaptureError::InvalidTable(
                Error::InvalidRow
            )))
        );

        let dirty = fixture(
            "printf '%s\\n' 'PRIVATE_FAKE_DIAGNOSTIC' >&2; printf '%s\\n' 'TYPE|TAG|STATE' '⇓|7|ACTIVE'",
        );
        assert_eq!(
            run_candidate_transfer_snapshot(
                &dirty.program,
                environment(&dirty.root),
            ),
            Err(TransferReadError::Capture(CaptureError::StandardErrorPresent))
        );

        let wrong = dirty.root.join("mega-sync");
        fs::copy(&dirty.program, &wrong).unwrap();
        let mut permissions = fs::metadata(&wrong).unwrap().permissions();
        permissions.set_mode(0o700);
        fs::set_permissions(&wrong, permissions).unwrap();
        assert_eq!(
            run_candidate_transfer_snapshot(&wrong, environment(&dirty.root)),
            Err(TransferReadError::InvalidExecutable)
        );
    }
}
