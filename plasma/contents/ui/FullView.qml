import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// The panel: what Mynah is doing, the button that starts and ends a session, the key, and the login service.
PlasmaExtras.Representation {
  id: view

  required property var mynah

  Layout.preferredWidth: Kirigami.Units.gridUnit * 20
  Layout.preferredHeight: implicitHeight
  Layout.minimumWidth: Kirigami.Units.gridUnit * 16

  readonly property var m: view.mynah
  readonly property color faint: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.65)

  implicitHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2

  component Note: PlasmaComponents.Label {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: view.faint
  }

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: Kirigami.Units.largeSpacing
    spacing: Kirigami.Units.largeSpacing

    RowLayout {
      Layout.fillWidth: true
      spacing: Kirigami.Units.largeSpacing
      BirdMark {
        implicitWidth: Kirigami.Units.iconSizes.huge
        implicitHeight: implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        color: view.m.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: view.m.state === "off" ? 0.55 : 1
        pose: view.m.state === "transcribing" ? "saying" : view.m.state === "listening" ? "listening" : "rest"
        waves: view.m.active
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Kirigami.Heading {
          level: 2
          textFormat: Text.PlainText
          text: view.m.bin === "" ? "Not installed" : view.m.state === "listening" ? "Listening"
              : view.m.state === "transcribing" ? "Writing it down" : view.m.state === "off" ? "Not running" : "Ready"
        }
        Note {
          text: view.m.shortcut !== "" ? "Press " + view.m.shortcut + " to start and to stop, wherever you are."
              : "Give it a key: right click → Configure Mynah… → Keyboard Shortcuts."
        }
      }
    }

    PlasmaComponents.Button {
      Layout.fillWidth: true
      enabled: view.m.bin !== ""
      icon.name: view.m.active ? "media-playback-stop" : "audio-input-microphone"
      text: view.m.active ? "Stop" : "Start dictating"
      onClicked: { view.m.expanded = false; view.m.toggle() }
    }

    Note {
      visible: view.m.problem !== ""
      color: Kirigami.Theme.negativeTextColor
      text: view.m.problem
    }

    Kirigami.Separator { Layout.fillWidth: true; visible: view.m.bin !== "" }

    RowLayout {
      Layout.fillWidth: true
      visible: view.m.bin !== ""
      PlasmaComponents.Label {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: "Start Mynah at login"
      }
      PlasmaComponents.Button {
        text: "Turn on"
        onClicked: view.m.installLoginService()
      }
      PlasmaComponents.Button {
        text: "Turn off"
        onClicked: view.m.serviceCommand("uninstall")
      }
    }
    Note {
      visible: view.m.bin !== "" && view.m.serviceState !== ""
      font.family: "monospace"
      text: view.m.serviceState
    }

    Note {
      text: "Speech is recognised on this computer by whisper.cpp; nothing is sent anywhere. On Plasma, Mynah types by "
          + "pasting: the first time, Plasma asks whether it may control the keyboard. Allow it, and tick \"without asking next time\"."
    }
  }
}
