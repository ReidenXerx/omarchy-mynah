import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Mynah for Plasma: voice dictation on a key. Say it, and it types where you are.
//
// The engine is the same `mynah` as on Omarchy; on Plasma it types through the desktop's RemoteDesktop portal,
// since KWin gives ordinary programs no virtual keyboard. This widget adopts an engine that is already running (the
// login service, or one you started), runs one itself otherwise, and asks it what it is doing over its control
// socket. The widget's own keyboard shortcut starts and ends a session instead of opening the panel.
PlasmoidItem {
  id: root

  readonly property string code: String(Qt.resolvedUrl("../code")).replace("file://", "")
  // What the engine is given of Plasma's environment: what it needs to find its socket, hear the microphone and
  // type into the window you are in, and every MYNAH_* override it documents.
  readonly property string envPrefix: "/usr/bin/env -i HOME=\"$HOME\" LANG=\"$LANG\" PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin\""
    + " PYTHONIOENCODING=utf-8 XDG_RUNTIME_DIR=\"$XDG_RUNTIME_DIR\" XDG_CONFIG_HOME=\"$XDG_CONFIG_HOME\""
    + " XDG_DATA_HOME=\"$XDG_DATA_HOME\" XDG_CACHE_HOME=\"$XDG_CACHE_HOME\" XDG_STATE_HOME=\"$XDG_STATE_HOME\""
    + " XDG_CURRENT_DESKTOP=\"$XDG_CURRENT_DESKTOP\" WAYLAND_DISPLAY=\"$WAYLAND_DISPLAY\" DISPLAY=\"$DISPLAY\""
    + " DBUS_SESSION_BUS_ADDRESS=\"$DBUS_SESSION_BUS_ADDRESS\" PULSE_SERVER=\"$PULSE_SERVER\""
    + " MYNAH_CONFIG_DIR=\"$MYNAH_CONFIG_DIR\" MYNAH_MODEL_DIR=\"$MYNAH_MODEL_DIR\" MYNAH_SOCKET=\"$MYNAH_SOCKET\""
    + " MYNAH_WHISPER_CLI=\"$MYNAH_WHISPER_CLI\" "

  function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

  P5Support.DataSource {
    id: runner
    engine: "executable"
    property var onDone: ({})
    onNewData: function (source, data) {
      disconnectSource(source)
      var cb = runner.onDone[source]
      delete runner.onDone[source]
      if (cb) cb(Number(data["exit code"]), String(data["stdout"] || "").slice(0, 65536), String(data["stderr"] || "").slice(0, 4096))
    }
  }

  function run(command, done) {
    var key = command + " # " + Date.now() + Math.random()
    runner.onDone[key] = done || null
    runner.connectSource(key)
  }

  // ---------------------------------------------------------------- finding the engine

  // Resolved once to an absolute path from a fixed list, never left to PATH: nothing runs until one answers
  // --version.
  readonly property var candidates: ["$HOME/.local/bin/mynah", "/usr/local/bin/mynah", "/usr/bin/mynah"]
  property string bin: ""
  property string problem: ""

  function resolve(index) {
    if (index >= root.candidates.length) {
      root.bin = ""
      root.problem = "Mynah's engine is not installed. The README has the install command."
      return
    }
    var path = root.candidates[index]
    // The candidates are fixed strings; the shell expands $HOME inside the double quotes.
    root.run(root.envPrefix + "/usr/bin/timeout 20 \"" + path + "\" --version >/dev/null 2>&1 && printf '%s' \"" + path + "\"",
             function (code, out) {
      if (code === 0 && out.charAt(0) === "/") {
        root.bin = out
        root.problem = ""
        root.ask("status")
      } else {
        root.resolve(index + 1)
      }
    })
  }

  Component.onCompleted: root.resolve(0)

  // ---------------------------------------------------------------- talking to it

  // "off" until an engine answers; then what it says: idle, listening, transcribing.
  property string state: "off"
  readonly property bool active: root.state === "listening" || root.state === "transcribing"

  // Answers can cross: a status asked just before a toggle may arrive after it, with the old state. Each request is
  // numbered, and a status older than the last command is not believed.
  property int asked: 0
  property int commanded: 0

  function ask(command) {
    var number = ++root.asked
    if (command !== "status") root.commanded = number
    root.run(root.envPrefix + "/usr/bin/python3 -I " + root.quote(root.code + "/bin/mynah-ask") + " " + command, function (code, out) {
      if (number < root.commanded) return
      if (code === 3) { root.noEngine(); return }
      var reply = null
      try { reply = JSON.parse(out) } catch (e) { reply = null }
      if (reply && typeof reply.state === "string" && /^[a-z]{1,16}$/.test(reply.state)) root.state = reply.state
      else if (reply && reply.ok === false) root.problem = String(reply.error || "Mynah refused that.").slice(0, 200)
    })
  }

  function toggle() {
    if (root.bin === "") { root.expanded = true; return }
    if (root.state === "off") { root.startEngine(); root.pendingToggle = true; return }
    root.ask("toggle")
  }

  property bool pendingToggle: false

  // Fast while you dictate, slow otherwise: enough to notice a session that ended on silence, or one started from
  // somewhere else.
  Timer {
    interval: root.active ? 400 : 3000
    repeat: true
    running: root.bin !== ""
    onTriggered: root.ask("status")
  }

  // ---------------------------------------------------------------- running one

  // Ours only when nobody else's: it lives as long as Plasma, which is the right lifetime for something that types
  // into the session's windows. Asked again every time rather than remembered, so an engine stopped elsewhere is
  // noticed and replaced.
  property string engineCommand: ""

  P5Support.DataSource {
    id: engineSource
    engine: "executable"
    onNewData: function (source, data) {
      if (source !== root.engineCommand) return
      disconnectSource(source)
      root.engineCommand = ""
      var err = String(data["stderr"] || "").trim().split("\n").pop()
      if (Number(data["exit code"]) !== 0 && err) root.problem = err.slice(0, 200)
      root.state = "off"
    }
  }

  function startEngine() {
    if (root.engineCommand !== "" || root.bin === "") return
    root.engineCommand = root.envPrefix + root.quote(root.bin)
    engineSource.connectSource(root.engineCommand)
    settle.restart()
  }

  Timer {
    id: settle
    interval: 1500
    repeat: true
    property int tries: 0
    onTriggered: {
      tries++
      root.ask("status")
      if (root.state !== "off" || tries > 20) {
        stop()
        tries = 0
        if (root.pendingToggle && root.state !== "off") root.ask("toggle")
        root.pendingToggle = false
      }
    }
  }

  function noEngine() {
    root.state = "off"
    if (root.engineCommand === "" && !retry.running) retry.restart()
  }

  Timer { id: retry; interval: 10000; onTriggered: root.startEngine() }

  // ---------------------------------------------------------------- the login service

  property string serviceState: ""
  function serviceCommand(what) {
    if (root.bin === "") return
    root.run(root.envPrefix + "/usr/bin/timeout 60 " + root.quote(root.bin) + " service " + what, function (code, out, err) {
      root.serviceState = (out || err).trim().split("\n").slice(-3).join("\n").slice(0, 400)
      if (what !== "status") root.serviceCommand("status")
    })
  }
  // Installing the login service while this widget runs its own engine would start a second one, which refuses
  // the socket the first owns: ours stops first, and the service's is adopted.
  function installLoginService() {
    if (root.engineCommand !== "") { engineSource.disconnectSource(root.engineCommand); root.engineCommand = "" }
    root.serviceCommand("install")
  }

  onExpandedChanged: function () {
    if (!root.expanded) return
    if (Date.now() - root.activatedAt < 500) { Qt.callLater(function () { root.expanded = false }); return }
    root.ask("status")
    root.serviceCommand("status")
  }

  // ---------------------------------------------------------------- the key

  // The widget's keyboard shortcut (its settings, Keyboard Shortcuts) starts and ends a session.
  // Plasma always opens a widget on its shortcut (activationTogglesExpanded only stops it closing again), so a
  // popup opened by the shortcut is folded straight back.
  activationTogglesExpanded: false
  property double activatedAt: 0
  Connections {
    target: Plasmoid
    function onActivated() {
      root.activatedAt = Date.now()
      root.toggle()
      Qt.callLater(function () { root.expanded = false })
    }
  }
  readonly property string shortcut: String(Plasmoid.globalShortcut || "")

  // ---------------------------------------------------------------- how it looks

  Plasmoid.icon: "audio-input-microphone"
  Plasmoid.status: root.active ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.ActiveStatus
  toolTipMainText: "Mynah"
  toolTipSubText: root.bin === "" ? "Not installed" : root.state === "listening" ? "Listening"
                : root.state === "transcribing" ? "Writing it down" : root.state === "off" ? "Not running" : "Ready"
                + (root.shortcut ? " · " + root.shortcut + " to dictate" : " · give it a shortcut in its settings")

  compactRepresentation: MouseArea {
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: function (mouse) {
      if (mouse.button === Qt.MiddleButton) root.toggle()
      else root.expanded = !root.expanded
    }
    BirdMark {
      anchors.centerIn: parent
      width: Math.min(parent.width, parent.height)
      height: width
      color: root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
      opacity: root.state === "off" ? 0.55 : 1
      pose: root.state === "transcribing" ? "saying" : root.state === "listening" ? "listening" : "rest"
      waves: root.active
    }
  }

  fullRepresentation: FullView { mynah: root }

  Loader {
    active: root.active && Plasmoid.configuration.showPill !== false
    sourceComponent: Pill { mynah: root }
  }
}
