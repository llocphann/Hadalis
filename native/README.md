# Hadalis native runtime

Hadalis uses this Rust workspace as its production backend. Python implementations remain installed as an explicit rollback path, not the default selector.

The workspace builds the production helpers, including the dedicated `inir-mega` Cloud Storage adapter and the Rust-only `inir-companiond` Wull state/scheduling backend. Current-source install/package paths ship `inir-companiond` in `native/bin/`, while Wull UI ownership remains disabled by default pending live acceptance. A source checkout can also use `native/target/release/` for development validation.

`scripts/native-dispatch` defaults to Rust. Explicit environment overrides have highest priority, then persisted selector state, then packaged binaries. Existing compatibility routes may use their retained Python fallback when strict mode is off. The `mega` and `companion` routes are exceptions: they always require their dedicated Rust helpers and never fall back to Python, even when the generic backend selector is set to Python.

Use `scripts/native-backend python` for emergency fallback, `scripts/native-backend rust` to return to production, and `scripts/native-backend status` to inspect state. Required migration `050-rust-native-default` clears benchmark-only selector overrides and promotes existing installations once.

Source build/install:

```bash
bash native/scripts/install-runtime.sh --build-only
bash native/scripts/install-runtime.sh --dest /path/to/runtime/native/bin
```

The final pre-cutover qualification at `1897c662cb2fd4123c254ed6b4242f0914dc5744` passed all native parity/build gates, deep MPD snapshot parity, and three alternating live Python/Rust A/B rounds with zero native activation blockers.
