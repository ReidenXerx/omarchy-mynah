import QtQuick
import QtQuick.Shapes

// Mynah's mark: a round-headed bird with a stubby yellow bill, too much eye and
// a crest that will not lie flat.
//
// One path with an odd-even fill, so the eye is a hole rather than a second
// colour — that is what lets the same drawing be a bar glyph, a pill mark and a
// favicon. It takes the colour it is given.
//
// Three poses, because the plugin knows the state: at rest, head cocked the way
// a bird listens, and bill open while it types. The paths are generated from
// the same source as the SVG assets and the page; do not hand-edit them.
Item {
  id: mark

  property color color: "white"
  // "rest" | "listening" | "saying"
  property string pose: "rest"

  // The bird is drawn in the box the assets use; everything scales from it.
  readonly property real boxSize: 208
  readonly property real boxX: 38
  readonly property real boxY: -10
  readonly property real factor: mark.width / mark.boxSize

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

  Shape {
    width: mark.boxSize
    height: mark.boxSize
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
  }
}
