use std::io::{self, Write};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, SyncSender};
use std::time::{Duration, Instant};

use inir_companiond::{BoundedLine, Engine, ProtocolError, StateMessage, read_bounded_line};

const INPUT_QUEUE_CAPACITY: usize = 64;
const IDLE_SEED: u64 = 0x5755_4c4c_5f41_4259;

enum InputRecord {
    Line(Vec<u8>),
    Oversized,
    Eof,
    ReadError,
}

fn spawn_stdin_reader(tx: SyncSender<InputRecord>) {
    std::thread::spawn(move || {
        let stdin = io::stdin();
        let mut reader = stdin.lock();
        loop {
            match read_bounded_line(&mut reader) {
                Ok(Some(BoundedLine::Line(line))) => {
                    if tx.send(InputRecord::Line(line)).is_err() {
                        break;
                    }
                }
                Ok(Some(BoundedLine::Oversized)) => {
                    if tx.send(InputRecord::Oversized).is_err() {
                        break;
                    }
                }
                Ok(None) => {
                    let _ = tx.send(InputRecord::Eof);
                    break;
                }
                Err(_) => {
                    let _ = tx.send(InputRecord::ReadError);
                    break;
                }
            }
        }
    });
}

fn write_message(out: &mut impl Write, message: &StateMessage) -> bool {
    if serde_json::to_writer(&mut *out, message).is_err() {
        return false;
    }
    out.write_all(b"\n").and_then(|_| out.flush()).is_ok()
}

fn elapsed_ms(started: Instant) -> u64 {
    started.elapsed().as_millis().min(u64::MAX as u128) as u64
}

fn handle_record(
    record: InputRecord,
    engine: &mut Engine,
    now_ms: u64,
    out: &mut impl Write,
) -> bool {
    match record {
        InputRecord::Line(line) => match engine.apply_line(&line, now_ms) {
            Ok(message) => write_message(out, &message),
            Err(error) => {
                eprintln!("inir-companiond: ignored_input={}", error.code());
                true
            }
        },
        InputRecord::Oversized => {
            eprintln!(
                "inir-companiond: ignored_input={}",
                ProtocolError::Oversized.code()
            );
            true
        }
        InputRecord::Eof => false,
        InputRecord::ReadError => {
            eprintln!("inir-companiond: stdin_read_error");
            false
        }
    }
}

fn run_loop(rx: Receiver<InputRecord>, engine: &mut Engine, out: &mut impl Write) {
    let started = Instant::now();
    if !write_message(out, &engine.initial_message()) {
        return;
    }

    loop {
        let now_ms = elapsed_ms(started);
        if let Some(deadline) = engine.next_deadline_ms() {
            if now_ms >= deadline {
                if let Some(message) = engine.tick(now_ms)
                    && !write_message(out, &message)
                {
                    break;
                }
                continue;
            }

            match rx.recv_timeout(Duration::from_millis(deadline - now_ms)) {
                Ok(record) => {
                    if !handle_record(record, engine, elapsed_ms(started), out) {
                        break;
                    }
                }
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => break,
            }
        } else {
            match rx.recv() {
                Ok(record) => {
                    if !handle_record(record, engine, elapsed_ms(started), out) {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    }
}

fn main() {
    if std::env::args().skip(1).any(|arg| arg == "--version") {
        println!("inir-companiond {}", env!("CARGO_PKG_VERSION"));
        return;
    }

    let (tx, rx) = mpsc::sync_channel(INPUT_QUEUE_CAPACITY);
    spawn_stdin_reader(tx);

    let stdout = io::stdout();
    let mut out = stdout.lock();
    let mut engine = Engine::new(IDLE_SEED);
    run_loop(rx, &mut engine, &mut out);
}
