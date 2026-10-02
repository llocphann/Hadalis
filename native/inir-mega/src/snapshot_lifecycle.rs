//! Synthetic-only UI refresh ordering for unqualified Sync snapshots.
//!
//! This unit-tested state machine is *not* wired to a live backend or QML.
//! External process supervision MUST ensure finish() only after child reap.
//! A parsed fake table is neither authentication nor vendor qualification.
#![allow(dead_code)]

use crate::column_fixtures::{
    CandidateCapture, CaptureError, SyncSnapshotRow, parse_sync_snapshot_capture,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct RefreshToken {
    generation: u64,
    serial: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Start {
    Hidden,
    Started(RefreshToken),
    Queued,
    Exhausted,
}

#[derive(Debug, Eq, PartialEq)]
pub enum Finish {
    Ignored,
    Restart(RefreshToken),
    Applied(usize),
    Rejected(CaptureError),
}

/// Separate fake-only cache, not the CloudStorageService production cache.
/// At most one simulated child may be in flight; when closed or expired,
/// the old token remains in_flight until its explicit *reap* callback.
#[derive(Debug, Default)]
pub struct SnapshotRefresh {
    active: bool,
    poisoned: bool,
    generation: u64,
    serial: u64,
    in_flight: Option<RefreshToken>,
    revoked: bool,
    queued: bool,
    snapshot: Option<Vec<SyncSnapshotRow>>,
}

impl SnapshotRefresh {
    pub fn activate(&mut self) -> bool {
        if self.poisoned || self.active {
            return false;
        }
        let Some(next) = self.generation.checked_add(1) else {
            self.poison();
            return false;
        };
        self.generation = next;
        self.active = true;
        self.queued = false;
        self.snapshot = None;
        // An earlier lease's simulated process may still need reaping.
        self.revoked = self.in_flight.is_some();
        true
    }

    pub fn close(&mut self) {
        self.active = false;
        self.queued = false;
        self.snapshot = None;
        // Preserve in_flight to prevent another simulated start before
        // the previous subprocess has actually exited/reaped.
        self.revoked = self.in_flight.is_some();
    }

    pub fn ready(&self) -> Option<&[SyncSnapshotRow]> {
        if !self.active || self.poisoned || self.in_flight.is_some()
            || self.revoked || self.queued {
            return None;
        }
        self.snapshot.as_deref()
    }

    fn poison(&mut self) {
        self.poisoned = true;
        self.active = false;
        self.queued = false;
        self.revoked = true;
        self.snapshot = None;
        // Keep any in-flight token for a later safe reap.
    }

    fn issue(&mut self) -> Start {
        if self.poisoned { return Start::Exhausted; }
        let Some(serial) = self.serial.checked_add(1) else {
            self.poison();
            return Start::Exhausted;
        };
        self.serial = serial;
        let token = RefreshToken { generation: self.generation, serial };
        self.in_flight = Some(token);
        self.revoked = false;
        self.queued = false;
        self.snapshot = None;
        Start::Started(token)
    }

    /// New requests while a child remains in flight are coalesced.
    /// Do not run a second (even read-only) vendor process before reap.
    pub fn request(&mut self) -> Start {
        if self.poisoned { return Start::Exhausted; }
        if !self.active { return Start::Hidden; }
        self.snapshot = None;
        if self.in_flight.is_some() {
            self.queued = true;
            return Start::Queued;
        }
        self.issue()
    }

    /// Mark a timed-out process obsolete. Only the external *reap* callback
    /// may clear in_flight: marking a timeout is NOT evidence of process exit.
    pub fn expire(&mut self, token: RefreshToken) -> bool {
        if self.in_flight != Some(token) { return false; }
        self.revoked = true;
        self.snapshot = None;
        true
    }

    /// Call only after the corresponding simulated child has been reaped.
    /// Never accept a late result from a hidden, expired or replaced lease.
    pub fn finish(
        &mut self,
        token: RefreshToken,
        capture: &CandidateCapture<'_>,
    ) -> Finish {
        if self.in_flight != Some(token) { return Finish::Ignored; }
        self.in_flight = None;
        let revoked = self.revoked;
        self.revoked = false;
        self.snapshot = None;
        if self.poisoned || !self.active { return Finish::Ignored; }
        // A newer request supersedes this result. One new start is allowed
        // only now, after this token's reap callback has been observed.
        if self.queued {
            return match self.issue() {
                Start::Started(next) => Finish::Restart(next),
                _ => Finish::Ignored, // poisoned on monotonic counter overflow
            };
        }
        if revoked || token.generation != self.generation {
            return Finish::Ignored;
        }
        match parse_sync_snapshot_capture(capture) {
            Ok(rows) => {
                let count = rows.len();
                self.snapshot = Some(rows);
                Finish::Applied(count)
            }
            Err(err) => Finish::Rejected(err),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::column_fixtures::{Error, RunState, Status};

    fn good() -> CandidateCapture<'static> {
        CandidateCapture {
            stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n",
            stderr: b"",
            exit_code: Some(0),
            timed_out: false,
            output_capped: false,
        }
    }
    fn token(start: Start) -> RefreshToken {
        let Start::Started(value) = start else {
            panic!("expected one new candidate request: {start:?}");
        };
        value
    }

    #[test]
    fn only_matching_current_clean_capture_becomes_visible() {
        let mut state = SnapshotRefresh::default();
        assert_eq!(state.request(), Start::Hidden);
        assert!(state.activate());
        assert!(!state.activate());
        let first = token(state.request());
        assert!(state.ready().is_none());
        assert_eq!(state.finish(first, &good()), Finish::Applied(1));
        assert_eq!(state.ready().unwrap().len(), 1);
        assert_eq!(state.ready().unwrap()[0].id, "AbcDef12_-x");
        assert_eq!(state.ready().unwrap()[0].run_state, RunState::Running);
        assert_eq!(state.ready().unwrap()[0].status, Status::Synced);

        let second = token(state.request());
        assert!(state.ready().is_none()); // never display old state as fresh
        assert_eq!(state.finish(first, &good()), Finish::Ignored);
        assert!(state.ready().is_none());
        let truncated = CandidateCapture {
            stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced",
            ..good()
        };
        assert_eq!(
            state.finish(second, &truncated),
            Finish::Rejected(CaptureError::InvalidTable(Error::Incomplete))
        );
        assert!(state.ready().is_none());
    }

    #[test]
    fn burst_refresh_coalesces_and_drops_superseded_results() {
        let mut state = SnapshotRefresh::default();
        assert!(state.activate());
        let first = token(state.request());
        assert_eq!(state.request(), Start::Queued);
        assert_eq!(state.request(), Start::Queued);
        assert!(state.ready().is_none());
        let Finish::Restart(next) = state.finish(first, &good()) else {
            panic!("latest queued request must restart only after old reap");
        };
        assert_ne!(next, first);
        assert_eq!(state.finish(first, &good()), Finish::Ignored);
        assert!(state.ready().is_none());
        assert_eq!(state.finish(next, &good()), Finish::Applied(1));
        assert_eq!(state.ready().unwrap().len(), 1);
    }

    #[test]
    fn closing_and_reopening_blocks_old_child_until_reaped() {
        let mut state = SnapshotRefresh::default();
        assert!(state.activate());
        let old = token(state.request());
        state.close();
        assert_eq!(state.request(), Start::Hidden);
        assert!(state.ready().is_none());
        assert!(state.activate());
        assert_eq!(state.request(), Start::Queued);
        // Old generation's result may look valid, but must never apply.
        let Finish::Restart(fresh) = state.finish(old, &good()) else {
            panic!("new lease may begin only after old reap");
        };
        assert_ne!(fresh.generation, old.generation);
        assert!(state.ready().is_none());
        assert_eq!(state.finish(old, &good()), Finish::Ignored);
        state.close();
        assert_eq!(state.finish(fresh, &good()), Finish::Ignored);
        assert!(state.ready().is_none());
        assert!(state.activate());
        let newest = token(state.request());
        assert_eq!(state.finish(newest, &good()), Finish::Applied(1));
    }

    #[test]
    fn timeout_does_not_implicitly_reap_or_unlock_next_process() {
        let mut state = SnapshotRefresh::default();
        assert!(state.activate());
        let pending = token(state.request());
        assert!(state.expire(pending));
        assert_eq!(state.request(), Start::Queued);
        assert!(state.ready().is_none());
        // A forged, nonmatching completion cannot remove the old process.
        let forged = RefreshToken {
            generation: pending.generation,
            serial: pending.serial + 1,
        };
        assert!(!state.expire(forged));
        assert_eq!(state.finish(forged, &good()), Finish::Ignored);
        assert_eq!(state.request(), Start::Queued);
        let Finish::Restart(next) = state.finish(pending, &good()) else {
            panic!("restart only once after expired child reap");
        };
        let dirty = CandidateCapture {
            stderr: b"PRIVATE_FAKE_DIAGNOSTIC",
            ..good()
        };
        assert_eq!(
            state.finish(next, &dirty),
            Finish::Rejected(CaptureError::StandardErrorPresent)
        );
        assert!(state.ready().is_none());
    }

    #[test]
    fn timeout_without_new_request_never_promotes_late_valid_output() {
        let mut state = SnapshotRefresh::default();
        assert!(state.activate());
        let current = token(state.request());
        assert!(state.expire(current));
        // Timeout is NOT a reap event and must never make output ready.
        assert!(state.ready().is_none());
        assert_eq!(state.finish(current, &good()), Finish::Ignored);
        assert!(state.ready().is_none());
        let next = token(state.request());
        assert_ne!(next, current);
        assert_eq!(state.finish(next, &good()), Finish::Applied(1));
    }

    #[test]
    fn reopen_without_request_never_adopts_old_child_output() {
        let mut state = SnapshotRefresh::default();
        assert!(state.activate());
        let old = token(state.request());
        state.close();
        assert!(state.activate());
        // The new generation must explicitly request a fresh capture.
        assert_eq!(state.finish(old, &good()), Finish::Ignored);
        assert!(state.ready().is_none());
        let next = token(state.request());
        assert_ne!(next, old);
        assert_eq!(state.finish(next, &good()), Finish::Applied(1));
        state.close();
        assert!(state.ready().is_none());
    }

    #[test]
    fn all_short_fake_event_sequences_keep_the_reap_and_visibility_invariants() {
        // Bounded deterministic exploration: 8^5 event traces. No threads,
        // clocks, filesystem, subprocesses, accounts, or vendor binaries.
        const ACTIONS: u32 = 8;
        const DEPTH: usize = 5;
        for trace in 0..ACTIONS.pow(DEPTH as u32) {
            let mut code = trace;
            let mut state = SnapshotRefresh::default();
            let mut active = false;
            let mut live: Option<RefreshToken> = None;
            let mut old: Option<RefreshToken> = None;
            let mut expected_ready = false;
            for _ in 0..DEPTH {
                let action = code % ACTIONS;
                code /= ACTIONS;
                match action {
                    0 => {
                        let opened = state.activate();
                        assert_eq!(opened, !active, "trace={trace}");
                        if opened {
                            active = true;
                            expected_ready = false;
                        }
                    }
                    1 => {
                        state.close();
                        active = false;
                        expected_ready = false;
                    }
                    2 => {
                        match state.request() {
                            Start::Hidden => assert!(!active, "trace={trace}"),
                            Start::Started(next) => {
                                assert!(active && live.is_none(), "trace={trace}");
                                live = Some(next);
                            }
                            Start::Queued => {
                                assert!(active && live.is_some(), "trace={trace}");
                            }
                            Start::Exhausted => panic!("short trace unexpectedly overflowed"),
                        }
                        if active { expected_ready = false; }
                    }
                    3 => {
                        if let Some(current) = live {
                            assert!(state.expire(current), "trace={trace}");
                            expected_ready = false;
                        } else {
                            assert!(!state.expire(RefreshToken {
                                generation: 0, serial: 0,
                            }));
                        }
                    }
                    4 | 5 => {
                        if let Some(current) = live {
                            let broken = CandidateCapture {
                                stdout: b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced",
                                ..good()
                            };
                            let capture = if action == 4 { good() } else { broken };
                            let result = state.finish(current, &capture);
                            old = Some(current);
                            live = None;
                            match result {
                                Finish::Applied(1) => {
                                    assert_eq!(action, 4, "trace={trace}");
                                    expected_ready = true;
                                }
                                Finish::Restart(next) => {
                                    assert!(active && next != current, "trace={trace}");
                                    live = Some(next);
                                    expected_ready = false;
                                }
                                Finish::Rejected(
                                    CaptureError::InvalidTable(Error::Incomplete)
                                ) => expected_ready = false,
                                Finish::Ignored => expected_ready = false,
                                unexpected => panic!(
                                    "unexpected fake result {unexpected:?} trace={trace}"
                                ),
                            }
                        }
                    }
                    6 => {
                        let stale = old.unwrap_or(RefreshToken {
                            generation: 0, serial: 0,
                        });
                        let prior_ready = state.ready().is_some();
                        assert_eq!(
                            state.finish(stale, &good()), Finish::Ignored,
                            "trace={trace}"
                        );
                        assert_eq!(state.ready().is_some(), prior_ready);
                    }
                    7 => {
                        // Visibility inspection without changing the model.
                    }
                    _ => unreachable!(),
                }
                assert_eq!(state.active, active, "trace={trace} action={action}");
                assert_eq!(state.in_flight, live, "trace={trace} action={action}");
                assert_eq!(
                    state.ready().is_some(), expected_ready,
                    "trace={trace} action={action}"
                );
                if !active || live.is_some() {
                    assert!(state.ready().is_none(), "trace={trace}");
                }
            }
        }
    }

    #[test]
    fn monotonic_overflow_permanently_fails_closed() {
        let mut state = SnapshotRefresh::default();
        state.generation = u64::MAX;
        assert!(!state.activate());
        assert_eq!(state.request(), Start::Exhausted);
        assert!(state.ready().is_none());
        state.close();
        assert!(!state.activate());
        let mut serial = SnapshotRefresh::default();
        assert!(serial.activate());
        serial.serial = u64::MAX;
        assert_eq!(serial.request(), Start::Exhausted);
        assert!(!serial.activate());
        assert!(serial.ready().is_none());
    }
}
