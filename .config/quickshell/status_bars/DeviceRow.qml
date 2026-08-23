import QtQuick
import QtQuick.Layouts

// Одна строка меню: метка выбора + название устройства + правая приписка.
Item {
    id: row

    property var node: null
    property string label: ""
    property string detail: ""
    property bool current: false
    property bool busy: false
    property bool showMark: true
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color markColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"
    property color labelColor: current ? textColor : mutedTextColor
    property color detailColor: mutedTextColor

    signal activated()

    Layout.fillWidth: true
    Layout.preferredHeight: 24
    implicitWidth: 18 + rowLabel.implicitWidth + 4
        + (rowDetail.visible ? rowDetail.implicitWidth + 10 : 0)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        radius: 3
        color: rowHover.hovered ? row.hoverColor : "transparent"

        Behavior on color {
            ColorAnimation { duration: 90 }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: row.showMark
        text: row.busy ? "◐" : (row.current ? "●" : "○")
        color: row.current || row.busy ? row.textColor : row.markColor
        font.family: row.fontFamily
        font.pixelSize: 11
        renderType: Text.NativeRendering
    }

    Text {
        id: rowLabel

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: rowDetail.visible ? rowDetail.left : parent.right
        anchors.rightMargin: rowDetail.visible ? 10 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        color: row.labelColor
        font.family: row.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    Text {
        id: rowDetail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.detail.length > 0
        text: row.detail
        color: row.detailColor
        font.family: row.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        anchors.fill: parent
        enabled: !row.busy
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
