//! Allowlisted diagnostic/redaction substrate.
//!
//! Diagnostics are safe by construction: there is no field for request JSON,
//! vendor stdout/stderr, paths, emails, credentials, public links, or arbitrary
//! human text. Opaque resource identifiers can only enter after one-way,
//! domain-separated hashing.
#![allow(dead_code)]

use serde::Serialize;
use sha2::{Digest, Sha256};

const DIAGNOSTIC_SCHEMA: u32 = 1;
const MAX_IDENTIFIER_HASHES: usize = 8;

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum OperationKey {
    Detect,
    ConnectPreflight,
    FeatureGatesPreview,
    SyncRead,
    TransfersRead,
    DiagnosticsPreview,
    DiagnosticsExport,
    ReconcilePending,
}

impl OperationKey {
    fn as_str(self) -> &'static str {
        match self {
            Self::Detect => "detect",
            Self::ConnectPreflight => "connect_preflight",
            Self::FeatureGatesPreview => "feature_gates_preview",
            Self::SyncRead => "sync_read",
            Self::TransfersRead => "transfers_read",
            Self::DiagnosticsPreview => "diagnostics_preview",
            Self::DiagnosticsExport => "diagnostics_export",
            Self::ReconcilePending => "reconcile_pending",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Stage {
    StaticProbe,
    Connect,
    Read,
    Validate,
    Review,
    Dispatch,
    Reconcile,
    Serialize,
}

impl Stage {
    fn as_str(self) -> &'static str {
        match self {
            Self::StaticProbe => "static_probe",
            Self::Connect => "connect",
            Self::Read => "read",
            Self::Validate => "validate",
            Self::Review => "review",
            Self::Dispatch => "dispatch",
            Self::Reconcile => "reconcile",
            Self::Serialize => "serialize",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ResultCode {
    Ok,
    DependencyMissing,
    AdapterProtocolMismatch,
    HelperSpawnFailed,
    ServerNotRunning,
    ServerUnresponsive,
    Offline,
    CommandTimedOut,
    OutputTooLarge,
    LoginRequired,
    AccountChanged,
    VendorVersionUnsupported,
    OperationUnsupported,
    AmbiguousVendorOutput,
    UnknownVendorState,
    StalePrecondition,
    ActionOutcomeUnknown,
    ActionFailedBeforeDispatch,
    AlreadyCompletedOrMissing,
    InternalFailure,
}

impl ResultCode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Ok => "OK",
            Self::DependencyMissing => "DEPENDENCY_MISSING",
            Self::AdapterProtocolMismatch => "ADAPTER_PROTOCOL_MISMATCH",
            Self::HelperSpawnFailed => "HELPER_SPAWN_FAILED",
            Self::ServerNotRunning => "SERVER_NOT_RUNNING",
            Self::ServerUnresponsive => "SERVER_UNRESPONSIVE",
            Self::Offline => "OFFLINE",
            Self::CommandTimedOut => "COMMAND_TIMED_OUT",
            Self::OutputTooLarge => "OUTPUT_TOO_LARGE",
            Self::LoginRequired => "LOGIN_REQUIRED",
            Self::AccountChanged => "ACCOUNT_CHANGED",
            Self::VendorVersionUnsupported => "VENDOR_VERSION_UNSUPPORTED",
            Self::OperationUnsupported => "OPERATION_UNSUPPORTED",
            Self::AmbiguousVendorOutput => "AMBIGUOUS_VENDOR_OUTPUT",
            Self::UnknownVendorState => "UNKNOWN_VENDOR_STATE",
            Self::StalePrecondition => "STALE_PRECONDITION",
            Self::ActionOutcomeUnknown => "ACTION_OUTCOME_UNKNOWN",
            Self::ActionFailedBeforeDispatch => "ACTION_FAILED_BEFORE_DISPATCH",
            Self::AlreadyCompletedOrMissing => "ALREADY_COMPLETED_OR_MISSING",
            Self::InternalFailure => "INTERNAL_FAILURE",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum IdentifierKind {
    SyncId,
    TransferTag,
    BackupId,
    NodeHandle,
    ActionId,
}

impl IdentifierKind {
    fn as_str(self) -> &'static str {
        match self {
            Self::SyncId => "sync_id",
            Self::TransferTag => "transfer_tag",
            Self::BackupId => "backup_id",
            Self::NodeHandle => "node_handle",
            Self::ActionId => "action_id",
        }
    }
}

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd, Serialize)]
pub struct HashedIdentifier {
    kind: IdentifierKind,
    sha256: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct SanitizedDiagnostic {
    schema: u32,
    request_id: String,
    operation: OperationKey,
    stage: Stage,
    result_code: ResultCode,
    elapsed_ms: u64,
    vendor_exit_code: Option<i32>,
    identifiers: Vec<HashedIdentifier>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DiagnosticError {
    InvalidRequestId,
    InvalidOpaqueIdentifier,
    TooManyIdentifiers,
}

fn safe_request_id(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 128
        && value.bytes().all(|b| {
            b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-')
        })
}

fn safe_opaque_identifier(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 192
        && value.is_ascii()
        && value.bytes().all(|b| {
            b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b':')
        })
}

fn hash_field(hasher: &mut Sha256, value: &[u8]) {
    hasher.update((value.len() as u64).to_le_bytes());
    hasher.update(value);
}

pub fn hash_identifier(
    kind: IdentifierKind,
    opaque_identifier: &str,
) -> Result<HashedIdentifier, DiagnosticError> {
    if !safe_opaque_identifier(opaque_identifier) {
        return Err(DiagnosticError::InvalidOpaqueIdentifier);
    }
    let mut hasher = Sha256::new();
    hash_field(&mut hasher, b"megaqml-diagnostic-identifier-v1");
    hash_field(&mut hasher, kind.as_str().as_bytes());
    hash_field(&mut hasher, opaque_identifier.as_bytes());
    Ok(HashedIdentifier {
        kind,
        sha256: format!("{:x}", hasher.finalize()),
    })
}

impl SanitizedDiagnostic {
    pub fn new(
        request_id: String,
        operation: OperationKey,
        stage: Stage,
        result_code: ResultCode,
        elapsed_ms: u64,
        vendor_exit_code: Option<i32>,
        mut identifiers: Vec<HashedIdentifier>,
    ) -> Result<Self, DiagnosticError> {
        if !safe_request_id(&request_id) {
            return Err(DiagnosticError::InvalidRequestId);
        }
        if identifiers.len() > MAX_IDENTIFIER_HASHES {
            return Err(DiagnosticError::TooManyIdentifiers);
        }
        identifiers.sort();
        identifiers.dedup();
        Ok(Self {
            schema: DIAGNOSTIC_SCHEMA,
            request_id,
            operation,
            stage,
            result_code,
            elapsed_ms,
            vendor_exit_code,
            identifiers,
        })
    }

    /// SHA-256 over a fixed-order typed representation, not arbitrary JSON
    /// object text. Preview/export can compare this value before copying data.
    pub fn payload_hash(&self) -> String {
        let mut hasher = Sha256::new();
        hash_field(&mut hasher, b"megaqml-diagnostic-payload-v1");
        hasher.update(self.schema.to_le_bytes());
        hash_field(&mut hasher, self.request_id.as_bytes());
        hash_field(&mut hasher, self.operation.as_str().as_bytes());
        hash_field(&mut hasher, self.stage.as_str().as_bytes());
        hash_field(&mut hasher, self.result_code.as_str().as_bytes());
        hasher.update(self.elapsed_ms.to_le_bytes());
        match self.vendor_exit_code {
            Some(code) => {
                hasher.update([1]);
                hasher.update(code.to_le_bytes());
            }
            None => hasher.update([0]),
        }
        hasher.update((self.identifiers.len() as u64).to_le_bytes());
        for item in &self.identifiers {
            hash_field(&mut hasher, item.kind.as_str().as_bytes());
            hash_field(&mut hasher, item.sha256.as_bytes());
        }
        format!("{:x}", hasher.finalize())
    }

    pub fn diagnostic_id(&self) -> String {
        let hash = self.payload_hash();
        format!("diag-{}", &hash[..24])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn structured_payload_contains_only_allowlisted_fields_and_hashed_ids() {
        let raw_id = "AbcDef12_-x";
        let item = hash_identifier(IdentifierKind::SyncId, raw_id).unwrap();
        let diagnostic = SanitizedDiagnostic::new(
            "cloud-sync-42".into(),
            OperationKey::SyncRead,
            Stage::Read,
            ResultCode::Ok,
            17,
            Some(0),
            vec![item],
        )
        .unwrap();

        let encoded = serde_json::to_string(&diagnostic).unwrap();
        assert!(encoded.contains("\"request_id\":\"cloud-sync-42\""));
        assert!(encoded.contains("\"operation\":\"sync_read\""));
        assert!(encoded.contains("\"stage\":\"read\""));
        assert!(encoded.contains("\"result_code\":\"OK\""));
        assert!(!encoded.contains(raw_id));
        for forbidden in [
            "stdout", "stderr", "password", "mfa", "email", "local_path",
            "remote_path", "public_link", "session",
        ] {
            assert!(!encoded.contains(forbidden), "{forbidden} field leaked");
        }
        assert_eq!(diagnostic.payload_hash().len(), 64);
        assert!(diagnostic.diagnostic_id().starts_with("diag-"));
    }

    #[test]
    fn sensitive_shaped_or_path_shaped_identifiers_are_rejected_before_hashing() {
        for value in [
            "person@example.invalid",
            "/home/private/path",
            "https://mega.invalid/#secret",
            "line1\nline2",
            "",
        ] {
            assert_eq!(
                hash_identifier(IdentifierKind::NodeHandle, value),
                Err(DiagnosticError::InvalidOpaqueIdentifier)
            );
        }
    }

    #[test]
    fn canonical_hash_is_order_independent_for_identifier_set() {
        let a = hash_identifier(IdentifierKind::SyncId, "SyncA").unwrap();
        let b = hash_identifier(IdentifierKind::TransferTag, "TagB").unwrap();
        let first = SanitizedDiagnostic::new(
            "req-1".into(),
            OperationKey::DiagnosticsPreview,
            Stage::Serialize,
            ResultCode::Ok,
            10,
            None,
            vec![a.clone(), b.clone()],
        )
        .unwrap();
        let second = SanitizedDiagnostic::new(
            "req-1".into(),
            OperationKey::DiagnosticsPreview,
            Stage::Serialize,
            ResultCode::Ok,
            10,
            None,
            vec![b, a],
        )
        .unwrap();
        assert_eq!(first, second);
        assert_eq!(first.payload_hash(), second.payload_hash());
        assert_eq!(first.diagnostic_id(), second.diagnostic_id());
    }

    #[test]
    fn payload_hash_changes_with_semantic_diagnostic_state() {
        let base = SanitizedDiagnostic::new(
            "req-1".into(),
            OperationKey::Detect,
            Stage::StaticProbe,
            ResultCode::DependencyMissing,
            5,
            None,
            vec![],
        )
        .unwrap();
        let changed = SanitizedDiagnostic::new(
            "req-1".into(),
            OperationKey::Detect,
            Stage::StaticProbe,
            ResultCode::Ok,
            5,
            None,
            vec![],
        )
        .unwrap();
        assert_ne!(base.payload_hash(), changed.payload_hash());
    }

    #[test]
    fn request_id_and_identifier_count_are_bounded() {
        assert_eq!(
            SanitizedDiagnostic::new(
                "bad\nrequest".into(),
                OperationKey::Detect,
                Stage::Validate,
                ResultCode::InternalFailure,
                0,
                None,
                vec![],
            ),
            Err(DiagnosticError::InvalidRequestId)
        );

        let one = hash_identifier(IdentifierKind::ActionId, "action-1").unwrap();
        assert_eq!(
            SanitizedDiagnostic::new(
                "req-2".into(),
                OperationKey::ReconcilePending,
                Stage::Reconcile,
                ResultCode::ActionOutcomeUnknown,
                100,
                None,
                vec![one; MAX_IDENTIFIER_HASHES + 1],
            ),
            Err(DiagnosticError::TooManyIdentifiers)
        );
    }
}
