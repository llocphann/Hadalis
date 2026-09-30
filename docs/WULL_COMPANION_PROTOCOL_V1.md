# Wull companion protocol v1

Transport candidate: newline-delimited JSON over one long-lived stdio child process. This contract is intentionally small enough to validate before production integration.

Daemon -> QML state message:

```json
{"v":1,"seq":1,"type":"state","visibility":"present","mood":"calm","activity":"idle","energy":0.35,"gaze":[0.0,0.0],"body":{"squash":0.0,"stretch":0.0,"lean":0.0,"tip":0.0,"ripple":0.0},"face":{"eye":1.0,"mouth":0.15},"pulse":0.0}
```

QML -> daemon semantic event:

```json
{"v":1,"seq":1,"type":"event","event":"hover","active":true}
```

Rules: one JSON object per line; `v` and monotonic `seq` required; messages are semantic state/events only, never frames or pixels; unknown fields are ignored; unknown versions/types are rejected; malformed or oversized input must not terminate the daemon; hidden state must not require periodic QML updates.
