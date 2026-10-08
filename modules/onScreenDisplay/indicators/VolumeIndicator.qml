import qs.services
import QtQuick
import qs.modules.onScreenDisplay

OsdValueIndicator {
    id: osdValues
    value: Audio.osdSinkVolume
    icon: Audio.sink?.audio.muted ? "volume_off" : "volume_up"
    name: Translation.tr("Volume")
}
