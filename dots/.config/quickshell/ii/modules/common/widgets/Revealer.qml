import qs.modules.common
import QtQuick

/**
 * Recreation of GTK revealer. Expects one single child.
 */
Item {
    id: root
    property bool reveal
    property bool vertical: false
    readonly property Item contentItem: children.length > 0 ? children[0] : null
    clip: true

    implicitWidth: (reveal || vertical) ? (contentItem ? contentItem.implicitWidth : 0) : 0
    implicitHeight: (reveal || !vertical) ? (contentItem ? contentItem.implicitHeight : 0) : 0
    visible: reveal || (width > 0 && height > 0)

    Behavior on implicitWidth {
        enabled: !vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        enabled: vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
}
