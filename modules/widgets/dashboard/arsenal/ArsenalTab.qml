import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config

// I.A.M Arsenal — Cybersecurity tool launcher
FocusScope {
    id: root

    property string searchText: ""
    property int selectedCategory: 0
    property int hoveredCategory: -1

    readonly property var categories: [
        { name: "All",        icon: Icons.shield },
        { name: "Recon",      icon: Icons.globe },
        { name: "Web",        icon: Icons.globe },
        { name: "Exploit",    icon: Icons.lightning },
        { name: "Wireless",   icon: Icons.wifiHigh },
        { name: "Password",   icon: Icons.lock },
        { name: "Forensics",  icon: Icons.glassPlus }
    ]

    ListModel {
        id: toolsModel
        ListElement { name: "nmap";        cmd: "nmap";        cat: "Recon";     desc: "Network scanner — host discovery, port scanning, OS detection, NSE scripts" }
        ListElement { name: "rustscan";    cmd: "rustscan";    cat: "Recon";     desc: "Blazing port scanner — all 65k ports in seconds, pipes into nmap" }
        ListElement { name: "nikto";       cmd: "nikto";       cat: "Recon";     desc: "Web server scanner — dangerous files, outdated versions, misconfigs" }
        ListElement { name: "dnsmasq";     cmd: "dnsmasq";     cat: "Recon";     desc: "DNS forwarder & DHCP — spoofing, rogue APs, network pivoting" }
        ListElement { name: "burpsuite";   cmd: "burpsuite";   cat: "Web";       desc: "Web attack platform — intercept proxy, scanner, intruder, repeater" }
        ListElement { name: "gobuster";    cmd: "gobuster";    cat: "Web";       desc: "Brute-force URIs, subdomains, vhosts, S3 buckets — written in Go" }
        ListElement { name: "feroxbuster"; cmd: "feroxbuster";  cat: "Web";      desc: "Recursive content discovery — auto-crawls found directories" }
        ListElement { name: "sqlmap";      cmd: "sqlmap";      cat: "Web";       desc: "SQL injection automation — all major DBMS, OS shell, db dump" }
        ListElement { name: "metasploit";  cmd: "msfconsole";  cat: "Exploit";   desc: "Penetration testing framework — exploits, payloads, post-exploitation" }
        ListElement { name: "hydra";       cmd: "hydra";       cat: "Exploit";   desc: "Network login cracker — 50+ protocols, SSH, FTP, HTTP, RDP, SMB" }
        ListElement { name: "searchsploit"; cmd: "searchsploit"; cat: "Exploit"; desc: "Offline ExploitDB search — public exploits and shellcodes" }
        ListElement { name: "pspy";        cmd: "pspy";      cat: "Exploit";   desc: "Unprivileged process monitor — cron jobs, scheduled tasks, IPC" }
        ListElement { name: "aircrack-ng"; cmd: "aircrack-ng"; cat: "Wireless";  desc: "WiFi audit suite — monitor, capture, WEP/WPA crack, deauth, replay" }
        ListElement { name: "hashcat";     cmd: "hashcat";     cat: "Password";  desc: "GPU password recovery — 350+ hash types, rules, masks, hybrid" }
        ListElement { name: "john";        cmd: "john";        cat: "Password";  desc: "Password cracker — auto hash detect, wordlist, incremental modes" }
        ListElement { name: "wireshark";   cmd: "wireshark";   cat: "Forensics"; desc: "Packet analyzer — deep inspection, live capture, display filters" }
        ListElement { name: "autopsy";     cmd: "autopsy";     cat: "Forensics"; desc: "Digital forensics — timeline, keyword search, hash filter, artifacts" }
        ListElement { name: "volatility3"; cmd: "vol";         cat: "Forensics"; desc: "Memory forensics — processes, connections, registry, malware extraction" }
    }

    property var filteredTools: {
        var result = [];
        for (var i = 0; i < toolsModel.count; i++) {
            var tool = toolsModel.get(i);
            var matchCat = selectedCategory === 0 || tool.cat === categories[selectedCategory].name;
            var matchSearch = searchText === "" ||
                tool.name.toLowerCase().indexOf(searchText.toLowerCase()) >= 0 ||
                tool.desc.toLowerCase().indexOf(searchText.toLowerCase()) >= 0;
            if (matchCat && matchSearch) result.push(tool);
        }
        return result;
    }

    function getCatIcon(catName) {
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].name === catName) return categories[i].icon;
        }
        return Icons.terminal;
    }

    function launchTool(cmd) {
        Visibilities.setActiveModule("");
        proc.command = ["kitty", "--title", "arsenal", "-e", "arsenal-launch", cmd];
        proc.running = true;
    }

    Process { id: proc; command: [] }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════════════════
        // ── Search + count (integrated top bar) ────────────────
        // ═══════════════════════════════════════════════════════
        SearchInput {
            id: searchInput
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            iconText: Icons.shield
            placeholderText: "Search " + root.filteredTools.length + " tools..."
            onSearchTextChanged: function(text) { root.searchText = text; }
        }

        Item { Layout.preferredHeight: 8 }

        // ═══════════════════════════════════════════════════════
        // ── Category selector ──────────────────────────────────
        // ═══════════════════════════════════════════════════════
        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            variant: "pane"
            radius: Styling.radius(4)

            // Elastic highlight
            StyledRect {
                id: hl
                variant: "primary"
                radius: Styling.radius(0)
                z: 0
                clip: true

                property real cellW: catRepeater.count > 0 ? (parent.width - 8) / catRepeater.count : 40
                property real targetX: 4 + root.selectedCategory * cellW

                // Dual tracker — fast lead, slow follow
                property real t1: targetX
                property real t2: targetX

                x: Math.min(t1, t2)
                y: 4
                width: Math.abs(t2 - t1) + cellW
                height: parent.height - 8

                Behavior on t1 {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration / 3; easing.type: Easing.OutSine }
                }
                Behavior on t2 {
                    enabled: Config.animDuration > 0
                    NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutSine }
                }
                onTargetXChanged: { t1 = targetX; t2 = targetX; }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 4

                Repeater {
                    id: catRepeater
                    model: root.categories

                    Item {
                        required property int index
                        required property var modelData

                        width: parent.width / catRepeater.count
                        height: parent.height

                        property bool isSel: root.selectedCategory === index
                        property bool isHov: catMA.containsMouse

                        // Hover glow behind the button
                        Rectangle {
                            anchors.fill: parent
                            radius: Styling.radius(0)
                            color: Colors.surfaceBright
                            opacity: isHov && !isSel ? 0.5 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: Config.animDuration / 2 }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                text: modelData.icon
                                font.family: Icons.font
                                font.pixelSize: 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: isSel ? Styling.srItem("primary") : isHov ? Colors.primary : Colors.overBackground

                                Behavior on color {
                                    ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                                }
                            }
                            Text {
                                text: modelData.name
                                font.family: Config.theme.font
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: isSel ? Styling.srItem("primary") : isHov ? Colors.primary : Colors.overSurfaceVariant

                                Behavior on color {
                                    ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                                }
                            }
                        }

                        MouseArea {
                            id: catMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedCategory = index
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 8 }

        // ═══════════════════════════════════════════════════════
        // ── Tool grid ──────────────────────────────────────────
        // ═══════════════════════════════════════════════════════
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            cellWidth: width / 2
            cellHeight: 92

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
            }

            model: root.filteredTools

            delegate: Item {
                id: del
                required property int index
                required property var modelData

                width: grid.cellWidth
                height: grid.cellHeight

                property bool isHovered: delMA.containsMouse
                property bool isPressed: delMA.pressed

                StyledRect {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Styling.radius(4)
                    variant: del.isHovered ? "focus" : "pane"

                    scale: del.isPressed ? 0.95 : 1.0
                    transformOrigin: Item.Center
                    Behavior on scale {
                        NumberAnimation { duration: Config.animDuration / 3; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        // Icon — variant-driven depth
                        StyledRect {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: Styling.radius(0)
                            variant: del.isHovered ? "primary" : "internalbg"

                            Text {
                                anchors.centerIn: parent
                                text: root.getCatIcon(del.modelData.cat)
                                font.family: Icons.font
                                font.pixelSize: 22
                                color: del.isHovered ? Styling.srItem("primary") : Colors.primary

                                Behavior on color {
                                    ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                                }
                            }
                        }

                        // Text
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 3

                            RowLayout {
                                spacing: 6

                                Text {
                                    text: del.modelData.name
                                    font.family: Config.theme.monoFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: del.isHovered ? Colors.primary : Colors.overBackground

                                    Behavior on color {
                                        ColorAnimation { duration: Config.animDuration / 2; easing.type: Easing.OutQuart }
                                    }
                                }

                                StyledRect {
                                    width: catLbl.implicitWidth + 10
                                    height: 16
                                    radius: 8
                                    variant: del.isHovered ? "primaryfocus" : "internalbg"

                                    Text {
                                        id: catLbl
                                        anchors.centerIn: parent
                                        text: del.modelData.cat
                                        font.family: Config.theme.font
                                        font.pixelSize: 9
                                        font.weight: Font.Medium
                                        color: del.isHovered ? Styling.srItem("primaryfocus") : Colors.overBackground
                                    }
                                }
                            }

                            Text {
                                text: del.modelData.desc
                                font.family: Config.theme.font
                                font.pixelSize: 11
                                color: Colors.overSurfaceVariant
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.3
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        id: delMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchTool(del.modelData.cmd)
                    }
                }
            }

            // Empty state
            Column {
                visible: root.filteredTools.length === 0
                anchors.centerIn: parent
                spacing: 12
                opacity: 0.4

                Text {
                    text: Icons.shield
                    font.family: Icons.font
                    font.pixelSize: 40
                    color: Colors.overSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "No tools match"
                    font.family: Config.theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Colors.overSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    function focusSearchInput() {
        searchInput.focusInput();
    }
}
