pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.config

// I.A.M Arsenal Settings Panel
Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property bool editMode: false
    property int editingIndex: -1
    property bool isCreatingNew: false

    // Edit form state
    property string editName: ""
    property string editCmd: ""
    property string editCat: "Recon"
    property string editDesc: ""
    property string editTip: ""

    readonly property var phaseLabels: ["Recon", "Web", "Exploit", "Wireless", "Password", "Forensics"]

    // Tool list loaded from tools.json
    property var toolsList: []

    // Load tools from file
    Process {
        id: loadProc
        command: ["cat", Qt.resolvedUrl("").toString().replace("file://", "").replace(/\/[^/]*$/, "") + "/../../../../.config/arsenal/tools.json"]
        onExited: function(code, status) {
            // Fallback: load via home path
        }
    }

    // Use a simpler approach — read via shell
    Process {
        id: readToolsProc
        command: ["sh", "-c", "cat ~/.config/arsenal/tools.json 2>/dev/null || echo '{\"tools\":[]}'"]
        stdout: SplitParser {
            onRead: function(line) {
                // Accumulate lines
                root._jsonBuf += line;
            }
        }
        onExited: function(code, status) {
            try {
                var data = JSON.parse(root._jsonBuf);
                root.toolsList = data.tools || [];
            } catch(e) {
                console.log("ArsenalPanel: Failed to parse tools.json:", e);
                root.toolsList = [];
            }
        }
    }
    property string _jsonBuf: ""

    // Save tools to file
    Process {
        id: saveToolsProc
        command: []
    }

    // Save tip file
    Process {
        id: saveTipProc
        command: []
    }

    // Read tip file for editing
    Process {
        id: readTipProc
        command: []
        stdout: SplitParser {
            onRead: function(line) {
                root._tipBuf += line + "\n";
            }
        }
        onExited: function(code, status) {
            root.editTip = root._tipBuf;
        }
    }
    property string _tipBuf: ""

    Component.onCompleted: {
        _jsonBuf = "";
        readToolsProc.running = true;
    }

    function saveTools() {
        var obj = { "tools": root.toolsList };
        var json = JSON.stringify(obj, null, 2);
        saveToolsProc.command = ["sh", "-c", "cat > ~/.config/arsenal/tools.json << 'JSONEOF'\n" + json + "\nJSONEOF"];
        saveToolsProc.running = true;
    }

    function saveTip(cmd, content) {
        saveTipProc.command = ["sh", "-c", "cat > ~/.config/arsenal/tips/" + cmd + ".tip << 'TIPEOF'\n" + content + "\nTIPEOF"];
        saveTipProc.running = true;
    }

    function openEdit(index) {
        var tool = root.toolsList[index];
        root.editingIndex = index;
        root.editName = tool.name || "";
        root.editCmd = tool.cmd || "";
        root.editCat = tool.phase || "recon";
        root.editDesc = tool.desc || "";
        root.isCreatingNew = false;

        // Load tip
        root._tipBuf = "";
        root.editTip = "";
        readTipProc.command = ["sh", "-c", "cat ~/.config/arsenal/tips/" + tool.cmd + ".tip 2>/dev/null || echo ''"];
        readTipProc.running = true;

        root.editMode = true;
    }

    function openNew() {
        root.editingIndex = -1;
        root.editName = "";
        root.editCmd = "";
        root.editCat = "recon";
        root.editDesc = "";
        root.editTip = "";
        root.isCreatingNew = true;
        root.editMode = true;
    }

    function saveEdit() {
        var newTool = {
            "id": root.editCmd,
            "name": root.editName,
            "desc": root.editDesc,
            "phase": root.editCat,
            "icon": "terminal",
            "cmd": root.editCmd,
            "gui": false
        };

        var newList = [];
        for (var i = 0; i < root.toolsList.length; i++) {
            newList.push(root.toolsList[i]);
        }

        if (root.isCreatingNew) {
            newList.push(newTool);
        } else if (root.editingIndex >= 0 && root.editingIndex < newList.length) {
            newList[root.editingIndex] = newTool;
        }

        root.toolsList = newList;
        saveTools();

        // Save tip if content exists
        if (root.editTip.trim() !== "") {
            saveTip(root.editCmd, root.editTip.trim());
        }

        closeEdit();
    }

    function deleteTool() {
        if (root.editingIndex < 0) return;
        var newList = [];
        for (var i = 0; i < root.toolsList.length; i++) {
            if (i !== root.editingIndex) newList.push(root.toolsList[i]);
        }
        root.toolsList = newList;
        saveTools();
        closeEdit();
    }

    function closeEdit() {
        root.editMode = false;
        root.isCreatingNew = false;
        root.editingIndex = -1;
    }

    // ═══════════════════════════════════════════════════════════
    // ── List View ──────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: !root.editMode
        opacity: root.editMode ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.sideMargin
            anchors.rightMargin: root.sideMargin
            spacing: 0

            PanelTitlebar {
                title: "Arsenal"
                statusText: root.toolsList.length + " tools"
                actions: [
                    {
                        icon: Icons.arrowCounterClockwise,
                        tooltip: "Reload",
                        onClicked: function() {
                            root._jsonBuf = "";
                            readToolsProc.running = true;
                        }
                    },
                    {
                        icon: "+",
                        tooltip: "Add tool",
                        onClicked: function() { root.openNew(); }
                    }
                ]
            }

            Item { Layout.preferredHeight: 12 }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: toolColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                ColumnLayout {
                    id: toolColumn
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.toolsList

                        delegate: StyledRect {
                            id: toolItem
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            height: 56
                            radius: Styling.radius(-2)
                            variant: toolMA.containsMouse ? "focus" : "common"
                            enableShadow: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 12

                                // Icon
                                StyledRect {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: Styling.radius(-4)
                                    variant: toolMA.containsMouse ? "primary" : "internalbg"

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.terminal
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: toolMA.containsMouse ? Styling.srItem("primary") : Colors.primary
                                    }
                                }

                                // Name + desc
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: toolItem.modelData.name || ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        font.weight: Font.Medium
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: toolItem.modelData.desc || ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.overSurfaceVariant
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Category badge
                                StyledRect {
                                    Layout.preferredWidth: catBadge.width + 16
                                    Layout.preferredHeight: 24
                                    radius: Styling.radius(-4)
                                    variant: "internalbg"

                                    Text {
                                        id: catBadge
                                        anchors.centerIn: parent
                                        text: toolItem.modelData.phase || ""
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.weight: Font.Medium
                                        color: Styling.srItem("overprimary")
                                    }
                                }

                                // Command pill
                                StyledRect {
                                    Layout.preferredWidth: cmdLabel.width + 16
                                    Layout.preferredHeight: 24
                                    radius: Styling.radius(-4)
                                    variant: "internalbg"

                                    Text {
                                        id: cmdLabel
                                        anchors.centerIn: parent
                                        text: toolItem.modelData.cmd || ""
                                        font.family: Config.theme.monoFont
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.primary
                                    }
                                }
                            }

                            MouseArea {
                                id: toolMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEdit(toolItem.index)
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // ── Edit View ──────────────────────────────────────────────
    // ═══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: root.editMode
        opacity: root.editMode ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.sideMargin
            anchors.rightMargin: root.sideMargin
            spacing: 0

            PanelTitlebar {
                title: root.isCreatingNew ? "New Tool" : "Edit Tool"
                actions: [
                    {
                        icon: Icons.caretLeft,
                        tooltip: "Back",
                        onClicked: function() { root.closeEdit(); }
                    },
                    {
                        icon: "−",
                        tooltip: "Delete",
                        enabled: !root.isCreatingNew,
                        onClicked: function() { root.deleteTool(); }
                    },
                    {
                        icon: Icons.accept,
                        tooltip: "Save",
                        onClicked: function() { root.saveEdit(); }
                    }
                ]
            }

            Item { Layout.preferredHeight: 12 }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: editColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                }

                ColumnLayout {
                    id: editColumn
                    width: parent.width
                    spacing: 12

                    // ── Name ─────────────────────────────────
                    Text {
                        text: "Name"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    SearchInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: root.editName
                        placeholderText: "Tool display name"
                        onSearchTextChanged: function(t) { root.editName = t; }
                    }

                    // ── Command ──────────────────────────────
                    Text {
                        text: "Command"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    SearchInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: root.editCmd
                        placeholderText: "Binary name (e.g. nmap)"
                        onSearchTextChanged: function(t) { root.editCmd = t; }
                    }

                    // ── Description ──────────────────────────
                    Text {
                        text: "Description"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    SearchInput {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: root.editDesc
                        placeholderText: "Short description"
                        onSearchTextChanged: function(t) { root.editDesc = t; }
                    }

                    // ── Category ─────────────────────────────
                    Text {
                        text: "Category"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    Row {
                        spacing: 4
                        Layout.fillWidth: true

                        Repeater {
                            model: ["recon", "web", "exploit", "wireless", "passwords", "forensics", "post"]

                            StyledRect {
                                required property int index
                                required property string modelData

                                width: catChipText.implicitWidth + 16
                                height: 32
                                radius: Styling.radius(-4)
                                variant: root.editCat === modelData ? "primary" : catChipMA.containsMouse ? "focus" : "common"

                                Text {
                                    id: catChipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.weight: Font.Medium
                                    color: root.editCat === modelData ? Styling.srItem("primary") : Colors.overBackground
                                }

                                MouseArea {
                                    id: catChipMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editCat = modelData
                                }
                            }
                        }
                    }

                    // ── Tip File ─────────────────────────────
                    Text {
                        text: "Tip Card"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overSurfaceVariant
                    }
                    Text {
                        text: "Shown when launching from Arsenal. Use # for headers, $ for commands, - for bullets."
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.outline
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        variant: "pane"
                        radius: Styling.radius(4)

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8

                            TextArea {
                                id: tipEditor
                                text: root.editTip
                                font.family: Config.theme.monoFont
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                placeholderText: "# tool-name\n> Short description\n\n## Quick Start\n$ command --help\n\n## Common Flags\n- -v  Verbose output"
                                placeholderTextColor: Colors.outline
                                wrapMode: TextArea.Wrap
                                background: null
                                onTextChanged: root.editTip = text
                            }
                        }
                    }
                }
            }
        }
    }
}
