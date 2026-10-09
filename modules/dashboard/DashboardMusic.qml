pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls
import qs.modules.abyss.looks
import "DashboardMusicModel.js" as Library

Item {
    id: root
    objectName: "dashboardMusic"
    required property var backend
    property bool presentationActive: visible
    property string sourceMode: ""
    // One Library column; tabs only change the browsing surface, not playback.
    property string libraryTab: "genre"
    property string selectedGenre: ""
    property string selectedFolder: ""
    property string resultFolder: ""
    property alias query: search.text
    property var selectedKeys: []
    property int selectionAnchor: -1
    property string selectedPlaylistName: ""
    readonly property var selectedPlaylist: (backend.playlists ?? []).find(value => String(value.name ?? "") === selectedPlaylistName) ?? null
    property bool browserRestored: false
    property Item contextAnchor: null
    property var contextActions: []
    property bool playlistDialogVisible: false
    property var pendingPlaylistTracks: []
    readonly property var tracks: backend.libraryTracks ?? []
    readonly property var genres: Library.genres(tracks)
    readonly property var folders: Library.roots(tracks)
    readonly property bool hasLyrics: (backend.localLyricsLines ?? []).some(line => String(line.text ?? "").trim().length > 0)
    readonly property var results: {
        if (sourceMode === "queue") {
            const entries = (backend.activeQueue ?? []).map((track, index) => ({
                        kind: "track",
                        track,
                        name: String(track.title || track.uri || ""),
                        queueIndex: index
                    }));
            if (!query.trim())
                return entries;
            const matched = new Set(Library.matching(backend.activeQueue ?? [], query));
            return entries.filter(entry => matched.has(entry.track));
        }
        if (sourceMode === "playlist")
            return Library.matching(selectedPlaylist?.tracks ?? [], query).map(track => ({
                        kind: "track",
                        track,
                        name: String(track.title || track.uri || "")
                    }));
        if (query.trim())
            return Library.matching(tracks, query).map(track => ({
                        kind: "track",
                        track,
                        name: String(track.title || track.uri || "")
                    }));
        return Library.results(tracks, sourceMode, selectedGenre, resultFolder);
    }
    readonly property var selectedTracks: Library.selectedTracks(sourceMode === "playlist" ? (selectedPlaylist?.tracks ?? []) : sourceMode === "queue" ? (backend.activeQueue ?? []) : tracks, selectedKeys)
     readonly property var allResultTracks: Library.selectedTracks(
        sourceMode === "playlist" ? (selectedPlaylist?.tracks ?? []) :
        sourceMode === "queue" ? (backend.activeQueue ?? []) : tracks,
        results.map(entry => Library.key(entry)))
    readonly property bool abyss: Config.options?.panelFamily === "abyss"
    readonly property color ink: abyss ? (Appearance.m3colors.darkmode ? AbyssStyle.textColor : "#000000") : Appearance.colors.colOnSurface
    readonly property color mutedInk: abyss ? (Appearance.m3colors.darkmode ? AbyssStyle.textColorMuted : Qt.alpha("#000000", .66)) : Appearance.colors.colSubtext
    readonly property color accent: abyss ? AbyssStyle.accent : Appearance.colors.colPrimary
    readonly property color surface: abyss ? AbyssStyle.contentLayer : Appearance.colors.colLayer1
    function clearSelection(): void {
        selectedKeys = [];
        selectionAnchor = -1;
    }
    function rememberBrowser(): void {
        if (!browserRestored)
            return;
        GlobalStates.dashboardMusicBrowser = {
            mode: sourceMode,
            tab: libraryTab,
            genre: selectedGenre,
            folder: selectedFolder,
            path: resultFolder,
            query,
            playlist: selectedPlaylistName
        };
    }
    Component.onCompleted: {
        const saved = GlobalStates.dashboardMusicBrowser;
        sourceMode = String(saved.mode ?? "");
        libraryTab = ["genre", "folder"].includes(saved.tab) ? saved.tab
            : (sourceMode === "folder" || sourceMode === "playlist" ? "folder" : "genre");
        selectedGenre = String(saved.genre ?? "");
        selectedFolder = String(saved.folder ?? "");
        resultFolder = String(saved.path ?? "");
        query = String(saved.query ?? "");
        selectedPlaylistName = String(saved.playlist ?? "");
        browserRestored = true;
    }
    onSourceModeChanged: {
        clearSelection();
        rememberBrowser();
    }
    onResultFolderChanged: {
        clearSelection();
        rememberBrowser();
    }
    onQueryChanged: {
        clearSelection();
        rememberBrowser();
    }
    onLibraryTabChanged: rememberBrowser()
    onSelectedGenreChanged: rememberBrowser()
    onSelectedFolderChanged: rememberBrowser()
    onSelectedPlaylistNameChanged: rememberBrowser()
    // First Escape clears the active library drill-down, second closes Dashboard.
    function restoreBrowserColumns(): bool {
        if (playlistDialogVisible) {
            playlistDialogVisible = false
            return true
        }
        if (!["genre", "folder", "playlist"].includes(sourceMode))
            return false
        sourceMode = ""
        selectedGenre = ""
        selectedFolder = ""
        selectedPlaylistName = ""
        resultFolder = ""
        query = ""
        clearSelection()
        rememberBrowser()
        return true
    }
    function switchLibraryTab(tab): void {
        if (tab !== "genre" && tab !== "folder")
            return
        libraryTab = tab
        if (["genre", "folder", "playlist"].includes(sourceMode)) {
            sourceMode = ""
            selectedGenre = ""
            selectedFolder = ""
            selectedPlaylistName = ""
            resultFolder = ""
            query = ""
            clearSelection()
        }
        rememberBrowser()
    }
    function chooseGenre(value): void {
        libraryTab = "genre"
        query = "";
        sourceMode = "genre";
        selectedGenre = value;
        clearSelection();
    }
    function chooseFolder(path): void {
        libraryTab = "folder"
        query = "";
        sourceMode = "folder";
        selectedFolder = path;
        resultFolder = path;
        clearSelection();
    }
    function choosePlaylist(value): void {
        libraryTab = "folder"
        query = "";
        sourceMode = "playlist";
        selectedPlaylistName = String(value.name ?? "");
        clearSelection();
    }
    function selectEntry(index, modifiers): void {
        const next = Library.select(results, selectedKeys, selectionAnchor, index, !!(modifiers & Qt.ControlModifier), !!(modifiers & Qt.ShiftModifier));
        selectedKeys = next.keys;
        selectionAnchor = next.anchor;
    }
    function activate(entry): void {
        if (entry.kind === "folder")
            resultFolder = entry.path;
        else if (sourceMode === "queue")
            backend.playTrackAt(entry.queueIndex);
        else
            backend.enqueueTrack(entry.track, true);
    }
    // Leave nested list scrolling intact when vertical wheel navigates pages.
    function acceptsPageWheel(x, y): bool {
        const lists = [genreList, folderList, playlistList, resultList, queueList, lyricsList]
        for (const item of lists) {
            if (!item.visible || item.width <= 0 || item.height <= 0)
                continue
            const p = item.mapFromItem(root, x, y)
            if (p.x >= 0 && p.x < item.width && p.y >= 0 && p.y < item.height)
                return false
        }
        return true
    }
    function panHorizontally(amount): bool {
        const next = Math.max(0, Math.min(horizontal.contentWidth - horizontal.width, horizontal.contentX - amount));
        if (Math.abs(next - horizontal.contentX) < .01)
            return false;
        horizontal.contentX = next;
        return true;
    }
    function openContext(entry, index, anchor): void {
        if (!selectedKeys.includes(Library.key(entry)))
            selectEntry(index, 0);
        const snapshot = selectedTracks.slice();
        contextAnchor = anchor;
        contextActions = [
            {
                iconName: "play_arrow",
                monochromeIcon: true,
                text: Translation.tr("Play selection"),
                action: () => backend.playQueue(snapshot, 0, Translation.tr("Selection"))
            },
            {
                iconName: "playlist_add",
                monochromeIcon: true,
                text: Translation.tr("Add to queue"),
                action: () => backend.enqueueTracks(snapshot)
            },
            {
                iconName: "library_add",
                monochromeIcon: true,
                text: Translation.tr("Create playlist…"),
                action: () => openCreatePlaylist(snapshot)
            }
        ];
        for (const playlist of backend.playlists ?? []) {
            const name = String(playlist.name ?? "");
            if (name)
                contextActions.push({
                    iconName: "queue_music",
                    monochromeIcon: true,
                    text: Translation.tr("Add to %1").arg(name),
                    action: () => backend.addTracksToPlaylist(name, snapshot)
                });
        }
        if (sourceMode === "queue")
            contextActions.push({
                iconName: "remove",
                monochromeIcon: true,
                text: Translation.tr("Remove from queue"),
                action: () => {
                    const current = (backend.activeQueue ?? []).findIndex(track => track === entry.track || (entry.track.queueId !== undefined && track.queueId === entry.track.queueId));
                    if (current >= 0)
                        backend.removeQueueTrack(current);
                }
            });
        contextMenu.requestOpen();
    }
    function openCreatePlaylist(values): void {
        pendingPlaylistTracks = values.slice();
        if (!values.length)
            return;
        playlistName.text = "";
        playlistDialogVisible = true;
        Qt.callLater(() => playlistName.forceActiveFocus());
    }
    function commitPlaylist(): void {
        const name = playlistName.text.trim();
        if (!name || !pendingPlaylistTracks.length)
            return;
        backend.createPlaylist(name, pendingPlaylistTracks);
        playlistDialogVisible = false;
        pendingPlaylistTracks = [];
    }
    onPresentationActiveChanged: if (!presentationActive) {
        contextMenu.close();
        playlistDialogVisible = false;
        pendingPlaylistTracks = [];
    }

    QtObject {
        id: playerAdapter
        readonly property string title: root.backend.currentTitle ?? ""
        readonly property string artist: root.backend.currentArtist ?? ""
        readonly property string album: root.backend.currentAlbum ?? ""
        readonly property string artUrl: root.backend.currentArt ?? ""
        readonly property real position: root.backend.lyricsPosition ?? 0
        readonly property real length: root.backend.currentDuration ?? 0
        readonly property bool isPlaying: root.backend.playing ?? false
        readonly property bool canSeek: root.backend.hasCurrentTrack ?? false
        readonly property bool canGoPrevious: root.backend.canGoPrevious ?? false
        readonly property bool canGoNext: root.backend.canGoNext ?? false
        readonly property bool shuffleSupported: root.backend.available ?? false
        readonly property bool shuffle: root.backend.shuffleMode ?? false
        readonly property bool repeatSupported: root.backend.available ?? false
        readonly property int repeatMode: root.backend.repeatMode ?? 0
        function togglePlaying(): void {
            root.backend.togglePlaying();
        }
        function previous(): void {
            root.backend.previous();
        }
        function next(): void {
            root.backend.next();
        }
        function seek(seconds): void {
            root.backend.seek(seconds);
        }
        function toggleShuffle(): void {
            root.backend.toggleShuffle();
        }
        function cycleRepeat(): void {
            root.backend.cycleRepeatMode();
        }
    }
    component Pane: Rectangle {
        property string title: ""
        default property alias content: body.data
        color: root.surface
        radius: root.abyss ? 18 : Appearance.rounding.small
        clip: true
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: parent.parent.title
                color: root.ink
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Item {
                id: body
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
    component Entry: AbstractButton {
        id: entry
        property string caption: ""
        property string detail: ""
        property bool selected: false
        property string glyph: ""
        property string artUrl: ""
        hoverEnabled: true
        implicitHeight: detail ? 52 : 38
        Accessible.name: caption
        background: Rectangle {
            radius: 10
            color: Qt.alpha(root.accent, entry.selected ? .20 : entry.hovered ? .10 : 0)
        }
        contentItem: RowLayout {
            spacing: 5
            Item {
                visible: entry.glyph.length > 0 || entry.artUrl.length > 0
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                Image {
                    id: cover
                    anchors.fill: parent
                    source: entry.artUrl
                    asynchronous: true
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectCrop
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: entry.glyph
                    color: root.mutedInk
                    iconSize: 20
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: entry.caption
                    color: root.ink
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: entry.detail.length > 0
                    text: entry.detail
                    color: root.mutedInk
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    elide: Text.ElideRight
                }
            }
        }
        leftPadding: 8
        rightPadding: 8
        topPadding: 6
        bottomPadding: 6
    }
    Flickable {
        id: horizontal
        objectName: "musicColumnsViewport"
        anchors.fill: parent
        contentWidth: Math.max(width, root.hasLyrics ? 1040 : 800)
        contentHeight: height
        onContentWidthChanged: contentX = Math.max(0, Math.min(contentX, contentWidth - width))
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        Row {
            width: horizontal.contentWidth
            height: horizontal.height
            spacing: 8
            readonly property int shownColumns: root.hasLyrics ? 4 : 3
            readonly property real weight: root.hasLyrics ? 106 : 90
            readonly property real unit: (width - spacing * (shownColumns - 1)) / weight
            Pane {
                id: libraryPane
                objectName: "musicLibrary"
                width: parent.unit * 24
                height: parent.height
                title: Translation.tr("Library")
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        AbyssButton {
                            objectName: "musicGenreTab"
                            Layout.fillWidth: true
                            text: Translation.tr("Genre")
                            outlined: false
                            // Keep tab highlight declarative; a button click must
                            // not imperatively toggle away the bound checked state.
                            checked: root.libraryTab === "genre"
                            onClicked: root.switchLibraryTab("genre")
                        }
                        AbyssButton {
                            objectName: "musicFolderTab"
                            Layout.fillWidth: true
                            text: Translation.tr("Folders")
                            outlined: false
                            // Keep tab highlight declarative; a button click must
                            // not imperatively toggle away the bound checked state.
                            checked: root.libraryTab === "folder"
                            onClicked: root.switchLibraryTab("folder")
                        }
                    }
                    Item {
                        objectName: "musicGenres"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.libraryTab === "genre"
                        ListView {
                            id: genreList
                            objectName: "musicGenreList"
                            anchors.fill: parent
                            model: root.genres
                            clip: true
                            spacing: 3
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Entry {
                                required property var modelData
                                width: ListView.view.width
                                caption: modelData.key || Translation.tr("Unknown genre")
                                detail: Translation.tr("%1 tracks").arg(modelData.count)
                                selected: root.sourceMode === "genre" && root.selectedGenre === modelData.key
                                onClicked: root.chooseGenre(modelData.key)
                            }
                        }
                    }
                    Item {
                        objectName: "musicFolders"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.libraryTab === "folder"
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6
                            ListView {
                                id: folderList
                                objectName: "musicFolderList"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root.folders
                                clip: true
                                spacing: 3
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                delegate: Entry {
                                    required property var modelData
                                    width: ListView.view.width
                                    caption: modelData.name
                                    detail: Translation.tr("%1 tracks").arg(modelData.count)
                                    selected: root.sourceMode === "folder" && root.selectedFolder === modelData.path
                                    onClicked: root.chooseFolder(modelData.path)
                                }
                            }
                            StyledText {
                                visible: (root.backend.playlists ?? []).length > 0
                                text: Translation.tr("Playlists")
                                color: root.ink
                            }
                            ListView {
                                id: playlistList
                                objectName: "musicPlaylistList"
                                visible: count > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight, parent.height * .35)
                                model: root.backend.playlists ?? []
                                clip: true
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                                delegate: Entry {
                                    required property var modelData
                                    width: ListView.view.width
                                    caption: String(modelData.name ?? "")
                                    detail: Translation.tr("%1 tracks").arg(modelData.tracks?.length ?? 0)
                                    glyph: "queue_music"
                                    selected: root.sourceMode === "playlist" && root.selectedPlaylist === modelData
                                    onClicked: root.choosePlaylist(modelData)
                                    onDoubleClicked: root.backend.playCollection(modelData)
                                }
                            }
                            AbyssButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Update")
                                glyph: "refresh"
                                outlined: false
                                enabled: root.backend.available ?? false
                                onClicked: root.backend.updateDatabase()
                            }
                        }
                    }
                }
            }
            Pane {
                objectName: "musicResults"
                width: parent.unit * (root.hasLyrics ? 30 : 34)
                height: parent.height
                title: root.sourceMode === "queue" ? Translation.tr("Queue") : root.sourceMode === "playlist" ? String(root.selectedPlaylist?.name ?? Translation.tr("Playlist")) : root.sourceMode === "genre" ? (root.selectedGenre || Translation.tr("Unknown genre")) : root.sourceMode === "folder" ? (root.resultFolder || Translation.tr("Music library")) : Translation.tr("Results")
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: 36
                        Layout.maximumHeight: 36
                        spacing: 3
                        ToolbarTextField {
                            id: search
                            objectName: "musicSearch"
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.minimumWidth: 0
                            placeholderText: Translation.tr("Search music")
                        }
                        AbyssButton {
                            objectName: "musicQueue"
                            compact: true
                            glyph: "queue_music"
                            description: Translation.tr("Queue")
                            outlined: false
                            onClicked: {
                                root.query = "";
                                root.sourceMode = "queue";
                            }
                        }
                        AbyssButton {
                            visible: root.sourceMode === "queue"
                            compact: true
                            glyph: "delete_sweep"
                            description: Translation.tr("Clear queue")
                            outlined: false
                            onClicked: root.backend.clearQueue()
                        }
                    }
                    AbyssButton {
                        visible: root.sourceMode === "folder" && root.resultFolder.length > 0
                        text: Translation.tr("Parent folder")
                        glyph: "arrow_upward"
                        outlined: false
                        onClicked: root.resultFolder = Library.parent(root.resultFolder)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        AbyssButton {
                            objectName: "musicPlayAll"
                            Layout.fillWidth: true
                            compact: false
                            glyph: "play_arrow"
                            text: Translation.tr("Play All")
                            outlined: false
                            enabled: root.allResultTracks.length > 0
                            onClicked: root.backend.playQueue(root.allResultTracks, 0, Translation.tr("Results"))
                        }
                        AbyssButton {
                            objectName: "musicPlaySelection"
                            Layout.fillWidth: true
                            compact: false
                            glyph: "playlist_play"
                            text: Translation.tr("Play Selected")
                            outlined: false
                            enabled: root.selectedTracks.length > 0
                            onClicked: root.backend.playQueue(root.selectedTracks, 0, Translation.tr("Selection"))
                        }
                        AbyssButton {
                            objectName: "musicEnqueueSelection"
                            compact: true
                            glyph: "playlist_add"
                            description: Translation.tr("Add to queue")
                            outlined: false
                            enabled: root.selectedTracks.length > 0
                            onClicked: root.backend.enqueueTracks(root.selectedTracks)
                        }
                    }
                    ListView {
                        id: resultList
                        objectName: "musicResultList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: root.results
                        clip: true
                        spacing: 3
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                        delegate: Entry {
                            id: resultEntry
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            caption: modelData.name
                            glyph: modelData.kind === "folder" ? "folder" : "music_note"
                            artUrl: modelData.kind === "track" ? String(modelData.track.artUrl ?? modelData.track.art ?? "") : ""
                            detail: modelData.kind === "folder" ? Translation.tr("Folder · %1 tracks").arg(modelData.count) : String(modelData.track.artist ?? "")
                            selected: root.selectedKeys.includes(Library.key(modelData))
                            onClicked: root.selectEntry(index, 0)
                            Keys.onReturnPressed: root.activate(modelData)
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: event => {
                                    if (event.button === Qt.RightButton)
                                        root.openContext(resultEntry.modelData, resultEntry.index, resultEntry);
                                    else
                                        root.selectEntry(resultEntry.index, event.modifiers);
                                }
                                onDoubleClicked: event => {
                                    if (event.button === Qt.LeftButton)
                                        root.activate(resultEntry.modelData);
                                }
                            }
                        }
                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            color: root.mutedInk
                            visible: root.results.length === 0
                            text: root.sourceMode || root.query ? Translation.tr("No tracks") : ""
                        }
                    }
                }
            }
            Column {
                objectName: "musicPlaybackAndQueue"
                width: parent.unit * (root.hasLyrics ? 30 : 32)
                height: parent.height
                spacing: 8
                Pane {
                    id: musicPlayer
                    objectName: "musicPlayer"
                    width: parent.width
                    // Queue owns most of the column. The DSP/player remains
                    // scrollable when screen height cannot fit both completely.
                    height: Math.round((parent.height - parent.spacing) * .43)
                    title: Translation.tr("Now playing")
                    Flickable {
                        id: musicControlsScroll
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: musicControlsStack.implicitHeight
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        ColumnLayout {
                            id: musicControlsStack
                            width: musicControlsScroll.width
                            spacing: 8
                        PlayerControl {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: 142
                            player: root.backend.mprisPlayer ?? null
                            playbackAdapter: playerAdapter
                            compactLayout: true
                            visualizerPoints: []
                            radius: root.abyss ? 18 : Appearance.rounding.normal
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            MaterialSymbol {
                                text: "volume_up"
                                color: root.mutedInk
                                iconSize: 18
                            }
                            StyledSlider {
                                objectName: "musicVolume"
                                Layout.fillWidth: true
                                configuration: StyledSlider.Configuration.XS
                                value: root.backend.volume ?? 1
                                onMoved: root.backend.setVolume(value)
                            }
                        }
                        EqualizerPanel {
                            id: musicEqualizer
                            objectName: "musicEqualizer"
                            Layout.fillWidth: true
                            compactLayout: true
                            active: root.presentationActive && root.visible
                        }

                        }
                    }
                }
                Pane {
                    id: musicQueuePanel
                    objectName: "musicQueuePanel"
                    width: parent.width
                    height: Math.max(0, parent.height - musicPlayer.height - parent.spacing)
                    title: Translation.tr("Queue")
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("%1 tracks").arg((root.backend.activeQueue ?? []).length)
                                color: root.mutedInk
                            }
                            AbyssButton {
                                objectName: "musicClearQueue"
                                compact: true
                                glyph: "delete_sweep"
                                description: Translation.tr("Clear queue")
                                outlined: false
                                enabled: (root.backend.activeQueue ?? []).length > 0
                                onClicked: root.backend.clearQueue()
                            }
                        }
                        ListView {
                            id: queueList
                            objectName: "musicQueueList"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            model: root.backend.activeQueue ?? []
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: Entry {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                caption: String(modelData.title || modelData.uri || "")
                                detail: String(modelData.artist ?? "")
                                glyph: "music_note"
                                artUrl: String(modelData.artUrl ?? modelData.art ?? "")
                                onDoubleClicked: root.backend.playTrackAt(index)
                            }
                        }
                    }
                }
            }
            Pane {
                objectName: "musicLyrics"
                visible: root.hasLyrics
                width: root.hasLyrics ? parent.unit * 22 : 0
                height: parent.height
                title: Translation.tr("Lyrics")
                ListView {
                    id: lyricsList
                    objectName: "musicLyricsList"
                    anchors.fill: parent
                    clip: true
                    spacing: 12
                    model: root.backend.localLyricsLines ?? []
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                    currentIndex: root.presentationActive ? (root.backend.localLyricsActiveIndex ?? -1) : -1
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: height * .35
                    preferredHighlightEnd: height * .65
                    delegate: StyledText {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        text: String(modelData.text ?? "")
                        wrapMode: Text.WordWrap
                        color: index === ListView.view.currentIndex ? root.ink : root.mutedInk
                        font.weight: index === ListView.view.currentIndex ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
    ContextMenu {
        id: contextMenu
        anchorItem: root.contextAnchor ?? root
        model: root.contextActions
        closeOnHoverLost: false
        closeOnFocusLost: true
    }
    Rectangle {
        anchors.fill: parent
        visible: root.playlistDialogVisible
        z: 100
        color: Qt.alpha(root.surface, .9)
        MouseArea {
            anchors.fill: parent
            onClicked: root.playlistDialogVisible = false
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 320)
            height: 160
            radius: 18
            color: root.surface
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                StyledText {
                    text: Translation.tr("Create playlist…")
                    color: root.ink
                }
                ToolbarTextField {
                    id: playlistName
                    objectName: "musicPlaylistName"
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Playlist name")
                    onAccepted: root.commitPlaylist()
                    Keys.onEscapePressed: root.playlistDialogVisible = false
                }
                RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.fillWidth: true
                    }
                    AbyssButton {
                        text: Translation.tr("Cancel")
                        outlined: false
                        onClicked: root.playlistDialogVisible = false
                    }
                    AbyssButton {
                        text: Translation.tr("Create")
                        outlined: false
                        enabled: playlistName.text.trim().length > 0
                        onClicked: root.commitPlaylist()
                    }
                }
            }
        }
    }
}
