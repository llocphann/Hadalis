pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.mediaControls

Item {
    id: root
    property alias inputField: searchField
    property string section: "songs"

    readonly property string query: searchField.text.trim().toLowerCase()
    readonly property var filteredTracks: {
        if (!root.query) return LocalMusic.libraryTracks
        return LocalMusic.libraryTracks.filter(track => {
            const haystack = [track?.title, track?.artist, track?.album, track?.folder]
                .map(value => String(value ?? "").toLowerCase()).join(" ")
            return haystack.includes(root.query)
        })
    }

    function formatTime(seconds): string {
        const value = Math.max(0, Math.floor(Number(seconds) || 0))
        const minutes = Math.floor(value / 60)
        const rest = value % 60
        return minutes + ":" + (rest < 10 ? "0" : "") + rest
    }

    function sectionIndex(): int {
        switch (root.section) {
        case "playlists": return 1
        case "queue": return 2
        case "lyrics": return 3
        default: return 0
        }
    }

    CavaProcess {
        id: localMusicCava
        active: root.visible && LocalMusic.mprisAvailable && LocalMusic.playing
        sampleCount: 64
    }

    component ToolIconButton: RippleButton {
        id: toolButton
        property string symbol: ""
        property string tip: ""
        implicitWidth: 38
        implicitHeight: 38
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: toolButton.symbol
            iconSize: 20
            color: Appearance.colors.colOnLayer1
        }
        StyledToolTip { text: toolButton.tip }
    }

    component TrackRow: Rectangle {
        id: trackRow
        required property var track
        required property int trackIndex
        property bool active: String(track?.path ?? "") === LocalMusic.currentPath
        signal activated()

        implicitHeight: 62
        radius: Appearance.rounding.small
        color: active ? Appearance.colors.colSecondaryContainer
            : (rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                clip: true
                Image {
                    anchors.fill: parent
                    source: String(trackRow.track?.art ?? "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source.toString().length > 0
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: String(trackRow.track?.art ?? "").length === 0
                    text: trackRow.active && LocalMusic.playing ? "graphic_eq" : "music_note"
                    iconSize: 23
                    color: trackRow.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                StyledText {
                    Layout.fillWidth: true
                    text: String(trackRow.track?.title ?? "")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: trackRow.active ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const artist = String(trackRow.track?.artist ?? "")
                        const album = String(trackRow.track?.album ?? "")
                        return artist && album ? artist + " • " + album : (artist || album)
                    }
                    visible: text.length > 0
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }
            StyledText {
                text: trackRow.track?.duration > 0 ? root.formatTime(trackRow.track.duration) : ""
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.numbers
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Desktop-player semantics: a single click only focuses the row;
            // a double click performs its action. This prevents the first click
            // of a double click from replacing the live MPD queue.
            onClicked: trackRow.forceActiveFocus()
            onDoubleClicked: trackRow.activated()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol { text: "library_music"; iconSize: 26; color: Appearance.colors.colPrimary }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Translation.tr("Music")
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "MPD · " + LocalMusic.mpdHost + ":" + LocalMusic.mpdPort
                        + (LocalMusic.libraryFolder.length > 0 ? " · " + LocalMusic.libraryFolder : "")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                }
            }
            ToolIconButton {
                symbol: "folder_open"
                tip: Translation.tr("Folder")
                onClicked: folderDialog.open()
            }
            ToolIconButton {
                symbol: "database"
                tip: Translation.tr("Update")
                enabled: LocalMusic.available && !LocalMusic.scanning
                onClicked: LocalMusic.updateDatabase()
            }
            ToolIconButton {
                symbol: "refresh"; tip: Translation.tr("Refresh")
                enabled: !LocalMusic.scanning
                onClicked: LocalMusic.rescan()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { id: "songs", label: Translation.tr("Songs"), icon: "music_note" },
                    { id: "playlists", label: Translation.tr("Playlists"), icon: "queue_music" },
                    { id: "queue", label: Translation.tr("Queue"), icon: "format_list_numbered" },
                    { id: "lyrics", label: Translation.tr("Lyrics"), icon: "lyrics" }
                ]
                delegate: RippleButton {
                    id: sectionButton
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 38
                    buttonRadius: Appearance.rounding.full
                    colBackground: root.section === modelData.id
                        ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                    onClicked: root.section = modelData.id
                    contentItem: RowLayout {
                        spacing: 5
                        Item { Layout.fillWidth: true }
                        MaterialSymbol { text: sectionButton.modelData.icon; iconSize: 17; color: Appearance.colors.colOnLayer2 }
                        StyledText {
                            text: sectionButton.modelData.label
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        ToolbarTextField {
            id: searchField
            Layout.fillWidth: true
            // ToolbarTextField normally fills toolbar height. In this vertical
            // view that consumed the entire song viewport.
            Layout.fillHeight: false
            Layout.minimumHeight: 38
            Layout.preferredHeight: 38
            Layout.maximumHeight: 38
            placeholderText: Translation.tr("Search")
            visible: root.section === "songs"
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            StackLayout {
                anchors.fill: parent
                currentIndex: root.sectionIndex()

                Item {
                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        model: root.filteredTracks
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            track: modelData
                            trackIndex: index
                            // Double-click appends the selected song to the
                            // existing MPD queue and immediately plays that
                            // appended entry. It must not clear the current queue.
                            onActivated: LocalMusic.enqueueTrack(modelData, true)
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: !LocalMusic.scanning && root.filteredTracks.length === 0
                        spacing: 8
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "music_off"; iconSize: 42; color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No results")
                            color: Appearance.colors.colSubtext
                        }
                        RippleButton {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 120; implicitHeight: 38
                            enabled: LocalMusic.available
                            onClicked: LocalMusic.updateDatabase()
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("Update")
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                Item {
                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        model: LocalMusic.collections
                        delegate: Rectangle {
                            id: playlistRow
                            required property var modelData
                            width: ListView.view.width
                            implicitHeight: 66
                            radius: Appearance.rounding.small
                            color: playlistMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                                    radius: Appearance.rounding.small
                                    color: Appearance.colors.colSecondaryContainer
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: playlistRow.modelData?.kind === "playlist" ? "queue_music" : "folder"
                                        iconSize: 22
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: String(playlistRow.modelData?.name ?? "")
                                        color: Appearance.colors.colOnLayer1
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        text: Translation.tr("%1 songs").arg(playlistRow.modelData?.tracks?.length ?? 0)
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                }
                                MaterialSymbol { text: "play_arrow"; iconSize: 22; color: Appearance.colors.colPrimary }
                            }
                            MouseArea {
                                id: playlistMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LocalMusic.playCollection(playlistRow.modelData)
                            }
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: LocalMusic.collections.length === 0
                        text: Translation.tr("No results")
                        color: Appearance.colors.colSubtext
                    }
                }

                Item {
                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        model: LocalMusic.activeQueue
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            track: modelData
                            trackIndex: index
                            onActivated: LocalMusic.jumpTo(index)
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: LocalMusic.activeQueue.length === 0
                        text: Translation.tr("Queue")
                        color: Appearance.colors.colSubtext
                    }
                }

                Item {
                    ListView {
                        id: lyricsList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        model: LocalMusic.localLyricsLines
                        currentIndex: LocalMusic.localLyricsActiveIndex

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0)
                                Qt.callLater(() => positionViewAtIndex(currentIndex, ListView.Center))
                        }

                        header: ColumnLayout {
                            width: lyricsList.width
                            spacing: 2
                            visible: LocalMusic.hasLocalLyrics
                            StyledText {
                                Layout.fillWidth: true
                                text: LocalMusic.localLyricsSynced
                                    ? Translation.tr("Synced local lyrics")
                                    : Translation.tr("Local lyrics")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Directories.shortHomePath(LocalMusic.localLyricsPath)
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                elide: Text.ElideMiddle
                            }
                            Item { Layout.preferredHeight: 6 }
                        }

                        delegate: Rectangle {
                            id: lyricRow
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            implicitHeight: lyricText.implicitHeight + 16
                            radius: Appearance.rounding.small
                            color: index === LocalMusic.localLyricsActiveIndex
                                ? Appearance.colors.colSecondaryContainer : "transparent"

                            StyledText {
                                id: lyricText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: String(lyricRow.modelData?.text ?? "")
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: index === LocalMusic.localLyricsActiveIndex
                                    ? Appearance.font.pixelSize.normal
                                    : Appearance.font.pixelSize.small
                                font.weight: index === LocalMusic.localLyricsActiveIndex
                                    ? Font.Medium : Font.Normal
                                color: index === LocalMusic.localLyricsActiveIndex
                                    ? Appearance.colors.colOnSecondaryContainer
                                    : Appearance.colors.colOnLayer1
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 280)
                        spacing: 8
                        visible: !LocalMusic.hasLocalLyrics
                        MaterialLoadingIndicator {
                            Layout.alignment: Qt.AlignHCenter
                            visible: LocalMusic.localLyricsStatus === "loading"
                            loading: visible
                            implicitSize: 30
                        }
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            visible: LocalMusic.localLyricsStatus !== "loading"
                            text: "lyrics"
                            iconSize: 36
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: LocalMusic.currentPath.length === 0
                                ? Translation.tr("Nothing playing")
                                : LocalMusic.localLyricsStatus === "loading"
                                    ? Translation.tr("Loading local lyrics")
                                    : Translation.tr("No local .lrc or .txt lyrics beside this track")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
            MaterialLoadingIndicator { anchors.centerIn: parent; visible: LocalMusic.scanning }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Appearance.sizes.mediaControlsHeight : 0
            visible: LocalMusic.hasCurrentTrack && LocalMusic.mprisAvailable

            // Same player card used by modules/mediaControls/BarMediaPopup.qml.
            PlayerControl {
                anchors.fill: parent
                player: LocalMusic.mprisPlayer
                visualizerPoints: localMusicCava.points
                visualizerMaxValue: Math.max(1, localMusicCava.normalizationCeiling)
                radius: Appearance.rounding.normal
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 34 : 0
            visible: LocalMusic.hasCurrentTrack && LocalMusic.mprisAvailable
            spacing: 6
            ToolIconButton {
                symbol: LocalMusic.shuffleMode ? "shuffle_on" : "shuffle"
                tip: Translation.tr("Shuffle")
                onClicked: LocalMusic.toggleShuffle()
            }
            ToolIconButton {
                symbol: LocalMusic.repeatMode === 1 ? "repeat_one_on"
                    : (LocalMusic.repeatMode === 2 ? "repeat_on" : "repeat")
                tip: Translation.tr("Repeat")
                onClicked: LocalMusic.cycleRepeatMode()
            }
            Item { Layout.fillWidth: true }
            MaterialSymbol {
                text: LocalMusic.volume <= 0 ? "volume_off"
                    : (LocalMusic.volume < 0.5 ? "volume_down" : "volume_up")
                iconSize: 18
                color: Appearance.colors.colSubtext
            }
            StyledSlider {
                Layout.preferredWidth: 120
                from: 0
                to: 1
                value: LocalMusic.volume
                onMoved: LocalMusic.setVolume(value)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 34 : 0
            visible: !LocalMusic.available || !LocalMusic.mprisAvailable
            radius: Appearance.rounding.small
            color: Appearance.colors.colErrorContainer
            StyledText {
                anchors.centerIn: parent
                text: !LocalMusic.available
                    ? "MPD · " + LocalMusic.mpdHost + ":" + LocalMusic.mpdPort
                    : Translation.tr("Waiting for mpd-mpris")
                color: Appearance.colors.colOnErrorContainer
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: Translation.tr("Music")
        onAccepted: LocalMusic.setLibraryFolder(String(selectedFolder))
    }
}
