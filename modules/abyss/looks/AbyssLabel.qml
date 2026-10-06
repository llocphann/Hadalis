import QtQuick
import qs.modules.common

Text {
    color: Appearance.m3colors.darkmode ? AbyssStyle.textColor : "#000000"
    font.family: AbyssStyle.fontFamily
    font.pixelSize: AbyssStyle.fontSize
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
}
