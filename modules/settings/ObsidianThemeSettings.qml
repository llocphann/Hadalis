pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import qs
import qs.services
import qs.modules.settings
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
SettingsCardSection {
 id:root
 title:Translation.tr("Obsidian theming");icon:"palette";expanded:true
 Component.onCompleted:ObsidianTheme.inspect()
 SettingsNativeDialogGuard {dialog:picker;dialogKey:"obsidianConfigPicker"}
 FolderDialog {
  id:picker;title:"Obsidian configuration folder"
  onAccepted:Config.setNestedValue("integrations.obsidian.configPath",FileUtils.trimFileProtocol(String(selectedFolder)))
 }
 SettingsGroup {
  StyledText {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Uses the shared vault below. Hadalis detects its active theme and adds a color snippet using your Carbon Cyan gradient.";color:Appearance.colors.colSubtext}
  SettingsSwitch {text:"Follow shell colors automatically";autoToggle:false;checked:ObsidianTheme.enabled;onToggledByUser:checked=>Config.setNestedValue("integrations.obsidian.autoTheme",checked)}
  StyledText {text:"Vault configuration folder";color:Appearance.colors.colSubtext}
  RowLayout {
   Layout.fillWidth:true
   MaterialTextField {Layout.fillWidth:true;wrapMode:TextInput.NoWrap;text:Config.options?.integrations?.obsidian?.configPath ?? "";placeholderText:".obsidian (inside the shared vault)";onEditingFinished:Config.setNestedValue("integrations.obsidian.configPath",text.trim())}
   RippleButtonWithIcon {materialIcon:"folder_open";onClicked:picker.open()}
  }
  StyledText {text:"Application configuration folder";color:Appearance.colors.colSubtext}
  MaterialTextField {Layout.fillWidth:true;wrapMode:TextInput.NoWrap;text:Config.options?.integrations?.obsidian?.applicationConfigPath ?? "";placeholderText:"Auto-detect Obsidian's application config";onEditingFinished:Config.setNestedValue("integrations.obsidian.applicationConfigPath",text.trim())}
  StyledText {text:"Application executable";color:Appearance.colors.colSubtext}
  RowLayout {
   Layout.fillWidth:true
   MaterialTextField {Layout.fillWidth:true;wrapMode:TextInput.NoWrap;text:Config.options?.integrations?.obsidian?.applicationPath ?? "obsidian";placeholderText:"obsidian";onEditingFinished:Config.setNestedValue("integrations.obsidian.applicationPath",text.trim() || "obsidian")}
   DialogButton {buttonText:"Open Obsidian";onClicked:Quickshell.execDetached([String(Config.options?.integrations?.obsidian?.applicationPath || "obsidian").trim()])}
  }
  StyledText {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:ObsidianTheme.error ? Appearance.colors.colError : Appearance.colors.colSubtext;text:ObsidianTheme.error || (ObsidianTheme.info.activeTheme ? "Active theme: "+ObsidianTheme.info.activeTheme+" · "+ObsidianTheme.info.profile+"\n"+ObsidianTheme.info.configPath : "Choose a shared vault or detect the open Obsidian vault.")}
  RowLayout {
   DialogButton {buttonText:"Detect theme";enabled:!ObsidianTheme.busy;onClicked:ObsidianTheme.inspect()}
   DialogButton {buttonText:"Apply colors";enabled:!ObsidianTheme.busy;onClicked:ObsidianTheme.apply()}
   DialogButton {buttonText:"Restore theme colors";enabled:!ObsidianTheme.busy && (ObsidianTheme.info.enabled ?? false);onClicked:ObsidianTheme.restore()}
  }
  DialogButton {buttonText:"Use detected vault";visible:!Todo.sharedVaultPath && !!ObsidianTheme.info.vaultPath;onClicked:Config.setNestedValue("todo.obsidian.vaultPath",ObsidianTheme.info.vaultPath)}
 }
}
