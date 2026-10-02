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

#[cfg(test)]
mod tests {
    use super::*;
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
            (Column::SyncId, b"ID\nAbcDef12_-x\nPRIVATE_SECRET\n", Error::InvalidRow),
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
