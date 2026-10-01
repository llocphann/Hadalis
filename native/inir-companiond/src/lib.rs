use std::io::{self, BufRead};

use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u32 = 1;
pub const MAX_LINE_BYTES: usize = 8 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Visibility {
    Hidden,
    Peeking,
    Present,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Mood {
    Calm,
    Happy,
    Curious,
    Focused,
    Sleepy,
    Concerned,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Activity {
    Idle,
    Thinking,
    Working,
    Success,
    Warning,
    Error,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BodyTargets {
    pub squash: f32,
    pub stretch: f32,
    pub lean: f32,
    pub tip: f32,
    pub ripple: f32,
}

impl Default for BodyTargets {
    fn default() -> Self {
        Self {
            squash: 0.0,
            stretch: 0.0,
            lean: 0.0,
            tip: 0.0,
            ripple: 0.0,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FaceTargets {
    pub eye: f32,
    pub mouth: f32,
}

impl Default for FaceTargets {
    fn default() -> Self {
        Self {
            eye: 1.0,
            mouth: 0.12,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct StateSnapshot {
    pub visibility: Visibility,
    pub mood: Mood,
    pub activity: Activity,
    pub energy: f32,
    pub gaze: [f32; 2],
    pub body: BodyTargets,
    pub face: FaceTargets,
    pub pulse: f32,
}

impl StateSnapshot {
    fn dormant() -> Self {
        Self {
            visibility: Visibility::Hidden,
            mood: Mood::Calm,
            activity: Activity::Idle,
            energy: 0.0,
            gaze: [0.0, 0.0],
            body: BodyTargets::default(),
            face: FaceTargets::default(),
            pulse: 0.0,
        }
    }

    fn settle(&mut self) {
        self.mood = Mood::Calm;
        self.activity = Activity::Idle;
        self.energy = 0.22;
        self.gaze = [0.0, 0.0];
        self.body = BodyTargets::default();
        self.face = FaceTargets::default();
        self.pulse = 0.0;
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct StateMessage {
    pub v: u32,
    pub seq: u64,
    #[serde(rename = "type")]
    pub kind: &'static str,
    #[serde(flatten)]
    pub state: StateSnapshot,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    Show,
    Hide,
    Hover,
    Click,
    SurfaceOpen,
    SurfaceClose,
    TaskStart,
    TaskSuccess,
    Warning,
    Error,
    Sleep,
    Wake,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SemanticEvent {
    pub seq: u64,
    pub event: EventKind,
    pub active: Option<bool>,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum ClientMessage {
    Event {
        v: u32,
        seq: u64,
        event: EventKind,
        #[serde(default)]
        active: Option<bool>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProtocolError {
    Empty,
    Oversized,
    Malformed,
    UnsupportedVersion,
    NonMonotonicSequence,
    MissingActive,
}

impl ProtocolError {
    pub const fn code(self) -> &'static str {
        match self {
            Self::Empty => "empty",
            Self::Oversized => "oversized",
            Self::Malformed => "malformed",
            Self::UnsupportedVersion => "unsupported_version",
            Self::NonMonotonicSequence => "non_monotonic_sequence",
            Self::MissingActive => "missing_active",
        }
    }
}

pub fn parse_event_line(
    line: &[u8],
    last_sequence: Option<u64>,
) -> Result<SemanticEvent, ProtocolError> {
    if line.is_empty() {
        return Err(ProtocolError::Empty);
    }
    if line.len() > MAX_LINE_BYTES {
        return Err(ProtocolError::Oversized);
    }

    let message: ClientMessage =
        serde_json::from_slice(line).map_err(|_| ProtocolError::Malformed)?;
    match message {
        ClientMessage::Event {
            v,
            seq,
            event,
            active,
        } => {
            if v != PROTOCOL_VERSION {
                return Err(ProtocolError::UnsupportedVersion);
            }
            if last_sequence.is_some_and(|last| seq <= last) {
                return Err(ProtocolError::NonMonotonicSequence);
            }
            if event == EventKind::Hover && active.is_none() {
                return Err(ProtocolError::MissingActive);
            }
            Ok(SemanticEvent { seq, event, active })
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BoundedLine {
    Line(Vec<u8>),
    Oversized,
}

pub fn read_bounded_line<R: BufRead>(reader: &mut R) -> io::Result<Option<BoundedLine>> {
    let mut output = Vec::with_capacity(256);
    let mut oversized = false;
    let mut saw_any = false;

    loop {
        let buffer = reader.fill_buf()?;
        if buffer.is_empty() {
            if !saw_any {
                return Ok(None);
            }
            return Ok(Some(if oversized {
                BoundedLine::Oversized
            } else {
                BoundedLine::Line(output)
            }));
        }

        saw_any = true;
        let newline = buffer.iter().position(|byte| *byte == b'\n');
        let take = newline.map_or(buffer.len(), |index| index + 1);

        if !oversized {
            let remaining = MAX_LINE_BYTES.saturating_sub(output.len());
            if take > remaining {
                if remaining > 0 {
                    output.extend_from_slice(&buffer[..remaining]);
                }
                oversized = true;
            } else {
                output.extend_from_slice(&buffer[..take]);
            }
        }

        reader.consume(take);
        if newline.is_some() {
            return Ok(Some(if oversized {
                BoundedLine::Oversized
            } else {
                BoundedLine::Line(output)
            }));
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Phase {
    Dormant,
    Idle,
    Curious,
    Engage,
    React,
    Settle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ScheduledAction {
    Settle,
    BlinkClose,
    BlinkOpen,
    IdleCuriosity,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Scheduled {
    at_ms: u64,
    action: ScheduledAction,
}

pub struct Engine {
    state: StateSnapshot,
    phase: Phase,
    last_input_seq: Option<u64>,
    next_output_seq: u64,
    scheduled: Option<Scheduled>,
    rng_state: u64,
}

impl Engine {
    pub fn new(seed: u64) -> Self {
        Self {
            state: StateSnapshot::dormant(),
            phase: Phase::Dormant,
            last_input_seq: None,
            next_output_seq: 1,
            scheduled: None,
            rng_state: if seed == 0 {
                0x9e37_79b9_7f4a_7c15
            } else {
                seed
            },
        }
    }

    pub fn state(&self) -> &StateSnapshot {
        &self.state
    }

    pub const fn phase(&self) -> Phase {
        self.phase
    }

    pub fn next_deadline_ms(&self) -> Option<u64> {
        self.scheduled.map(|scheduled| scheduled.at_ms)
    }

    pub fn initial_message(&mut self) -> StateMessage {
        self.next_message()
    }

    pub fn apply_line(
        &mut self,
        line: &[u8],
        now_ms: u64,
    ) -> Result<StateMessage, ProtocolError> {
        let event = parse_event_line(line, self.last_input_seq)?;
        self.last_input_seq = Some(event.seq);
        self.apply_event(event, now_ms);
        Ok(self.next_message())
    }

    pub fn tick(&mut self, now_ms: u64) -> Option<StateMessage> {
        let scheduled = self.scheduled?;
        if now_ms < scheduled.at_ms {
            return None;
        }
        self.scheduled = None;

        match scheduled.action {
            ScheduledAction::Settle => {
                if self.state.visibility == Visibility::Hidden {
                    self.phase = Phase::Dormant;
                } else {
                    self.phase = Phase::Settle;
                    self.state.settle();
                    self.schedule_idle(now_ms);
                }
            }
            ScheduledAction::BlinkClose => {
                if self.state.visibility != Visibility::Present {
                    return None;
                }
                self.state.face.eye = 0.08;
                self.scheduled = Some(Scheduled {
                    at_ms: now_ms.saturating_add(120),
                    action: ScheduledAction::BlinkOpen,
                });
            }
            ScheduledAction::BlinkOpen => {
                if self.state.visibility != Visibility::Present {
                    return None;
                }
                self.state.face.eye = 1.0;
                self.schedule_idle(now_ms);
            }
            ScheduledAction::IdleCuriosity => {
                if self.state.visibility != Visibility::Present {
                    return None;
                }
                self.phase = Phase::Curious;
                self.state.mood = Mood::Curious;
                self.state.energy = 0.30;
                self.state.body.lean = 0.10;
                self.state.body.tip = 0.14;
                self.scheduled = Some(Scheduled {
                    at_ms: now_ms.saturating_add(700),
                    action: ScheduledAction::Settle,
                });
            }
        }

        Some(self.next_message())
    }

    fn apply_event(&mut self, event: SemanticEvent, now_ms: u64) {
        match event.event {
            EventKind::Show | EventKind::Wake => {
                self.state.visibility = Visibility::Present;
                self.state.settle();
                self.phase = Phase::Idle;
                self.schedule_idle(now_ms);
            }
            EventKind::Hide => {
                self.state = StateSnapshot::dormant();
                self.phase = Phase::Dormant;
                self.scheduled = None;
            }
            EventKind::Hover => {
                self.state.visibility = Visibility::Present;
                if event.active.unwrap_or(false) {
                    self.phase = Phase::Curious;
                    self.state.mood = Mood::Curious;
                    self.state.activity = Activity::Idle;
                    self.state.energy = 0.48;
                    self.state.body.lean = 0.12;
                    self.state.body.tip = 0.16;
                    self.scheduled = None;
                } else {
                    self.phase = Phase::Settle;
                    self.state.settle();
                    self.schedule_idle(now_ms);
                }
            }
            EventKind::Click => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::React;
                self.state.mood = Mood::Happy;
                self.state.activity = Activity::Idle;
                self.state.energy = 0.90;
                self.state.body.squash = 0.85;
                self.state.body.stretch = -0.20;
                self.state.body.ripple = 0.85;
                self.state.face.mouth = 0.55;
                self.state.pulse = 0.80;
                self.schedule_settle(now_ms, 650);
            }
            EventKind::SurfaceOpen => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::Engage;
                self.state.mood = Mood::Focused;
                self.state.activity = Activity::Working;
                self.state.energy = 0.46;
                self.state.body.lean = 0.18;
                self.state.body.tip = 0.20;
                self.state.pulse = 0.20;
                self.schedule_settle(now_ms, 1_600);
            }
            EventKind::SurfaceClose => {
                self.phase = Phase::Settle;
                self.state.settle();
                self.schedule_idle(now_ms);
            }
            EventKind::TaskStart => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::Engage;
                self.state.mood = Mood::Focused;
                self.state.activity = Activity::Working;
                self.state.energy = 0.38;
                self.state.body.lean = 0.08;
                self.scheduled = None;
            }
            EventKind::TaskSuccess => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::React;
                self.state.mood = Mood::Happy;
                self.state.activity = Activity::Success;
                self.state.energy = 0.82;
                self.state.body.stretch = 0.24;
                self.state.body.ripple = 0.65;
                self.state.face.mouth = 0.68;
                self.state.pulse = 0.72;
                self.schedule_settle(now_ms, 900);
            }
            EventKind::Warning => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::React;
                self.state.mood = Mood::Concerned;
                self.state.activity = Activity::Warning;
                self.state.energy = 0.52;
                self.state.body.squash = 0.18;
                self.state.face.mouth = -0.20;
                self.state.pulse = 0.52;
                self.schedule_settle(now_ms, 1_300);
            }
            EventKind::Error => {
                self.state.visibility = Visibility::Present;
                self.phase = Phase::React;
                self.state.mood = Mood::Concerned;
                self.state.activity = Activity::Error;
                self.state.energy = 0.64;
                self.state.body.squash = 0.28;
                self.state.body.ripple = 0.32;
                self.state.face.mouth = -0.34;
                self.state.pulse = 0.90;
                self.schedule_settle(now_ms, 1_600);
            }
            EventKind::Sleep => {
                self.state.visibility = Visibility::Peeking;
                self.phase = Phase::Idle;
                self.state.mood = Mood::Sleepy;
                self.state.activity = Activity::Idle;
                self.state.energy = 0.04;
                self.state.body = BodyTargets::default();
                self.state.face.eye = 0.28;
                self.state.face.mouth = 0.02;
                self.state.pulse = 0.0;
                self.scheduled = None;
            }
        }
    }

    fn schedule_settle(&mut self, now_ms: u64, delay_ms: u64) {
        self.scheduled = Some(Scheduled {
            at_ms: now_ms.saturating_add(delay_ms),
            action: ScheduledAction::Settle,
        });
    }

    fn schedule_idle(&mut self, now_ms: u64) {
        if self.state.visibility != Visibility::Present {
            self.scheduled = None;
            return;
        }

        let random = self.next_random();
        let delay_ms = 6_000 + (random % 5_001);
        let action = if random % 5 == 0 {
            ScheduledAction::IdleCuriosity
        } else {
            ScheduledAction::BlinkClose
        };
        self.scheduled = Some(Scheduled {
            at_ms: now_ms.saturating_add(delay_ms),
            action,
        });
    }

    fn next_random(&mut self) -> u64 {
        let mut x = self.rng_state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.rng_state = x;
        x
    }

    fn next_message(&mut self) -> StateMessage {
        let seq = self.next_output_seq;
        self.next_output_seq = self.next_output_seq.saturating_add(1);
        StateMessage {
            v: PROTOCOL_VERSION,
            seq,
            kind: "state",
            state: self.state.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::{
        Activity, BoundedLine, Engine, MAX_LINE_BYTES, Mood, Phase, ProtocolError, Visibility,
        parse_event_line, read_bounded_line,
    };

    #[test]
    fn protocol_rejects_unknown_version_and_non_monotonic_sequence() {
        let unsupported =
            br#"{"v":2,"seq":1,"type":"event","event":"show"}"#;
        assert_eq!(
            parse_event_line(unsupported, None),
            Err(ProtocolError::UnsupportedVersion)
        );

        let repeated =
            br#"{"v":1,"seq":7,"type":"event","event":"show"}"#;
        assert_eq!(
            parse_event_line(repeated, Some(7)),
            Err(ProtocolError::NonMonotonicSequence)
        );
    }

    #[test]
    fn hover_requires_explicit_active_state() {
        let missing =
            br#"{"v":1,"seq":1,"type":"event","event":"hover"}"#;
        assert_eq!(
            parse_event_line(missing, None),
            Err(ProtocolError::MissingActive)
        );
    }

    #[test]
    fn malformed_input_does_not_consume_sequence() {
        let mut engine = Engine::new(1);
        assert_eq!(
            engine.apply_line(b"{not-json}", 0),
            Err(ProtocolError::Malformed)
        );

        let accepted = engine
            .apply_line(br#"{"v":1,"seq":1,"type":"event","event":"show"}"#, 0)
            .expect("valid event should still be accepted");
        assert_eq!(accepted.seq, 1);
        assert_eq!(accepted.state.visibility, Visibility::Present);
    }

    #[test]
    fn hidden_state_has_no_scheduled_wakeup() {
        let mut engine = Engine::new(2);
        assert_eq!(engine.phase(), Phase::Dormant);
        assert_eq!(engine.next_deadline_ms(), None);

        engine
            .apply_line(br#"{"v":1,"seq":1,"type":"event","event":"show"}"#, 100)
            .expect("show");
        assert!(engine.next_deadline_ms().is_some());

        engine
            .apply_line(br#"{"v":1,"seq":2,"type":"event","event":"hide"}"#, 200)
            .expect("hide");
        assert_eq!(engine.state().visibility, Visibility::Hidden);
        assert_eq!(engine.phase(), Phase::Dormant);
        assert_eq!(engine.next_deadline_ms(), None);
    }

    #[test]
    fn click_reacts_then_settles() {
        let mut engine = Engine::new(3);
        engine
            .apply_line(br#"{"v":1,"seq":1,"type":"event","event":"show"}"#, 0)
            .expect("show");
        let reaction = engine
            .apply_line(br#"{"v":1,"seq":2,"type":"event","event":"click"}"#, 10)
            .expect("click");

        assert_eq!(engine.phase(), Phase::React);
        assert_eq!(reaction.state.mood, Mood::Happy);
        assert!(reaction.state.body.squash > 0.8);
        assert!(reaction.state.pulse > 0.7);

        let deadline = engine.next_deadline_ms().expect("settle deadline");
        let settled = engine.tick(deadline).expect("settle state");
        assert_eq!(settled.state.mood, Mood::Calm);
        assert_eq!(settled.state.activity, Activity::Idle);
        assert_eq!(settled.state.pulse, 0.0);
        assert!(engine.next_deadline_ms().is_some());
    }

    #[test]
    fn deterministic_seed_produces_same_idle_deadline() {
        let mut first = Engine::new(0x1234);
        let mut second = Engine::new(0x1234);
        for engine in [&mut first, &mut second] {
            engine
                .apply_line(br#"{"v":1,"seq":1,"type":"event","event":"show"}"#, 500)
                .expect("show");
        }
        assert_eq!(first.next_deadline_ms(), second.next_deadline_ms());
    }

    #[test]
    fn task_state_waits_for_semantic_completion_without_polling() {
        let mut engine = Engine::new(4);
        let working = engine
            .apply_line(
                br#"{"v":1,"seq":1,"type":"event","event":"task_start"}"#,
                0,
            )
            .expect("task start");
        assert_eq!(working.state.activity, Activity::Working);
        assert_eq!(engine.next_deadline_ms(), None);

        let success = engine
            .apply_line(
                br#"{"v":1,"seq":2,"type":"event","event":"task_success"}"#,
                100,
            )
            .expect("task success");
        assert_eq!(success.state.activity, Activity::Success);
        assert!(engine.next_deadline_ms().is_some());
    }

    #[test]
    fn bounded_reader_discards_oversized_record_and_recovers() {
        let valid = b"{\"v\":1,\"seq\":1,\"type\":\"event\",\"event\":\"show\"}\n";
        let mut bytes = vec![b'x'; MAX_LINE_BYTES + 32];
        bytes.push(b'\n');
        bytes.extend_from_slice(valid);

        let mut cursor = Cursor::new(bytes);
        assert_eq!(
            read_bounded_line(&mut cursor).expect("first read"),
            Some(BoundedLine::Oversized)
        );
        assert_eq!(
            read_bounded_line(&mut cursor).expect("second read"),
            Some(BoundedLine::Line(valid.to_vec()))
        );
    }
}
