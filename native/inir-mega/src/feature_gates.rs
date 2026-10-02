//! Offline *policy* preview for the next read-mostly Cloud Storage phase.
//!
//! This is deliberately not an installed-version capability probe. It never
//! executes MEGAcmd, opens a socket, reads account data, or grants access.
//! Until explicit owner-approved installed-version disposable qualification,
//! every live operation stays denied, even when static executables are found.
use serde_json::{Value, json};

pub(crate) const DOMAINS: [&str; 10] = [
    "overview", "drive", "transfers", "sync", "backups",
    "sharing", "contacts", "mounts", "security", "preferences",
];

pub(crate) fn offline_policy_preview() -> Value {
    let domains: serde_json::Map<String, Value> = DOMAINS
        .iter()
        .map(|name| ((*name).to_owned(), json!({
            "read": false,
            "write": false,
            "reason": "installed_version_unqualified"
        })))
        .collect();
    json!({
        "adapter": "inir-mega",
        "probe_kind": "offline_policy_preview",
        "vendor_execution": "blocked_pending_disposable_qualification",
        "installed_version_qualified": false,
        "connection_attempted": false,
        "connected": false,
        "auth_qualified": false,
        "account_reads_enabled": false,
        "writes_enabled": false,
        "domains": domains
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn synthetic_sync_parse_evidence_never_unlocks_any_cloud_domain() {
        // A clean-looking capture is deliberately NOT trusted installed
        // evidence: neither parser success nor an argv candidate may
        // ever grant permissions, connections or authentication.
        use crate::column_fixtures::{
            CandidateCapture, CaptureError, Error as ParserError,
            RunState, Status, SyncSnapshotProfile, SyncSnapshotRow,
            parse_sync_snapshot_capture,
        };

        assert_eq!(
            SyncSnapshotProfile::args(),
            ["sync", "--output-cols=ID,RUN_STATE,STATUS", "--col-separator=|"]
        );
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
        let rejected = CandidateCapture {
            stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced",
            ..clean
        };
        assert_eq!(
            parse_sync_snapshot_capture(&rejected),
            Err(CaptureError::InvalidTable(ParserError::Incomplete))
        );

        // Inspect the ACTUAL production offline policy, not a mock, after
        // both accepted and rejected untrusted synthetic inputs.
        for _ in [true, false] {
            let preview = offline_policy_preview();
            assert_eq!(preview["probe_kind"], "offline_policy_preview");
            assert_eq!(
                preview["vendor_execution"],
                "blocked_pending_disposable_qualification"
            );
            for key in [
                "installed_version_qualified", "connection_attempted",
                "connected", "auth_qualified", "account_reads_enabled",
                "writes_enabled",
            ] {
                assert_eq!(preview[key], false, "{key}");
            }
            let domains = preview["domains"].as_object()
                .expect("explicit deny catalog must be present");
            assert_eq!(domains.len(), DOMAINS.len());
            for name in DOMAINS {
                let item = domains.get(name).expect("missing domain");
                assert_eq!(item["read"], false, "{name}");
                assert_eq!(item["write"], false, "{name}");
                assert_eq!(
                    item["reason"], "installed_version_unqualified", "{name}"
                );
            }
        }
    }

    #[test]
    fn all_ten_domains_explicitly_deny_unqualified_reads_and_writes() {
        let preview = offline_policy_preview();
        let domains = preview["domains"].as_object().unwrap();
        assert_eq!(domains.len(), DOMAINS.len());
        for name in DOMAINS {
            let domain = domains.get(name).expect("explicit locked domain");
            assert_eq!(domain["read"], false, "{name}");
            assert_eq!(domain["write"], false, "{name}");
            assert_eq!(domain["reason"], "installed_version_unqualified");
        }
        for field in ["installed_version_qualified", "connection_attempted",
            "connected", "auth_qualified", "account_reads_enabled", "writes_enabled"] {
            assert_eq!(preview[field], false, "{field}");
        }
        assert_eq!(preview["probe_kind"], "offline_policy_preview");
        assert_eq!(preview["vendor_execution"],
            "blocked_pending_disposable_qualification");
    }
}
