//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1

import QtQuick
import Quickshell
import qs.modules.abyss.companion

// Development-only Wull renderer/attachment entry point. Keep this at the
// repository root so Quickshell resolves qs.modules.* against the Hadalis
// shell root exactly like the shipped standalone entry points.
AbyssCompanionProof {
}
