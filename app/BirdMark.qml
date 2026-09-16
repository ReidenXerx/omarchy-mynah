import QtQuick
import QtQuick.Shapes

// Mynah's mark: the bird in profile, beak open mid-word.
//
// One path with an odd-even fill, so the eye is a hole rather than a second
// colour. That is what lets the same drawing work as a bar glyph, a HUD mark
// and a favicon: it is a silhouette, and it takes the colour it is given.
Item {
  id: mark

  property color color: "white"
  // The bird sits in a 256x256 box; everything below scales from that, so a
  // caller only ever sets width and height.
  readonly property real unit: 256

  implicitWidth: 22
  implicitHeight: 22

  // The Shape is drawn at its native 256 units and scaled into place: a
  // ShapePath has no path-level scale (PathScale belongs to QtQuick's Path,
  // not to Shapes), so the transform is the item's.
  Shape {
    width: mark.unit
    height: mark.unit
    preferredRendererType: Shape.CurveRenderer
    transform: Scale {
      xScale: mark.width / mark.unit
      yScale: mark.height / mark.unit
    }

    ShapePath {
      fillColor: mark.color
      strokeWidth: 0
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill

      PathSvg {
        path: "M92.0 41.0 C86.0 29.0 88.0 18.0 97.0 11.0 C98.0 22.0 103.0 30.0 112.0 35.0 Z "
            + "M104.0 40.0 C148.0 40.0 182.0 72.0 182.0 114.0 C182.0 122.0 181.0 130.0 178.0 137.0 "
            + "L200.0 141.0 C206.0 142.0 208.0 149.0 203.0 153.0 L173.0 178.0 "
            + "C161.0 188.0 145.0 194.0 128.0 194.0 C82.0 194.0 46.0 159.0 46.0 114.0 "
            + "C46.0 69.0 58.0 40.0 104.0 40.0 Z "
            + "M174.0 96.0 L236.0 102.0 C240.0 102.0 242.0 107.0 239.0 110.0 L225.0 122.0 "
            + "C223.0 124.0 220.0 124.0 218.0 123.0 L174.0 108.0 Z "
            + "M176.0 122.0 L228.0 130.0 C232.0 131.0 232.0 136.0 228.0 137.0 L198.0 145.0 "
            + "C196.0 146.0 194.0 145.0 193.0 143.0 L176.0 128.0 Z "
            + "M130 88 a11 11 0 1 0 22 0 a11 11 0 1 0 -22 0 z"
      }
    }
  }
}
