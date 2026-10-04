//! Synthetic-only refresh ordering for unqualified Transfers snapshots.
//!
//! This is intentionally separate from the production CloudStorageService and
//! is not exposed to JSON/QML. External process supervision must call finish()
//! only after the corresponding child has been reaped.
#![allow(dead_code)]

use crate::column_fixtures::{
    CandidateCapture, CaptureError, TransferSnapshot, parse_transfer_snapshot_capture,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TransferRefreshToken {
    generation: u64,
    serial: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TransferStart {
    Hidden,
    Started(TransferRefreshToken),
    Queued,
    Exhausted,
}

#[derive(Debug, Eq, PartialEq)]
pub enum TransferFinish {
    Ignored,
    Restart(TransferRefreshToken),
    Applied(usize),
    Rejected(CaptureError),
}

/// Fake-only cache for transfer snapshots.
///
/// At most one simulated vendor child may be in flight. Closing, expiring or
/// superseding a request invalidates its result but does not clear in_flight;
/// only finish() after reap can release that lease.
#[derive(Debug, Default)]
pub struct TransferSnapshotRefresh {
    active: bool,
    poisoned: bool,
    generation: u64,
    serial: u64,
    in_flight: Option<TransferRefreshToken>,
    revoked: bool,
    queued: bool,
    snapshot: Option<TransferSnapshot>,
}

impl TransferSnapshotRefresh {
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
        self.revoked = self.in_flight.is_some();
        true
    }

    pub fn close(&mut self) {
        self.active = false;
        self.queued = false;
        self.snapshot = None;
        self.revoked = self.in_flight.is_some();
    }

    pub fn ready(&self) -> Option<&TransferSnapshot> {
        if !self.active || self.poisoned || self.in_flight.is_some()
            || self.revoked || self.queued {
            return None;
        }
        self.snapshot.as_ref()
    }

    fn poison(&mut self) {
        self.poisoned = true;
        self.active = false;
        self.queued = false;
        self.revoked = true;
        self.snapshot = None;
    }

    fn issue(&mut self) -> TransferStart {
        if self.poisoned {
            return TransferStart::Exhausted;
        }
        let Some(serial) = self.serial.checked_add(1) else {
            self.poison();
            return TransferStart::Exhausted;
        };
        self.serial = serial;
        let token = TransferRefreshToken {
            generation: self.generation,
            serial,
        };
        self.in_flight = Some(token);
        self.revoked = false;
        self.queued = false;
        self.snapshot = None;
        TransferStart::Started(token)
    }

    /// Coalesce refreshes while a child remains in flight.
    pub fn request(&mut self) -> TransferStart {
        if self.poisoned {
            return TransferStart::Exhausted;
        }
        if !self.active {
            return TransferStart::Hidden;
        }
        self.snapshot = None;
        if self.in_flight.is_some() {
            self.queued = true;
            return TransferStart::Queued;
        }
        self.issue()
    }

    /// Mark a request obsolete without claiming the child has exited.
    pub fn expire(&mut self, token: TransferRefreshToken) -> bool {
        if self.in_flight != Some(token) {
            return false;
        }
        self.revoked = true;
        self.snapshot = None;
        true
    }

    /// Call only after the matching child has exited and been reaped.
    pub fn finish(
        &mut self,
        token: TransferRefreshToken,
        capture: &CandidateCapture<'_>,
    ) -> TransferFinish {
        if self.in_flight != Some(token) {
            return TransferFinish::Ignored;
        }
        self.in_flight = None;
        let revoked = self.revoked;
        self.revoked = false;
        self.snapshot = None;

        if self.poisoned || !self.active {
            return TransferFinish::Ignored;
        }
        if self.queued {
            return match self.issue() {
                TransferStart::Started(next) => TransferFinish::Restart(next),
                _ => TransferFinish::Ignored,
            };
        }
        if revoked || token.generation != self.generation {
            return TransferFinish::Ignored;
        }

        match parse_transfer_snapshot_capture(capture) {
            Ok(snapshot) => {
                let count = snapshot.rows.len();
                self.snapshot = Some(snapshot);
                TransferFinish::Applied(count)
            }
            Err(err) => TransferFinish::Rejected(err),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::column_fixtures::{Error, TransferPause};

    fn good() -> CandidateCapture<'static> {
        CandidateCapture {
            stdout: "TYPE|TAG|STATE\n⇓|7|ACTIVE\n".as_bytes(),
            stderr: b"",
            exit_code: Some(0),
            timed_out: false,
            output_capped: false,
        }
    }

    fn token(start: TransferStart) -> TransferRefreshToken {
        let TransferStart::Started(token) = start else {
            panic!("expected started transfer refresh");
        };
        token
    }

    #[test]
    fn hidden_refresh_and_applied_snapshot_follow_visibility() {
        let mut state = TransferSnapshotRefresh::default();
        assert_eq!(state.request(), TransferStart::Hidden);
        assert!(state.activate());

        let first = token(state.request());
        assert!(state.ready().is_none());
        assert_eq!(state.finish(first, &good()), TransferFinish::Applied(1));
        let ready = state.ready().unwrap();
        assert_eq!(ready.rows.len(), 1);
        assert_eq!(ready.rows[0].tag, 7);

        state.close();
        assert!(state.ready().is_none());
        assert_eq!(state.request(), TransferStart::Hidden);
    }

    #[test]
    fn queued_refresh_waits_for_reap_and_rejects_stale_result() {
        let mut state = TransferSnapshotRefresh::default();
        assert!(state.activate());
        let old = token(state.request());

        assert_eq!(state.request(), TransferStart::Queued);
        assert_eq!(state.request(), TransferStart::Queued);
        assert!(state.ready().is_none());

        let TransferFinish::Restart(fresh) = state.finish(old, &good()) else {
            panic!("queued refresh must restart only after old reap");
        };
        assert_eq!(state.finish(old, &good()), TransferFinish::Ignored);
        assert!(state.ready().is_none());
        assert_eq!(state.finish(fresh, &good()), TransferFinish::Applied(1));
        assert_eq!(state.ready().unwrap().rows[0].tag, 7);
    }

    #[test]
    fn expired_or_closed_generation_never_becomes_visible() {
        let mut state = TransferSnapshotRefresh::default();
        assert!(state.activate());
        let old = token(state.request());
        assert!(state.expire(old));
        assert!(state.ready().is_none());
        assert_eq!(state.finish(old, &good()), TransferFinish::Ignored);

        let fresh = token(state.request());
        state.close();
        assert_eq!(state.finish(fresh, &good()), TransferFinish::Ignored);
        assert!(state.ready().is_none());

        assert!(state.activate());
        let newest = token(state.request());
        assert_eq!(state.finish(newest, &good()), TransferFinish::Applied(1));
    }

    #[test]
    fn empty_candidate_is_a_visible_zero_row_snapshot_only_after_clean_reap() {
        let mut state = TransferSnapshotRefresh::default();
        assert!(state.activate());
        let current = token(state.request());
        let empty = CandidateCapture {
            stdout: b"\n",
            ..good()
        };
        assert_eq!(state.finish(current, &empty), TransferFinish::Applied(0));
        let ready = state.ready().unwrap();
        assert_eq!(ready.pause, TransferPause::None);
        assert!(ready.rows.is_empty());
    }

    #[test]
    fn rejected_capture_clears_ready_state_and_never_reuses_old_snapshot() {
        let mut state = TransferSnapshotRefresh::default();
        assert!(state.activate());
        let first = token(state.request());
        assert_eq!(state.finish(first, &good()), TransferFinish::Applied(1));
        assert!(state.ready().is_some());

        let next = token(state.request());
        assert!(state.ready().is_none());
        let dirty = CandidateCapture {
            stderr: b"PRIVATE_FAKE_DIAGNOSTIC",
            ..good()
        };
        assert_eq!(
            state.finish(next, &dirty),
            TransferFinish::Rejected(CaptureError::StandardErrorPresent)
        );
        assert!(state.ready().is_none());

        let third = token(state.request());
        let truncated = CandidateCapture {
            stdout: "TYPE|TAG|STATE\n⇓|7|ACTIVE".as_bytes(),
            ..good()
        };
        assert_eq!(
            state.finish(third, &truncated),
            TransferFinish::Rejected(CaptureError::InvalidTable(Error::Incomplete))
        );
        assert!(state.ready().is_none());
    }

    #[test]
    fn serial_overflow_poisoning_fails_closed() {
        let mut state = TransferSnapshotRefresh::default();
        assert!(state.activate());
        state.serial = u64::MAX;
        assert_eq!(state.request(), TransferStart::Exhausted);
        assert!(state.ready().is_none());
        assert!(!state.activate());
    }
}
