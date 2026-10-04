use std::env;
use std::fs;
use std::io::{self, Read};
use std::path::Path;
use std::time::Duration;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

mod pty;
mod feature_gates;
mod column_fixtures;
mod snapshot_lifecycle;
mod vendor_process;
mod sync_read;
mod transfer_read;
mod transfer_snapshot_lifecycle;
mod mutation_lock;
mod mutation_journal;
mod backend_identity;
mod diagnostic_sanitizer;

const PROTOCOL_VERSION: u32 = 1;
// Upper bound for one typed stdin envelope, including escaped credential bytes.
const MAX_REQUEST_BYTES: usize = 16 * 1024;
const LIVE_AUTH_VENDOR_ENABLED: bool = false;
const AUTH_VENDOR_TIMEOUT_SECS: u64 = 30;
const AUTH_VENDOR_OUTPUT_CAP: usize = 32 * 1024;

#[derive(Debug, Parser)]
#[command(about = "Typed, one-shot MEGAcmd adapter for Hadalis")]
struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Read exactly one typed JSON request from stdin and emit one JSON envelope.
    Request,
}

// Reject unknown protocol keys instead of silently discarding unsupported
// credentials or capability overrides. Invalid JSON receives a fixed public
// error envelope; untrusted field names/values are never reflected.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Request {
    protocol: u32,
    request_id: String,
    operation: Operation,
    #[serde(default)]
    params: Value,
    #[serde(default)]
    secret: Option<SecretInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Operation {
    Detect,
    ConnectPreflight,
    FeatureGatesPreview,
    AuthBegin,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct SecretInput {
    #[serde(default)]
    password: Option<String>,
    #[serde(default)]
    mfa_code: Option<String>,
}

#[derive(Debug, Serialize)]
struct Response {
    protocol: u32,
    request_id: String,
    ok: bool,
    result: Value,
    error: Option<SafeError>,
}

#[derive(Debug, Serialize)]
struct VendorBinary {
    name: &'static str,
    path: Option<String>,
    executable: bool,
}

fn is_executable(path: &Path) -> bool {
    let Ok(metadata) = fs::metadata(path) else { return false; };
    if !metadata.is_file() { return false; }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        metadata.permissions().mode() & 0o111 != 0
    }
    #[cfg(not(unix))]
    {
        true
    }
}

fn find_in_path(name: &'static str, path_env: Option<&str>) -> VendorBinary {
    let found = path_env.and_then(|value| {
        env::split_paths(value)
            .map(|dir| dir.join(name))
            .find(|candidate| is_executable(candidate))
    });
    VendorBinary {
        name,
        executable: found.is_some(),
        path: found.and_then(|path| fs::canonicalize(path).ok()).map(|path| path.to_string_lossy().into_owned()),
    }
}

fn static_detection(path_env: Option<&str>) -> Vec<VendorBinary> {
    [
        "mega-cmd",
        "mega-cmd-server",
        "mega-exec",
        "mega-login",
        "mega-whoami",
        "mega-version",
    ]
    .into_iter()
    .map(|name| find_in_path(name, path_env))
    .collect()
}

#[derive(Debug, Serialize)]
struct SafeError {
    stage: &'static str,
    kind: &'static str,
    outcome: &'static str,
    user_message: &'static str,
}

#[derive(Debug, PartialEq, Eq)]
enum AuthPrompt {
    Password,
    Mfa,
    Complete,
    Failed,
    Unexpected,
}

fn classify_auth_prompt(text: &str) -> AuthPrompt {
    // Match complete finite prompts, not substrings inside diagnostics or
    // vendor-echoed secret text. New installed-version variants must be
    // individually qualified before enabling live authentication.
    let normalized = text.trim().to_ascii_lowercase();
    match normalized.as_str() {
        "password:" => AuthPrompt::Password,
        "multi-factor authentication code:"
        | "two-factor authentication code:"
        | "2fa code:"
        | "mfa code:" => AuthPrompt::Mfa,
        "logged in" | "login successful" => AuthPrompt::Complete,
        "login failed" | "incorrect password" => AuthPrompt::Failed,
        _ => AuthPrompt::Unexpected,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AuthState {
    AwaitPassword,
    AwaitMfaOrComplete,
    AwaitCompleteAfterMfa,
    Terminal,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SecretWrite {
    Password,
    Mfa,
}

#[derive(Debug, PartialEq, Eq)]
enum AuthStep {
    Write(SecretWrite),
    Complete,
    Failed,
    RejectUnexpected,
}

fn advance_auth(state: &mut AuthState, prompt: AuthPrompt) -> AuthStep {
    match (*state, prompt) {
        (AuthState::AwaitPassword, AuthPrompt::Password) => {
            *state = AuthState::AwaitMfaOrComplete;
            AuthStep::Write(SecretWrite::Password)
        }
        (AuthState::AwaitMfaOrComplete, AuthPrompt::Mfa) => {
            // A repeated MFA prompt must never resend a code.
            *state = AuthState::AwaitCompleteAfterMfa;
            AuthStep::Write(SecretWrite::Mfa)
        }
        (AuthState::AwaitMfaOrComplete | AuthState::AwaitCompleteAfterMfa, AuthPrompt::Complete) => {
            *state = AuthState::Terminal;
            AuthStep::Complete
        }
        (_, AuthPrompt::Failed) => {
            *state = AuthState::Terminal;
            AuthStep::Failed
        }
        _ => {
            *state = AuthState::Terminal;
            AuthStep::RejectUnexpected
        }
    }
}

fn is_safe_request_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 128
        && id.bytes().all(|byte| byte.is_ascii_alphanumeric()
            || matches!(byte, b'.' | b'_' | b'-'))
}

fn validate_request(request: &Request) -> Option<SafeError> {
    if request.protocol != PROTOCOL_VERSION {
        return Some(SafeError {
            stage: "validate",
            kind: "PROTOCOL_MISMATCH",
            outcome: "not_dispatched",
            user_message: "Cloud Storage backend protocol mismatch.",
        });
    }
    if !is_safe_request_id(&request.request_id) {
        return Some(SafeError {
            stage: "validate",
            kind: "INVALID_REQUEST_ID",
            outcome: "not_dispatched",
            user_message: "Invalid Cloud Storage request.",
        });
    }
    None
}

#[cfg(unix)]
fn disable_core_dumps() -> Result<()> {
    let limit = libc::rlimit {
        rlim_cur: 0,
        rlim_max: 0,
    };
    if unsafe { libc::setrlimit(libc::RLIMIT_CORE, &limit) } != 0 {
        return Err(std::io::Error::last_os_error()).context("disable inir-mega core dumps");
    }
    Ok(())
}

#[cfg(not(unix))]
fn disable_core_dumps() -> Result<()> {
    Ok(())
}

fn is_safe_login_email(value: &str) -> bool {
    if value.is_empty() || value.len() > 254 || !value.is_ascii() {
        return false;
    }
    let Some((local, domain)) = value.split_once('@') else {
        return false;
    };
    if local.is_empty() || domain.is_empty() || domain.contains('@') || !domain.contains('.') {
        return false;
    }
    let local_ok = local
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || b"._%+-".contains(&byte));
    let domain_ok = domain
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'.' || byte == b'-');
    local_ok && domain_ok
}

fn auth_error(
    request_id: String,
    stage: &'static str,
    kind: &'static str,
    outcome: &'static str,
    user_message: &'static str,
) -> Response {
    Response {
        protocol: PROTOCOL_VERSION,
        request_id,
        ok: false,
        result: json!({"state": "blocked"}),
        error: Some(SafeError {
            stage,
            kind,
            outcome,
            user_message,
        }),
    }
}

fn handle_auth(request: Request) -> Response {
    // Do not let unrelated or future-looking auth parameters pass unnoticed.
    // The only supported auth parameter is one string-valued email.
    if !matches!(&request.params, Value::Object(fields)
        if fields.len() == 1 && fields.get("email").is_some_and(Value::is_string)) {
        return auth_error(
            request.request_id,
            "validate", "AUTH_PARAMS_INVALID", "not_dispatched",
            "Invalid Cloud Storage sign-in request.",
        );
    }
    let Request {
        request_id,
        params,
        secret,
        ..
    } = request;
    let email = params.get("email").and_then(Value::as_str).unwrap_or("");
    let password = secret
        .as_ref()
        .and_then(|value| value.password.as_deref())
        .unwrap_or("");
    let mfa = secret
        .as_ref()
        .and_then(|value| value.mfa_code.as_deref())
        .filter(|value| !value.is_empty());

    if !is_safe_login_email(email) || password.is_empty() || password.len() > 4096 {
        return auth_error(
            request_id,
            "validate",
            "AUTH_INPUT_REQUIRED",
            "not_dispatched",
            "A valid email and password are required.",
        );
    }
    if mfa.is_some_and(|value| value.len() != 6 || !value.bytes().all(|byte| byte.is_ascii_digit())) {
        return auth_error(
            request_id,
            "validate",
            "MFA_INPUT_INVALID",
            "not_dispatched",
            "Enter a valid six-digit two-factor authentication code.",
        );
    }

    if !LIVE_AUTH_VENDOR_ENABLED {
        return auth_error(
            request_id,
            "dispatch",
            "AUTH_VENDOR_NOT_QUALIFIED",
            "not_dispatched",
            "MEGAcmd sign-in is staged but remains disabled until installed-version disposable qualification passes.",
        );
    }

    let shell = find_in_path("mega-cmd", env::var("PATH").ok().as_deref());
    let Some(program) = shell.path.as_deref() else {
        return auth_error(
            request_id,
            "detect",
            "MEGACMD_INTERACTIVE_SHELL_MISSING",
            "not_dispatched",
            "MEGAcmd interactive shell is not installed.",
        );
    };

    match pty::run_auth_dialog(
        Path::new(program),
        email,
        password,
        mfa,
        Duration::from_secs(AUTH_VENDOR_TIMEOUT_SECS),
        AUTH_VENDOR_OUTPUT_CAP,
    ) {
        Ok(result) => match result.outcome {
            pty::AuthDialogOutcome::Authenticated => Response {
                protocol: PROTOCOL_VERSION,
                request_id,
                ok: true,
                result: json!({"state": "vendor_reported_authenticated"}),
                error: None,
            },
            pty::AuthDialogOutcome::MfaRequired => Response {
                protocol: PROTOCOL_VERSION,
                request_id,
                ok: true,
                result: json!({"state": "mfa_required"}),
                error: None,
            },
            pty::AuthDialogOutcome::Failed => auth_error(
                request_id,
                "dispatch",
                "AUTH_REJECTED",
                "confirmed_failed",
                "MEGAcmd rejected the sign-in request.",
            ),
            pty::AuthDialogOutcome::Unexpected => auth_error(
                request_id,
                "dispatch",
                "AUTH_PROMPT_UNSUPPORTED",
                "unknown",
                "MEGAcmd requested an unsupported interactive response.",
            ),
        },
        Err(_) => auth_error(
            request_id,
            "dispatch",
            "AUTH_VENDOR_UNKNOWN",
            "unknown",
            "MEGAcmd sign-in did not finish with a recognized result.",
        ),
    }
}

// Explicit, non-vendor preflight: a separate typed opt-in operation. This
// does not initiate an MEGA session, spawn vendor binaries or imply login.
fn handle_connect_preflight(request: Request, path_env: Option<&str>) -> Response {
    if request.params != json!({}) || request.secret.is_some() {
        return auth_error(
            request.request_id,
            "validate",
            "PREFLIGHT_INPUT_FORBIDDEN",
            "not_dispatched",
            "Connection readiness accepts no account details or credentials.",
        );
    }
    let binaries = static_detection(path_env);
    let shell = binaries.iter().any(|item| item.name == "mega-cmd" && item.executable);
    let server = binaries.iter().any(|item| item.name == "mega-cmd-server" && item.executable);
    let dispatcher = binaries.iter().any(|item| item.name == "mega-exec" && item.executable);
    Response {
        protocol: PROTOCOL_VERSION,
        request_id: request.request_id,
        ok: true,
        result: json!({
            "adapter": "inir-mega",
            "probe_kind": "static_connect_preflight",
            "vendor_execution": "blocked_pending_disposable_qualification",
            "connection_attempted": false,
            "connected": false,
            "auth_qualified": false,
            "account_reads_enabled": false,
            "dependencies_ready": shell && server && dispatcher,
            "reason": if shell && server && dispatcher {
                "installed_vendor_not_qualified"
            } else {
                "dependency_missing"
            }
        }),
        error: None,
    }
}

// Pure offline policy only: a preview is not installed capability evidence.
// Reject every unexpected parameter or secret before producing a fixed deny
// catalog. This branch contains no path inspection or vendor execution.
fn handle_feature_gates_preview(request: Request) -> Response {
    if request.params != json!({}) || request.secret.is_some() {
        return auth_error(
            request.request_id,
            "validate", "FEATURE_GATE_INPUT_FORBIDDEN", "not_dispatched",
            "Offline feature preview accepts no account details or credentials.",
        );
    }
    Response {
        protocol: PROTOCOL_VERSION,
        request_id: request.request_id,
        ok: true,
        result: feature_gates::offline_policy_preview(),
        error: None,
    }
}

fn handle(request: Request) -> Response {
    if let Some(error) = validate_request(&request) {
        // Never reflect an invalid caller-controlled ID back into responses.
        let safe_id = if is_safe_request_id(&request.request_id) {
            request.request_id
        } else {
            String::new()
        };
        return Response {
            protocol: PROTOCOL_VERSION,
            request_id: safe_id,
            ok: false,
            result: json!({}),
            error: Some(error),
        };
    }

    match request.operation {
        Operation::Detect => {
            // Static detection never needs parameters or secret material.
            if request.params != json!({}) || request.secret.is_some() {
                return auth_error(
                    request.request_id,
                    "validate", "DETECT_INPUT_FORBIDDEN", "not_dispatched",
                    "Static dependency detection accepts no account details or credentials.",
                );
            }
            let binaries = static_detection(env::var("PATH").ok().as_deref());
            let interactive_shell_available = binaries
                .iter()
                .any(|item| item.name == "mega-cmd" && item.executable);
            let server_available = binaries
                .iter()
                .any(|item| item.name == "mega-cmd-server" && item.executable);
            let scriptable_dispatcher_available = binaries
                .iter()
                .any(|item| item.name == "mega-exec" && item.executable);
            Response {
                protocol: PROTOCOL_VERSION,
                request_id: request.request_id,
                ok: true,
                result: json!({
                    "adapter": "inir-mega",
                    "probe_kind": "static_no_vendor_execution",
                    "vendor_execution": if LIVE_AUTH_VENDOR_ENABLED {
                        "auth_transport_enabled"
                    } else {
                        "auth_blocked_pending_disposable_qualification"
                    },
                    "auth_transport": "private_pty_fake_qualified",
                    "secret_argv": false,
                    "python_mutation_fallback": false,
                    "interactive_shell_available": interactive_shell_available,
                    "server_available": server_available,
                    "scriptable_dispatcher_available": scriptable_dispatcher_available,
                    "binaries": binaries
                }),
                error: None,
            }
        }
        Operation::ConnectPreflight => {
            handle_connect_preflight(request, env::var("PATH").ok().as_deref())
        }
        Operation::FeatureGatesPreview => handle_feature_gates_preview(request),
        Operation::AuthBegin => handle_auth(request),
    }
}

fn read_bounded_request<R: Read>(reader: R) -> Result<Request> {
    // take(MAX+1) enforces a finite allocation even for an untrusted
    // stdin producer that never closes its stream. Reject before JSON parsing.
    let mut limited = reader.take((MAX_REQUEST_BYTES + 1) as u64);
    let mut raw = Vec::new();
    limited.read_to_end(&mut raw).context("read bounded request")?;
    if raw.len() > MAX_REQUEST_BYTES {
        anyhow::bail!("request exceeds fixed byte limit");
    }
    serde_json::from_slice(&raw).context("parse bounded request JSON")
}

fn run() -> Result<()> {
    let args = Args::parse();
    match args.command {
        Command::Request => {
            disable_core_dumps()?;
            let request = read_bounded_request(io::stdin().lock())?;
            println!("{}", serde_json::to_string(&handle(request))?);
        }
    }
    Ok(())
}

fn main() {
    if run().is_err() {
        let safe = json!({
            "protocol": PROTOCOL_VERSION,
            "request_id": "",
            "ok": false,
            "result": {},
            "error": {
                "stage": "validate",
                "kind": "INVALID_REQUEST",
                "outcome": "not_dispatched",
                "user_message": "Invalid Cloud Storage request."
            }
        });
        println!("{safe}");
        eprintln!("inir-mega request rejected"); // Never include untrusted JSON/errors.
        std::process::exit(2);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_request_accepts_valid_envelope_and_full_allowed_password() {
        let payload = serde_json::to_vec(&json!({
            "protocol": PROTOCOL_VERSION,
            "request_id": "cloud-auth-123",
            "operation": "auth_begin",
            "params": {"email": "fixture@example.invalid"},
            "secret": {"password": "x".repeat(4096), "mfa_code": "123456"}
        })).unwrap();
        assert!(payload.len() < MAX_REQUEST_BYTES);
        let decoded = read_bounded_request(std::io::Cursor::new(payload)).unwrap();
        assert!(matches!(decoded.operation, Operation::AuthBegin));
        assert_eq!(decoded.request_id, "cloud-auth-123");
    }

    #[test]
    fn oversized_or_invalid_request_never_echoes_secret_or_untrusted_id() {
        let canary = "private-test-password-do-not-echo";
        let huge = serde_json::to_vec(&json!({
            "protocol": PROTOCOL_VERSION,
            "request_id": "cloud-auth-123",
            "operation": "auth_begin",
            "params": {},
            "secret": {"password": canary.repeat(MAX_REQUEST_BYTES)}
        })).unwrap();
        assert!(huge.len() > MAX_REQUEST_BYTES);
        let error = read_bounded_request(std::io::Cursor::new(huge))
            .err().expect("oversized request must be rejected");
        assert!(!format!("{error:?}").contains(canary));

        let bad = read_bounded_request(std::io::Cursor::new(
            serde_json::to_vec(&json!({
                "protocol": PROTOCOL_VERSION, "operation": "detect",
                "request_id": "private\\npassword:123", "params": {}
            })).unwrap(),
        )).unwrap();
        let encoded = serde_json::to_string(&handle(bad)).unwrap();
        assert!(encoded.contains("INVALID_REQUEST_ID"));
        let response: Value = serde_json::from_str(&encoded).unwrap();
        assert_eq!(response["request_id"], "");
        assert!(!encoded.contains("private"));
        assert!(!encoded.contains("password:123"));
    }

    #[test]
    fn typed_envelope_rejects_unknown_root_and_secret_keys_before_dispatch() {
        let base = json!({
            "protocol": PROTOCOL_VERSION,
            "request_id": "schema-1",
            "operation": "auth_begin",
            "params": {"email": "fixture@example.invalid"},
            "secret": {"password": "TEST_ONLY_PASSWORD"}
        });
        let mut unknown_root = base.clone();
        unknown_root["unsupported_override"] = json!("TEST_ONLY_CANARY");
        let mut unknown_secret = base;
        unknown_secret["secret"]["session_token"] = json!("TEST_ONLY_CANARY");
        for invalid in [unknown_root, unknown_secret] {
            let encoded = serde_json::to_vec(&invalid).unwrap();
            let result = read_bounded_request(std::io::Cursor::new(encoded));
            assert!(result.is_err(), "unsupported field must fail before dispatch");
            assert!(!format!("{:?}", result.err()).contains("TEST_ONLY_CANARY"));
        }
    }

    #[test]
    fn detect_rejects_unexpected_params_or_secret_without_reflecting_them() {
        for (params, secret) in [
            (json!({"email": "TEST_ONLY_CANARY"}), None),
            (json!({}), Some(SecretInput {
                password: Some("TEST_ONLY_CANARY".into()), mfa_code: None,
            })),
        ] {
            let response = handle(Request {
                protocol: PROTOCOL_VERSION,
                request_id: "detect-negative".into(),
                operation: Operation::Detect,
                params, secret,
            });
            assert!(!response.ok);
            assert_eq!(response.error.as_ref().unwrap().kind, "DETECT_INPUT_FORBIDDEN");
            assert_eq!(response.error.as_ref().unwrap().outcome, "not_dispatched");
            assert!(!serde_json::to_string(&response).unwrap().contains("TEST_ONLY_CANARY"));
        }
    }

    #[test]
    fn auth_rejects_extra_or_non_string_params_before_vendor_dispatch() {
        for params in [
            json!({"email": "fixture@example.invalid", "force_login": true}),
            json!({"email": 123}),
            json!({"other": "fixture@example.invalid"}),
            json!(null),
        ] {
            let response = handle(Request {
                protocol: PROTOCOL_VERSION,
                request_id: "auth-params-negative".into(),
                operation: Operation::AuthBegin,
                params,
                secret: Some(SecretInput {
                    password: Some("TEST_ONLY_PASSWORD".into()), mfa_code: None,
                }),
            });
            assert!(!response.ok);
            assert_eq!(response.error.as_ref().unwrap().kind, "AUTH_PARAMS_INVALID");
            assert_eq!(response.error.as_ref().unwrap().outcome, "not_dispatched");
            assert!(!serde_json::to_string(&response).unwrap().contains("TEST_ONLY_PASSWORD"));
        }
    }

    #[test]
    fn static_detection_does_not_execute_vendor_binary() {
        let root = env::temp_dir().join(format!("inir-mega-static-probe-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let marker = root.join("executed");
        let fake = root.join("mega-cmd");
        fs::write(&fake, format!("#!/bin/sh\\ntouch '{}'\\n", marker.display())).unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut permissions = fs::metadata(&fake).unwrap().permissions();
            permissions.set_mode(0o700);
            fs::set_permissions(&fake, permissions).unwrap();
        }
        let path_value = root.to_string_lossy().into_owned();
        let detected = static_detection(Some(&path_value));
        assert!(detected.iter().any(|item| item.name == "mega-cmd" && item.executable));
        assert!(detected.iter().any(|item| item.name == "mega-exec" && !item.executable));
        assert!(!marker.exists());
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn static_detection_reports_missing_dependency_without_vendor_call() {
        let detected = static_detection(Some(""));
        assert!(detected.iter().all(|item| !item.executable));
    }

    #[test]
    fn auth_prompt_state_machine_requires_explicit_known_prompts() {
        assert_eq!(classify_auth_prompt("Password:"), AuthPrompt::Password);
        assert_eq!(classify_auth_prompt("Multi-factor authentication code:"), AuthPrompt::Mfa);
        assert_eq!(classify_auth_prompt("Login successful"), AuthPrompt::Complete);
        assert_eq!(classify_auth_prompt("Login failed"), AuthPrompt::Failed);
        assert_eq!(classify_auth_prompt("Enter something else:"), AuthPrompt::Unexpected);
    }

    #[test]
    fn auth_prompt_classifier_rejects_embedded_or_echoed_phrases() {
        for ambiguous in [
            "Debug: Password:",
            "Please check password:",
            "Secret value includes 2fa code:",
            "Login successful despite unknown output",
            "Warning: login failed unexpectedly",
            "Logged in to an unrelated service",
            "Login successful: vendor debug suffix",
        ] {
            assert_eq!(
                classify_auth_prompt(ambiguous),
                AuthPrompt::Unexpected,
                "unexpected accepted prompt shape"
            );
        }
    }

    #[test]
    fn auth_state_rejects_repeat_mfa_without_duplicate_secret_submission() {
        let (terminal, writes) = FakeVendorHarness {
            prompts: vec![
                "Password:",
                "Multi-factor authentication code:",
                "Multi-factor authentication code:",
                "Login successful",
            ],
            writes: Vec::new(),
        }
        .run("fixture-password-never-log", "123456");
        assert_eq!(terminal, AuthStep::RejectUnexpected);
        assert_eq!(writes, vec!["fixture-password-never-log", "123456"]);
    }

    struct FakeVendorHarness {
        prompts: Vec<&'static str>,
        writes: Vec<String>,
    }

    impl FakeVendorHarness {
        fn run(mut self, password: &str, mfa: &str) -> (AuthStep, Vec<String>) {
            let mut state = AuthState::AwaitPassword;
            let mut terminal = AuthStep::RejectUnexpected;
            for prompt in self.prompts {
                match advance_auth(&mut state, classify_auth_prompt(prompt)) {
                    AuthStep::Write(SecretWrite::Password) => self.writes.push(password.to_owned()),
                    AuthStep::Write(SecretWrite::Mfa) => self.writes.push(mfa.to_owned()),
                    step @ (AuthStep::Complete | AuthStep::Failed | AuthStep::RejectUnexpected) => {
                        terminal = step;
                        break;
                    }
                }
            }
            (terminal, self.writes)
        }
    }

    #[test]
    fn fake_vendor_harness_qualifies_password_then_mfa_flow() {
        let password = "fixture-password-never-log";
        let mfa = "123456";
        let (terminal, writes) = FakeVendorHarness {
            prompts: vec!["Password:", "Multi-factor authentication code:", "Login successful"],
            writes: Vec::new(),
        }
        .run(password, mfa);
        assert_eq!(terminal, AuthStep::Complete);
        assert_eq!(writes, vec![password, mfa]);
    }

    #[test]
    fn fake_vendor_harness_never_submits_secret_to_unknown_prompt() {
        let password = "fixture-password-never-log";
        let mfa = "123456";
        let (terminal, writes) = FakeVendorHarness {
            prompts: vec!["Enter account recovery key:"],
            writes: Vec::new(),
        }
        .run(password, mfa);
        assert_eq!(terminal, AuthStep::RejectUnexpected);
        assert!(writes.is_empty());
    }

    #[test]
    fn fake_vendor_harness_rejects_out_of_order_mfa_without_secret_write() {
        let (terminal, writes) = FakeVendorHarness {
            prompts: vec!["2FA code:"],
            writes: Vec::new(),
        }
        .run("fixture-password-never-log", "123456");
        assert_eq!(terminal, AuthStep::RejectUnexpected);
        assert!(writes.is_empty());
    }

    #[test]
    fn safe_login_email_rejects_command_text() {
        assert!(is_safe_login_email("fixture@example.invalid"));
        assert!(!is_safe_login_email("fixture@example.invalid\nlogout"));
        assert!(!is_safe_login_email("fixture name@example.invalid"));
        assert!(!is_safe_login_email("fixture@example"));
    }

    #[test]
    fn secrets_are_not_part_of_serialized_response() {
        let password = "phase1-secret-password";
        let mfa = "123456";
        let email = "fixture@example.invalid";
        let request = Request {
            protocol: PROTOCOL_VERSION,
            request_id: "auth-1".into(),
            operation: Operation::AuthBegin,
            params: json!({"email": email}),
            secret: Some(SecretInput {
                password: Some(password.into()),
                mfa_code: Some(mfa.into()),
            }),
        };
        let encoded = serde_json::to_string(&handle(request)).unwrap();
        assert!(!encoded.contains(password));
        assert!(!encoded.contains(mfa));
        assert!(!encoded.contains(email));
    }

    #[test]
    fn auth_is_fail_closed_until_installed_vendor_is_qualified() {
        let response = handle(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "auth-2".into(),
            operation: Operation::AuthBegin,
            params: json!({"email": "fixture@example.invalid"}),
            secret: Some(SecretInput { password: Some("secret".into()), mfa_code: None }),
        });
        assert!(!response.ok);
        assert_eq!(response.error.unwrap().kind, "AUTH_VENDOR_NOT_QUALIFIED");
    }

    #[test]
    fn invalid_mfa_is_rejected_before_vendor_dispatch() {
        let response = handle(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "auth-3".into(),
            operation: Operation::AuthBegin,
            params: json!({"email": "fixture@example.invalid"}),
            secret: Some(SecretInput {
                password: Some("secret".into()),
                mfa_code: Some("12 456".into()),
            }),
        });
        let error = response.error.unwrap();
        assert_eq!(error.kind, "MFA_INPUT_INVALID");
        assert_eq!(error.outcome, "not_dispatched");
    }

    #[test]
    fn feature_gate_preview_never_authorizes_live_domains() {
        let response = handle_feature_gates_preview(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "gates-1".into(),
            operation: Operation::FeatureGatesPreview,
            params: json!({}),
            secret: None,
        });
        assert!(response.ok);
        assert!(response.error.is_none());
        assert_eq!(response.request_id, "gates-1");
        assert_eq!(response.result["probe_kind"], "offline_policy_preview");
        assert_eq!(response.result["connected"], false);
        assert_eq!(response.result["auth_qualified"], false);
        assert_eq!(response.result["account_reads_enabled"], false);
        assert_eq!(response.result["writes_enabled"], false);
        assert_eq!(response.result["domains"].as_object().unwrap().len(), 10);
    }

    #[test]
    fn feature_gate_preview_rejects_secrets_and_override_params() {
        for (params, secret) in [
            (json!({"enable_live": true}), None),
            (json!({}), Some(SecretInput {
                password: Some("PRIVATE_PREVIEW_CANARY".into()),
                mfa_code: None,
            })),
            (json!({}), Some(SecretInput { password: None, mfa_code: None })),
        ] {
            let response = handle_feature_gates_preview(Request {
                protocol: PROTOCOL_VERSION,
                request_id: "gates-reject".into(),
                operation: Operation::FeatureGatesPreview,
                params,
                secret,
            });
            assert!(!response.ok);
            assert_eq!(response.error.unwrap().kind, "FEATURE_GATE_INPUT_FORBIDDEN");
            let serialized = serde_json::to_string(&response.result).unwrap();
            assert!(!serialized.contains("PRIVATE_PREVIEW_CANARY"));
        }
    }

    #[test]
    fn preflight_missing_does_not_start_vendor_or_advertise_live_read() {
        let request = Request {
            protocol: PROTOCOL_VERSION,
            request_id: "preflight-1".into(),
            operation: Operation::ConnectPreflight,
            params: json!({}),
            secret: None,
        };
        let response = handle_connect_preflight(request, Some(""));
        assert!(response.ok);
        assert_eq!(response.result["probe_kind"], "static_connect_preflight");
        assert_eq!(response.result["dependencies_ready"], false);
        assert_eq!(response.result["connected"], false);
        assert_eq!(response.result["connection_attempted"], false);
        assert_eq!(response.result["auth_qualified"], false);
        assert_eq!(response.result["account_reads_enabled"], false);
        assert_eq!(response.result["reason"], "dependency_missing");
    }

    #[test]
    fn preflight_without_scriptable_dispatcher_is_not_ready() {
        let root = env::temp_dir().join(format!(
            "inir-mega-preflight-no-dispatcher-{}-{:?}",
            std::process::id(), std::thread::current().id()
        ));
        fs::create_dir_all(&root).unwrap();
        for name in ["mega-cmd", "mega-cmd-server"] {
            let file = root.join(name);
            fs::write(&file, "#!/bin/sh\nexit 99\n").unwrap();
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut mode = fs::metadata(&file).unwrap().permissions();
                mode.set_mode(0o700);
                fs::set_permissions(&file, mode).unwrap();
            }
        }
        let path = root.to_string_lossy().into_owned();
        let response = handle_connect_preflight(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "preflight-no-dispatcher".into(),
            operation: Operation::ConnectPreflight,
            params: json!({}),
            secret: None,
        }, Some(&path));
        assert!(response.ok);
        assert_eq!(response.result["dependencies_ready"], false);
        assert_eq!(response.result["reason"], "dependency_missing");
        assert_eq!(response.result["connection_attempted"], false);
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn preflight_present_never_executes_fake_vendor() {
        let root = env::temp_dir().join(format!(
            "inir-mega-preflight-{}-{:?}", std::process::id(), std::thread::current().id()
        ));
        fs::create_dir_all(&root).unwrap();
        let marker = root.join("vendor-executed");
        for name in ["mega-cmd", "mega-cmd-server", "mega-exec"] {
            let file = root.join(name);
            fs::write(&file, format!("#!/bin/sh\nprintf MARKER > '{}'\n", marker.display())).unwrap();
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut mode = fs::metadata(&file).unwrap().permissions();
                mode.set_mode(0o700);
                fs::set_permissions(&file, mode).unwrap();
            }
        }
        let path = root.to_string_lossy().into_owned();
        let response = handle_connect_preflight(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "preflight-present".into(),
            operation: Operation::ConnectPreflight,
            params: json!({}),
            secret: None,
        }, Some(&path));
        assert!(response.ok);
        assert_eq!(response.result["dependencies_ready"], true);
        assert_eq!(response.result["reason"], "installed_vendor_not_qualified");
        assert_eq!(response.result["connected"], false);
        assert_eq!(response.result["connection_attempted"], false);
        assert!(!marker.exists());
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn preflight_rejects_secret_and_arbitrary_params_without_vendor() {
        let response = handle_connect_preflight(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "preflight-secret".into(),
            operation: Operation::ConnectPreflight,
            params: json!({}),
            secret: Some(SecretInput {
                password: Some("PRIVATE_TEST_CANARY".into()),
                mfa_code: None,
            }),
        }, None);
        assert!(!response.ok);
        assert_eq!(response.error.unwrap().kind, "PREFLIGHT_INPUT_FORBIDDEN");
        assert!(!serde_json::to_string(&response.result).unwrap().contains("PRIVATE_TEST_CANARY"));

        let invalid = handle_connect_preflight(Request {
            protocol: PROTOCOL_VERSION,
            request_id: "preflight-params".into(),
            operation: Operation::ConnectPreflight,
            params: json!({"arbitrary_command": "mega-rm"}),
            secret: None,
        }, None);
        assert!(!invalid.ok);
        assert_eq!(invalid.error.unwrap().outcome, "not_dispatched");
    }

    #[test]
    fn opaque_ids_remain_strings_at_protocol_boundary() {
        let value: Value = serde_json::from_str(r#"{"id":"18446744073709551615"}"#).unwrap();
        assert_eq!(value["id"].as_str(), Some("18446744073709551615"));
    }
}
