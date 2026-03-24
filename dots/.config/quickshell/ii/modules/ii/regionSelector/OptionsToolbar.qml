pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Options toolbar
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    property bool updatingSelectionMode: false
    property bool updatingTabIndex: false
    // Signals
    signal dismiss()

    function selectionModeToIndex(mode) {
        return mode === RegionSelection.SelectionMode.RectCorners ? 0 : 1;
    }

    function indexToSelectionMode(index) {
        return index === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
    }

    Component.onCompleted: {
        updatingTabIndex = true;
        tabBar.setCurrentIndex(selectionModeToIndex(root.selectionMode));
        updatingTabIndex = false;
    }

    onSelectionModeChanged: {
        if (updatingSelectionMode) return;
        const nextIndex = selectionModeToIndex(root.selectionMode);
        if (tabBar.currentIndex === nextIndex) return;
        updatingTabIndex = true;
        tabBar.setCurrentIndex(nextIndex);
        updatingTabIndex = false;
    }

    ToolbarTabBar {
        id: tabBar
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]
        onCurrentIndexChanged: {
            if (root.updatingTabIndex) return;
            const nextSelectionMode = root.indexToSelectionMode(currentIndex);
            if (root.selectionMode === nextSelectionMode) return;
            root.updatingSelectionMode = true;
            root.selectionMode = nextSelectionMode;
            root.updatingSelectionMode = false;
        }
    }
}
