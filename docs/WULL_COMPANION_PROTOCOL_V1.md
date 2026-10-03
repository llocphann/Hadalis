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

## Optional local-model intent adapter

State messages additionally include `expression`: `idle`, `happy`, `excited`, `thinking`, `working`, `surprised`, `sleepy`, `sad`, or `alert`. Older QML clients ignore it; newer QML clients derive it from mood/activity when talking to an older daemon.

A future small local model may suggest one bounded semantic reaction:

```json
{"v":1,"seq":2,"type":"intent","expression":"thinking","intensity":0.45,"ttl_ms":1600}
```

The adapter calls `CompanionBridge.sendIntent(expression, intensity, ttlMs)` on the existing single stdio bridge. The model must not create another writer/daemon or supply protocol sequence numbers. Intensity is a finite number in 0..1; TTL is an integer in 250..10000 ms. Invalid records do not consume sequence numbers. Hidden hosts ignore intents and schedule no work. Repeated intents replace the temporary reaction while preserving the original state. Expiry restores that state, including an ongoing task; shell events preempt the overlay. Rust owns deadlines, QML owns interpolation.

No model, inference runtime, conversation history, network endpoint, or command/tool execution is installed by this change. The eventual adapter runs inference only for an explicit conversation or meaningful event, validates structured output, and forwards this vocabulary. Model size and CPU/RAM budgets must be measured on the target machine before choosing a model.
