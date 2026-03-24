pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool available: false
    property bool discoveryEnabled: false
    property string statusText: !available
        ? Translation.tr("Not installed")
        : (discoveryEnabled ? Translation.tr("%1 peers").arg(discoveredCount) : Translation.tr("Off"))
    property int discoveredCount: 0
    property var peers: []
    property string peersFilePath: `${Directories.cache}/opendrop/peers.json`
    property string stateDirPath: `${Directories.cache}/opendrop`

    function toggleDiscovery() {
        if (!available)
            return;
        if (discoveryEnabled)
            stopDiscovery();
        else
            startDiscovery();
    }

    function startDiscovery() {
        if (!available || discoveryEnabled)
            return;
        discoveryEnabled = true;
        peers = [];
        discoveredCount = 0;
        Quickshell.execDetached(["bash", "-lc", `mkdir -p "${stateDirPath}" && printf '[]' > "${peersFilePath}"`]);
        discoverProc.running = true;
        Quickshell.execDetached(["notify-send", Translation.tr("OpenDrop"), Translation.tr("Discovery enabled"), "-a", "Shell"]);
        promptReceiveApproval();
    }

    function stopDiscovery() {
        if (!discoveryEnabled)
            return;
        discoveryEnabled = false;
        discoverProc.running = false;
        Quickshell.execDetached(["notify-send", Translation.tr("OpenDrop"), Translation.tr("Discovery disabled"), "-a", "Shell"]);
    }

    function promptReceiveApproval() {
        if (!available)
            return;
        Quickshell.execDetached(["bash", "-lc", `${Directories.scriptPath}/opendrop/receive-on-accept.sh`]);
    }

    function openSendDialog() {
        if (!available)
            return;
        Quickshell.execDetached(["bash", "-lc", `${Directories.scriptPath}/opendrop/send-discovered.sh`]);
    }

    function updatePeers() {
        Quickshell.execDetached(["bash", "-lc", `mkdir -p "${stateDirPath}" && printf '%s' '${JSON.stringify(peers).replace(/'/g, "'\\''")}' > "${peersFilePath}"`]);
        discoveredCount = peers.length;
    }

    function upsertPeer(index, id, name) {
        const key = String(index);
        const existingIndex = peers.findIndex((peer) => peer.index === key || peer.id === id);
        const nextPeer = {
            index: key,
            id: id,
            name: name
        };

        if (existingIndex >= 0)
            peers[existingIndex] = nextPeer;
        else
            peers.push(nextPeer);

        updatePeers();
    }

    Process {
        id: checkAvailabilityProc
        running: true
        command: ["bash", "-lc", "command -v opendrop >/dev/null 2>&1"]
        onExited: (exitCode) => {
            root.available = exitCode === 0;
        }
    }

    Process {
        id: discoverProc
        command: ["bash", "-lc", "opendrop find"]
        stdout: SplitParser {
            onRead: (line) => {
                // Example: Found  index 0  ID ecc...  name John's iPhone
                const m = line.match(/Found\\s+index\\s+(\\d+)\\s+ID\\s+([^\\s]+)\\s+name\\s+(.+)$/);
                if (!m)
                    return;
                root.upsertPeer(m[1], m[2], m[3].trim());
            }
        }
        onExited: () => {
            if (root.discoveryEnabled) {
                // Restart discovery if it exits unexpectedly.
                discoverProc.running = true;
            }
        }
    }
}
