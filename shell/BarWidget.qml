import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "../app" as App

// Mynah in the bar: the bird, in the bar's own colour when idle and in the
// accent while it listens, with the level moving beside it.
//
// Left click starts or ends a session — the same thing the key does. Right
// click is for the things you do once: install the login service, stop it,
// see why it is not running.
BarWidget {
  id: root
  moduleName: "reidenxerx.mynah"

  readonly property string pluginId: "reidenxerx.mynah"

  // The plugin's own service, through the bar's shell facade. Services can be
  // created after widgets, so the lookup is retried until it lands.
  property var mynah: null

  function findService() {
    if (root.mynah) return
    const shell = root.bar ? root.bar.shell : null
    root.mynah = shell && typeof shell.serviceFor === "function" ? shell.serviceFor(root.pluginId) : null
  }

  Timer {
    interval: 1000
    repeat: true
    running: !root.mynah
    triggeredOnStart: true
    onTriggered: root.findService()
  }

  onBarChanged: findService()

  readonly property string state: root.mynah ? root.mynah.state : "off"
  readonly property real level: root.mynah ? root.mynah.level : 0
  readonly property bool listening: root.state === "listening"

  readonly property color stateColor: {
    if (root.state === "listening") return Color.accent
    if (root.state === "transcribing") return Color.foreground
    if (root.state === "off") return Color.muted
    return root.bar ? root.bar.barForeground : Color.foreground
  }

  readonly property string tooltip: {
    if (!root.mynah) return "Mynah"
    if (root.mynah.stopped) return "Mynah: stopped — right click to start it"
    switch (root.state) {
    case "listening": return "Mynah: listening — " + root.mynah.hotkey + " or click to stop"
    case "transcribing": return "Mynah: typing what you said"
    case "idle": return "Mynah: ready — " + root.mynah.hotkey + " or click to dictate"
    default: return root.mynah.problem !== "" ? "Mynah: " + root.mynah.problem
                                              : "Mynah: not running — right click for why"
    }
  }

  // ---------------------------------------------------------------- the menu

  property bool menuOpen: false

  readonly property var menuEntries: {
    const entries = []
    if (!root.mynah) return entries
    if (root.mynah.stopped || root.state === "off") {
      entries.push({ action: "start", label: "Start dictation service" })
    } else {
      entries.push({ action: "toggle", label: root.listening ? "Stop this session" : "Dictate now" })
    }
    entries.push({ action: "login", label: "Start it at login" })
    entries.push({ action: "setup", label: "Check what is missing" })
    if (!root.mynah.stopped && root.state !== "off") entries.push({ action: "quit", label: "Stop dictation service" })
    return entries
  }

  function runMenu(action) {
    root.menuOpen = false
    if (!root.mynah) return
    if (action === "toggle") root.mynah.toggle()
    else if (action === "start") root.mynah.startUp()
    else if (action === "quit") root.mynah.shutDown()
    else if (action === "login") root.mynah.installLoginService()
    else if (action === "setup") {
      // setup asks questions and prints a list; it belongs in a terminal the
      // user can read and answer, not in a pipe.
      Quickshell.execDetached(["/usr/bin/omarchy-launch-floating-terminal-with-presentation",
                               "mynah setup"])
    }
  }

  PopupCard {
    id: menu
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.menuOpen && !!root.mynah
    padding: Style.space(8)
    contentWidth: menu.fittedContentWidth(Style.space(240))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)
    onVisibleChanged: if (!visible) root.menuOpen = false

    Column {
      id: menuColumn
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(2)

      // Why it is not running, when it is not: the CLI's own words, which name
      // the package or the model that is missing.
      Text {
        width: parent.width
        visible: !!root.mynah && root.mynah.problem !== "" && root.state === "off"
        textFormat: Text.PlainText
        text: root.mynah ? root.mynah.problem : ""
        wrapMode: Text.WordWrap
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        bottomPadding: Style.space(6)
      }

      Repeater {
        model: root.menuEntries

        delegate: Rectangle {
          id: entry
          required property var modelData
          width: parent.width
          height: Style.space(30)
          radius: Style.space(6)
          color: entryHover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"

          HoverHandler { id: entryHover }

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: entry.modelData.label
            elide: Text.ElideRight
            color: entry.modelData.action === "quit" ? Color.urgent : Color.popups.text
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.runMenu(entry.modelData.action)
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- the glyph

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    foreground: root.stateColor
    tooltipText: root.tooltip
    onPressed: function (which) {
      if (which === Qt.RightButton) root.menuOpen = !root.menuOpen
      else if (root.mynah) root.mynah.toggle()
    }

    iconComponent: Component {
      // The bar loads this into a fixed 16px canvas and nothing clips it, so
      // the icon must lay itself out INSIDE the space it is given. An earlier
      // version put a level meter beside the bird and set implicitWidth for it;
      // the canvas ignored that and the meter was drawn over the next icon.
      // The bird carries its own sound now, in its own box.
      Item {
        App.BirdMark {
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height)
          height: width
          color: root.stateColor
          pose: root.state === "transcribing" ? "saying"
              : root.state === "listening" ? "listening" : "rest"
          waves: root.state === "listening" || root.state === "transcribing"
          level: root.level
          // Off means no engine; dim rather than gone, so the bar does not
          // jump when dictation stops.
          opacity: root.state === "off" ? 0.45 : 1
        }
      }
    }
  }
}
