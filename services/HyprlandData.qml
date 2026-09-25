pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    property bool _clientsRefreshQueued: false
    property bool _monitorsRefreshQueued: false
    property bool _layersRefreshQueued: false
    property bool _workspacesRefreshQueued: false

    function updateWindowList() {
        if (!CompositorService.isHyprland)
            return;
        if (getClients.running) {
            root._clientsRefreshQueued = true
            return
        }
        root._clientsRefreshQueued = false
        getClients.running = true;
    }

    function updateLayers() {
        if (!CompositorService.isHyprland)
            return;
        if (getLayers.running) {
            root._layersRefreshQueued = true
            return
        }
        root._layersRefreshQueued = false
        getLayers.running = true;
    }

    function updateMonitors() {
        if (!CompositorService.isHyprland)
            return;
        if (getMonitors.running) {
            root._monitorsRefreshQueued = true
            return
        }
        root._monitorsRefreshQueued = false
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        if (!CompositorService.isHyprland)
            return;
        if (getWorkspaces.running || getActiveWorkspace.running) {
            root._workspacesRefreshQueued = true
            return
        }
        root._workspacesRefreshQueued = false
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        if (!CompositorService.isHyprland)
            return;
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    function _finishClientsRefresh() {
        if (!root._clientsRefreshQueued)
            return
        root._clientsRefreshQueued = false
        Qt.callLater(() => root.updateWindowList())
    }

    function _finishMonitorsRefresh() {
        if (!root._monitorsRefreshQueued)
            return
        root._monitorsRefreshQueued = false
        Qt.callLater(() => root.updateMonitors())
    }

    function _finishLayersRefresh() {
        if (!root._layersRefreshQueued)
            return
        root._layersRefreshQueued = false
        Qt.callLater(() => root.updateLayers())
    }

    function _finishWorkspacesRefresh() {
        if (getWorkspaces.running || getActiveWorkspace.running
                || !root._workspacesRefreshQueued)
            return
        root._workspacesRefreshQueued = false
        Qt.callLater(() => root.updateWorkspaces())
    }

    function biggestWindowForWorkspace(workspaceId) {
        if (workspaceId === null || workspaceId === undefined)
            return null;
        const windowsInThisWorkspace = HyprlandData.windowList.filter(
            w => w?.workspace?.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        if (!CompositorService.isHyprland)
            return;
        updateAll();
    }

    Connections {
        target: Hyprland
        enabled: CompositorService.isHyprland

        function onRawEvent(event) {
            // console.log("Hyprland raw event:", event.name);
            updateAll()
        }
    }

    Process {
        id: getClients
        property bool startObserved: false
        command: ["/usr/bin/hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(clientsCollector.text)
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse clients JSON:", e);
                    root.windowList = [];
                }
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
        onRunningChanged: {
            if (getClients.running) {
                getClients.startObserved = false
                return
            }
            if (getClients.startObserved)
                return
            root._finishClientsRefresh()
        }
        onStarted: getClients.startObserved = true
        onExited: root._finishClientsRefresh()
    }

    Process {
        id: getMonitors
        property bool startObserved: false
        command: ["/usr/bin/hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(monitorsCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse monitors JSON:", e);
                    root.monitors = [];
                }
            }
        }
        onRunningChanged: {
            if (getMonitors.running) {
                getMonitors.startObserved = false
                return
            }
            if (getMonitors.startObserved)
                return
            root._finishMonitorsRefresh()
        }
        onStarted: getMonitors.startObserved = true
        onExited: root._finishMonitorsRefresh()
    }

    Process {
        id: getLayers
        property bool startObserved: false
        command: ["/usr/bin/hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(layersCollector.text);
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse layers JSON:", e);
                    root.layers = {};
                }
            }
        }
        onRunningChanged: {
            if (getLayers.running) {
                getLayers.startObserved = false
                return
            }
            if (getLayers.startObserved)
                return
            root._finishLayersRefresh()
        }
        onStarted: getLayers.startObserved = true
        onExited: root._finishLayersRefresh()
    }

    Process {
        id: getWorkspaces
        property bool startObserved: false
        command: ["/usr/bin/hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(workspacesCollector.text)
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse workspaces JSON:", e);
                    root.workspaces = [];
                }
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
        onRunningChanged: {
            if (getWorkspaces.running) {
                getWorkspaces.startObserved = false
                return
            }
            if (getWorkspaces.startObserved)
                return
            root._finishWorkspacesRefresh()
        }
        onStarted: getWorkspaces.startObserved = true
        onExited: root._finishWorkspacesRefresh()
    }

    Process {
        id: getActiveWorkspace
        property bool startObserved: false
        command: ["/usr/bin/hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                try {
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text)
                } catch (e) {
                    console.log("[HyprlandData] Failed to parse active workspace JSON:", e);
                    root.activeWorkspace = null;
                }
            }
        }
        onRunningChanged: {
            if (getActiveWorkspace.running) {
                getActiveWorkspace.startObserved = false
                return
            }
            if (getActiveWorkspace.startObserved)
                return
            root._finishWorkspacesRefresh()
        }
        onStarted: getActiveWorkspace.startObserved = true
        onExited: root._finishWorkspacesRefresh()
    }
}
