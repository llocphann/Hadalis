# Hadalis native runtime

Hadalis uses this Rust workspace as its production backend. Python implementations remain installed as an explicit rollback path, not the default selector.

The workspace builds `inir-native`, `inir-inputd`, `inir-mpdd`, and `inir-theme`. Packaged/source-installed runtimes place them in `native/bin/`; a source checkout can also use `native/target/release/`.

`scripts/native-dispatch` defaults to Rust. Explicit environment overrides have highest priority, then persisted selector state, then packaged binaries. If a Rust binary is unavailable or fails and strict mode is off, the dispatcher logs the failure and executes the retained Python implementation.

Use `scripts/native-backend python` for emergency fallback, `scripts/native-backend rust` to return to production, and `scripts/native-backend status` to inspect state. Required migration `050-rust-native-default` clears benchmark-only selector overrides and promotes existing installations once.

Source build/install:

```bash
bash native/scripts/install-runtime.sh --build-only
bash native/scripts/install-runtime.sh --dest /path/to/runtime/native/bin
```

The final pre-cutover qualification at `1897c662cb2fd4123c254ed6b4242f0914dc5744` passed all native parity/build gates, deep MPD snapshot parity, and three alternating live Python/Rust A/B rounds with zero native activation blockers.
