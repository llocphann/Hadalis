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

const PROTOCOL_VERSION: u32 = 1;
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

#[derive(Deserialize)]
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
    AuthBegin,
}

#[derive(Deserialize)]
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
        "mega-login",
        "mega-cmd-server",
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
    let normalized = text.to_ascii_lowercase();
    if normalized.contains("multi-factor") || normalized.contains("two-factor")
        || normalized.contains("2fa") || normalized.contains("mfa")
    {
        AuthPrompt::Mfa
    } else if normalized.contains("password") {
        AuthPrompt::Password
    } else if normalized.contains("logged in") || normalized.contains("login successful") {
        AuthPrompt::Complete
    } else if normalized.contains("incorrect") || normalized.contains("failed") {
        AuthPrompt::Failed
    } else {
        AuthPrompt::Unexpected
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AuthState {
    AwaitPassword,
    AwaitMfaOrComplete,
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
            AuthStep::Write(SecretWrite::Mfa)
        }
        (AuthState::AwaitMfaOrComplete, AuthPrompt::Complete) => {
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

fn validate_request(request: &Request) -> Option<SafeError> {
    if request.protocol != PROTOCOL_VERSION {
        return Some(SafeError {
            stage: "validate",
            kind: "PROTOCOL_MISMATCH",
            outcome: "not_dispatched",
            user_message: "Cloud Storage backend protocol mismatch.",
        });
    }
    if request.request_id.is_empty() || request.request_id.len() > 128 {
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

fn handle(request: Request) -> Response {
    if let Some(error) = validate_request(&request) {
        return Response {
            protocol: PROTOCOL_VERSION,
            request_id: request.request_id,
            ok: false,
            result: json!({}),
            error: Some(error),
        };
    }

    match request.operation {
        Operation::Detect => {
            let binaries = static_detection(env::var("PATH").ok().as_deref());
            let interactive_shell_available = binaries
                .iter()
                .any(|item| item.name == "mega-cmd" && item.executable);
            let server_available = binaries
                .iter()
                .any(|item| item.name == "mega-cmd-server" && item.executable);
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
                    "binaries": binaries
                }),
                error: None,
            }
        }
        Operation::AuthBegin => handle_auth(request),
    }
}

fn run() -> Result<()> {
    let args = Args::parse();
    match args.command {
        Command::Request => {
            disable_core_dumps()?;
            let mut input = String::new();
            io::stdin().read_to_string(&mut input).context("read request stdin")?;
            let request: Request = serde_json::from_str(&input).context("parse request JSON")?;
            println!("{}", serde_json::to_string(&handle(request))?);
        }
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
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
        eprintln!("inir-mega request rejected: {}", error.root_cause());
        std::process::exit(2);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
    fn opaque_ids_remain_strings_at_protocol_boundary() {
        let value: Value = serde_json::from_str(r#"{"id":"18446744073709551615"}"#).unwrap();
        assert_eq!(value["id"].as_str(), Some("18446744073709551615"));
    }
}
