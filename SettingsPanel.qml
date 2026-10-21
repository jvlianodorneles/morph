import QtQuick
import qs.Commons as Commons
import qs.Ui

FocusScope {
    id: panel

    property var original: ({})
    property int diameter: 280
    property int slotCount: 8
    property bool animation: true
    property string outputDirectoryMode: "source"
    property string customOutputPath: ""
    property bool notifications: true
    property bool dragShift: true
    property string shortcut: "SUPER + ALT + C"
    property var preferredFormats: ({})

    property int tab: 0
    property string currentCategory: "image"
    property bool busy: false
    property string error: ""

    signal saveRequested(var draft)
    signal canceled()

    implicitWidth: Math.min(460, parent ? parent.width - 40 : 460)
    implicitHeight: contentCol.height + Commons.Style.space(36)
    height: implicitHeight

    function begin(cfg) {
        original = JSON.parse(JSON.stringify(cfg || {}));
        diameter = cfg.diameter || 280;
        slotCount = cfg.slotCount || 8;
        animation = cfg.animation !== false;
        outputDirectoryMode = cfg.outputDirectoryMode || "source";
        customOutputPath = cfg.customOutputPath || "";
        notifications = cfg.notifications !== false;
        dragShift = cfg.dragShift !== false;
        shortcut = cfg.shortcut || "SUPER + ALT + C";
        preferredFormats = JSON.parse(JSON.stringify(cfg.preferredFormats || {}));
        tab = 0;
        currentCategory = "image";
        error = "";
    }

    function draft() {
        return {
            diameter: diameter,
            slotCount: slotCount,
            animation: animation,
            outputDirectoryMode: outputDirectoryMode,
            customOutputPath: customOutputPath,
            notifications: notifications,
            dragShift: dragShift,
            shortcut: shortcut,
            preferredFormats: preferredFormats
        };
    }

    function moveFormat(cat, index, delta) {
        var list = preferredFormats[cat] ? preferredFormats[cat].slice() : [];
        var target = index + delta;
        if (target < 0 || target >= list.length) return;
        var temp = list[index];
        list[index] = list[target];
        list[target] = temp;
        var updated = JSON.parse(JSON.stringify(preferredFormats));
        updated[cat] = list;
        preferredFormats = updated;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            canceled();
            event.accepted = true;
        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
            saveRequested(draft());
            event.accepted = true;
        }
    }

    component Label: Text {
        textFormat: Text.PlainText
        color: Commons.Color.menu.text
        font.family: Commons.Style.font.menuFamily
        font.pixelSize: Commons.Style.space(12)
        elide: Text.ElideRight
    }

    // Background card
    Rectangle {
        anchors.fill: parent
        radius: Commons.Style.cornerRadius
        color: Commons.Color.menu.background
        border.width: 1
        border.color: Commons.Util.alpha(Commons.Color.menu.text, 0.22)
    }

    Column {
        id: contentCol
        x: Commons.Style.space(18); y: x
        width: parent.width - x * 2
        spacing: Commons.Style.space(12)

        // Title and subtitle
        Row {
            width: parent.width
            spacing: Commons.Style.space(8)

            Column {
                width: parent.width - closeBtn.width - parent.spacing
                spacing: 2
                Label {
                    text: "Convert Orb"
                    font.pixelSize: Commons.Style.space(18)
                    font.weight: Font.DemiBold
                }
                Label {
                    text: "Configure triggers, output formats, and appearance"
                    font.pixelSize: Commons.Style.space(11)
                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.6)
                }
            }

            Button {
                id: closeBtn
                text: "×"
                width: Commons.Style.space(26)
                height: width
                bordered: true
                foreground: Commons.Color.menu.text
                onClicked: panel.canceled()
            }
        }

        // Tabs
        Row {
            width: parent.width
            spacing: Commons.Style.space(6)
            Repeater {
                model: [
                    { title: "Formats", id: 0 },
                    { title: "Triggers & Output", id: 1 },
                    { title: "Appearance", id: 2 }
                ]
                delegate: Button {
                    required property var modelData
                    width: (contentCol.width - Commons.Style.space(12)) / 3
                    text: modelData.title
                    selected: panel.tab === modelData.id
                    bordered: true
                    foreground: Commons.Color.menu.text
                    onClicked: { panel.tab = modelData.id; panel.forceActiveFocus(); }
                }
            }
        }

        // TAB 0: FORMATS
        Column {
            visible: panel.tab === 0
            width: parent.width
            spacing: Commons.Style.space(10)

            // Category selector chips
            Row {
                width: parent.width
                spacing: Commons.Style.space(4)
                Repeater {
                    model: [
                        { name: "Images", key: "image" },
                        { name: "Video", key: "video" },
                        { name: "Audio", key: "audio" },
                        { name: "Docs", key: "document" },
                        { name: "Archive", key: "archive" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - Commons.Style.space(16)) / 5
                        height: Commons.Style.space(26)
                        radius: Commons.Style.cornerRadius
                        color: panel.currentCategory === modelData.key ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.menu.text, 0.08)
                        border.width: 1
                        border.color: panel.currentCategory === modelData.key ? Commons.Color.accent : Commons.Util.alpha(Commons.Color.menu.text, 0.15)

                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData.name
                            font.pixelSize: Commons.Style.space(10)
                            color: panel.currentCategory === parent.modelData.key ? "#ffffff" : Commons.Color.menu.text
                            font.weight: panel.currentCategory === parent.modelData.key ? Font.Bold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.currentCategory = parent.modelData.key
                        }
                    }
                }
            }

            Label {
                text: "Preferred output formats (top formats appear first on the wheel):"
                font.pixelSize: Commons.Style.space(10)
                color: Commons.Util.alpha(Commons.Color.menu.text, 0.6)
            }

            // Format reordering list
            ListView {
                id: formatsList
                width: parent.width
                height: Commons.Style.space(160)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: Commons.Style.space(4)
                model: panel.preferredFormats[panel.currentCategory] || []

                delegate: Rectangle {
                    required property int index
                    required property string modelData
                    width: formatsList.width
                    height: Commons.Style.space(32)
                    radius: Commons.Style.cornerRadius
                    color: Commons.Util.alpha(Commons.Color.menu.text, 0.04)
                    border.width: 1
                    border.color: Commons.Util.alpha(Commons.Color.menu.text, 0.12)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Commons.Style.space(10)
                        anchors.rightMargin: Commons.Style.space(6)
                        spacing: Commons.Style.space(8)

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(index + 1)
                            font.pixelSize: Commons.Style.space(10)
                            color: Commons.Util.alpha(Commons.Color.menu.text, 0.5)
                            width: Commons.Style.space(14)
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            font.weight: Font.DemiBold
                            width: parent.width - Commons.Style.space(100)
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Commons.Style.space(4)

                            Button {
                                text: "▲"
                                width: Commons.Style.space(22)
                                height: width
                                enabled: index > 0
                                bordered: true
                                foreground: Commons.Color.menu.text
                                onClicked: panel.moveFormat(panel.currentCategory, index, -1)
                            }
                            Button {
                                text: "▼"
                                width: Commons.Style.space(22)
                                height: width
                                enabled: index < (panel.preferredFormats[panel.currentCategory] ? panel.preferredFormats[panel.currentCategory].length - 1 : 0)
                                bordered: true
                                foreground: Commons.Color.menu.text
                                onClicked: panel.moveFormat(panel.currentCategory, index, 1)
                            }
                        }
                    }
                }
            }
        }

        // TAB 1: TRIGGERS & OUTPUT
        Column {
            visible: panel.tab === 1
            width: parent.width
            spacing: Commons.Style.space(12)

            // Trigger dragShift
            Row {
                width: parent.width
                spacing: Commons.Style.space(10)

                Column {
                    width: parent.width - shiftToggle.width - parent.spacing
                    spacing: 2
                    Label { text: "Drag + Shift trigger"; font.weight: Font.DemiBold }
                    Label {
                        text: "Show wheel when dragging any file while holding Shift"
                        font.pixelSize: Commons.Style.space(10)
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.6)
                    }
                }
                Button {
                    id: shiftToggle
                    text: panel.dragShift ? "Enabled" : "Disabled"
                    selected: panel.dragShift
                    bordered: true
                    foreground: Commons.Color.menu.text
                    onClicked: panel.dragShift = !panel.dragShift
                }
            }

            Rectangle { width: parent.width; height: 1; color: Commons.Util.alpha(Commons.Color.menu.text, 0.1) }

            // Output directory mode
            Column {
                width: parent.width
                spacing: Commons.Style.space(6)
                Label { text: "Output destination"; font.weight: Font.DemiBold }
                Row {
                    width: parent.width
                    spacing: Commons.Style.space(8)
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: "Same as source file"
                        selected: panel.outputDirectoryMode === "source"
                        bordered: true
                        foreground: Commons.Color.menu.text
                        onClicked: panel.outputDirectoryMode = "source"
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: "Custom folder"
                        selected: panel.outputDirectoryMode === "custom"
                        bordered: true
                        foreground: Commons.Color.menu.text
                        onClicked: panel.outputDirectoryMode = "custom"
                    }
                }

                Item {
                    visible: panel.outputDirectoryMode === "custom"
                    width: parent.width
                    height: Commons.Style.space(32)
                    Rectangle {
                        anchors.fill: parent
                        radius: Commons.Style.cornerRadius
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.05)
                        border.width: 1
                        border.color: Commons.Util.alpha(Commons.Color.menu.text, 0.2)

                        TextInput {
                            id: customPathInput
                            anchors.fill: parent
                            anchors.leftMargin: Commons.Style.space(8)
                            anchors.rightMargin: Commons.Style.space(8)
                            verticalAlignment: TextInput.AlignVCenter
                            text: panel.customOutputPath
                            font.family: Commons.Style.font.menuFamily
                            font.pixelSize: Commons.Style.space(11)
                            color: Commons.Color.menu.text
                            onTextChanged: panel.customOutputPath = text
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Commons.Util.alpha(Commons.Color.menu.text, 0.1) }

            // Notifications toggle
            Row {
                width: parent.width
                spacing: Commons.Style.space(10)
                Column {
                    width: parent.width - notifToggle.width - parent.spacing
                    spacing: 2
                    Label { text: "Desktop notifications"; font.weight: Font.DemiBold }
                    Label {
                        text: "Display system notification when conversion completes"
                        font.pixelSize: Commons.Style.space(10)
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.6)
                    }
                }
                Button {
                    id: notifToggle
                    text: panel.notifications ? "On" : "Off"
                    selected: panel.notifications
                    bordered: true
                    foreground: Commons.Color.menu.text
                    onClicked: panel.notifications = !panel.notifications
                }
            }
        }

        // TAB 2: APPEARANCE
        Column {
            visible: panel.tab === 2
            width: parent.width
            spacing: Commons.Style.space(14)

            // Diameter slider
            Column {
                width: parent.width
                spacing: Commons.Style.space(4)
                Label { text: "Wheel diameter: " + panel.diameter + " px"; font.weight: Font.DemiBold }
                PanelSlider {
                    width: parent.width
                    minimum: 220
                    maximum: 450
                    step: 10
                    integer: true
                    value: panel.diameter
                    trackColor: Commons.Util.alpha(Commons.Color.menu.text, 0.15)
                    fillColor: Commons.Color.accent
                    knobColor: Commons.Color.accent
                    onMoved: val => panel.diameter = Math.round(val / 10) * 10
                }
            }

            // Slot count (6 or 8)
            Column {
                width: parent.width
                spacing: Commons.Style.space(4)
                Label { text: "Format slots per ring"; font.weight: Font.DemiBold }
                Row {
                    width: parent.width
                    spacing: Commons.Style.space(8)
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: "6 Slots (Spacious)"
                        selected: panel.slotCount === 6
                        bordered: true
                        foreground: Commons.Color.menu.text
                        onClicked: panel.slotCount = 6
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: "8 Slots (Standard)"
                        selected: panel.slotCount === 8
                        bordered: true
                        foreground: Commons.Color.menu.text
                        onClicked: panel.slotCount = 8
                    }
                }
            }

            // Animation
            Row {
                width: parent.width
                spacing: Commons.Style.space(10)
                Column {
                    width: parent.width - animToggle.width - parent.spacing
                    spacing: 2
                    Label { text: "Smooth animations"; font.weight: Font.DemiBold }
                    Label {
                        text: "Enable wheel scale and opacity bloom effects"
                        font.pixelSize: Commons.Style.space(10)
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.6)
                    }
                }
                Button {
                    id: animToggle
                    text: panel.animation ? "Enabled" : "Disabled"
                    selected: panel.animation
                    bordered: true
                    foreground: Commons.Color.menu.text
                    onClicked: panel.animation = !panel.animation
                }
            }
        }

        // Error message if any
        Label {
            visible: panel.error !== ""
            width: parent.width
            text: panel.error
            color: "#ef4444"
            font.pixelSize: Commons.Style.space(11)
        }

        // Action buttons: Cancel / Save
        Row {
            width: parent.width
            spacing: Commons.Style.space(8)

            Button {
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                bordered: true
                foreground: Commons.Color.menu.text
                onClicked: panel.canceled()
            }

            Button {
                width: (parent.width - parent.spacing) / 2
                text: "Save Settings"
                selected: true
                bordered: true
                foreground: "#ffffff"
                onClicked: panel.saveRequested(panel.draft())
            }
        }
    }
}
