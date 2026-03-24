import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    name: Translation.tr("OpenDrop")
    statusText: OpenDrop.statusText
    available: OpenDrop.available
    toggled: OpenDrop.discoveryEnabled
    icon: toggled ? "nearby" : "nearby_off"

    mainAction: () => OpenDrop.toggleDiscovery()
    hasMenu: true
    altAction: () => OpenDrop.openSendDialog()
    tooltipText: Translation.tr("OpenDrop discovery | Right-click to send")
}
