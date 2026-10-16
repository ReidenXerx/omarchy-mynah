import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

// The pill near the bottom of the screen while you dictate: the bird, what it is doing, and the key that stops it.
// An on-screen display, so it takes no keyboard and stays above the window you are typing into.
PlasmaCore.Dialog {
  id: pill

  property var mynah: null

  type: PlasmaCore.Dialog.OnScreenDisplay
  flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
  location: PlasmaCore.Types.Floating
  outputOnly: true
  visible: true

  readonly property rect area: pill.screen ? Qt.rect(pill.screen.virtualX, pill.screen.virtualY, pill.screen.width, pill.screen.height)
                                           : Qt.rect(0, 0, 1280, 800)
  x: pill.area.x + Math.round((pill.area.width - pill.width) / 2)
  y: pill.area.y + pill.area.height - pill.height - Kirigami.Units.gridUnit * 4

  mainItem: RowLayout {
    spacing: Kirigami.Units.largeSpacing
    BirdMark {
      Layout.preferredWidth: Kirigami.Units.iconSizes.medium
      Layout.preferredHeight: Layout.preferredWidth
      color: Kirigami.Theme.highlightColor
      pose: pill.mynah && pill.mynah.state === "transcribing" ? "saying" : "listening"
      waves: true
    }
    Kirigami.Heading {
      level: 3
      textFormat: Text.PlainText
      text: pill.mynah && pill.mynah.state === "transcribing" ? "Writing it down" : "Listening"
    }
    Rectangle {
      visible: keyLabel.text !== ""
      Layout.preferredWidth: keyLabel.implicitWidth + Kirigami.Units.largeSpacing
      Layout.preferredHeight: keyLabel.implicitHeight + Kirigami.Units.smallSpacing
      radius: Kirigami.Units.cornerRadius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35)
      Text {
        id: keyLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        color: Kirigami.Theme.textColor
        text: pill.mynah ? pill.mynah.shortcut : ""
      }
    }
    Text {
      visible: keyLabel.text !== ""
      textFormat: Text.PlainText
      color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.65)
      text: "to stop"
    }
  }
}
