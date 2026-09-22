pragma ComponentBehavior: Bound

import QtQuick
import org.kde.syntaxhighlighting
import qs.modules.common

Item {
    id: root

    property var targetTextEdit: null
    property string definitionName: "plaintext"

    width: 0
    height: 0
    visible: false

    SyntaxHighlighter {
        textEdit: root.targetTextEdit
        repository: Repository
        definition: Repository.definitionForName(root.definitionName)
        theme: Appearance.syntaxHighlightingTheme
    }
}
