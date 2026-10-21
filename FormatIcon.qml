import QtQuick
import qs.Commons as Commons

Item {
    id: root
    property string formatName: ""
    property string category: "other"
    property bool selected: false
    property color ink: Commons.Color.menu.text

    implicitWidth: 50
    implicitHeight: 28

    // Category accent dot / tint
    readonly property color categoryColor: {
        switch (root.category) {
            case "image": return "#38bdf8";      // sky blue
            case "video": return "#a855f7";      // purple
            case "audio": return "#22c55e";      // green
            case "document": return "#f97316";   // orange
            case "archive": return "#eab308";    // yellow
            default: return Commons.Color.accent;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.parent.width, badgeText.implicitWidth + 12)
            height: Math.round(badgeText.implicitHeight + 4)
            radius: height / 2
            color: root.selected ? Commons.Color.accent : Commons.Util.alpha(root.categoryColor, 0.15)
            border.width: 1
            border.color: root.selected ? "#ffffff" : Commons.Util.alpha(root.categoryColor, 0.4)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.formatName
                color: root.selected ? "#ffffff" : root.ink
                font.family: Commons.Style.font.menuFamily
                font.pixelSize: Commons.Style.space(11)
                font.weight: Font.Bold
                textFormat: Text.PlainText
            }
        }
    }
}
