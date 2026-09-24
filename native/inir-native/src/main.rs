use std::io::{self, Read, Write};
use std::process::{Command as ProcessCommand, Stdio};

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use regex::Regex;

const HTML_PAYLOAD_PREFIX: &[u8] =
    b"<meta http-equiv=\"content-type\" content=\"text/html";
const HTML_FRAGMENT_MARKER: &[u8] = b"<!--StartFragment-->";

#[derive(Debug, Parser)]
#[command(about = "Dormant one-shot native helpers for Hadalis")]
struct Args {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Native parity implementation of scripts/clipboard-store.py.
    ClipboardFilter {
        /// Write the sanitized payload to stdout instead of calling cliphist store.
        #[arg(long)]
        filter: bool,
    },
}

fn is_browser_markup(payload: &[u8]) -> bool {
    payload.starts_with(HTML_PAYLOAD_PREFIX)
        || payload
            .windows(HTML_FRAGMENT_MARKER.len())
            .any(|window| window == HTML_FRAGMENT_MARKER)
}

fn replace(pattern: &str, input: &str, replacement: &str) -> String {
    Regex::new(pattern)
        .expect("clipboard regex must compile")
        .replace_all(input, replacement)
        .into_owned()
}

fn strip_browser_markup(markup: &str) -> String {
    let text = replace(r"^<meta[^>]*>", markup, "");
    let text = replace(r"(?is)<(script|style)\b.*?</(?:script|style)>", &text, "");
    let text = replace(r"(?s)<!--.*?-->", &text, "");
    let text = replace(r"(?i)<br\s*/?>", &text, "\n");
    let text = replace(
        r"(?i)</(?:p|div|li|tr|h[1-6]|blockquote|pre)>",
        &text,
        "\n",
    );
    let text = replace(
        r#"(?i)<img[^>]*\bsrc=["']([^"']+)["'][^>]*>"#,
        &text,
        "$1",
    );
    let text = replace(r"<[^>]+>", &text, "");
    let text = html_escape::decode_html_entities(&text).into_owned();
    let text = replace(r"[ \t]+\n", &text, "\n");
    replace(r"\n{3,}", &text, "\n\n").trim().to_owned()
}

fn sanitize_payload(payload: Vec<u8>) -> Vec<u8> {
    if !is_browser_markup(&payload) {
        return payload;
    }
    strip_browser_markup(&String::from_utf8_lossy(&payload)).into_bytes()
}

fn store_with_cliphist(payload: &[u8]) -> Result<i32> {
    let mut child = ProcessCommand::new("cliphist")
        .arg("store")
        .stdin(Stdio::piped())
        .spawn()
        .context("failed to start cliphist store")?;

    child
        .stdin
        .take()
        .context("cliphist stdin was not piped")?
        .write_all(payload)
        .context("failed to write clipboard payload to cliphist")?;

    let status = child.wait().context("failed to wait for cliphist store")?;
    Ok(status.code().unwrap_or(1))
}

fn clipboard_filter(filter: bool) -> Result<i32> {
    let mut payload = Vec::new();
    io::stdin()
        .read_to_end(&mut payload)
        .context("failed to read clipboard payload")?;
    let payload = sanitize_payload(payload);

    if payload.is_empty() {
        return Ok(0);
    }

    if filter {
        io::stdout()
            .write_all(&payload)
            .context("failed to write filtered clipboard payload")?;
        return Ok(0);
    }

    store_with_cliphist(&payload)
}

fn main() -> Result<()> {
    let args = Args::parse();
    let code = match args.command {
        Command::ClipboardFilter { filter } => clipboard_filter(filter)?,
    };
    std::process::exit(code);
}

#[cfg(test)]
mod tests {
    use super::{is_browser_markup, sanitize_payload, strip_browser_markup};

    #[test]
    fn plain_text_is_byte_for_byte_passthrough() {
        let input = b"alpha <div>literal source</div>\n".to_vec();
        assert!(!is_browser_markup(&input));
        assert_eq!(sanitize_payload(input.clone()), input);
    }

    #[test]
    fn firefox_html_payload_is_sanitized() {
        let input =
            r#"<meta http-equiv="content-type" content="text/html; charset=utf-8"><div>Hello&nbsp;world</div><div>Next</div>"#;
        assert_eq!(strip_browser_markup(input), "Hello\u{00a0}world\nNext");
    }

    #[test]
    fn chromium_fragment_removes_wrapper_and_preserves_lines() {
        let input =
            r#"<!--StartFragment--><p>One<br>Two</p><script>bad()</script><!--EndFragment-->"#;
        assert_eq!(strip_browser_markup(input), "One\nTwo");
    }

    #[test]
    fn image_only_markup_keeps_source() {
        let input =
            r#"<!--StartFragment--><img alt="x" src="https://example.test/a.png"><!--EndFragment-->"#;
        assert_eq!(strip_browser_markup(input), "https://example.test/a.png");
    }
}
