import QtQuick
import QtQuick.Shapes

// Mynah's mark: a round-headed bird with a stubby yellow bill, too much eye and
// a crest that will not lie flat.
//
// One path with an odd-even fill, so the eye is a hole rather than a second
// colour — that is what lets the same drawing be a bar glyph, a pill mark and a
// favicon. It takes the colour it is given.
//
// Three poses, because everything that draws it knows the state: at rest, head
// cocked the way a bird listens, and bill open while it types. With `waves` it
// also makes a sound — two arcs off the bill, which is the difference between
// "there is a bird here" and "the bird is doing something".
//
// The item's SIZE NEVER CHANGES when the waves appear: the drawing box widens
// instead, so the bird gives up a little room rather than the widget growing
// into its neighbours. A bar icon is loaded into a fixed 16px canvas and
// nothing clips it, so anything that overflows is drawn over the icon beside it.
//
// The paths are generated from the same source as the SVG assets and the page
// (scratchpad/mynah_mark.py); do not hand-edit them.
Item {
  id: mark

  property color color: "white"
  // "rest" | "listening" | "saying"
  property string pose: "rest"
  // Whether the bird is making a sound, and how loudly (0..1) — the level only
  // shapes the waves while listening; while typing they pulse on their own.
  property bool waves: false
  property real level: 0

  readonly property real boxY: -10
  readonly property real boxX: 38
  // 208 is the bird alone; the extra 60 is where the sound goes. Not readonly:
  // the Behavior below animates the binding's changes, so the bird eases aside
  // for the sound instead of jumping.
  property real boxSize: mark.waves ? 268 : 208
  readonly property real factor: mark.width / mark.boxSize

  Behavior on boxSize { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  implicitWidth: 22
  implicitHeight: 22

  readonly property string restPath: "M178 86 C176 58 156 36 126 34 C86 32 52 64 52 104 C52 136 70 162 98 172 C124 "
      + "182 152 176 168 158 C176 140 179 112 178 86 Z M104 40 C96 22 98 10 110 2 "
      + "C112 16 118 26 128 32 Z M132 30 C128 12 134 2 148 0 C146 14 148 24 154 34 Z "
      + "M88 50 C74 38 70 26 78 16 C84 28 92 36 102 40 Z M176 78 L224 92 C232 95 232 "
      + "105 224 108 L176 120 C172 106 172 92 176 78 Z M126 92 a24 24 0 1 0 48 0 a24 "
      + "24 0 1 0 -48 0 z "

  readonly property string sayingPath: "M178 86 C176 58 156 36 126 34 C86 32 52 64 52 104 C52 136 70 162 98 172 C124 "
      + "182 152 176 168 158 C176 140 179 112 178 86 Z M104 40 C96 22 98 10 110 2 "
      + "C112 16 118 26 128 32 Z M132 30 C128 12 134 2 148 0 C146 14 148 24 154 34 Z "
      + "M88 50 C74 38 70 26 78 16 C84 28 92 36 102 40 Z M176 78 L224 90 C232 93 232 "
      + "99 224 101 L178 100 Z M178 112 L220 116 C227 118 227 124 220 125 L178 126 Z "
      + "M126 92 a24 24 0 1 0 48 0 a24 24 0 1 0 -48 0 z "

  // How loud each arc is drawn. Listening follows your voice; typing pulses,
  // because then the sound is the bird's own.
  property real nearWave: 0
  property real farWave: 0

  readonly property real levelWave: Math.max(0.25, Math.min(1, mark.level * 2.2))

  states: [
    State {
      name: "listening"
      when: mark.waves && mark.pose === "listening"
      PropertyChanges { target: mark; nearWave: mark.levelWave; farWave: mark.levelWave * 0.6 }
    },
    State {
      name: "saying"
      when: mark.waves && mark.pose !== "listening"
      PropertyChanges { target: mark; nearWave: 1; farWave: 0.7 }
    }
  ]

  Behavior on nearWave { NumberAnimation { duration: 120 } }
  Behavior on farWave { NumberAnimation { duration: 160 } }

  // While it types, the two arcs travel outward rather than sitting still.
  SequentialAnimation {
    running: mark.waves && mark.pose !== "listening"
    loops: Animation.Infinite
    NumberAnimation { target: mark; property: "farWave"; to: 0.15; duration: 480; easing.type: Easing.InOutSine }
    NumberAnimation { target: mark; property: "farWave"; to: 0.85; duration: 480; easing.type: Easing.InOutSine }
  }

  Shape {
    width: mark.boxSize
    height: 208
    // Put the drawing's own origin at this item's top left, then scale.
    x: -mark.boxX * mark.factor
    y: -mark.boxY * mark.factor
    scale: mark.factor
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer

    // A bird cocks its head to listen. It is the same drawing, turned.
    rotation: mark.pose === "listening" ? -14 : 0
    Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

    ShapePath {
      fillColor: mark.color
      strokeWidth: 0
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill

      PathSvg { path: mark.pose === "saying" ? mark.sayingPath : mark.restPath }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(mark.color.r, mark.color.g, mark.color.b, mark.nearWave)
      strokeWidth: 20
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M246 84 C254 94 254 110 246 120" }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.rgba(mark.color.r, mark.color.g, mark.color.b, mark.farWave)
      strokeWidth: 20
      capStyle: ShapePath.RoundCap
      PathSvg { path: "M268 72 C280 88 280 116 268 132" }
    }
  }
}
