import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls.Basic
import Qt5Compat.GraphicalEffects
import ".."

// Quest Board — desktop quests, rewards and a chronicle of completed quests, in the antiquity style.
// Data lives in ~/.config/quickshell/quests.json (you can edit it by hand too):
//   { "quests":  [{ "id", "title", "done" }],
//     "rewards": [{ "id", "title", "done" }],
//     "history": [{ "title", "completedAt" }] }   // newest first
// Completing a quest plays a celebration, then moves it into the Chronicle.
// Click it again mid-celebration to keep it on the board.
// Drag the board by any empty space; its position is saved to widgets.json.
Rectangle {
    id: root

    property bool widgetBackground: true
    // The theme's accentDark is too faint on dark wood, so the board uses a brighter version of it.
    readonly property color dimInk: Qt.lighter(Config.colors.accentDark, widgetBackground ? 1.45 : 1)
    // Colors for writing on the parchment notes
    readonly property color ink: "#2e1f10"
    readonly property color inkFaded: "#76644a"
    readonly property color sealColor: "#8e2a1e"   // red wax: done quests, claimed rewards
    readonly property color manaInk: Qt.darker(manaColor, 2.1)
    // Set by WidgetScreen so a drag can save the new position to widgets.json
    property var widgetData: null
    property bool showHistory: false
    property bool showHelp: false
    property bool showSettings: false
    onShowHelpChanged: if (showHelp) showSettings = false
    onShowSettingsChanged: if (showSettings) { showHelp = false; settingsField.text = canvasUrlFile.loadedUrl; settingsStatus = ""; }
    width: 800
    // Room left below the board before the bottom bar (~170px) so the guide never runs off-screen.
    readonly property real helpRoom: (parent && parent.parent) ? Math.max(320, parent.parent.height - y - 170) : 700
    height: showHelp ? Math.max(content.implicitHeight + 44, Math.min(helpCol.implicitHeight + 64, helpRoom))
          : showSettings ? Math.max(content.implicitHeight + 44, settingsCol.implicitHeight + 64)
          : content.implicitHeight + 44

    color: "transparent"

    readonly property var cheers: ["Huzzah!", "Quest fulfilled!", "Onward, adventurer!", "+1 Glory", "The realm thanks you!", "Well struck!", "Legendary!", "Another deed for the ages!"]
    readonly property int rewardsClaimed: board.rewards.filter(r => r.done).length
    // ── Mana: earned with each fulfilled quest (same amount as the XP), spent on rewards ──
    readonly property color manaColor: "#9fb4ff"
    readonly property int defaultCost: 50
    property string lastClaimedUid: ""   // lets the re-created reward row play its "-N mana" sparkle
    signal notEnoughMana(int index, int missing)
    readonly property int doneToday: board.history.filter(h => new Date(h.completedAt).toDateString() === new Date().toDateString()).length

    // ── Levels ──
    readonly property var ranks: ["Wanderer", "Village Hero", "Squire", "Footsoldier", "Knight-Errant", "Knight", "Champion", "Paladin", "Warlord", "Hero of the Realm", "Legend", "Mythic"]
    readonly property var lvl: levelInfo(board.xp)
    function xpToNext(level) {
        return 100 + 50 * (level - 1);
    }
    function levelInfo(xp) {
        let level = 1, rem = Math.max(0, xp);
        while (rem >= xpToNext(level)) {
            rem -= xpToNext(level);
            level++;
        }
        return { "level": level, "into": rem, "need": xpToNext(level), "rank": ranks[Math.min(level - 1, ranks.length - 1)] };
    }
    // XP for the next quest fulfilled: 25 base, +5 for each quest already done today (max +25).
    function nextGain() {
        return 25 + 5 * Math.min(doneToday, 5);
    }

    function newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
    }
    // Generic list helpers; key is "quests" or "rewards".
    function addEntry(key, title) {
        if (!dataReady)
            return;
        let t = title.trim();
        if (t.length === 0)
            return;
        if (key === "rewards") {
            // "Pizza night 80" -> title "Pizza night", cost 80
            let cost = defaultCost;
            const m = t.match(/^(.*\S)\s+(\d{1,5})$/);
            if (m) {
                t = m[1];
                cost = parseInt(m[2]);
            }
            board.rewards = board.rewards.concat([{ "id": newId(), "title": t, "done": false, "cost": cost }]);
            return;
        }
        board[key] = board[key].concat([{ "id": newId(), "title": t, "done": false }]);
    }
    function toggleEntry(key, i) {
        if (!dataReady)
            return;
        const list = board[key].slice();
        if (key === "rewards") {
            const r = list[i];
            const cost = r.cost !== undefined ? r.cost : defaultCost;
            if (!r.done) {
                if (board.mana < cost) {
                    notEnoughMana(i, cost - board.mana);
                    return;
                }
                board.mana = board.mana - cost;
                lastClaimedUid = r.id || r.title;
                list[i] = Object.assign({}, r, { "done": true, "claimedAt": new Date().toISOString() });
            } else {
                board.mana = board.mana + cost; // unclaim = refund
                list[i] = Object.assign({}, r, { "done": false, "claimedAt": undefined });
            }
            board.rewards = list;
            return;
        }
        list[i] = Object.assign({}, list[i], { "done": !list[i].done });
        board[key] = list;
    }
    function adjustCost(i, delta) {
        if (!dataReady)
            return;
        const list = board.rewards.slice();
        const cur = list[i].cost !== undefined ? list[i].cost : defaultCost;
        list[i] = Object.assign({}, list[i], { "cost": Math.max(0, cur + delta) });
        board.rewards = list;
    }
    function removeEntry(key, i) {
        if (!dataReady)
            return;
        const list = board[key].slice();
        list.splice(i, 1);
        board[key] = list;
    }
    // Tag each entry with its list key, index and a stable uid for the shared delegate.
    function tagged(key) {
        return board[key].map((e, i) => ({ "key": key, "i": i, "uid": e.id || e.title, "title": e.title, "done": e.done, "cost": e.cost !== undefined ? e.cost : defaultCost }));
    }
    // Called when a quest's celebration finishes: move it from the board into the chronicle.
    function archiveQuest(uid) {
        if (!dataReady)
            return;
        const idx = board.quests.findIndex(q => (q.id || q.title) === uid && q.done);
        if (idx < 0)
            return;
        const q = board.quests[idx];
        const gain = nextGain();
        const before = lvl.level;
        const list = board.quests.slice();
        list.splice(idx, 1);
        board.quests = list;
        board.history = [{ "title": q.title, "completedAt": new Date().toISOString(), "xp": gain, "mana": gain }].concat(board.history);
        board.xp = board.xp + gain;
        board.mana = board.mana + gain;
        if (lvl.level > before)
            levelUp.show(lvl.level, lvl.rank);
    }
    function restoreHistory(i) {
        if (!dataReady)
            return;
        const h = board.history[i];
        const list = board.history.slice();
        list.splice(i, 1);
        board.history = list;
        board.xp = Math.max(0, board.xp - (h.xp || 25));
        board.mana = Math.max(0, board.mana - (h.mana !== undefined ? h.mana : (h.xp || 25)));
        board.quests = board.quests.concat([{ "id": newId(), "title": h.title, "done": false }]);
    }
    function deleteHistory(i) {
        if (!dataReady)
            return;
        const list = board.history.slice();
        list.splice(i, 1);
        board.history = list;
    }

    // ── Data safety ──
    // dataReady stays false until quests.json has loaded and parsed cleanly. Until then
    // nothing is written, so a damaged or unreadable file is never overwritten with an
    // empty board. Writes are atomic (temp file + rename), so a crash or power cut can't
    // leave a half-written file. Daily backups go to ~/.local/share/questboard/backups.
    property bool dataReady: false
    property string dataError: ""

    FileView {
        id: questFile
        path: Qt.resolvedUrl("../quests.json")
        atomicWrites: true
        blockWrites: !root.dataReady
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: if (root.dataReady) writeAdapter()
        onLoaded: {
            try {
                JSON.parse(text());
                root.dataError = "";
                root.dataReady = true;
                if (board.mana < 0)
                    board.mana = board.xp; // existing progress converts to starting mana
                backupProc.running = true;
            } catch (e) {
                root.dataReady = false;
                root.dataError = "quests.json is damaged — not saving, to protect your data";
                console.error("QuestBoard: quests.json failed to parse, writes blocked:", e);
            }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                // Genuinely first run: start a fresh file.
                root.dataReady = true;
                writeAdapter();
            } else {
                root.dataReady = false;
                root.dataError = "Couldn't read quests.json — not saving, to protect your data";
                console.error("QuestBoard: quests.json failed to load, writes blocked:", error);
            }
        }
        onSaveFailed: error => console.error("QuestBoard: failed to save quests.json:", error)
        JsonAdapter {
            id: board
            // IGNORE WARNING, do not wrap in ()
            property var quests: []
            property var rewards: []
            property var history: []
            property int xp: 0
            property int mana: -1   // -1 = not set yet; initialised to your XP on first load
            // Folded sections (click a heading to toggle); saved so they stay folded
            property bool questsFolded: false
            property bool rewardsFolded: true
        }
    }

    // ── Canvas calendar link (Settings pane) ──
    // The link lives in ~/.config/questboard/canvas.url; canvas-quest-sync reads it.
    property string settingsStatus: ""
    property bool settingsError: false
    FileView {
        id: canvasUrlFile
        readonly property string loadedUrl: text().trim()
        path: Quickshell.env("HOME") + "/.config/questboard/canvas.url"
        watchChanges: true
        onFileChanged: reload()
    }
    function saveCanvasUrl(url) {
        const u = url.trim();
        if (!/^(https?|webcal):\/\/\S+$/.test(u)) {
            settingsError = true;
            settingsStatus = "That doesn't look like a link. It should start with https://";
            return;
        }
        settingsError = false;
        settingsStatus = "Saving…";
        saveUrlProc.command = ["sh", "-c",
            'umask 077; d="$HOME/.config/questboard"; mkdir -p "$d" && printf "%s\\n" "$1" > "$d/canvas.url.tmp" && mv "$d/canvas.url.tmp" "$d/canvas.url"',
            "sh", u.replace(/^webcal:/, "https:")];
        saveUrlProc.running = true;
    }
    function runCanvasSync() {
        if (syncProc.running)
            return;
        settingsError = false;
        settingsStatus = "Checking Canvas…";
        syncProc.running = true;
    }
    Process {
        id: saveUrlProc
        onExited: (code, status) => {
            if (code === 0) {
                canvasUrlFile.reload();
                root.runCanvasSync(); // test the new link straight away
            } else {
                root.settingsError = true;
                root.settingsStatus = "Couldn't save the link (error " + code + ")";
            }
        }
    }
    Process {
        id: syncProc
        command: ["sh", "-c", '"$HOME/.local/bin/canvas-quest-sync" 2>&1']
        stdout: StdioCollector {
            id: syncOut
        }
        onExited: (code, status) => {
            const out = syncOut.text.trim().replace(/^canvas-quest-sync:\s*/, "");
            const m = out.match(/(\d+) added, (\d+) updated/);
            if (code === 0 && m) {
                root.settingsError = false;
                root.settingsStatus = "✓ Link works: " + m[1] + " new quest" + (m[1] === "1" ? "" : "s") + " added, " + m[2] + " updated";
            } else {
                root.settingsError = true;
                root.settingsStatus = "✗ Sync failed: " + (out.replace(/^error:\s*/, "") || "error " + code);
            }
        }
    }

    // Snapshot quests.json once per day (refreshed hourly), keeping the newest 30 days.
    Process {
        id: backupProc
        command: ["sh", "-c",
            'src="$HOME/.config/quickshell/quests.json"; dir="$HOME/.local/share/questboard/backups"; ' +
            'mkdir -p "$dir" && [ -s "$src" ] && cp "$src" "$dir/quests-$(date +%F).json.tmp" && ' +
            'mv "$dir/quests-$(date +%F).json.tmp" "$dir/quests-$(date +%F).json"; ' +
            'ls -1t "$dir"/quests-*.json 2>/dev/null | tail -n +31 | xargs -r rm --']
    }
    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: root.dataReady
        onTriggered: backupProc.running = true
    }

    // Board backing: dark stained planks in a nailed wooden frame (see WoodBacking.qml)
    WoodBacking {
        anchors.fill: parent
        visible: root.widgetBackground
    }

    // Drag anywhere on the board's empty space to move it; position is saved on release.
    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent && root.parent.parent) ? root.parent.parent.width - root.width : 10000
        drag.maximumY: (root.parent && root.parent.parent) ? root.parent.parent.height - root.height : 10000
        onPressed: dragArea.forceActiveFocus() // drops focus from any input box
        onReleased: {
            const d = root.widgetData;
            if (!d)
                return;
            Config.updateWidget(d.monitorName, d.widgetId, d.widgetName, Math.round(root.x), Math.round(root.y), d.enableBackground, d.widgetType);
        }
    }

    // ── Shared pieces ──────────────────────────────────────────────────────

    // Ornamental divider: ───◆───
    Component {
        id: divider
        Row {
            spacing: 8
            Rectangle { width: 120; height: 1; color: Config.colors.accent; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 7; height: 7; rotation: 45; color: Config.colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 120; height: 1; color: Config.colors.accent; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Section heading with a status line under it.
    Component {
        id: sectionHeading
        Column {
            readonly property string title: parent ? parent.title : ""
            readonly property string status: parent ? parent.status : ""
            readonly property int size: parent ? parent.size : 28
            spacing: 4
            // Dark outline around the letters so headings stand out against the wood grain.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.title
                font.family: fontBoska.name
                font.pixelSize: parent.size
                font.weight: 600
                color: Qt.lighter(Config.colors.accent, 1.12)
                style: Text.Outline
                styleColor: "#e6140a04"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.status
                font.family: fontDominica.name
                font.pixelSize: 15
                color: Config.colors.textLight
                style: Text.Outline
                styleColor: "#d9140a04"
            }
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: divider
            }
        }
    }

    // One quest / reward row. Quests get a diamond seal, rewards get a round coin.
    Component {
        id: entryRow
        Item {
            id: row
            required property var modelData
            readonly property bool isReward: modelData.key === "rewards"
            readonly property bool celebrating: !isReward && modelData.done
            readonly property real baseHeight: Math.max(40, entryTitle.implicitHeight + 18)
            readonly property string cheer: root.cheers[Math.floor(Math.random() * root.cheers.length)] + "  +" + root.nextGain() + " XP"
            property real collapse: 1
            property real burst: 0

            width: content.width
            height: baseHeight * collapse
            z: celebrating ? 10 : 0

            HoverHandler { id: rowHover }

            Item {
                id: body
                width: parent.width
                height: row.baseHeight

                // Gold flash behind the row when a quest is fulfilled
                Rectangle {
                    id: glow
                    anchors.fill: parent
                    anchors.leftMargin: -8
                    anchors.rightMargin: -8
                    radius: 6
                    color: Config.colors.accent
                    opacity: 0
                }

                // The note itself: parchment pinned to the board, tilted a hair as if pinned by hand
                ParchmentNote {
                    id: paper
                    x: -6 - margin
                    y: 2 - margin
                    width: parent.width + 12 + 2 * margin
                    height: parent.height - 4 + 2 * margin
                    key: (row.isReward ? "reward:" : "quest:") + row.modelData.title
                    pinX: 9
                    rotation: (hash(key) % 100) / 100 - 0.5   // between -0.5° and +0.5°
                    antialiasing: true
                }

                Rectangle {
                    id: marker
                    width: row.isReward ? 18 : 17
                    height: width
                    radius: row.isReward ? width / 2 : 0
                    rotation: row.isReward ? 0 : 45
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    // done: stamped with a red wax seal
                    color: row.modelData.done ? root.sealColor : "transparent"
                    border.width: 1.5
                    border.color: row.modelData.done ? Qt.darker(root.sealColor, 1.5) : root.inkFaded
                    // Little star stamped on reward coins
                    Text {
                        anchors.centerIn: parent
                        visible: row.isReward
                        text: "✦"
                        font.pixelSize: 10
                        color: row.modelData.done ? "#f3d9b0" : root.inkFaded
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleEntry(row.modelData.key, row.modelData.i)
                    }
                }

                Text {
                    id: entryTitle
                    anchors.left: marker.right
                    anchors.leftMargin: 14
                    anchors.right: row.isReward ? costBadge.left : removeBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.title
                    wrapMode: Text.Wrap
                    font.family: fontRecia.name
                    font.pixelSize: 17
                    font.strikeout: row.celebrating
                    // written in ink on the parchment
                    color: row.celebrating ? root.sealColor
                         : row.modelData.done ? root.inkFaded : root.ink
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleEntry(row.modelData.key, row.modelData.i)
                    }
                }

                // Cost: "◆ 80" (hover for − / +), or "claimed" once bought
                Row {
                    id: costBadge
                    visible: row.isReward
                    anchors.right: removeBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    readonly property bool canEdit: rowHover.hovered && !row.modelData.done
                    Text {
                        visible: costBadge.canEdit
                        text: "−"
                        font.pixelSize: 15
                        color: minusArea.containsMouse ? root.manaInk : root.inkFaded
                        MouseArea { id: minusArea; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.adjustCost(row.modelData.i, -10) }
                    }
                    Text {
                        text: row.modelData.done ? "claimed" : "◆ " + row.modelData.cost
                        font.family: fontDominica.name
                        font.pixelSize: 14
                        color: row.modelData.done ? root.sealColor
                             : board.mana >= row.modelData.cost ? root.manaInk : root.inkFaded
                    }
                    Text {
                        visible: costBadge.canEdit
                        text: "+"
                        font.pixelSize: 15
                        color: plusArea.containsMouse ? root.manaInk : root.inkFaded
                        MouseArea { id: plusArea; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.adjustCost(row.modelData.i, 10) }
                    }
                }

                Text {
                    id: removeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    font.pixelSize: 14
                    color: removeArea.containsMouse ? root.sealColor : root.inkFaded
                    opacity: rowHover.hovered && !row.celebrating ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        enabled: !row.celebrating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeEntry(row.modelData.key, row.modelData.i)
                    }
                }

            }

            // Star burst out of the seal
            Item {
                id: burstOrigin
                x: marker.x + marker.width / 2
                y: body.height / 2
                visible: row.burst > 0 && row.burst < 1
                Repeater {
                    model: 8
                    Text {
                        required property int index
                        readonly property real angle: index * Math.PI / 4 + 0.3
                        x: Math.cos(angle) * 46 * row.burst - width / 2
                        y: Math.sin(angle) * 30 * row.burst - height / 2
                        text: index % 2 ? "✦" : "✧"
                        font.pixelSize: index % 2 ? 14 : 11
                        color: Config.colors.accent
                        opacity: 1 - row.burst
                        scale: 1.4 - row.burst * 0.8
                    }
                }
            }

            // Floating cheer
            Text {
                id: cheerText
                x: entryTitle.x + 40
                y: 0
                text: row.cheer
                font.family: fontBoska.name
                font.pixelSize: 20
                font.weight: 600
                color: Config.colors.accent
                opacity: 0
                DropShadow {
                    anchors.fill: parent
                    source: parent
                    color: "Black"
                    opacity: 0.5
                    radius: 4
                }
            }

            // Reward feedback text ("Need 30 more mana" / "-80 mana")
            Text {
                id: rewardMsg
                x: entryTitle.x + 30
                y: 0
                font.family: fontBoska.name
                font.pixelSize: 17
                font.weight: 600
                opacity: 0
                DropShadow { anchors.fill: parent; source: parent; color: "Black"; opacity: 0.5; radius: 4 }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: body; property: "x"; to: -8; duration: 50 }
                NumberAnimation { target: body; property: "x"; to: 8; duration: 70 }
                NumberAnimation { target: body; property: "x"; to: -6; duration: 70 }
                NumberAnimation { target: body; property: "x"; to: 4; duration: 60 }
                NumberAnimation { target: body; property: "x"; to: 0; duration: 50 }
            }
            SequentialAnimation {
                id: floatMsg
                ParallelAnimation {
                    NumberAnimation { target: rewardMsg; property: "opacity"; from: 0; to: 1; duration: 150 }
                    NumberAnimation { target: rewardMsg; property: "y"; from: 0; to: -24; duration: 1200; easing.type: Easing.OutCubic }
                }
                NumberAnimation { target: rewardMsg; property: "opacity"; to: 0; duration: 350 }
            }
            Connections {
                target: root
                function onNotEnoughMana(index, missing) {
                    if (!row.isReward || row.modelData.i !== index)
                        return;
                    rewardMsg.text = "Need " + missing + " more mana";
                    rewardMsg.color = Config.colors.danger;
                    shake.restart();
                    floatMsg.restart();
                }
            }
            function playClaim() {
                rewardMsg.text = "−" + row.modelData.cost + " mana  ✦";
                rewardMsg.color = root.manaColor;
                row.burst = 0;
                claimBurst.restart();
                floatMsg.restart();
            }
            NumberAnimation { id: claimBurst; target: row; property: "burst"; from: 0; to: 1; duration: 750; easing.type: Easing.OutCubic }

            SequentialAnimation {
                id: celebrate
                ParallelAnimation {
                    // flash
                    SequentialAnimation {
                        NumberAnimation { target: glow; property: "opacity"; to: 0.35; duration: 140; easing.type: Easing.OutQuad }
                        NumberAnimation { target: glow; property: "opacity"; to: 0.08; duration: 600; easing.type: Easing.InOutQuad }
                    }
                    // seal pop
                    SequentialAnimation {
                        NumberAnimation { target: marker; property: "scale"; to: 1.8; duration: 160; easing.type: Easing.OutBack }
                        NumberAnimation { target: marker; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.InOutQuad }
                    }
                    // star burst
                    NumberAnimation { target: row; property: "burst"; from: 0; to: 1; duration: 750; easing.type: Easing.OutCubic }
                    // cheer floats up and fades
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: cheerText; property: "opacity"; to: 1; duration: 180 }
                            NumberAnimation { target: cheerText; property: "y"; from: 0; to: -26; duration: 1100; easing.type: Easing.OutCubic }
                        }
                        NumberAnimation { target: cheerText; property: "opacity"; to: 0; duration: 300 }
                    }
                }
                // slide off the board
                ParallelAnimation {
                    NumberAnimation { target: body; property: "x"; to: row.width * 0.5; duration: 380; easing.type: Easing.InCubic }
                    NumberAnimation { target: body; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InCubic }
                }
                NumberAnimation { target: row; property: "collapse"; to: 0; duration: 220; easing.type: Easing.InOutQuad }
                ScriptAction { script: root.archiveQuest(row.modelData.uid) }
            }

            Component.onCompleted: {
                if (celebrating)
                    celebrate.start();
                else if (isReward && modelData.done && root.lastClaimedUid !== "" && modelData.uid === root.lastClaimedUid) {
                    root.lastClaimedUid = "";
                    playClaim();
                }
            }
        }
    }

    // "+ Add…" box. Used through a Loader that carries listKey and hint.
    Component {
        id: entryInput
        Rectangle {
            id: box
            readonly property string listKey: parent ? parent.listKey : ""
            readonly property string hint: parent ? parent.hint : ""
            width: content.width
            height: 38
            radius: 6
            color: Config.colors.shadow
            border.width: 1
            border.color: field.activeFocus ? Config.colors.accent : Config.colors.highlight

            Text {
                id: plus
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                font.pixelSize: 20
                color: Config.colors.accent
            }
            TextField {
                id: field
                anchors.left: plus.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: box.hint
                placeholderTextColor: root.dimInk
                color: Config.colors.textLight
                font.family: fontRecia.name
                font.pixelSize: 16
                background: null
                onAccepted: {
                    root.addEntry(box.listKey, text);
                    text = "";
                }
                Keys.onEscapePressed: focus = false
            }
        }
    }

    // One chronicle (history) row: ✓ title · date, hover for ↺ restore / ✕ delete.
    Component {
        id: historyRow
        Item {
            id: hrow
            required property var modelData
            width: content.width
            height: Math.max(26, hTitle.implicitHeight + 6)

            HoverHandler { id: hHover }

            Text {
                id: check
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "✓"
                font.pixelSize: 13
                color: Config.colors.accent
            }
            Text {
                id: hTitle
                anchors.left: check.right
                anchors.leftMargin: 12
                anchors.right: hDate.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: hrow.modelData.title
                wrapMode: Text.Wrap
                font.family: fontRecia.name
                font.pixelSize: 15
                color: Config.colors.textLight
                opacity: 0.7
            }
            Text {
                id: hDate
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !hHover.hovered
                text: Qt.formatDateTime(new Date(hrow.modelData.completedAt), "MMM d")
                font.family: fontDominica.name
                font.pixelSize: 13
                color: root.dimInk
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                visible: hHover.hovered
                Text {
                    text: "↺"
                    font.pixelSize: 15
                    color: restoreArea.containsMouse ? Config.colors.accent : root.dimInk
                    MouseArea {
                        id: restoreArea
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.restoreHistory(hrow.modelData.i)
                    }
                }
                Text {
                    text: "✕"
                    font.pixelSize: 13
                    color: hDelArea.containsMouse ? Config.colors.danger : root.dimInk
                    MouseArea {
                        id: hDelArea
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteHistory(hrow.modelData.i)
                    }
                }
            }
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────

    Column {
        id: content
        anchors.top: parent.top
        anchors.topMargin: 22
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        spacing: 6

        // Shown only if quests.json couldn't be read (nothing will be saved until fixed)
        Text {
            visible: root.dataError !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "⚠ " + root.dataError + ". Backups: ~/.local/share/questboard/backups"
            font.family: fontDominica.name
            font.pixelSize: 13
            color: Config.colors.danger
        }

        // Quests — click the heading to fold the quest list.
        // The title hangs on a little wooden signboard from two brass chains.
        Item {
            width: parent.width
            height: questHead.implicitHeight + 22

            // Chains up to the top of the frame
            Repeater {
                model: [-1, 1]
                delegate: Column {
                    required property var modelData
                    x: parent.width / 2 + modelData * (sign.width / 2 - 26) - width / 2
                    y: -22
                    spacing: -3
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            width: index % 2 ? 4 : 9
                            height: 11
                            radius: 4.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"
                            border.width: 2.2
                            border.color: index % 2 ? "#9c7a36" : "#d4ae62"
                        }
                    }
                }
            }
            WoodBacking {
                id: sign
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: Math.max(questHead.implicitWidth + 90, 300)
                height: questHead.implicitHeight + 14
                singleBoard: true
                ornaments: false
                cornerRadius: 6
                seed: 77
                visible: root.widgetBackground
            }
            Loader {
                id: questHead
                anchors.horizontalCenter: parent.horizontalCenter
                y: 11
                property string title: (board.questsFolded ? "▸ " : "▾ ") + "Quest Board"
                property int size: 40
                property string status: board.quests.length === 0
                    ? (root.doneToday > 0 ? "Board cleared! " + root.doneToday + " fulfilled today" : "No quests posted")
                    : board.quests.length + " active · " + root.doneToday + " fulfilled today"
                sourceComponent: sectionHeading
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.dataReady) board.questsFolded = !board.questsFolded
            }
        }
        // Level / XP bar
        Item {
            width: parent.width
            height: 68
            Text {
                id: lvlBadge
                anchors.left: parent.left
                anchors.top: parent.top
                text: "Lv " + root.lvl.level
                style: Text.Outline
                styleColor: "#d9140a04"
                font.family: fontBoska.name
                font.pixelSize: 20
                font.weight: 600
                color: Config.colors.accent
            }
            Text {
                anchors.left: lvlBadge.right
                anchors.leftMargin: 10
                anchors.baseline: lvlBadge.baseline
                text: root.lvl.rank
                style: Text.Outline
                styleColor: "#d9140a04"
                font.family: fontDominica.name
                font.pixelSize: 15
                color: Config.colors.textLight
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: lvlBadge.baseline
                text: root.lvl.into + " / " + root.lvl.need + " XP"
                style: Text.Outline
                styleColor: "#d9140a04"
                font.family: fontDominica.name
                font.pixelSize: 13
                color: root.dimInk
            }
            Rectangle {
                id: xpTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: lvlBadge.bottom
                anchors.topMargin: 6
                height: 8
                radius: 4
                color: Config.colors.shadow
                border.width: 1
                border.color: Config.colors.highlight
                Rectangle {
                    id: xpFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    radius: 3
                    width: Math.max(0, (parent.width - 2) * root.lvl.into / root.lvl.need)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.dimInk }
                        GradientStop { position: 1; color: Config.colors.accent }
                    }
                    Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                id: manaText
                anchors.left: parent.left
                anchors.top: xpTrack.bottom
                anchors.topMargin: 7
                text: "◆ " + Math.max(0, board.mana) + " mana"
                style: Text.Outline
                styleColor: "#d9140a04"
                font.family: fontBoska.name
                font.pixelSize: 16
                font.weight: 600
                color: root.manaColor
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: manaText.baseline
                text: "next quest: +" + root.nextGain() + " XP · +" + root.nextGain() + " mana"
                style: Text.Outline
                styleColor: "#d9140a04"
                font.family: fontDominica.name
                font.pixelSize: 12
                color: root.dimInk
            }
        }
        Repeater {
            model: board.questsFolded ? [] : root.tagged("quests")
            delegate: entryRow
        }
        Loader {
            visible: !board.questsFolded
            active: !board.questsFolded
            property string listKey: "quests"
            property string hint: "Post a new quest…"
            sourceComponent: entryInput
        }

        // Rewards
        Item { width: 1; height: 14 }
        Item {
            width: parent.width
            height: rewardHead.implicitHeight
            Loader {
                id: rewardHead
                anchors.horizontalCenter: parent.horizontalCenter
                property string title: (board.rewardsFolded ? "▸ " : "▾ ") + "Rewards"
                property int size: 28
                property string status: board.rewards.length === 0
                    ? "No rewards yet — add something to look forward to"
                    : (board.rewards.length - root.rewardsClaimed) + " waiting · " + root.rewardsClaimed + " claimed · ◆ " + Math.max(0, board.mana) + " mana to spend"
                sourceComponent: sectionHeading
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.dataReady) board.rewardsFolded = !board.rewardsFolded
            }
        }
        Repeater {
            model: board.rewardsFolded ? [] : root.tagged("rewards")
            delegate: entryRow
        }
        Loader {
            visible: !board.rewardsFolded
            active: !board.rewardsFolded
            property string listKey: "rewards"
            property string hint: "Add a reward… e.g. Pizza 80"
            sourceComponent: entryInput
        }

        // Chronicle (history of fulfilled quests) — click the heading to expand
        Item { width: 1; height: 14 }
        Item {
            width: parent.width
            height: chronHead.implicitHeight
            Loader {
                id: chronHead
                anchors.horizontalCenter: parent.horizontalCenter
                property string title: (root.showHistory ? "▾ " : "▸ ") + "Chronicle"
                property int size: 24
                property string status: board.history.length === 0
                    ? "Fulfilled quests will be recorded here"
                    : board.history.length + (board.history.length === 1 ? " deed" : " deeds") + " recorded"
                sourceComponent: sectionHeading
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showHistory = !root.showHistory
            }
        }
        Repeater {
            model: root.showHistory
                   ? board.history.slice(0, 8).map((h, i) => ({ "i": i, "title": h.title, "completedAt": h.completedAt }))
                   : []
            delegate: historyRow
        }
        Text {
            visible: root.showHistory && board.history.length > 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: "…and " + (board.history.length - 8) + " older deeds"
            font.family: fontDominica.name
            font.pixelSize: 13
            color: root.dimInk
        }
    }

    // ── Settings ──
    // "⚙" button, left of the "?"
    Rectangle {
        id: settingsBtn
        z: 60
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 48
        width: 24
        height: 24
        radius: 12
        color: setArea.containsMouse || root.showSettings ? Config.colors.accent : "transparent"
        border.width: 1.5
        border.color: setArea.containsMouse || root.showSettings ? Config.colors.accent : root.dimInk
        Text {
            anchors.centerIn: parent
            text: root.showSettings ? "✕" : "⚙"
            font.pixelSize: root.showSettings ? 12 : 15
            font.weight: 700
            color: setArea.containsMouse || root.showSettings ? Config.colors.base : Config.colors.accent
        }
        MouseArea {
            id: setArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showSettings = !root.showSettings
        }
    }

    // Settings overlay
    Item {
        id: settingsOverlay
        anchors.fill: parent
        z: 55
        visible: opacity > 0
        opacity: root.showSettings ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            anchors.fill: parent
            radius: Config.settings.defaultWindowRadius
            color: Config.colors.base
            opacity: 0.97
            border.width: 1
            border.color: root.dimInk
        }
        // Blocks clicks reaching the board underneath
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: settingsCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 22
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Settings"
                font.family: fontBoska.name
                font.pixelSize: 30
                font.weight: 600
                color: Config.colors.accent
            }
            Text {
                width: parent.width
                text: "Canvas calendar link"
                font.family: fontBoska.name
                font.pixelSize: 17
                font.weight: 600
                color: Config.colors.textLight
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Your homework is added from this link. To get a new one: in Canvas open Calendar, click “Calendar Feed” (bottom right) and copy the link."
                font.family: fontDominica.name
                font.pixelSize: 13
                color: root.dimInk
            }
            Rectangle {
                width: parent.width
                height: 38
                radius: 6
                color: Config.colors.shadow
                border.width: 1
                border.color: settingsField.activeFocus ? Config.colors.accent : Config.colors.highlight
                TextField {
                    id: settingsField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "https://….ics"
                    placeholderTextColor: root.dimInk
                    color: Config.colors.textLight
                    font.family: fontRecia.name
                    font.pixelSize: 14
                    selectByMouse: true
                    background: null
                    onAccepted: root.saveCanvasUrl(text)
                    Keys.onEscapePressed: focus = false
                }
            }
            Row {
                spacing: 10
                PaneButton {
                fontFamily: fontDominica.name
                    label: "Save link"
                    enabledBtn: settingsField.text.trim() !== canvasUrlFile.loadedUrl && !saveUrlProc.running && !syncProc.running
                    onClicked: root.saveCanvasUrl(settingsField.text)
                }
                PaneButton {
                fontFamily: fontDominica.name
                    label: syncProc.running ? "Syncing…" : "Sync now"
                    enabledBtn: !syncProc.running && canvasUrlFile.loadedUrl !== ""
                    onClicked: root.runCanvasSync()
                }
            }
            Text {
                visible: root.settingsStatus !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: root.settingsStatus
                font.family: fontDominica.name
                font.pixelSize: 13
                color: root.settingsError ? Config.colors.danger : Config.colors.textLight
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Homework also syncs automatically every Sunday at 9 PM."
                font.family: fontDominica.name
                font.pixelSize: 12
                color: root.dimInk
            }
            Item { width: 1; height: 4 }
            PaneButton {
                fontFamily: fontDominica.name
                anchors.horizontalCenter: parent.horizontalCenter
                label: "Done"
                onClicked: root.showSettings = false
            }
        }
    }

    // ── Help ──
    // "?" button, top-right corner
    Rectangle {
        id: helpBtn
        z: 60
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16
        anchors.rightMargin: 16
        width: 24
        height: 24
        radius: 12
        color: helpArea.containsMouse || root.showHelp ? Config.colors.accent : "transparent"
        border.width: 1.5
        border.color: helpArea.containsMouse || root.showHelp ? Config.colors.accent : root.dimInk
        Text {
            anchors.centerIn: parent
            text: root.showHelp ? "✕" : "?"
            font.family: fontBoska.name
            font.pixelSize: root.showHelp ? 12 : 15
            font.weight: 700
            color: helpArea.containsMouse || root.showHelp ? Config.colors.base : Config.colors.accent
        }
        MouseArea {
            id: helpArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showHelp = !root.showHelp
        }
    }

    // Guide overlay
    Item {
        id: helpOverlay
        anchors.fill: parent
        z: 55
        visible: opacity > 0
        opacity: root.showHelp ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Rectangle {
            anchors.fill: parent
            radius: Config.settings.defaultWindowRadius
            color: Config.colors.base
            opacity: 0.97
            border.width: 1
            border.color: root.dimInk
        }
        // Click anywhere on the guide to close it (also blocks clicks reaching the board)
        MouseArea {
            anchors.fill: parent
            onClicked: root.showHelp = false
        }

        Flickable {
            id: helpFlick
            anchors.fill: parent
            anchors.topMargin: 22
            anchors.bottomMargin: 18
            anchors.leftMargin: 26
            anchors.rightMargin: 26
            contentHeight: helpCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: helpCol
            width: helpFlick.width
            spacing: 10

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Adventurer's Guide"
                font.family: fontBoska.name
                font.pixelSize: 30
                font.weight: 500
                color: Config.colors.accent
            }
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: divider
            }

            Repeater {
                model: [
                    { "icon": "⚙", "head": "Settings",
                      "body": "The ⚙ button opens Settings. Paste a new Canvas calendar link there and press Save link (it's tested right away), or press Sync now to pull in new homework. Homework also syncs every Sunday at 9 PM." },
                    { "icon": "▾", "head": "Folding sections",
                      "body": "Click the Quest Board, Rewards or Chronicle heading to fold or unfold that section (▾ open, ▸ folded). Quest Board and Rewards remember how you left them." },
                    { "icon": "◇", "head": "Quests",
                      "body": "Type in “Post a new quest…” and press Enter. Click a quest or its diamond to fulfil it — it celebrates, then moves to the Chronicle. Clicked by mistake? Click it again during the celebration to keep it. Hover a quest and press ✕ to delete it (no XP)." },
                    { "icon": "✦", "head": "Levels & XP",
                      "body": "Each fulfilled quest earns 25 XP, +5 for every quest already done today (up to +25). Your next quest is worth " + root.nextGain() + " XP — and the same amount of mana to spend on rewards. Each level needs 50 XP more than the last; ranks rise from Wanderer to Mythic." },
                    { "icon": "◯", "head": "Rewards",
                      "body": "Rewards cost mana (◆), earned from quests. Add one with its price at the end — “Pizza night 80” (no number = 50). Hover a reward for − / + to change its price. Click to claim it: the mana is spent. Not enough? It tells you how much more you need. Click a claimed reward to unclaim it and get the mana back. ✕ removes a reward (no refund)." },
                    { "icon": "▸", "head": "Chronicle",
                      "body": "Click the Chronicle heading to open your history of fulfilled quests (newest 8 shown). Hover an entry: ↺ puts it back on the board and returns its XP, ✕ erases the entry but keeps the XP." },
                    { "icon": "✥", "head": "Moving the board",
                      "body": "Press and drag any empty part of the board — the title or background — to move it. Its position is remembered." },
                    { "icon": "⛨", "head": "Your data",
                      "body": "Everything is saved in ~/.config/quickshell/quests.json and survives reboots. Daily backups (last 30 days) are kept in ~/.local/share/questboard/backups. If a red ⚠ appears, the file couldn't be read and nothing is saved until it's fixed." }
                ]
                delegate: Row {
                    required property var modelData
                    width: helpCol.width
                    spacing: 12
                    Text {
                        id: hIcon
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.icon
                        font.pixelSize: 16
                        color: Config.colors.accent
                    }
                    Column {
                        width: parent.width - hIcon.width - parent.spacing
                        spacing: 2
                        Text {
                            text: modelData.head
                            font.family: fontBoska.name
                            font.pixelSize: 18
                            font.weight: 600
                            color: Config.colors.accent
                        }
                        Text {
                            width: parent.width
                            text: modelData.body
                            wrapMode: Text.Wrap
                            lineHeight: 1.1
                            font.family: fontRecia.name
                            font.pixelSize: 14
                            color: Config.colors.textLight
                            opacity: 0.9
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 4
                text: "Click ✕ (top right) to close"
                font.family: fontDominica.name
                font.pixelSize: 13
                color: root.dimInk
            }
        }
        }

        // "scroll for more" hint when the guide is taller than the board
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.showHelp && !helpFlick.atYEnd && helpFlick.contentHeight > helpFlick.height + 1 ? 1 : 0
            width: moreText.implicitWidth + 20
            height: 22
            radius: 11
            color: Config.colors.shadow
            border.width: 1
            border.color: root.dimInk
            Text {
                id: moreText
                anchors.centerIn: parent
                text: "scroll for more ▾"
                font.family: fontDominica.name
                font.pixelSize: 12
                color: Config.colors.accent
            }
        }
    }

    // ── LEVEL UP banner ──
    Item {
        id: levelUp
        anchors.fill: parent
        z: 100
        visible: opacity > 0
        opacity: 0
        property int newLevel: 1
        property string newRank: ""
        property real ring: 0

        function show(level, rank) {
            newLevel = level;
            newRank = rank;
            levelUpAnim.restart();
        }

        Rectangle {
            anchors.fill: parent
            radius: Config.settings.defaultWindowRadius
            color: Config.colors.base
            opacity: 0.9
        }
        // ring of stars
        Repeater {
            model: 12
            Text {
                required property int index
                readonly property real angle: index * Math.PI / 6
                x: levelUp.width / 2 + Math.cos(angle) * (60 + 90 * levelUp.ring) - width / 2
                y: levelUp.height / 2 + Math.sin(angle) * (40 + 60 * levelUp.ring) - height / 2
                text: index % 2 ? "✦" : "✧"
                font.pixelSize: 18
                color: Config.colors.accent
                opacity: 1 - levelUp.ring * 0.7
            }
        }
        Column {
            id: luText
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "LEVEL UP!"
                font.family: fontBoska.name
                font.pixelSize: 46
                font.weight: 700
                color: Config.colors.accent
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Level " + levelUp.newLevel + " — " + levelUp.newRank
                font.family: fontDominica.name
                font.pixelSize: 18
                color: Config.colors.textLight
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { levelUpAnim.stop(); levelUp.opacity = 0; }
        }
        SequentialAnimation {
            id: levelUpAnim
            ParallelAnimation {
                NumberAnimation { target: levelUp; property: "opacity"; from: 0; to: 1; duration: 200 }
                NumberAnimation { target: luText; property: "scale"; from: 0.4; to: 1; duration: 450; easing.type: Easing.OutBack }
                NumberAnimation { target: levelUp; property: "ring"; from: 0; to: 1; duration: 1400; easing.type: Easing.OutCubic }
            }
            PauseAnimation { duration: 1600 }
            NumberAnimation { target: levelUp; property: "opacity"; to: 0; duration: 500 }
        }
    }
}
