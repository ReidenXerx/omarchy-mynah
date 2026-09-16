import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../app" as App

// The pill that shows dictation is on.
//
// It is the only thing mynah puts on screen, so it says exactly three things:
// that it is listening, how loud you are, and what it just typed. It takes no
// keyboard focus and no pointer input — you are typing into another window, and
// nothing here may take that away.
Scope {
  id: hud

  property var service: null

  readonly property string state: hud.service ? hud.service.state : "idle"
  readonly property string hotkey: hud.service ? hud.service.hotkey : ""
  readonly property real level: hud.service ? hud.service.level : 0
  readonly property var bands: hud.service ? hud.service.bands : []
  // The last utterance, for a few seconds after it landed.
  readonly property bool showText: !!hud.service && hud.service.lastText !== "" && textLife.running

  Timer {
    id: textLife
    interval: 4000
  }

  Connections {
    target: hud.service
    function onLastTextAtChanged() { textLife.restart() }
  }

  PanelWindow {
    id: surface

    // The focused screen only: a pill on every monitor would be three pills.
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    visible: true
    color: "transparent"
    WlrLayershell.namespace: "omarchy-mynah-hud"
    WlrLayershell.layer: WlrLayer.Overlay
    // Never take the keyboard: the words are going somewhere else.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors { bottom: true }
    margins.bottom: Style.space(64)
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Nothing in the pill is clickable, so the surface accepts no input at all
    // and clicks land in the window you are dictating into.
    mask: Region {}

    Rectangle {
      id: card
      implicitWidth: row.implicitWidth + Style.space(32)
      implicitHeight: Math.max(Style.space(52), row.implicitHeight + Style.space(20))
      radius: height / 2
      color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.96)
      border.width: 1
      border.color: hud.state === "listening"
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
                    : Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.35)

      Behavior on border.color { ColorAnimation { duration: 180 } }

      Row {
        id: row
        anchors.centerIn: parent
        spacing: Style.space(14)

        App.BirdMark {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(28)
          height: Style.space(28)
          color: hud.state === "transcribing" ? Color.accent : Color.popups.text
          // It cocks its head while it listens and opens its bill while it
          // types, and makes a sound either way: the pill shows what it is
          // doing without reading a word.
          pose: hud.state === "transcribing" ? "saying"
              : hud.state === "listening" ? "listening" : "rest"
          waves: hud.state === "listening" || hud.state === "transcribing"
          level: hud.level

          SequentialAnimation on opacity {
            running: hud.state === "listening"
            loops: Animation.Infinite
            NumberAnimation { to: 0.62; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
          }
          onOpacityChanged: if (hud.state !== "listening" && opacity !== 1) opacity = 1
        }

        // Your voice, in twelve bands. See Spectrum.qml.
        Spectrum {
          anchors.verticalCenter: parent.verticalCenter
          visible: hud.state === "listening"
          running: hud.state === "listening"
          bands: hud.service ? hud.service.bands : []
          level: hud.level
          color: Color.accent
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: hud.state === "transcribing" ? "typing…" : "listening"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        // How to stop. The pill is the only place it is written down: the key
        // that started dictation is not on screen anywhere else, and a mic
        // that is on with no visible way to turn it off is the thing people
        // dislike most about dictation tools.
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          visible: !hud.showText && hud.hotkey !== ""

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: keyLabel.implicitWidth + Style.space(12)
            implicitHeight: keyLabel.implicitHeight + Style.space(5)
            radius: Style.space(5)
            color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.18)

            Text {
              id: keyLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: hud.hotkey
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "to stop"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // What landed in the window, briefly. Elided hard: this is a receipt,
        // not a transcript.
        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: hud.showText
          textFormat: Text.PlainText
          text: hud.service ? hud.service.lastText : ""
          color: Color.popups.text
          elide: Text.ElideLeft
          maximumLineCount: 1
          width: Math.min(implicitWidth, Style.space(320))
          font.family: Style.font.family
          font.pixelSize: Style.font.caption

          Behavior on opacity { NumberAnimation { duration: 200 } }
        }
      }
    }
  }
}
