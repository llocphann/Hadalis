pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var availableLanguages: ["en_US"]
    readonly property var availableGeneratedLanguages: []
    readonly property var allAvailableLanguages: ["en_US"]
    readonly property string languageCode: "en_US"
    readonly property bool isScanning: false
    property bool isLoading: translationFileView.loadPending
    readonly property string translationKeepSuffix: "/*keep*/"
    property var translations: ({})

    function tr(text) {
        if (!text)
            return "";

        const key = text.toString();
        let translation = root.translations?.[key] ?? key;
        if (translation.endsWith(root.translationKeepSuffix))
            translation = translation.substring(0, translation.length - root.translationKeepSuffix.length).trim();
        return translation;
    }

    FileView {
        id: translationFileView
        property bool loadPending: true
        path: `${Quickshell.shellPath("translations")}/en_US.json`
        printErrors: false

        onLoaded: {
            try {
                root.translations = JSON.parse(text());
            } catch (e) {
                console.warn("[Translation] Failed to load English catalog:", e);
                root.translations = ({});
            }
            loadPending = false;
        }

        onLoadFailed: error => {
            console.warn("[Translation] English catalog unavailable; using source strings:", error);
            root.translations = ({});
            loadPending = false;
        }
    }
}
