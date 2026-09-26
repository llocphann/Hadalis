pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.common

// Thin wrapper for backwards compatibility. All consumers historically
// instantiated their own CavaProcess { active: ...; points }, which spawned
// a subprocess per consumer. The actual cava lifecycle now lives in
// services/CavaService.qml — see #160.
//
// This component just holds a shared ServiceLease and exposes the same public
// CavaProcess API as before.
Item {
    id: root

    property bool active: false
    property int sampleCount: 0
    readonly property var _emptyPoints: []
    readonly property bool _wanted: active && !Appearance.gameModeMinimal

    property QtObject _serviceLease: ServiceLease {
        active: root._wanted
        value: root.sampleCount
        acquire: count => CavaService.subscribe(count)
        update: (token, count) => {
            CavaService.updateSubscription(token, count)
            return token
        }
        release: token => CavaService.unsubscribe(token)
    }

    readonly property bool _held: root._serviceLease.held
    readonly property bool held: root._held
    readonly property int _subscriptionId:
        root._serviceLease.token === null || root._serviceLease.token === undefined
            ? -1 : Number(root._serviceLease.token)

    readonly property var points: root._held ? CavaService.points : root._emptyPoints
    readonly property real normalizationCeiling: root._held
        ? CavaService.normalizationCeiling : 100
    readonly property bool audioSignalActive: root._held
        ? CavaService.audioSignalActive : false
}
