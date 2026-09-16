import QtQuick
import qs.Commons

// Your voice, as twelve bands of it.
//
// The engine measures the frame's spectrum — a 480-sample FFT split across
// twelve log-spaced bands from 80 Hz to 5 kHz, which is where a voice lives —
// and sends it with the level. So this is the shape of what you are saying,
// not one amplitude drawn twelve times: vowels sit low and wide, an "s" lights
// up the right-hand end, and a quiet room is flat.
//
// Two details do most of the work:
//
//   Attack is instant, decay is not. A bar jumps to a new peak and then falls
//   exponentially, which is how every meter worth looking at behaves — the eye
//   needs the fall to read the rise.
//
//   The caps hang. Each band keeps a peak that descends slowly, so a syllable
//   leaves a mark for a moment after it is gone.
//
// Frames arrive about 30 times a second; the timer below runs at the same rate
// whether or not one arrived, so the meter decays smoothly into silence
// instead of freezing at the last thing it heard.
Item {
  id: spectrum

  // 0..1, low to high. Reassigned whole, never edited in place.
  property var bands: []
  // Used when the engine sends no bands at all: an older engine, or one whose
  // indicator does not ask for a spectrum.
  property real level: 0
  property bool running: true

  property color color: Color.accent
  property int count: 12
  property real barWidth: Style.space(3)
  property real gap: Style.space(2)
  property real minHeight: Style.space(3)
  property real maxHeight: Style.space(26)

  // How much of a bar survives each frame (0.86 ≈ a half-life of 140 ms) and
  // how far a cap falls in one.
  readonly property real decay: 0.86
  readonly property real capFall: 0.022

  property var values: []
  property var peaks: []

  implicitWidth: count * barWidth + (count - 1) * gap
  implicitHeight: maxHeight

  function shaped(index) {
    // With no spectrum, fall back to the level with a gentle curve across the
    // bands so the meter still moves rather than sitting flat.
    const middle = (spectrum.count - 1) / 2
    const weight = 1 - Math.abs(index - middle) / (middle + 1.4)
    return Math.min(1, spectrum.level * weight * 1.7)
  }

  function step() {
    const incoming = spectrum.bands
    const hasBands = incoming && incoming.length > 0
    const nextValues = []
    const nextPeaks = []
    for (let i = 0; i < spectrum.count; i++) {
      // Map our bar count onto however many bands arrived.
      const band = hasBands
        ? incoming[Math.min(incoming.length - 1, Math.floor(i * incoming.length / spectrum.count))]
        : spectrum.shaped(i)
      const previous = spectrum.values[i] || 0
      const value = Math.max(Number(band) || 0, previous * spectrum.decay)
      nextValues.push(value)
      nextPeaks.push(Math.max(value, (spectrum.peaks[i] || 0) - spectrum.capFall))
    }
    spectrum.values = nextValues
    spectrum.peaks = nextPeaks
  }

  Timer {
    interval: 33
    repeat: true
    running: spectrum.running && spectrum.visible
    onTriggered: spectrum.step()
  }

  // Leaving the meter behind at whatever it last heard would freeze a loud
  // syllable on screen for as long as the pill stays up.
  onRunningChanged: if (!running) { spectrum.values = []; spectrum.peaks = [] }

  Row {
    anchors.centerIn: parent
    spacing: spectrum.gap

    Repeater {
      model: spectrum.count

      delegate: Item {
        id: band
        required property int index
        readonly property real value: spectrum.values[band.index] || 0
        readonly property real peak: spectrum.peaks[band.index] || 0

        width: spectrum.barWidth
        height: spectrum.maxHeight

        Rectangle {
          id: bar
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          width: spectrum.barWidth
          radius: width / 2
          height: spectrum.minHeight + (spectrum.maxHeight - spectrum.minHeight) * band.value

          // Brighter at the top of the bar than at its waist, so a tall band
          // reads as louder and not merely longer.
          gradient: Gradient {
            GradientStop {
              position: 0
              color: Qt.rgba(spectrum.color.r, spectrum.color.g, spectrum.color.b, 1)
            }
            GradientStop {
              position: 0.5
              color: Qt.rgba(spectrum.color.r, spectrum.color.g, spectrum.color.b, 0.72)
            }
            GradientStop {
              position: 1
              color: Qt.rgba(spectrum.color.r, spectrum.color.g, spectrum.color.b, 1)
            }
          }

          Behavior on height {
            NumberAnimation { duration: 70; easing.type: Easing.OutQuad }
          }
        }

        // The cap: where this band last peaked, on its way down.
        Rectangle {
          width: spectrum.barWidth
          height: Math.max(1, Style.space(2))
          radius: height / 2
          color: spectrum.color
          opacity: band.peak > 0.04 ? 0.55 : 0
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height / 2
             - (spectrum.minHeight + (spectrum.maxHeight - spectrum.minHeight) * band.peak) / 2
             - height

          Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
          Behavior on opacity { NumberAnimation { duration: 160 } }
        }
      }
    }
  }
}
