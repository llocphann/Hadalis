pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.perimeter
import qs.modules.dashboard
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool panelVisible: true
    property bool directBottomAttachment: false
    property bool popupPresented: true
    property string searchingText: ""
    property real revealProgress: 0
    property real dashboardProgress: 1
    property real availableWidth: root.QsWindow?.window?.screen?.width ?? 1920
    property real availableHeight: root.QsWindow?.window?.screen?.height ?? 1080

    readonly property bool applicationDragActive: searchWidget.applicationDragActive
    readonly property bool searching: root.searchingText.length > 0
    readonly property real widthRatio: Math.min(0.9, Math.max(0.4, Config.options?.dashboard?.widthRatio ?? 0.72))
    readonly property real heightRatio: Math.min(0.9, Math.max(0.45, Config.options?.dashboard?.heightRatio ?? 0.72))
    readonly property real dashboardWidth: Math.round(Math.max(0,
        Math.min(root.availableWidth - 24, root.availableWidth * root.widthRatio)))
    readonly property bool editing: dashboardContent.editMode
    readonly property real editToolbarReserve: root.editing
        ? Math.max(0, dashboardEditToolbar.implicitHeight - 1) : 0
    readonly property real baseConfiguredHeight: Math.round(Math.min(
        Math.max(320, root.availableHeight - 24),
        Math.max(420, root.availableHeight * root.heightRatio)))
    readonly property real configuredHeight: Math.round(Math.max(320,
        Math.min(root.baseConfiguredHeight,
            root.availableHeight - 24 - root.editToolbarReserve)))
    readonly property real searchOnlyHeight: Math.min(root.configuredHeight, Math.max(searchWidget.collapsedHeight + 24, searchWidget.implicitHeight + 24))
    readonly property real dashboardContentHeight: Math.max(240, root.configuredHeight - searchWidget.collapsedHeight - 36)

    readonly property bool screenEdgeShadowEnabled: Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true
    readonly property real screenEdgeShadowSize: Math.max(0, Math.min(32, Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
    readonly property real screenEdgeShadowOpacity: Math.max(0, Math.min(1.0, Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70)))
    readonly property real connectedDecorationMargin: root.directBottomAttachment
        ? Math.max(Appearance.sizes.elevationMargin, PerimeterTokens.joinFlareRadius, root.screenEdgeShadowSize + 2)
        : Appearance.sizes.elevationMargin

    implicitWidth: dashContainer.width + root.connectedDecorationMargin * 2
    implicitHeight: dashContainer.height + root.editToolbarReserve
        + (root.directBottomAttachment
            ? root.connectedDecorationMargin
            : root.connectedDecorationMargin * 2)
    clip: root.directBottomAttachment
    readonly property rect connectedSurfaceRect: Qt.rect(dashContainer.x, dashContainer.y, dashContainer.width, dashContainer.height)
    readonly property color connectedSurfaceColor: dashContainer.color

    function focusSearchInput(): void { searchWidget.focusSearchInput() }
    function disableExpandAnimation(): void { searchWidget.disableExpandAnimation() }
    function cancelSearch(): void { searchWidget.cancelSearch() }
    function focusFirstItem(): void { searchWidget.focusFirstItem() }
    function setSearchingText(text): void { searchWidget.setSearchingText(text) }
    function syncReveal(): void { root.revealProgress = root.popupPresented ? 1 : 0 }
    function syncDashboard(): void { root.dashboardProgress = root.searching ? 0 : 1 }
    onPopupPresentedChanged: root.syncReveal()
    onSearchingChanged: root.syncDashboard()

    Component.onCompleted: {
        root.revealProgress = 0
        root.dashboardProgress = root.searching ? 0 : 1
        Qt.callLater(root.syncReveal)
    }

    Behavior on revealProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: SurfaceMotion.duration; easing.type: SurfaceMotion.easingType }
    }
    Behavior on dashboardProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: SurfaceMotion.duration; easing.type: SurfaceMotion.easingType }
    }

    Item {
        id: dashboardSurfaceLayer
        anchors.fill: parent
        transform: Translate { y: (1 - root.revealProgress) * dashContainer.height }
    }

    StyledRectangularShadow {
        parent: dashboardSurfaceLayer
        z: 0
        target: dashContainer
        visible: root.panelVisible && root.screenEdgeShadowEnabled && root.screenEdgeShadowSize > 0 && root.screenEdgeShadowOpacity > 0
        blur: root.screenEdgeShadowSize
        spread: 0
        offset: Qt.vector2d(0, 0)
        color: ColorUtils.applyAlpha(Appearance.colors.colShadow, root.screenEdgeShadowOpacity)
        joinBottom: root.directBottomAttachment
    }

    ConnectedSurfaceJoinFlares {
        parent: dashboardSurfaceLayer
        z: 5
        anchors.fill: parent
        bodyItem: dashContainer
        fillColor: dashContainer.color
        flareRadius: PerimeterTokens.joinFlareRadius
        progress: root.revealProgress > 0.001 ? 1 : 0
        joinBottom: root.directBottomAttachment
    }

    DashboardEditToolbar {
        id: dashboardEditToolbar
        parent: dashboardSurfaceLayer
        z: 8
        canvasController: dashboardContent.canvasController
        width: Math.min(
            dashboardEditToolbar.implicitWidth,
            Math.max(1, dashContainer.width - 32))
        x: Math.round(dashContainer.x
            + (dashContainer.width - width) / 2)
        y: Math.round(dashContainer.y - height + 1)
    }

    Rectangle {
        id: dashContainer
        parent: dashboardSurfaceLayer
        z: 1
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: root.directBottomAttachment ? parent.bottom : undefined
            verticalCenter: root.directBottomAttachment ? undefined : parent.verticalCenter
        }
        width: root.dashboardWidth
        height: root.searching ? root.searchOnlyHeight : root.configuredHeight
        radius: Appearance.rounding.large
        topLeftRadius: radius
        topRightRadius: radius
        bottomLeftRadius: root.directBottomAttachment ? 0 : radius
        bottomRightRadius: root.directBottomAttachment ? 0 : radius
        color: Appearance.colors.colLayer0
        clip: true

        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: SurfaceMotion.duration; easing.type: SurfaceMotion.easingType }
        }

        Item {
            id: dashboardViewport
            x: 12
            y: 12
            width: Math.max(0, dashContainer.width - 24)
            height: root.dashboardContentHeight
            clip: true
            visible: root.dashboardProgress > 0.001
            opacity: root.dashboardProgress

            DashboardContent {
                id: dashboardContent
                anchors.fill: parent
                embeddedSurface: true
                presentationActive: root.panelVisible && root.popupPresented && root.dashboardProgress > 0.001
                screenWidth: root.availableWidth
                screenHeight: root.availableHeight
            }
        }

        SearchWidget {
            id: searchWidget
            x: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: Math.max(0, dashContainer.width - 24)
            height: implicitHeight
            embeddedSurface: true
            panelVisible: root.panelVisible
            directBottomAttachment: false
            searchingText: root.searchingText
            resultsOpacity: 1 - root.dashboardProgress
            availableHeight: Math.max(220, root.configuredHeight - 24)
            onSearchingTextChanged: if (searchingText !== root.searchingText) root.searchingText = searchingText
        }
    }
}
