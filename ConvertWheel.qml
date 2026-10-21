import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
    id: root

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null

    readonly property string pluginId: "dorneles.convert-orb"
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy"
    readonly property string configPath: configDir + "/convert-orb.json"

    // Configuration object
    property var config: ({
        diameter: 280,
        slotCount: 8,
        animation: true,
        outputDirectoryMode: "source",
        customOutputPath: "",
        notifications: true,
        dragShift: true,
        shortcut: "SUPER + ALT + C",
        preferredFormats: {
            image: ["PNG", "WEBP", "JPEG", "AVIF", "PDF", "SVG", "GIF", "BMP"],
            video: ["MP4", "WEBM", "MKV", "MP3", "GIF", "MOV", "AVI"],
            audio: ["MP3", "WAV", "FLAC", "OGG", "AAC", "OPUS", "M4A"],
            document: ["PDF", "DOCX", "ODT", "TXT", "EPUB", "HTML"],
            archive: ["ZIP", "TAR.GZ", "TAR.XZ", "7Z"]
        }
    })

    // State
    property bool overlayActive: false
    property bool wheelOpened: false
    property bool settingsOpen: false
    property point pointer: Qt.point(0, 0)
    property bool positioned: false

    // Dragged item information
    property var draggedFiles: []
    property string sourceFormat: ""
    property string sourceFilename: ""
    property string category: "other"
    property var availableFormats: []
    property string defaultFormat: ""

    // Wheel paging & selection
    property int formatPage: 0
    property int selected: -1
    property var formatResult: Model.prioritizeFormats(
        category,
        availableFormats,
        config.preferredFormats,
        config.slotCount || 8,
        formatPage
    )
    readonly property var wheelSlices: formatResult.items
    readonly property int selectionCount: wheelSlices.length
    readonly property int totalPages: formatResult.totalPages

    // Hub active state
    readonly property bool hubActive: selected === -2

    // Helper process status
    property bool converting: false
    property string statusMessage: ""

    // Open/Close functions
    function open(payloadJson) { summon(payloadJson); }

    function summon(payloadJson) {
        try {
            var payload = JSON.parse(payloadJson || "{}");
            if (payload.openSettings) {
                openSettings();
                return;
            }
            if (payload.files && Array.isArray(payload.files) && payload.files.length > 0) {
                settingsOpen = false;
                overlayActive = true;
                cursorPos.running = true;
                requestFormats(payload.files);
                return;
            }
        } catch (e) {}
        openSettings();
    }

    function openSettings() {
        cursorPos.running = true;
        settingsCard.begin(root.config);
        settingsOpen = true;
        overlayActive = true;
        Qt.callLater(function() { settingsCard.forceActiveFocus(); });
    }

    function closeSettings() {
        settingsOpen = false;
        if (!wheelOpened) overlayActive = false;
    }

    function dismiss() {
        wheelOpened = false;
        settingsOpen = false;
        overlayActive = false;
        selected = -1;
        draggedFiles = [];
        availableFormats = [];
        sourceFormat = "";
        sourceFilename = "";
    }

    function turnPage(delta) {
        if (totalPages <= 1) return;
        formatPage = (formatPage + delta + totalPages) % totalPages;
        selected = -1;
    }

    function requestFormats(paths) {
        if (!paths || paths.length === 0) return;
        draggedFiles = paths;
        queryProc.running = false;
        queryProc.command = [
            "/usr/bin/python3",
            decodeURIComponent(Qt.resolvedUrl("scripts/query_formats.py").toString().replace(/^file:\/\//, ""))
        ].concat(paths);
        queryProc.running = true;
    }

    function executeConversion(targetFormat) {
        if (!targetFormat || draggedFiles.length === 0) {
            dismiss();
            return;
        }
        var args = [
            "/usr/bin/python3",
            decodeURIComponent(Qt.resolvedUrl("scripts/convert_file.py").toString().replace(/^file:\/\//, ""))
        ];
        if (config.outputDirectoryMode === "custom" && config.customOutputPath) {
            args.push("--output-dir");
            args.push(config.customOutputPath);
        }
        if (!config.notifications) {
            args.push("--no-notify");
        }
        args.push(targetFormat);
        for (var i = 0; i < draggedFiles.length; i++) {
            args.push(draggedFiles[i]);
        }

        converting = true;
        statusMessage = "Converting to " + targetFormat + "...";
        convertProc.command = args;
        convertProc.running = true;
    }

    // Default configuration loader
    Component.onCompleted: setupProcess.running = true

    Process {
        id: setupProcess
        command: [
            "bash",
            decodeURIComponent(Qt.resolvedUrl("scripts/setup").toString().replace(/^file:\/\//, "")),
            root.pluginId
        ]
    }

    FileView {
        id: defaults
        path: Qt.resolvedUrl("config.example.json")
        onLoaded: {
            root.config = Model.parse(text(), root.config).config;
            userConfigFile.reload();
        }
    }

    // User configuration watcher
    FileView {
        id: userConfigFile
        path: root.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var parsed = Model.parse(text(), root.config);
            if (!parsed.error) root.config = parsed.config;
        }
    }

    // Settings writer
    FileView {
        id: settingsWriter
        path: root.configPath
        preload: false
        blockLoading: true
        atomicWrites: true
        onSaved: {
            userConfigFile.reload();
            root.closeSettings();
        }
    }

    // Cursor position query
    Process {
        id: cursorPos
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var p = JSON.parse(text);
                    if (isFinite(p.x) && isFinite(p.y)) {
                        root.pointer = Qt.point(p.x, p.y);
                        root.positioned = true;
                    }
                } catch (e) {}
            }
        }
    }

    // Background drag + shift detector
    Process {
        id: dragListener
        command: [
            "/usr/bin/python3",
            decodeURIComponent(Qt.resolvedUrl("scripts/drag_listener.py").toString().replace(/^file:\/\//, ""))
        ]
        running: root.config.dragShift !== false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    var msg = JSON.parse(data.trim());
                    if (msg.drag_shift === true) {
                        cursorPos.running = true;
                        root.overlayActive = true;
                    } else if (msg.drag_shift === false) {
                        if (!root.settingsOpen && !root.converting) {
                            root.dismiss();
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // Format query process
    Process {
        id: queryProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var info = JSON.parse(text.trim());
                    if (info.valid && info.available_formats && info.available_formats.length > 0) {
                        root.sourceFormat = info.source_format;
                        root.sourceFilename = info.filename;
                        root.category = info.category;
                        root.availableFormats = info.available_formats;
                        root.defaultFormat = info.default_format;
                        root.formatPage = 0;
                        root.selected = -1;
                        root.wheelOpened = true;
                        cursorPos.running = false;
                        cursorPos.running = true;
                    } else {
                        root.wheelOpened = false;
                    }
                } catch (e) {
                    root.wheelOpened = false;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) console.warn("queryProc stderr:", text);
            }
        }
    }

    // Converter execution process
    Process {
        id: convertProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.converting = false;
                root.dismiss();
            }
        }
        onExited: (code, status) => {
            root.converting = false;
            root.dismiss();
        }
    }

    // IPC Handler
    IpcHandler {
        target: root.pluginId
        function open(payloadJson: string): void { root.open(payloadJson); }
        function summon(payloadJson: string): void { root.summon(payloadJson); }
        function testFile(filePath: string): void { root.open(JSON.stringify({ files: [filePath] })); }
        function openSettings(): void { root.openSettings(); }
        function dismiss(): void { root.dismiss(); }
        function close(): void { root.dismiss(); }
        function status(): string {
            return JSON.stringify({
                pluginId: root.pluginId,
                overlayActive: root.overlayActive,
                wheelOpened: root.wheelOpened,
                settingsOpen: root.settingsOpen,
                draggedFiles: root.draggedFiles,
                sourceFormat: root.sourceFormat,
                availableFormats: root.availableFormats,
                selected: root.selected
            });
        }
    }

    // Overlay Window
    OverlayWindow {
        id: panelWindow
        shown: root.overlayActive
        shownKeyboardFocus: root.settingsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "omarchy-plugin-convert-orb"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        readonly property var monitorData: targetMonitor ? targetMonitor.lastIpcObject : ({})
        readonly property var placement: Model.placement(
            root.pointer.x - (monitorData.x || 0),
            root.pointer.y - (monitorData.y || 0),
            width,
            height,
            monitorData.reserved || [0, 0, 0, 0],
            Commons.Style.space(root.config.diameter || 280)
        )

        // Dismiss on clicking empty area
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: {
                if (root.settingsOpen) root.closeSettings();
                else root.dismiss();
            }
        }

        // Fullscreen DropArea to detect dragging anywhere
        DropArea {
            id: globalDropArea
            anchors.fill: parent
            keys: ["text/uri-list"]

            onEntered: drag => {
                var rawUris = drag.getDataAsString("text/uri-list");
                var paths = Model.pathsFromUris(rawUris);
                if (paths.length > 0) {
                    root.requestFormats(paths);
                    drag.accept(Qt.CopyAction);
                }
            }

            onExited: {
                if (!root.settingsOpen && !root.converting) {
                    root.wheelOpened = false;
                }
            }
        }

        // The Radial Wheel
        Item {
            id: wheel
            visible: root.wheelOpened && !root.settingsOpen
            x: panelWindow.placement.x
            y: panelWindow.placement.y
            width: panelWindow.placement.size
            height: width
            opacity: visible ? 1 : 0
            scale: visible ? 1 : 0.85

            readonly property real captionScale: panelWindow.placement.captionScale

            Behavior on opacity {
                NumberAnimation {
                    duration: root.config.animation ? Commons.Style.duration(160) : 0
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.config.animation ? Commons.Style.duration(160) : 0
                    easing.type: Easing.OutCubic
                }
            }

            // Outer background ring
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.98; height: width; radius: width / 2
                color: Commons.Color.menu.background
                border.width: 1
                border.color: Commons.Util.alpha(Commons.Color.menu.text, 0.22)
            }

            // Canvas drawing sectors
            Canvas {
                id: ringCanvas
                anchors.fill: parent
                antialiasing: true

                property color surface: Commons.Color.menu.background
                property color ink: Commons.Color.menu.text
                property color selectedFill: Commons.Color.menu.selectedBackground
                property color selectedOutline: Commons.Color.menu.selectedBorder
                property int selection: root.selected
                property int count: root.selectionCount

                onSelectionChanged: requestPaint()
                onCountChanged: requestPaint()
                onSurfaceChanged: requestPaint()
                onSelectedFillChanged: requestPaint()

                onPaint: {
                    var c = getContext("2d");
                    c.reset();
                    var center = width / 2;
                    var outer = width * 0.48;
                    var inner = width * 0.18;
                    c.lineWidth = 1;
                    var step = 360 / Math.max(1, count);

                    for (var i = 0; i < count; i++) {
                        var start = (i * step - 90 - step / 2 + 1.2) * Math.PI / 180;
                        var end = (i * step - 90 + step / 2 - 1.2) * Math.PI / 180;

                        c.beginPath();
                        c.arc(center, center, outer, start, end);
                        c.arc(center, center, inner, end, start, true);
                        c.closePath();

                        c.fillStyle = (i === selection) ? selectedFill : surface;
                        c.fill();

                        c.strokeStyle = (i === selection) ? selectedOutline : Commons.Util.alpha(ink, 0.22);
                        c.stroke();

                        if (i === selection) {
                            c.beginPath();
                            c.arc(center, center, outer - 3, start + 0.03, end - 0.03);
                            c.strokeStyle = selectedOutline;
                            c.lineWidth = 3;
                            c.stroke();
                            c.lineWidth = 1;
                        }
                    }
                }
            }

            // Radial format items
            Repeater {
                model: root.wheelSlices
                delegate: Item {
                    required property int index
                    required property string modelData

                    readonly property real angle: (index * 360 / root.selectionCount - 90) * Math.PI / 180
                    readonly property bool chosen: root.selected === index

                    width: wheel.width * 0.24
                    height: Math.max(26, wheel.width * 0.09)
                    x: wheel.width / 2 + Math.cos(angle) * wheel.width * 0.33 - width / 2
                    y: wheel.height / 2 + Math.sin(angle) * wheel.width * 0.33 - height / 2

                    FormatIcon {
                        anchors.centerIn: parent
                        formatName: modelData
                        category: root.category
                        selected: chosen
                        ink: Commons.Color.menu.text
                    }
                }
            }

            // Center Hub (Source info / Settings opener)
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.32
                height: width
                radius: width / 2
                color: root.hubActive ? Commons.Color.menu.selectedBackground : Commons.Color.menu.background
                border.width: 1
                border.color: root.hubActive ? Commons.Color.menu.selectedBorder : Commons.Util.alpha(Commons.Color.menu.text, 0.22)

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    width: parent.width - 12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.parent.width * 0.34
                        height: width
                        source: Qt.resolvedUrl("assets/convert-icon.svg")
                        sourceSize.width: Math.ceil(width * 2)
                        sourceSize.height: Math.ceil(height * 2)
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.sourceFormat || "CONVERT"
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.space(9)
                        font.weight: Font.Bold
                        color: root.hubActive ? "#ffffff" : Commons.Color.accent
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSettings()
                }
            }

            // DropArea specific to the wheel
            DropArea {
                id: wheelDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                onPositionChanged: drag => {
                    var s = Model.hit(drag.x, drag.y, width, root.selectionCount);
                    root.selected = s;
                }

                onExited: {
                    root.selected = -1;
                }

                onDropped: drop => {
                    var s = Model.hit(drop.x, drop.y, width, root.selectionCount);
                    if (s >= 0 && s < root.selectionCount) {
                        var chosenFormat = root.wheelSlices[s];
                        drop.accept(Qt.CopyAction);
                        root.executeConversion(chosenFormat);
                    } else if (s === -2) {
                        root.openSettings();
                    } else {
                        root.dismiss();
                    }
                }
            }

            // Wheel MouseArea for hovering / scrolling without drag
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onPositionChanged: mouse => {
                    root.selected = Model.hit(mouse.x, mouse.y, width, root.selectionCount);
                }
                onExited: root.selected = -1
                onClicked: mouse => {
                    var s = Model.hit(mouse.x, mouse.y, width, root.selectionCount);
                    if (s >= 0 && s < root.selectionCount) {
                        root.executeConversion(root.wheelSlices[s]);
                    } else if (s === -2) {
                        root.openSettings();
                    } else {
                        root.dismiss();
                    }
                }
                onWheel: event => {
                    root.turnPage(event.angleDelta.y < 0 ? 1 : -1);
                    event.accepted = true;
                }
            }

            // Footer hint card
            Rectangle {
                anchors.top: parent.bottom
                anchors.topMargin: 10 * wheel.captionScale
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(panelWindow.width - 40, hintText.implicitWidth + (root.totalPages > 1 ? 72 : 28) * wheel.captionScale)
                height: 30 * wheel.captionScale
                radius: height / 2
                color: Commons.Color.menu.background
                border.width: 1
                border.color: Commons.Util.alpha(Commons.Color.menu.text, 0.18)

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: hintText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (root.converting) return root.statusMessage;
                            if (root.selected >= 0 && root.selected < root.selectionCount) {
                                return "Convert to " + root.wheelSlices[root.selected];
                            }
                            if (root.selected === -2) return "Convert Orb Settings";
                            if (root.draggedFiles.length > 1) {
                                return "Drop " + root.draggedFiles.length + " files on any format";
                            }
                            return root.sourceFilename ? ("Drop " + root.sourceFilename + " on format") : "Drop on any format";
                        }
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.space(11) * wheel.captionScale
                        font.weight: Font.DemiBold
                        color: Commons.Color.menu.text
                        elide: Text.ElideRight
                    }

                    // Page indicator if multiple pages
                    Text {
                        visible: root.totalPages > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "· " + (root.formatPage + 1) + "/" + root.totalPages
                        font.family: Commons.Style.font.menuFamily
                        font.pixelSize: Commons.Style.space(9) * wheel.captionScale
                        color: Commons.Util.alpha(Commons.Color.menu.text, 0.5)
                    }
                }
            }
        }

        // Settings Panel Card
        SettingsPanel {
            id: settingsCard
            visible: root.settingsOpen
            x: Math.max(16, (parent.width - width) / 2)
            y: Math.max(32, (parent.height - height) / 2)

            onSaveRequested: draft => {
                var merged = Model.mergeSettings(root.config, draft);
                var saveText = JSON.stringify(merged, null, 2) + "\n";
                settingsWriter.setText(saveText);
            }
            onCanceled: root.closeSettings()
        }
    }
}
