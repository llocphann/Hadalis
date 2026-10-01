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
    fn all_ten_domains_explicitly_deny_unqualified_reads_and_writes() {
        let preview = offline_policy_preview();
        let domains = preview["domains"].as_object().unwrap();
        assert_eq!(domains.len(), DOMAINS.len());
        for name in DOMAINS {
            assert_eq!(domains[name]["read"], false, "{name}");
            assert_eq!(domains[name]["write"], false, "{name}");
            assert_eq!(domains[name]["reason"], "installed_version_unqualified");
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
