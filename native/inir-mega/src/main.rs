use std::io::{self, Read};

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

const PROTOCOL_VERSION: u32 = 1;

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
    AuthMfa,
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
        Operation::Detect => Response {
            protocol: PROTOCOL_VERSION,
            request_id: request.request_id,
            ok: true,
            result: json!({
                "adapter": "inir-mega",
                "vendor_execution": "disabled_until_fake_harness_qualification",
                "auth_transport": "pty_required",
                "secret_argv": false,
                "python_mutation_fallback": false
            }),
            error: None,
        },
        Operation::AuthBegin => {
            let has_email = request.params.get("email").and_then(Value::as_str)
                .is_some_and(|value| !value.trim().is_empty());
            let has_password = request.secret.as_ref()
                .and_then(|secret| secret.password.as_deref())
                .is_some_and(|value| !value.is_empty());
            let error = if !has_email || !has_password {
                Some(SafeError {
                    stage: "validate",
                    kind: "AUTH_INPUT_REQUIRED",
                    outcome: "not_dispatched",
                    user_message: "Email and password are required.",
                })
            } else {
                Some(SafeError {
                    stage: "dispatch",
                    kind: "AUTH_VENDOR_NOT_QUALIFIED",
                    outcome: "not_dispatched",
                    user_message: "MEGAcmd sign-in is not enabled until the PTY harness is qualified.",
                })
            };
            Response {
                protocol: PROTOCOL_VERSION,
                request_id: request.request_id,
                ok: false,
                result: json!({"next": "blocked"}),
                error,
            }
        }
        Operation::AuthMfa => {
            let has_code = request.secret.as_ref()
                .and_then(|secret| secret.mfa_code.as_deref())
                .is_some_and(|value| !value.is_empty());
            Response {
                protocol: PROTOCOL_VERSION,
                request_id: request.request_id,
                ok: false,
                result: json!({"next": "blocked"}),
                error: Some(SafeError {
                    stage: if has_code { "dispatch" } else { "validate" },
                    kind: if has_code { "AUTH_VENDOR_NOT_QUALIFIED" } else { "MFA_INPUT_REQUIRED" },
                    outcome: "not_dispatched",
                    user_message: if has_code {
                        "MEGAcmd two-factor authentication is not enabled until the PTY harness is qualified."
                    } else {
                        "Two-factor authentication code is required."
                    },
                }),
            }
        }
    }
}

fn run() -> Result<()> {
    let args = Args::parse();
    match args.command {
        Command::Request => {
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
    fn secrets_are_not_part_of_serialized_response() {
        let password = "phase0-secret-password";
        let request = Request {
            protocol: PROTOCOL_VERSION,
            request_id: "auth-1".into(),
            operation: Operation::AuthBegin,
            params: json!({"email": "fixture@example.invalid"}),
            secret: Some(SecretInput { password: Some(password.into()), mfa_code: None }),
        };
        let encoded = serde_json::to_string(&handle(request)).unwrap();
        assert!(!encoded.contains(password));
        assert!(!encoded.contains("fixture@example.invalid"));
    }

    #[test]
    fn auth_is_fail_closed_until_pty_vendor_is_qualified() {
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
    fn opaque_ids_remain_strings_at_protocol_boundary() {
        let value: Value = serde_json::from_str(r#"{"id":"18446744073709551615"}"#).unwrap();
        assert_eq!(value["id"].as_str(), Some("18446744073709551615"));
    }
}
