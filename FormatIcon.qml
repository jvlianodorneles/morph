import QtQuick
import qs.Commons as Commons

Item {
    id: root
    property string formatName: ""
    property string category: "other"
    property bool selected: false
    property color ink: Commons.Color.menu.text

    implicitWidth: 64
    implicitHeight: 32

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
        spacing: 3

        Text {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.formatName
            color: root.selected ? Commons.Color.menu.selectedText || "#ffffff" : root.ink
            font.family: Commons.Style.font.menuFamily
            font.pixelSize: Commons.Style.space(12)
            font.weight: root.selected ? Font.Bold : Font.DemiBold
            textFormat: Text.PlainText
            elide: Text.ElideNone

            scale: root.selected ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // Elegant category indicator dot
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.selected ? 8 : 4
            height: 3
            radius: 1.5
            color: root.selected ? (Commons.Color.menu.selectedText || "#ffffff") : root.categoryColor
            opacity: root.selected ? 0.9 : 0.65

            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }
}
