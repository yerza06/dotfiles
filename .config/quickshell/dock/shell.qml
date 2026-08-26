import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Dock {
            required property var modelData
            targetScreen: modelData
        }
    }
}
