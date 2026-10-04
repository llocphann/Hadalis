//! Synthetic-only candidate parsers for single MEGAcmd output columns.
//! Never use parsed rows to unlock cloud capabilities or correlate
//! independently observed columns by row order.
#![allow(dead_code)]

use std::collections::HashSet;

const MAX_BYTES: usize = 16 * 1024;
const MAX_ROWS: usize = 1024;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Column {
    SyncId,
    SyncRunState,
    SyncStatus,
    TransferTag,
}

impl Column {
    fn header(self) -> &'static str {
        match self {
            Self::SyncId => "ID",
            Self::SyncRunState => "RUN_STATE",
            Self::SyncStatus => "STATUS",
            Self::TransferTag => "TAG",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RunState { Pending, Loading, Running, Suspended, Disabled }

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Status { None, Synced, Pending, Syncing, Processing }

#[derive(Debug, Eq, PartialEq)]
pub enum Value {
    SyncId(String),
    RunState(RunState),
    Status(Status),
    TransferTag(u32),
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Error {
    Incomplete,
    Oversized,
    InvalidEncoding,
    InvalidHeader,
    InvalidRow,
    EmptyRows,
    DuplicateIdentifier,
}

/// A complete, header-exact, scalar-only candidate parse.
/// Caller must pass complete=false after timeout, output cap or truncation.
/// These fixtures do not validate installed MEGAcmd behavior.
pub fn parse(column: Column, raw: &[u8], complete: bool) -> Result<Vec<Value>, Error> {
    if !complete { return Err(Error::Incomplete); }
    if raw.len() > MAX_BYTES { return Err(Error::Oversized); }
    let text = std::str::from_utf8(raw).map_err(|_| Error::InvalidEncoding)?;
    if text.is_empty() || !text.ends_with('\n') { return Err(Error::Incomplete); }
    if !text.is_ascii() || text.bytes().any(|b| {
        b == 0 || (b < 0x20 && b != b'\n' && b != b'\r') || b == 0x7f
    }) {
        return Err(Error::InvalidRow);
    }
    let mut lines = text.split_terminator('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line));
    if lines.next() != Some(column.header()) {
        return Err(Error::InvalidHeader);
    }
    let mut values = Vec::new();
    let mut identifiers = HashSet::new();
    for row in lines {
        if values.len() >= MAX_ROWS { return Err(Error::Oversized); }
        if row.is_empty() || row != row.trim() || row.contains('\r') {
            return Err(Error::InvalidRow);
        }
        let value = match column {
            Column::SyncId => {
                // Conservative unqualified candidate for sync backup IDs.
                if !(8..=16).contains(&row.len()) || !row.bytes().all(|b| {
                    b.is_ascii_alphanumeric() || b == b'-' || b == b'_'
                }) {
                    return Err(Error::InvalidRow);
                }
                if !identifiers.insert(row.to_owned()) {
                    return Err(Error::DuplicateIdentifier);
                }
                Value::SyncId(row.to_owned())
            }
            Column::SyncRunState => Value::RunState(match row {
                "Pending" => RunState::Pending,
                "Loading" => RunState::Loading,
                "Running" => RunState::Running,
                "Suspended" => RunState::Suspended,
                "Disabled" => RunState::Disabled,
                _ => return Err(Error::InvalidRow),
            }),
            Column::SyncStatus => Value::Status(match row {
                "NONE" => Status::None,
                "Synced" => Status::Synced,
                "Pending" => Status::Pending,
                "Syncing" => Status::Syncing,
                "Processing" => Status::Processing,
                _ => return Err(Error::InvalidRow),
            }),
            Column::TransferTag => {
                if row.starts_with('0') || !row.bytes().all(|b| b.is_ascii_digit()) {
                    return Err(Error::InvalidRow);
                }
                let tag: u32 = row.parse().map_err(|_| Error::InvalidRow)?;
                if tag == 0 || tag > i32::MAX as u32 {
                    return Err(Error::InvalidRow);
                }
                if !identifiers.insert(row.to_owned()) {
                    return Err(Error::DuplicateIdentifier);
                }
                Value::TransferTag(tag)
            }
        };
        values.push(value);
    }
    // A header-only response cannot prove the account/list is empty.
    if values.is_empty() { return Err(Error::EmptyRows); }
    Ok(values)
}


/// Strict, **synthetic** one-invocation sync pair candidate.
/// Never combine independently requested ID/state columns by row index.
/// Not authorized to dispatch commands or enable any sync feature.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum PairedSyncColumn { RunState, Status }

#[derive(Debug, Eq, PartialEq)]
pub enum PairedSyncState { RunState(RunState), Status(Status) }

#[derive(Debug, Eq, PartialEq)]
pub struct SyncPair {
    pub id: String,
    pub state: PairedSyncState,
}

/// Parse only ID|RUN_STATE or ID|STATUS from ONE already bounded response.
///
/// The "|" delimiter is excluded from BOTH scalar grammars, making these
/// two finite columns unambiguous for candidate fixtures. The installed
/// package has not yet been qualified for exact column behavior. A complete
/// flag is caller-provided and MUST be false after timeout/output truncation.
pub fn parse_sync_pair(
    column: PairedSyncColumn,
    raw: &[u8],
    complete: bool,
) -> Result<Vec<SyncPair>, Error> {
    if !complete { return Err(Error::Incomplete); }
    if raw.len() > MAX_BYTES { return Err(Error::Oversized); }
    let text = std::str::from_utf8(raw).map_err(|_| Error::InvalidEncoding)?;
    if text.is_empty() || !text.ends_with('\n') { return Err(Error::Incomplete); }
    if !text.is_ascii() || text.bytes().any(|b| {
        b == 0 || (b < 0x20 && b != b'\n' && b != b'\r') || b == 0x7f
    }) {
        return Err(Error::InvalidRow);
    }

    let (state_header, state_col) = match column {
        PairedSyncColumn::RunState => ("RUN_STATE", Column::SyncRunState),
        PairedSyncColumn::Status => ("STATUS", Column::SyncStatus),
    };
    let expected_header = format!("ID|{state_header}");
    let mut lines = text.split_terminator('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line));
    if lines.next() != Some(expected_header.as_str()) {
        return Err(Error::InvalidHeader);
    }

    // Split one immutable captured output, then reuse the SAME strict
    // single-column validators for ID uniqueness and finite enum syntax.
    let mut ids = String::from("ID\n");
    let mut states = format!("{state_header}\n");
    let mut count = 0usize;
    for row in lines {
        if count >= MAX_ROWS { return Err(Error::Oversized); }
        if row.is_empty() || row != row.trim() || row.contains('\r') {
            return Err(Error::InvalidRow);
        }
        let Some((id, state)) = row.split_once('|') else {
            return Err(Error::InvalidRow);
        };
        if id.is_empty() || state.is_empty() || state.contains('|') {
            return Err(Error::InvalidRow);
        }
        ids.push_str(id);
        ids.push('\n');
        states.push_str(state);
        states.push('\n');
        count += 1;
    }
    if count == 0 { return Err(Error::EmptyRows); }

    let parsed_ids = parse(Column::SyncId, ids.as_bytes(), true)?;
    let parsed_states = parse(state_col, states.as_bytes(), true)?;
    if parsed_ids.len() != count || parsed_states.len() != count {
        return Err(Error::InvalidRow);
    }

    parsed_ids.into_iter().zip(parsed_states).map(|(id, state)| {
        let Value::SyncId(id) = id else {
            return Err(Error::InvalidRow);
        };
        let state = match state {
            Value::RunState(s) if column == PairedSyncColumn::RunState => {
                PairedSyncState::RunState(s)
            }
            Value::Status(s) if column == PairedSyncColumn::Status => {
                PairedSyncState::Status(s)
            }
            _ => return Err(Error::InvalidRow),
        };
        Ok(SyncPair { id, state })
    }).collect()
}


/// Strict *candidate* argv allowlist for the scriptable `mega-sync` client.
/// The wrapper inserts `sync`; callers must not duplicate that command token.
/// These fixed constants are NOT executable dispatch rights, a vetted
/// executable path, session proof or authorization.
/// No user-controlled path, column expression, delimiter or mutation operand.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SyncReadProfile { RunState, Status }

impl SyncReadProfile {
    pub fn args(self) -> [&'static str; 2] {
        match self {
            Self::RunState =>
                ["--output-cols=ID,RUN_STATE", "--col-separator=|"],
            Self::Status =>
                ["--output-cols=ID,STATUS", "--col-separator=|"],
        }
    }

    fn paired_column(self) -> PairedSyncColumn {
        match self {
            Self::RunState => PairedSyncColumn::RunState,
            Self::Status => PairedSyncColumn::Status,
        }
    }
}

/// Candidate capture metadata supplied by a future separately qualified
/// fixed-argv vendor runner. A caller can forge this struct; these fields
/// alone cannot authenticate the executor or an MEGA account/session.
pub struct CandidateCapture<'a> {
    pub stdout: &'a [u8],
    pub stderr: &'a [u8],
    pub exit_code: Option<i32>,
    pub timed_out: bool,
    pub output_capped: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CaptureError {
    TimedOut,
    OutputCapped,
    AbnormalExit,
    StandardErrorPresent,
    InvalidTable(Error),
}

/// Shared fail-closed process-result gate for candidate parser fixtures.
/// Metadata is NOT executable, session, provenance or endpoint attestation.
fn check_clean_capture(capture: &CandidateCapture<'_>) -> Result<(), CaptureError> {
    if capture.timed_out { return Err(CaptureError::TimedOut); }
    if capture.output_capped { return Err(CaptureError::OutputCapped); }
    if capture.exit_code != Some(0) { return Err(CaptureError::AbnormalExit); }
    if !capture.stderr.is_empty() { return Err(CaptureError::StandardErrorPresent); }
    Ok(())
}

/// Reject failed/uncertain captures before interpreting even a valid prefix.
pub fn parse_sync_capture(
    profile: SyncReadProfile,
    capture: &CandidateCapture<'_>,
) -> Result<Vec<SyncPair>, CaptureError> {
    check_clean_capture(capture)?;
    parse_sync_pair(profile.paired_column(), capture.stdout, true)
        .map_err(CaptureError::InvalidTable)
}

/// A narrowly scoped synthetic three-column row from one bounded capture.
/// Still not an authenticated sync or an atomic vendor snapshot.
#[derive(Debug, Eq, PartialEq)]
pub struct SyncSnapshotRow {
    pub id: String,
    pub run_state: RunState,
    pub status: Status,
}

/// Fixed argv for the scriptable `mega-sync` client. The wrapper itself
/// inserts the `sync` command before forwarding these arguments to `mega-exec`.
/// A future separately qualified runner must still attest its executable,
/// environment, server, session and capture lifecycle.
pub struct SyncSnapshotProfile;

impl SyncSnapshotProfile {
    pub fn args() -> [&'static str; 2] {
        ["--output-cols=ID,RUN_STATE,STATUS", "--col-separator=|"]
    }
}

/// Parse exactly ID|RUN_STATE|STATUS rows from ONE complete byte stream.
/// No path, filename, error or other arbitrary text column is supported.
pub fn parse_sync_snapshot(
    raw: &[u8],
    complete: bool,
) -> Result<Vec<SyncSnapshotRow>, Error> {
    if !complete { return Err(Error::Incomplete); }
    if raw.len() > MAX_BYTES { return Err(Error::Oversized); }
    let text = std::str::from_utf8(raw).map_err(|_| Error::InvalidEncoding)?;
    if text.is_empty() || !text.ends_with('\n') { return Err(Error::Incomplete); }
    if !text.is_ascii() || text.bytes().any(|b| {
        b == 0 || (b < 0x20 && b != b'\n' && b != b'\r') || b == 0x7f
    }) {
        return Err(Error::InvalidRow);
    }

    let mut lines = text.split_terminator('\n')
        .map(|line| line.strip_suffix('\r').unwrap_or(line));
    if lines.next() != Some("ID|RUN_STATE|STATUS") {
        return Err(Error::InvalidHeader);
    }

    // Validate all three columns via the same strict scalar parsers.
    // Derive all columns from the SAME captured row, not separate calls.
    let mut ids = String::from("ID\n");
    let mut runs = String::from("RUN_STATE\n");
    let mut statuses = String::from("STATUS\n");
    let mut count = 0usize;
    for row in lines {
        if count >= MAX_ROWS { return Err(Error::Oversized); }
        if row.is_empty() || row != row.trim() || row.contains('\r') {
            return Err(Error::InvalidRow);
        }
        let mut fields = row.split('|');
        let (Some(id), Some(run), Some(status), None) =
            (fields.next(), fields.next(), fields.next(), fields.next()) else {
                return Err(Error::InvalidRow);
            };
        if id.is_empty() || run.is_empty() || status.is_empty() {
            return Err(Error::InvalidRow);
        }
        ids.push_str(id);
        ids.push('\n');
        runs.push_str(run);
        runs.push('\n');
        statuses.push_str(status);
        statuses.push('\n');
        count += 1;
    }
    if count == 0 { return Err(Error::EmptyRows); }

    let parsed_ids = parse(Column::SyncId, ids.as_bytes(), true)?;
    let parsed_runs = parse(Column::SyncRunState, runs.as_bytes(), true)?;
    let parsed_statuses = parse(Column::SyncStatus, statuses.as_bytes(), true)?;
    if parsed_ids.len() != count || parsed_runs.len() != count
        || parsed_statuses.len() != count {
        return Err(Error::InvalidRow);
    }
    parsed_ids.into_iter().zip(parsed_runs).zip(parsed_statuses)
        .map(|((id, run), status)| {
            let (Value::SyncId(id), Value::RunState(run),
                 Value::Status(status)) = (id, run, status) else {
                return Err(Error::InvalidRow);
            };
            Ok(SyncSnapshotRow { id, run_state: run, status })
        }).collect()
}

/// A valid-looking string still requires independently proven provenance.
pub fn parse_sync_snapshot_capture(
    capture: &CandidateCapture<'_>,
) -> Result<Vec<SyncSnapshotRow>, CaptureError> {
    check_clean_capture(capture)?;
    parse_sync_snapshot(capture.stdout, true).map_err(CaptureError::InvalidTable)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn triple_sync_snapshot_profile_and_finite_row_examples() {
        assert_eq!(
            SyncSnapshotProfile::args(),
            ["--output-cols=ID,RUN_STATE,STATUS", "--col-separator=|"]
        );
        let raw = b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\nZyxWvu98_-p|Suspended|Pending\n";
        assert_eq!(
            parse_sync_snapshot(raw, true),
            Ok(vec![
                SyncSnapshotRow {
                    id: "AbcDef12_-x".into(),
                    run_state: RunState::Running,
                    status: Status::Synced,
                },
                SyncSnapshotRow {
                    id: "ZyxWvu98_-p".into(),
                    run_state: RunState::Suspended,
                    status: Status::Pending,
                },
            ])
        );
        assert_eq!(
            parse_sync_snapshot(
                b"ID|RUN_STATE|STATUS\r\nAbcDef12_-x|Loading|Processing\r\n",
                true
            ),
            Ok(vec![SyncSnapshotRow {
                id: "AbcDef12_-x".into(),
                run_state: RunState::Loading,
                status: Status::Processing,
            }])
        );
    }

    #[test]
    fn triple_sync_snapshot_rejects_ambiguous_or_truncated_data() {
        let cases: &[(&[u8], Error)] = &[
            (b"", Error::Incomplete),
            (b"ID|RUN_STATE|STATUS\n", Error::EmptyRows),
            (b"ID|RUN_STATE\nAbcDef12_-x|Running\n", Error::InvalidHeader),
            (b"STATUS|RUN_STATE|ID\nSynced|Running|AbcDef12_-x\n", Error::InvalidHeader),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced", Error::Incomplete),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced|extra\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|UNKNOWN\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|UNKNOWN|Synced\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nPRIVATE/SECRET|Running|Synced\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\nAbcDef12_-x|Loading|Pending\n", Error::DuplicateIdentifier),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\rEXTRA\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\x1b[2J\n", Error::InvalidRow),
            (b"ID|RUN_STATE|STATUS\n\xff|Running|Synced\n", Error::InvalidEncoding),
        ];
        for (raw, expected) in cases {
            assert_eq!(
                parse_sync_snapshot(raw, true), Err(*expected),
                "invalid triple fixture should fail closed"
            );
        }
        let valid = b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\nZyxWvu98_-p|Suspended|Pending\n";
        // Every sliced prefix fails when the future capture supervisor
        // reports incomplete, including prefixes ending at row boundaries.
        for cut in 0..=valid.len() {
            assert_eq!(
                parse_sync_snapshot(&valid[..cut], false),
                Err(Error::Incomplete)
            );
        }
        assert_eq!(
            parse_sync_snapshot(&vec![b'x'; MAX_BYTES + 1], true),
            Err(Error::Oversized)
        );
        let large = format!(
            "ID|RUN_STATE|STATUS\n{}",
            (1..=(MAX_ROWS + 1))
                .map(|n| format!("Abc{n:08}|Running|Synced\n"))
                .collect::<String>()
        );
        assert_eq!(
            parse_sync_snapshot(large.as_bytes(), true),
            Err(Error::Oversized)
        );
    }

    #[test]
    fn triple_capture_rejects_uncertain_or_dirty_process_results() {
        let clean = CandidateCapture {
            stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n",
            stderr: b"",
            exit_code: Some(0),
            timed_out: false,
            output_capped: false,
        };
        assert_eq!(
            parse_sync_snapshot_capture(&clean),
            Ok(vec![SyncSnapshotRow {
                id: "AbcDef12_-x".into(),
                run_state: RunState::Running,
                status: Status::Synced,
            }])
        );
        assert_eq!(
            parse_sync_snapshot_capture(&CandidateCapture {
                timed_out: true, ..clean
            }),
            Err(CaptureError::TimedOut)
        );
        assert_eq!(
            parse_sync_snapshot_capture(&CandidateCapture {
                output_capped: true, ..clean
            }),
            Err(CaptureError::OutputCapped)
        );
        for code in [None, Some(1), Some(-9)] {
            assert_eq!(
                parse_sync_snapshot_capture(&CandidateCapture {
                    exit_code: code, ..clean
                }),
                Err(CaptureError::AbnormalExit)
            );
        }
        assert_eq!(
            parse_sync_snapshot_capture(&CandidateCapture {
                stderr: b"PRIVATE_FAKE_DIAGNOSTIC",
                ..clean
            }),
            Err(CaptureError::StandardErrorPresent)
        );
        assert_eq!(
            parse_sync_snapshot_capture(&CandidateCapture {
                stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::Incomplete))
        );
        assert_eq!(
            parse_sync_snapshot_capture(&CandidateCapture {
                stdout: b"ID|RUN_STATE|STATUS\n",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::EmptyRows))
        );
    }

    #[test]
    fn fixed_profile_argv_never_accepts_mutation_or_variable_columns() {
        assert_eq!(
            SyncReadProfile::RunState.args(),
            ["--output-cols=ID,RUN_STATE", "--col-separator=|"]
        );
        assert_eq!(
            SyncReadProfile::Status.args(),
            ["--output-cols=ID,STATUS", "--col-separator=|"]
        );
        for profile in [SyncReadProfile::RunState, SyncReadProfile::Status] {
            let args = profile.args();
            assert_eq!(args.len(), 2);
            assert!(!args.iter().any(|arg| {
                arg.starts_with('-') && !arg.starts_with("--output-cols=")
                    && !arg.starts_with("--col-separator=")
            }));
            assert!(!args.iter().any(|arg| {
                arg.contains(' ') || arg.contains('\n') || arg.contains('\\')
            }));
        }
    }

    #[test]
    fn paired_capture_requires_clean_zero_exit_and_complete_exact_table() {
        let clean = CandidateCapture {
            stdout: b"ID|RUN_STATE\nAbcDef12_-x|Running\n",
            stderr: b"",
            exit_code: Some(0),
            timed_out: false,
            output_capped: false,
        };
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &clean),
            Ok(vec![SyncPair {
                id: "AbcDef12_-x".into(),
                state: PairedSyncState::RunState(RunState::Running),
            }])
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::Status, &CandidateCapture {
                stdout: b"ID|STATUS\nAbcDef12_-x|Synced\n",
                ..clean
            }),
            Ok(vec![SyncPair {
                id: "AbcDef12_-x".into(),
                state: PairedSyncState::Status(Status::Synced),
            }])
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                timed_out: true, ..clean
            }),
            Err(CaptureError::TimedOut)
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                output_capped: true, ..clean
            }),
            Err(CaptureError::OutputCapped)
        );
        for code in [None, Some(1), Some(-9)] {
            assert_eq!(
                parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                    exit_code: code, ..clean
                }),
                Err(CaptureError::AbnormalExit)
            );
        }
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                stderr: b"PRIVATE_FAKE_DIAGNOSTIC",
                ..clean
            }),
            Err(CaptureError::StandardErrorPresent)
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                stdout: b"ID|RUN_STATE\nAbcDef12_-x|Running",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::Incomplete))
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                stdout: b"ID|RUN_STATE\nAbcDef12_-x|Running\nAbcDef12_-x|Loading\n",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::DuplicateIdentifier))
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                stdout: b"ID|RUN_STATE\nPRIVATE/SECRET|Running\n",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::InvalidRow))
        );
        assert_eq!(
            parse_sync_capture(SyncReadProfile::RunState, &CandidateCapture {
                stdout: b"ID|RUN_STATE\n",
                ..clean
            }),
            Err(CaptureError::InvalidTable(Error::EmptyRows))
        );
    }

    #[test]
    fn accepts_same_capture_paired_sync_scalars_only() {
        assert_eq!(
            parse_sync_pair(
                PairedSyncColumn::RunState,
                b"ID|RUN_STATE\nAbcDef12_-x|Running\nZyxWvu98_-p|Suspended\n",
                true,
            ),
            Ok(vec![
                SyncPair {
                    id: "AbcDef12_-x".into(),
                    state: PairedSyncState::RunState(RunState::Running),
                },
                SyncPair {
                    id: "ZyxWvu98_-p".into(),
                    state: PairedSyncState::RunState(RunState::Suspended),
                },
            ])
        );
        assert_eq!(
            parse_sync_pair(
                PairedSyncColumn::Status,
                b"ID|STATUS\r\nAbcDef12_-x|Synced\r\n", true,
            ),
            Ok(vec![SyncPair {
                id: "AbcDef12_-x".into(),
                state: PairedSyncState::Status(Status::Synced),
            }])
        );
    }

    #[test]
    fn paired_sync_requires_one_exact_bounded_unambiguous_table() {
        let invalid: &[(PairedSyncColumn, &[u8], Error)] = &[
            (PairedSyncColumn::RunState, b"", Error::Incomplete),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\n", Error::EmptyRows),
            (PairedSyncColumn::RunState, b"RUN_STATE|ID\nRunning|AbcDef12_-x\n", Error::InvalidHeader),
            (PairedSyncColumn::RunState, b"ID,RUN_STATE\nAbcDef12_-x,Running\n", Error::InvalidHeader),
            (PairedSyncColumn::RunState, b"ID|STATUS\nAbcDef12_-x|Synced\n", Error::InvalidHeader),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|Running", Error::Incomplete),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|Running|EXTRA\n", Error::InvalidRow),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|UNKNOWN\n", Error::InvalidRow),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|Running\nAbcDef12_-x|Loading\n", Error::DuplicateIdentifier),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nPRIVATE/SECRET|Running\n", Error::InvalidRow),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|Running\nID|RUN_STATE\n", Error::InvalidRow),
            (PairedSyncColumn::RunState, b"ID|RUN_STATE\nAbcDef12_-x|Running\n\n", Error::InvalidRow),
            (PairedSyncColumn::RunState, b"ID\nAbcDef12_-x\nRUN_STATE\nRunning\n", Error::InvalidHeader),
            (PairedSyncColumn::Status, b"ID|STATUS\nAbcDef12_-x|Processing\nAbcDef12_-x|Synced\n", Error::DuplicateIdentifier),
            (PairedSyncColumn::Status, b"ID|STATUS\nAbcDef12_-x|invalid\n", Error::InvalidRow),
            (PairedSyncColumn::Status, b"ID|STATUS\nAbcDef12_-x|Synced\x1b[2J\n", Error::InvalidRow),
            (PairedSyncColumn::Status, b"ID|STATUS\n\xff|Synced\n", Error::InvalidEncoding),
        ];
        for (column, raw, error) in invalid {
            assert_eq!(
                parse_sync_pair(*column, raw, true), Err(*error),
                "unexpected paired-grammar acceptance for {column:?}"
            );
        }
        assert_eq!(
            parse_sync_pair(
                PairedSyncColumn::RunState,
                b"ID|RUN_STATE\nAbcDef12_-x|Running\n", false,
            ),
            Err(Error::Incomplete)
        );
        assert_eq!(
            parse_sync_pair(
                PairedSyncColumn::RunState,
                &vec![b'x'; MAX_BYTES + 1], true,
            ),
            Err(Error::Oversized)
        );
        // Strictly valid-looking injected rows cannot be identified as
        // forgeries by lexical grammar alone: provenance stays external.
    }

    #[test]
    fn accepts_only_bounded_synthetic_scalars() {
        assert_eq!(
            parse(Column::SyncId, b"ID\nAbcDef12_-x\n", true),
            Ok(vec![Value::SyncId("AbcDef12_-x".into())])
        );
        assert_eq!(
            parse(Column::SyncRunState,
                  b"RUN_STATE\nPending\nLoading\nRunning\nSuspended\nDisabled\n", true),
            Ok(vec![
                Value::RunState(RunState::Pending),
                Value::RunState(RunState::Loading),
                Value::RunState(RunState::Running),
                Value::RunState(RunState::Suspended),
                Value::RunState(RunState::Disabled),
            ])
        );
        assert_eq!(
            parse(Column::SyncStatus,
                  b"STATUS\nNONE\nSynced\nPending\nSyncing\nProcessing\n", true),
            Ok(vec![
                Value::Status(Status::None), Value::Status(Status::Synced),
                Value::Status(Status::Pending), Value::Status(Status::Syncing),
                Value::Status(Status::Processing),
            ])
        );
        assert_eq!(
            parse(Column::TransferTag, b"TAG\n123\n789\n", true),
            Ok(vec![Value::TransferTag(123), Value::TransferTag(789)])
        );
        assert_eq!(
            parse(Column::TransferTag, b"TAG\r\n7\r\n", true),
            Ok(vec![Value::TransferTag(7)])
        );
    }

    #[test]
    fn refuses_ambiguous_rows_and_incomplete_outputs() {
        let invalid: &[(Column, &[u8], Error)] = &[
            (Column::SyncId, b"ID\n", Error::EmptyRows),
            (Column::SyncId, b"", Error::Incomplete),
            (Column::SyncId, b"ID\nAbcDef12_-x", Error::Incomplete),
            (Column::SyncId, b"ID\nAbcDef12_-x\nID\n", Error::InvalidRow),
            (Column::SyncId, b"LOCALPATH\nAbcDef12_-x\n", Error::InvalidHeader),
            (Column::SyncId, b"ID,LOCALPATH\nAbcDef12_-x,/tmp\n", Error::InvalidHeader),
            (Column::SyncId, b"ID\nAbcDef12_-x\nAbcDef12_-x\n", Error::DuplicateIdentifier),
            (Column::SyncId, b"ID\nAbcDef12_-x|/tmp\n", Error::InvalidRow),
            (Column::SyncRunState, b"RUN_STATE\nRunning\nUNKNOWN\n", Error::InvalidRow),
            (Column::SyncStatus, b"STATUS\nNONE\nFake\n", Error::InvalidRow),
            (Column::TransferTag, b"TAG\n0\n", Error::InvalidRow),
            (Column::TransferTag, b"TAG\n01\n", Error::InvalidRow),
            (Column::TransferTag, b"TAG\n-1\n", Error::InvalidRow),
            (Column::TransferTag, b"TAG\n2147483648\n", Error::InvalidRow),
            (Column::TransferTag, b"TAG\n7\n7\n", Error::DuplicateIdentifier),
            // This slash cannot occur in the current candidate ID grammar.
            // A lexical parser cannot identify "secret" words as secrets.
            (Column::SyncId, b"ID\nAbcDef12_-x\nPRIVATE/SECRET\n", Error::InvalidRow),
            (Column::SyncId, b"ID\nAbcDef12_-x\x1b[2J\n", Error::InvalidRow),
            (Column::SyncId, b"ID\nAbcDef12_-x\rOops\n", Error::InvalidRow),
            (Column::SyncId, b"ID\n\xff\n", Error::InvalidEncoding),
        ];
        for (column, raw, expected) in invalid {
            assert_eq!(
                parse(*column, raw, true), Err(*expected),
                "unexpected acceptance for {column:?}"
            );
        }
        assert_eq!(
            parse(Column::SyncId, b"ID\nAbcDef12_-x\n", false),
            Err(Error::Incomplete)
        );
    }

    #[test]
    fn lexical_id_match_is_not_identity_or_privacy_proof() {
        // Deliberately valid-looking fake text is accepted *syntactically*.
        // The caller MUST verify it came from a complete, permitted
        // single-column vendor result. Never infer identity or safe sharing.
        assert_eq!(
            parse(Column::SyncId, b"ID\nPRIVATE_SECRET\n", true),
            Ok(vec![Value::SyncId("PRIVATE_SECRET".into())])
        );
    }

    #[test]
    fn caps_fail_closed_even_when_prefix_is_valid() {
        assert_eq!(
            parse(Column::SyncId, &vec![b'x'; MAX_BYTES + 1], true),
            Err(Error::Oversized)
        );
        let many = format!("TAG\n{}", "1\n".repeat(MAX_ROWS + 1));
        assert_eq!(
            parse(Column::TransferTag, many.as_bytes(), true),
            Err(Error::DuplicateIdentifier)
        );
        let many_unique = format!(
            "TAG\n{}",
            (1..=(MAX_ROWS + 1))
                .map(|n| format!("{n}\n")).collect::<String>()
        );
        assert_eq!(
            parse(Column::TransferTag, many_unique.as_bytes(), true),
            Err(Error::Oversized)
        );
    }
}
