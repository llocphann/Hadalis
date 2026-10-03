# Wull liquid-glass design preview

Source: `0a639e67498ebf484f2f7854bf21f2ab0e5ba3e6`, branch `dev`.

![Actual procedural GPU renderer](gallery.png)

[Motion demonstration](motion.mp4): 180 real QML captures encoded as a 9-second, 20 fps video. Encoding cadence is a presentation choice, not measured runtime frame pacing. All nine expressions, local motion, positive shine, position interpolation and fade-out appear in the sequence.

[Software fallback](software-fallback.png) is a separate Qt software capture with the same contour/face vocabulary and simpler material. The normal renderer uses the bundled shader.

[Provenance](provenance.json) records artifact digests and immutable renderer/native source blobs. These files are development evidence and are never loaded as runtime character art. Only the gallery's own QML item was captured, with isolated config/data/cache. The core daemon was not launched by the gallery; a separate real stdio process test exercised nine intents, TTL restoration of a waiting task and quiet hide.

Status: **MANUAL VALIDATED / source renderer preview**. Maintainer resemblance approval, native production panel/popup/input acceptance and resource qualification are pending. Production Wull remains default-off. See [design and remaining acceptance](../../WULL_REFERENCE_DESIGN.md).
