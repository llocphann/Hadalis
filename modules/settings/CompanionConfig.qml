pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.companion
import qs.modules.abyss.looks
import "../abyss/companion/WullPreferences.js" as Preferences

ContentPage {
    id: root
    settingsPageIndex: 37
    settingsPageName: Translation.tr("Companion")
    property string activeSection: "overview"
    property string previewExpression: "idle"
    property string previewMotion: ""
    readonly property var preferences: Preferences.normalize(Config.options?.abyss?.companion)
    readonly property var personalityOptions: [
        { displayName: Translation.tr("Calm"), value: "calm" },
        { displayName: Translation.tr("Balanced"), value: "balanced" },
        { displayName: Translation.tr("Energetic"), value: "energetic" }
    ]
    readonly property var frequencyOptions: [
        { displayName: Translation.tr("Always visible"), value: "always" },
        { displayName: Translation.tr("Every minute"), value: "frequent" },
        { displayName: Translation.tr("Every 3 minutes"), value: "occasional" },
        { displayName: Translation.tr("Every 10 minutes"), value: "rare" }
    ]
    readonly property var qualityOptions: [
        { displayName: Translation.tr("Performance"), value: "performance" },
        { displayName: Translation.tr("Balanced"), value: "balanced" },
        { displayName: Translation.tr("Quality"), value: "quality" }
    ]
    readonly property var expressionOptions: [
        { displayName: Translation.tr("Idle"), value: "idle" },
        { displayName: Translation.tr("Happy"), value: "happy" },
        { displayName: Translation.tr("Excited"), value: "excited" },
        { displayName: Translation.tr("Thinking"), value: "thinking" },
        { displayName: Translation.tr("Working"), value: "working" },
        { displayName: Translation.tr("Surprised"), value: "surprised" },
        { displayName: Translation.tr("Sleepy"), value: "sleepy" },
        { displayName: Translation.tr("Sad"), value: "sad" },
        { displayName: Translation.tr("Alert"), value: "alert" }
    ]
    readonly property var motionOptions: [
        { displayName: Translation.tr("Rest"), value: "" },
        { displayName: Translation.tr("Walk"), value: "walk" },
        { displayName: Translation.tr("Run"), value: "run" },
        { displayName: Translation.tr("Fly"), value: "fly" },
        { displayName: Translation.tr("Jump"), value: "jump" },
        { displayName: Translation.tr("Dragged"), value: "drag" },
        { displayName: Translation.tr("Fall"), value: "fall" },
        { displayName: Translation.tr("Reach"), value: "reach" },
        { displayName: Translation.tr("Inspect"), value: "inspect" },
        { displayName: Translation.tr("Wave"), value: "wave" }
    ]

    function setPreference(key, value): void {
        Config.setNestedValue("abyss.companion." + key, value)
    }

    function resetPreferences(): void {
        const values = {}
        const defaults = Preferences.defaults()
        for (const key of Object.keys(defaults))
            values["abyss.companion." + key] = defaults[key]
        Config.setNestedValues(values)
    }

    component ChoiceRow: GridLayout {
        id: choice
        property string label: ""
        property string description: ""
        property var options: []
        property string currentValue: ""
        signal selected(string value)
        Layout.fillWidth: true
        columns: width > 540 ? 2 : 1
        columnSpacing: 24
        rowSpacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            StyledText { Layout.fillWidth: true; text: choice.label; wrapMode: Text.WordWrap }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: choice.description
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
        StyledComboBox {
            objectName: choice.objectName + "Control"
            Layout.preferredWidth: 224
            Layout.fillWidth: choice.columns === 1
            model: choice.options
            textRole: "displayName"
            settingsSearchLabel: choice.label
            settingsSearchDescription: choice.description
            currentIndex: Math.max(0, choice.options.findIndex(o => o.value === choice.currentValue))
            onActivated: index => choice.selected(choice.options[index].value)
        }
    }

    component PercentageRow: ColumnLayout {
        id: percentage
        property string label: ""
        property string description: ""
        property real value: 1
        property real minimum: 0
        property real maximum: 1
        signal moved(real value)
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            StyledText { Layout.fillWidth: true; text: percentage.label }
            StyledText { text: Math.round(percentage.value * 100) + "%"; color: Appearance.colors.colPrimary }
        }
        StyledText {
            Layout.fillWidth: true
            text: percentage.description
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
        StyledSlider {
            objectName: percentage.objectName + "Control"
            from: percentage.minimum
            to: percentage.maximum
            stepSize: 0.01
            value: percentage.value
            tooltipContent: Math.round(value * 100) + "%"
            settingsSearchLabel: percentage.label
            settingsSearchDescription: percentage.description
            onMoved: percentage.moved(value)
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + 32
        radius: SettingsMaterialPreset.cardRadius
        color: AbyssStyle.surface
        border.width: 1
        border.color: Qt.alpha(AbyssStyle.accent, 0.18)
        GridLayout {
            id: hero
            anchors.fill: parent
            anchors.margins: 16
            columns: width > 600 ? 2 : 1
            columnSpacing: 24
            rowSpacing: 8
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 260
                Layout.preferredHeight: 232
                WaterDropletBody {
                    id: preview
                    objectName: "companionPreview"
                    anchors.centerIn: parent
                    width: 76; height: 92
                    scale: Math.min(2, 1.8 * root.preferences.size)
                    transformOrigin: Item.Center
                    expression: root.previewExpression
                    motionAction: root.previewMotion
                    grounded: !["fly","jump","drag","fall"].includes(root.previewMotion)
                    motionScale: Preferences.motionScale(root.preferences.personality)
                    motionEnabled: root.preferences.animationsEnabled && AbyssStyle.motionEnabled && visible
                    effectsEnabled: root.preferences.effectsEnabled && Appearance.effectsEnabled
                        && AbyssStyle.quality !== "performance"
                    renderQuality: root.preferences.renderQuality
                    translucency: root.preferences.translucency
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                StyledText { text: "Wull"; font.pixelSize: 26; font.weight: Font.DemiBold }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("A little liquid companion for your desktop.")
                    wrapMode: Text.WordWrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Color and reflections follow Abyss Panel Style automatically.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
                ChoiceRow {
                    objectName: "companionPreviewExpression"
                    label: Translation.tr("Preview expression")
                    options: root.expressionOptions
                    currentValue: root.previewExpression
                    onSelected: value => root.previewExpression = value
                }
                ChoiceRow {
                    objectName: "companionPreviewMotion"
                    label: Translation.tr("Preview movement")
                    options: root.motionOptions
                    currentValue: root.previewMotion
                    onSelected: value => root.previewMotion = value
                }
            }
        }
    }

    SettingsTaskNavigator {
        showIntro: false
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Overview"), icon: "water_drop", value: "overview" },
            { displayName: Translation.tr("Behavior"), icon: "sentiment_satisfied", value: "behavior" },
            { displayName: Translation.tr("Rendering"), icon: "diamond", value: "rendering" },
            { displayName: Translation.tr("AI"), icon: "chat", value: "ai" }
        ]
    }

    SettingsCardSection {
        settingsTaskSection: "overview"
        visible: root.activeSection === "overview"
        title: Translation.tr("Overview")
        icon: "water_drop"
        SettingsGroup {
            enabled: Config.ready
            SettingsSwitch {
                objectName: "companionEnabled"
                text: Translation.tr("Enable Companion")
                description: Translation.tr("Let Wull join your desktop. Right-click Wull to open these settings.")
                autoToggle: false
                checked: root.preferences.enabled
                onToggledByUser: checked => root.setPreference("enabled", checked)
            }
            SettingsSwitch {
                objectName: "companionInteractive"
                text: Translation.tr("Respond to pointer interactions")
                description: Translation.tr("Highlight on hover, react to clicks, and drag Wull around your screen.")
                autoToggle: false
                checked: root.preferences.interactive
                onToggledByUser: checked => root.setPreference("interactive", checked)
            }
            SettingsSwitch {
                objectName: "companionFullscreen"
                text: Translation.tr("Always hide in fullscreen")
                description: Translation.tr("Otherwise, follow the screen edge fullscreen setting.")
                autoToggle: false
                checked: root.preferences.hideInFullscreen
                onToggledByUser: checked => root.setPreference("hideInFullscreen", checked)
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "behavior"
        visible: root.activeSection === "behavior"
        title: Translation.tr("Behavior")
        icon: "sentiment_satisfied"
        SettingsGroup {
            enabled: Config.ready
            ChoiceRow {
                objectName: "companionPersonality"
                label: Translation.tr("Personality")
                description: Translation.tr("Calm moves gently. Balanced feels natural. Energetic reacts with bigger movements and more frequent expressions.")
                options: root.personalityOptions
                currentValue: root.preferences.personality
                onSelected: value => root.setPreference("personality", value)
            }
            ChoiceRow {
                objectName: "companionFrequency"
                label: Translation.tr("Appearance frequency")
                description: Translation.tr("Scheduled visits last 20 seconds. Wull stays while you interact or a task is running.")
                options: root.frequencyOptions
                currentValue: root.preferences.appearanceFrequency
                onSelected: value => root.setPreference("appearanceFrequency", value)
            }
            SettingsSwitch {
                objectName: "companionExploreFeatures"
                text: Translation.tr("Explore Abyss features")
                description: Translation.tr("Occasionally open and explore panels, then close them. Wull leaves them open when you start using them.")
                autoToggle: false
                checked: root.preferences.exploreFeatures
                onToggledByUser: checked => root.setPreference("exploreFeatures", checked)
            }
            SettingsSwitch {
                objectName: "companionMotion"
                text: Translation.tr("Companion animations")
                description: Translation.tr("Walk on surfaces, float through open space, and react naturally. Respects the shell motion setting.")
                autoToggle: false
                checked: root.preferences.animationsEnabled
                onToggledByUser: checked => root.setPreference("animationsEnabled", checked)
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "rendering"
        visible: root.activeSection === "rendering"
        title: Translation.tr("Rendering")
        icon: "diamond"
        SettingsGroup {
            enabled: Config.ready
            PercentageRow {
                objectName: "companionSize"
                label: Translation.tr("Companion size")
                description: Translation.tr("Keep Wull small or give it a little more room.")
                value: root.preferences.size
                minimum: 0.65; maximum: 1.5
                onMoved: value => root.setPreference("size", value)
            }
            ChoiceRow {
                objectName: "companionQuality"
                label: Translation.tr("Rendering quality")
                description: Translation.tr("Performance keeps lighting simple. Balanced adds reflected detail. Quality adds deeper refraction and richer liquid light. Follows the shell performance policy.")
                options: root.qualityOptions
                currentValue: root.preferences.renderQuality
                onSelected: value => root.setPreference("renderQuality", value)
            }
            PercentageRow {
                objectName: "companionTranslucency"
                label: Translation.tr("Translucency")
                description: Translation.tr("Let a little of the background show through the liquid. Eyes and bright reflections stay clear.")
                value: root.preferences.translucency
                minimum: 0
                maximum: 0.35
                onMoved: value => root.setPreference("translucency", value)
            }
            SettingsSwitch {
                objectName: "companionEffects"
                text: Translation.tr("Bubbles and floor reflections")
                description: Translation.tr("Add floating bubbles, sparkle and the liquid reflection beneath Wull. Performance uses a simpler floor effect. Respects the shell effects setting.")
                autoToggle: false
                checked: root.preferences.effectsEnabled
                onToggledByUser: checked => root.setPreference("effectsEnabled", checked)
            }
        }
    }

    DialogButton {
        objectName: "companionReset"
        Layout.alignment: Qt.AlignRight
        enabled: Config.ready
        buttonText: Translation.tr("Reset Companion settings")
        onClicked: root.resetPreferences()
    }
    SettingsCardSection {
        settingsTaskSection:"ai"
        visible:root.activeSection==="ai"
        title:Translation.tr("AI")
        icon:"chat"
        SettingsGroup {
            SettingsSwitch {
                text:Translation.tr("Talk clouds")
                description:Translation.tr("Double-click Wull to chat. Occasional messages appear while you are idle.")
                autoToggle:false;checked:WullMind.talkEnabled
                onToggledByUser:checked=>Config.setNestedValue("abyss.companionMind.talkEnabled",checked)
            }
            ChoiceRow {
                label:Translation.tr("Check-ins and reminders")
                options:[{displayName:Translation.tr("Occasionally while idle"),value:"occasional"},{displayName:Translation.tr("Only when I chat"),value:"manual"}]
                currentValue:WullMind.proactive
                onSelected:value=>Config.setNestedValue("abyss.companionMind.proactive",value)
            }
            SettingsSwitch {
                text:Translation.tr("Enable local AI")
                description:Translation.tr("Use an installed Ollama model. Wull keeps moving when the model is unavailable.")
                autoToggle:false;checked:WullMind.aiEnabled
                onToggledByUser:checked=>Config.setNestedValue("abyss.companionMind.aiEnabled",checked)
            }
            StyledText {text:Translation.tr("Connection: Local LLM (Ollama)");Layout.fillWidth:true}
            MaterialTextField {
                objectName:"wullLocalEndpoint";Layout.fillWidth:true
                placeholderText:Translation.tr("Local endpoint")
                text:WullMind.endpoint
                onEditingFinished:Config.setNestedValue("abyss.companionMind.endpoint",text.trim())
            }
            MaterialTextField {
                objectName:"wullLocalModel";Layout.fillWidth:true
                placeholderText:Translation.tr("Installed model name")
                text:WullMind.model
                onEditingFinished:Config.setNestedValue("abyss.companionMind.model",text.trim())
            }
            StyledText {
                Layout.fillWidth:true;wrapMode:Text.WordWrap
                text:Translation.tr("Status")+": "+WullMind.connectionStatus+(WullMind.errorMessage ? " · "+WullMind.errorMessage : "")
                color:Appearance.colors.colSubtext
            }
            RowLayout {
                DialogButton {buttonText:Translation.tr("Test connection");enabled:!WullMind.busy;onClicked:WullMind.testConnection()}
                DialogButton {buttonText:Translation.tr("Chat with Wull");enabled:root.preferences.enabled;onClicked:WullMind.openChat()}
                DialogButton {buttonText:Translation.tr("Clear conversation");onClicked:WullMind.clearConversation()}
            }
            Repeater {
                model:WullMind.models
                DialogButton {
                    required property var modelData
                    buttonText:modelData.name
                    onClicked:Config.setNestedValue("abyss.companionMind.model",modelData.name)
                }
            }
            SettingsSwitch {
                text:Translation.tr("Connect Obsidian")
                description:Translation.tr("Read mood, energy and upcoming times from your shared Todo vault. Journals stay unchanged.")
                autoToggle:false;checked:WullMind.obsidianEnabled
                onToggledByUser:checked=>Config.setNestedValue("abyss.companionMind.obsidianEnabled",checked)
            }
            StyledText {Layout.fillWidth:true;wrapMode:Text.WordWrap
                text:Translation.tr("Obsidian vault")+": "+(Todo.sharedVaultPath || Translation.tr("Not configured"))}
            MaterialTextField {
                objectName:"wullReferenceVault";Layout.fillWidth:true
                placeholderText:Translation.tr("Reference vault (optional)")
                text:WullMind.options.referenceVault ?? ""
                onEditingFinished:Config.setNestedValue("abyss.companionMind.referenceVault",text.trim())
            }
            RowLayout {
                DialogButton {buttonText:Translation.tr("Read today's context");enabled:WullMind.obsidianEnabled && !WullMind.busy;onClicked:WullMind.refreshJournal()}
                DialogButton {buttonText:Translation.tr("Open journal");enabled:!!WullMind.journal.journalPath;onClicked:WullMind.openJournal()}
            }
            StyledText {Layout.fillWidth:true;wrapMode:Text.WordWrap
                text:Translation.tr("Session memory only. Model requests run on demand, with one request at a time.")
                color:Appearance.colors.colSubtext;font.pixelSize:Appearance.font.pixelSize.smaller}
        }
    }

}
