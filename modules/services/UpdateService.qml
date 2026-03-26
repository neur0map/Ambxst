pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string currentVersion: Config.version
    readonly property string repoUrl: "https://api.github.com/repos/neur0map/project-i-a-m/tags"
    readonly property string changelogUrl: "https://github.com/neur0map/project-i-a-m/releases"
    readonly property string cacheFile: Quickshell.env("HOME") + "/.cache/iam-shell/update_check.json"
    readonly property string iamUpdateScript: Quickshell.env("HOME") + "/.local/share/iam/bin/iam-update"

    // State exposed to settings UI
    property string lastDetectedVersion: ""
    property string latestVersion: ""
    property bool updateAvailable: false
    property bool isChecking: false
    property bool isUpdating: false
    property string updateStatus: ""  // "", "checking", "updating", "success", "error"
    property string updateError: ""
    property double lastCheckTime: 0
    property double nextCheckTime: 0

    // Cache persistence
    FileView {
        id: cacheFileView
        path: root.cacheFile
        onLoaded: {
            try {
                const content = text();
                if (content && content.trim() !== "") {
                    const data = JSON.parse(content);
                    root.lastCheckTime = data.lastCheckTime || 0;
                    root.nextCheckTime = data.nextCheckTime || 0;
                    root.lastDetectedVersion = data.lastDetectedVersion || "";
                    if (data.latestVersion) {
                        root.latestVersion = data.latestVersion;
                        root.updateAvailable = isNewer(root.latestVersion, root.currentVersion);
                    }
                } else {
                    root.nextCheckTime = Date.now();
                }
            } catch (e) {
                console.log("[UpdateService] Error loading cache:", e);
                root.nextCheckTime = Date.now();
            }
        }
    }

    function saveCache() {
        const data = {
            lastCheckTime: root.lastCheckTime,
            nextCheckTime: root.nextCheckTime,
            lastDetectedVersion: root.lastDetectedVersion,
            latestVersion: root.latestVersion
        };
        cacheFileView.setText(JSON.stringify(data));
    }

    // Startup check (2s delay)
    Timer {
        id: startupDelay
        interval: 2000
        running: true
        onTriggered: {
            if (Config.system.updateServiceEnabled) {
                checkUpdates();
            }
            checkTimer.running = true;
        }
    }

    // Periodic check (every 5 minutes, only fires if past nextCheckTime)
    Timer {
        id: checkTimer
        interval: 300000
        running: false
        repeat: true
        onTriggered: {
            if (!Config.system.updateServiceEnabled) return;
            const now = Date.now();
            if (now >= root.nextCheckTime) {
                checkUpdates();
            }
        }
    }

    // --- Check for updates via GitHub API ---
    function checkUpdates() {
        if (root.isChecking) return;
        root.isChecking = true;
        root.updateStatus = "checking";

        const xhr = new XMLHttpRequest();
        xhr.open("GET", root.repoUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isChecking = false;
                if (xhr.status === 200) {
                    try {
                        const tags = JSON.parse(xhr.responseText);
                        if (tags && Array.isArray(tags) && tags.length > 0) {
                            const latestTag = tags[0].name.replace(/^v/, "");
                            root.latestVersion = latestTag;
                            root.updateAvailable = isNewer(latestTag, root.currentVersion);

                            if (root.updateAvailable && latestTag !== root.lastDetectedVersion) {
                                root.lastDetectedVersion = latestTag;
                                sendUpdateNotification(latestTag);
                            }
                        }
                        root.updateStatus = "";
                    } catch (e) {
                        console.log("[UpdateService] Error parsing tags:", e);
                        root.updateStatus = "error";
                        root.updateError = "Failed to parse update info";
                    }
                } else {
                    root.updateStatus = "";
                    // Silent fail on network error — don't bother user
                }

                root.lastCheckTime = Date.now();
                if (root.nextCheckTime <= Date.now()) {
                    root.nextCheckTime = Date.now() + 3600000; // 1 hour
                }
                saveCache();
            }
        }
        xhr.send();
    }

    // --- Perform update via iam-update script ---
    function performUpdate() {
        if (root.isUpdating) return;
        root.isUpdating = true;
        root.updateStatus = "updating";
        root.updateError = "";

        updateProcess.running = true;
    }

    Process {
        id: updateProcess
        command: ["bash", root.iamUpdateScript]
        stdout: StdioCollector {
            id: updateStdout
        }
        stderr: StdioCollector {
            id: updateStderr
        }
        onExited: function(exitCode) {
            root.isUpdating = false;
            if (exitCode === 0) {
                root.updateStatus = "success";
                root.updateAvailable = false;
                root.latestVersion = root.currentVersion;
                root.saveCache();
                // Auto-clear success after 5s
                successClearTimer.start();
            } else {
                root.updateStatus = "error";
                root.updateError = updateStderr.text.trim() || "Update failed (exit code " + exitCode + ")";
            }
        }
    }

    Timer {
        id: successClearTimer
        interval: 5000
        onTriggered: {
            if (root.updateStatus === "success") {
                root.updateStatus = "";
            }
        }
    }

    // --- Helpers ---
    function isNewer(latest, current) {
        const l = latest.split('.').map(Number);
        const c = current.split('.').map(Number);
        for (let i = 0; i < Math.max(l.length, c.length); i++) {
            const lv = l[i] || 0;
            const cv = c[i] || 0;
            if (lv > cv) return true;
            if (lv < cv) return false;
        }
        return false;
    }

    function timeSinceLastCheck() {
        if (root.lastCheckTime === 0) return "Never";
        const diff = Date.now() - root.lastCheckTime;
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return "Just now";
        if (mins < 60) return mins + "m ago";
        const hours = Math.floor(mins / 60);
        if (hours < 24) return hours + "h ago";
        return Math.floor(hours / 24) + "d ago";
    }

    function sendUpdateNotification(newVersion) {
        const summary = "I.A.M update available!";
        const body = "v" + newVersion + " available (installed v" + root.currentVersion + ")";
        notificationProcess.command = ["notify-send", "-a", "I.A.M", "-i", "system-software-update", summary, body];
        notificationProcess.running = true;
    }

    property Process notificationProcess: Process {
        id: notificationProcess
    }
}
