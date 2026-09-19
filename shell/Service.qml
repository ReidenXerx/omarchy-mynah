import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Mynah inside Omarchy's shell.
//
// The dictation engine is a separate process — the `mynah` CLI — and this holds
// the two ends of it that the desktop owns: the key that starts a session, and
// the picture of what it is doing.
//
// Why a socket and not a library: no Wayland client may grab a global hotkey,
// so the compositor binds SUPER+ALT+D to `mynah toggle`, and `mynah watch`
// prints one JSON object per line for as long as the engine runs. Everything
// here is those two facts.
Item {
  id: service

  property var shell: null
  property var manifest: null

  // What the engine last said it was doing. "off" is ours, not the engine's: it
  // means nothing is answering on the socket.
  property string state: "off"
  // Mic amplitude 0..1, ~30 a second while a session is open, and the frame's
  // twelve band energies behind it (low to high) when the engine measures them.
  property real level: 0
  property var bands: []
  // The last utterance that actually reached a window, and when.
  property string lastText: ""
  property double lastTextAt: 0
  // Set from the menu. While true nothing is started, including on failure.
  property bool stopped: false
  // The last line the engine wrote to stderr that looked like a complaint.
  property string problem: ""
  // Whether a mynah outside this shell (the systemd service) owns the engine.
  property bool adopted: false

  readonly property string hotkey: "SUPER + ALT + D"
  readonly property bool running: state !== "off"
  readonly property bool active: state === "listening" || state === "transcribing"

  // ---------------------------------------------------------------- the CLI
  //
  // Resolved to an absolute path once, against a fixed list, rather than left
  // to PATH: a plugin runs unsandboxed, and "run whatever `mynah` resolves to"
  // is a promise about a search path we do not control. Nothing runs until one
  // of these answers `--version`, and if none does, the widget says so instead.
  readonly property var binCandidates: [
    Quickshell.env("HOME") + "/.local/bin/mynah",   // where pipx puts it
    "/usr/local/bin/mynah",
    "/usr/bin/mynah"
  ]
  property string bin: ""
  property int binIndex: 0

  readonly property string hyprctl: "/usr/bin/hyprctl"

  function resolveBin() {
    if (service.binIndex >= service.binCandidates.length) {
      service.bin = ""
      if (service.problem === "")
        service.problem = "mynah is not installed — see this plugin's README for the pinned install command."
      return
    }
    probe.command = [service.binCandidates[service.binIndex], "--version"]
    probe.running = true
  }

  // A child process starts with whatever the shell was started with, and the
  // shell is long-lived, so LD_PRELOAD, PYTHONPATH and PYTHONHOME would all
  // reach the engine this plugin runs — and the engine is a pipx console
  // script, which is to say a virtualenv interpreter, exactly the thing those
  // variables redirect. Each process is handed an explicit environment instead.
  //
  // The list is what the engine actually uses: the runtime directory for its
  // socket and for audio, the display and bus variables for typing into the
  // window you were in, the Hyprland signature for hyprctl, and every MYNAH_*
  // override it documents — scrubbing those would silently undo somebody's
  // configuration. PATH keeps ~/.local/bin, which is where pipx puts mynah and
  // where the engine looks for whisper-cli.
  readonly property var childEnv: {
    const env = {
      "PATH": (Quickshell.env("HOME") || "") + "/.local/bin:/usr/local/bin:/usr/bin:/bin",
      "PYTHONIOENCODING": "utf-8",
    }
    const wanted = [
      "HOME", "LANG", "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME",
      "XDG_CACHE_HOME", "XDG_CURRENT_DESKTOP", "WAYLAND_DISPLAY", "DISPLAY",
      "DBUS_SESSION_BUS_ADDRESS", "PULSE_SERVER", "HYPRLAND_INSTANCE_SIGNATURE",
      "MYNAH_CONFIG_DIR", "MYNAH_LEGACY_CONFIG", "MYNAH_MODEL_DIR", "MYNAH_SERVICE",
      "MYNAH_SOCKET", "MYNAH_WHISPER_CLI", "MYNAH_WTYPE",
    ]
    for (const name of wanted) {
      const value = Quickshell.env(name)
      if (value) env[name] = value
    }
    return env
  }

  Process {
    id: probe
    clearEnvironment: true
    environment: service.childEnv
    onExited: function (code) {
      if (code === 0) {
        service.bin = service.binCandidates[service.binIndex]
        service.problem = ""
        service.bindKey()
        adoptCheck.running = true
        return
      }
      service.binIndex += 1
      service.resolveBin()
    }
  }

  // ---------------------------------------------------------------- commands

  function toggle() { command("toggle") }
  function start() { command("start") }
  function stopSession() { command("stop") }

  function command(verb) {
    if (service.bin === "") return
    if (verb !== "toggle" && verb !== "start" && verb !== "stop" && verb !== "quit") return
    control.command = [service.bin, verb]
    control.running = true
    controlDeadline.restart()
  }

  // A command that never returns must not leave a process behind.
  Timer {
    id: controlDeadline
    interval: 10000
    onTriggered: if (control.running) control.signal(15)
  }

  // Stop dictating entirely: the engine exits and nothing restarts it until the
  // user asks. `quit` goes through the socket so a systemd-owned engine obeys
  // it too, rather than being killed under systemd's feet.
  function shutDown() {
    service.stopped = true
    command("quit")
  }

  function startUp() {
    service.stopped = false
    service.problem = ""
    if (service.bin === "") {
      service.binIndex = 0
      service.resolveBin()
      return
    }
    adoptCheck.running = true
  }

  // Hand the engine over to systemd.
  //
  // Installing the login service while the shell is running its own engine
  // would start a second one, and the second refuses to bind a socket the
  // first owns — so systemd would retry it three times and then report the
  // service as failed, for what is really "it is already running". Ours stops
  // first; the watcher then adopts the one systemd starts.
  function installLoginService() {
    engine.running = false
    service.handOver.running = true
  }

  property alias handOver: handOverProcess

  Process {
    id: handOverProcess
    clearEnvironment: true
    environment: service.childEnv
    command: service.bin === "" ? [] : [service.bin, "service", "install"]
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function (line) { service.noteStderr(line) }
    }
    onExited: function (code) {
      // Whether it worked or not, find out who owns the engine now.
      service.adopted = false
      adoptCheck.running = true
    }
  }

  Process { id: control; clearEnvironment: true; environment: service.childEnv }

  // ---------------------------------------------------------------- the engine

  // Is one already running? The systemd --user service is the normal way to run
  // mynah, and two engines would fight over the microphone and the socket.
  Process {
    id: adoptCheck
    clearEnvironment: true
    environment: service.childEnv
    command: service.bin === "" ? [] : [service.bin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const answered = String(text || "").trim().length > 0
        service.adopted = answered
        if (answered && service.state === "off") service.state = "idle"
      }
    }
    onExited: function (code) {
      if (code !== 0) service.adopted = false
      if (service.stopped || service.bin === "") return
      // Nobody else is running one, so we do. Asking again every time rather
      // than trusting the last answer matters: a systemd-owned engine can be
      // stopped while the shell keeps running, and a stale "adopted" would
      // leave the plugin waiting forever for an engine nobody will start.
      if (!service.adopted && !engine.running) engine.running = true
      watcher.running = true
    }
  }

  // Ours only when nobody else's. It ends with the shell, which is the right
  // lifetime for something that types into the session's windows.
  Process {
    id: engine
    clearEnvironment: true
    environment: service.childEnv
    command: service.bin === "" ? [] : [service.bin]
    running: false
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function (line) { service.noteStderr(line) }
    }
    onExited: function (code) {
      service.state = "off"
      service.level = 0
      service.bands = []
      if (!service.stopped) retry.restart()
    }
  }

  // `mynah watch` subscribes to the socket and prints events until the engine
  // goes away. When it cannot connect there is no engine, so start one.
  Process {
    id: watcher
    clearEnvironment: true
    environment: service.childEnv
    command: service.bin === "" ? [] : [service.bin, "watch"]
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function (line) { service.handle(line) }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function (line) { service.noteStderr(line) }
    }
    onExited: function (code) {
      service.state = "off"
      service.level = 0
      service.bands = []
      if (service.stopped) return
      service.noteAttemptFailed()
      retry.restart()
    }
  }

  // Whatever failed, try again later rather than spinning. A machine with no
  // mynah installed would otherwise start a process every few seconds forever,
  // so the wait doubles up to a minute and resets the moment something works.
  property int retryDelay: 4000

  Timer {
    id: retry
    interval: service.retryDelay
    onTriggered: {
      if (service.stopped || service.bin === "") return
      service.retryDelay = Math.min(service.retryDelay * 2, 60000)
      // Ask who owns the engine first; adoptCheck starts the watcher, and
      // ours, when there is nobody to adopt.
      if (!adoptCheck.running) adoptCheck.running = true
    }
  }

  // Three immediate failures in a row means the CLI is not there to run — a
  // Process that cannot be spawned reports nothing on stderr to explain itself.
  property int quickFailures: 0
  property double lastAttemptAt: 0

  function noteAttemptFailed() {
    const now = Date.now()
    const quick = service.lastAttemptAt > 0 && now - service.lastAttemptAt < 1500
    service.lastAttemptAt = now
    service.quickFailures = quick ? service.quickFailures + 1 : 1
    if (service.quickFailures >= 3 && service.problem === "")
      service.problem = "mynah did not start — see this plugin's README for the pinned install command."
  }

  function handle(raw) {
    const line = String(raw || "").trim()
    if (line.length === 0 || line.length > 8192) return
    let event
    try { event = JSON.parse(line) } catch (e) { return }
    if (!event || typeof event !== "object") return

    // Anything arriving at all means the engine is there; forget the backoff.
    // `problem` is NOT cleared here: a complaint on stderr mid-session would be
    // wiped by the next level event 30 ms later. It clears on connect, below.
    service.retryDelay = 4000
    service.quickFailures = 0

    if (event.event === "state") {
      const next = String(event.state || "")
      if (next === "idle" || next === "listening" || next === "transcribing") service.state = next
      if (next === "idle") { service.level = 0; service.bands = [] }
      return
    }
    if (event.event === "level") {
      const value = Number(event.level)
      if (isFinite(value)) service.level = Math.max(0, Math.min(1, value))
      // Reassigned whole rather than edited, so bindings see the change.
      service.bands = Array.isArray(event.bands) ? event.bands : []
      return
    }
    if (event.event === "text") {
      // What the engine typed is shown back for a few seconds. It is the user's
      // own words going into their own screen — but it is still worth keeping
      // short-lived, so the HUD clears it rather than leaving it on the desktop.
      service.lastText = String(event.text || "").slice(0, 400)
      service.lastTextAt = Date.now()
      return
    }
    // The reply to `subscribe`: a fresh connection, so whatever was wrong
    // before is over, and it carries the state we are joining at.
    if (event.ok === true && typeof event.state === "string") {
      service.problem = ""
      service.state = event.state
    }
  }

  function noteStderr(raw) {
    const line = String(raw || "").trim()
    if (line.length === 0) return
    // Only keep what a person could act on: install this, grant that.
    if (/not installed|no running mynah|not a Wayland|No whisper model|error|refused/i.test(line))
      service.problem = line.slice(0, 300)
  }

  // ---------------------------------------------------------------- the key

  // A plugin cannot edit anyone's hyprland.conf, so the binding is made at
  // runtime. Runtime binds do not survive a config reload, hence the watch on
  // `configreloaded` below.
  readonly property string bindLua:
    'hl.bind("' + hotkey + '", hl.dsp.exec_cmd("' + service.bin + ' toggle"), { description = "Mynah: dictate" })'
  readonly property string unbindLua: 'hl.unbind("' + hotkey + '")'

  Process { id: binder; clearEnvironment: true; environment: service.childEnv }

  function bindKey() {
    if (service.bin === "") return
    binder.command = [service.hyprctl, "eval", service.bindLua]
    binder.running = true
  }

  function unbindKey() {
    // hl.unbind removes every binding on the combo, so this only runs for the
    // one we added — never on someone else's key.
    binder.command = [service.hyprctl, "eval", service.unbindLua]
    binder.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") rebind.restart()
    }
  }

  // A reload can arrive in a burst (Omarchy's theme switch reloads twice);
  // rebinding once after it settles is enough.
  Timer {
    id: rebind
    interval: 500
    onTriggered: service.bindKey()
  }

  // ---------------------------------------------------------------- the HUD
  //
  // A layer-shell window is not something to keep parsed while idle, and a
  // PanelWindow cannot be loaded in an offscreen probe at all, so it lives in
  // its own file behind a Loader that only exists while dictation is on.
  Loader {
    id: hud
    active: service.active
    source: Qt.resolvedUrl("Hud.qml")
    onLoaded: if (item) item.service = service
  }

  Component.onCompleted: service.resolveBin()

  Component.onDestruction: unbindKey()
}
