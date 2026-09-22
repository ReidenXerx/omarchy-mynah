<div align="center">

# Mynah for Omarchy

**Say it. It types where you are.**

Press <kbd>SUPER</kbd>+<kbd>ALT</kbd>+<kbd>D</kbd> and talk. Each time you pause, that sentence is
transcribed on your own machine and typed into whatever window has focus — a commit message, a
chat, a form. The bird in the bar shows what it is doing; a pill shows your voice while it listens.

[![Omarchy plugin](https://img.shields.io/badge/omarchy-plugin-F5B301)](https://plugins.omarchy.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-F5B301)](LICENSE)

`omarchy plugin add https://github.com/ReidenXerx/omarchy-mynah.git --enable`

**[duduphudu.app/mynah](https://duduphudu.app/mynah/)** — what dictation itself does, and what it refuses to do

</div>

---

## What this plugin is

The dictation engine is [Mynah](https://github.com/ReidenXerx/mynah), a CLI. This plugin is the half
of it that belongs to the desktop:

- **The key.** No Wayland client may grab a global hotkey — that is the point of Wayland — so the
  compositor binds it. The plugin registers <kbd>SUPER</kbd>+<kbd>ALT</kbd>+<kbd>D</kbd> at runtime
  through `hl.bind`, and registers it again after a config reload, which drops runtime binds.
- **The bird in the bar.** Dim when nothing is running, the bar's own colour when it is ready, the
  accent while it listens, with your level moving beside it. Left click starts or ends a session;
  right click is the menu.
- **The pill.** While a session is open, a small pill sits above the bottom of the screen with a
  live level and the last sentence that landed. It takes no keyboard focus and no clicks: you are
  typing into another window, and nothing here may take that away.
- **Keeping it running.** If nothing else is running the engine, the plugin runs it for the life of
  the shell. If the systemd service already owns it, the plugin adopts that one instead of starting
  a second engine to fight over the microphone.

## What you need

```bash
MYNAH=f7722fc0b41a9428155bf4d8de8acd9f658534c6   # the engine commit this plugin was reviewed against
LOCKS=https://raw.githubusercontent.com/ReidenXerx/mynah/$MYNAH/requirements

# A throwaway builder whose only build backend is the hash-verified one.
python3 -m venv /tmp/mynah-build
/tmp/mynah-build/bin/pip install --require-hashes --only-binary :all: -r $LOCKS/build.lock

# Build the engine with that backend and nothing else, then install the wheel,
# which runs no build backend at all.
/tmp/mynah-build/bin/pip wheel --no-build-isolation --no-deps -w /tmp/mynah-wheel \
    "git+https://github.com/ReidenXerx/mynah.git@$MYNAH"
pipx install --pip-args="--no-deps" /tmp/mynah-wheel/mynah-0.1.0-py3-none-any.whl

# What the engine imports: pinned versions, every artifact checked against its hash.
pipx runpip mynah install --require-hashes --only-binary :all: -r $LOCKS/build.lock
pipx runpip mynah install --require-hashes --only-binary :all: \
    --no-binary webrtcvad-wheels --no-build-isolation -r $LOCKS/linux.lock

rm -rf /tmp/mynah-build /tmp/mynah-wheel
sudo pacman -S whisper-cpp wtype wl-clipboard   # speech, typing, and pasting
mynah setup                                     # checks each and names what is missing
```

**Why a commit and not a branch.** The plugin runs the engine, so installing it
from a moving branch would mean the code this listing was reviewed against could
be replaced afterwards by a later push. The pin is bumped deliberately, with the
plugin, and re-reviewed. The name `mynah` on PyPI belongs to an unrelated
package, which is why the extra is requested from this repository rather than by
name.

**Why the locks.** The engine commit fixes the code Mynah runs; the locks fix
everything it imports. Installed with `--require-hashes`, pip refuses any
artifact not named in them, so a package released after this listing was
reviewed cannot reach a program that listens to a microphone and types into the
focused window. One package is built from source rather than installed as a
wheel -- `webrtcvad-wheels` publishes none for CPython 3.14, which is what Arch
ships -- and its source archive is hash-checked exactly like every wheel, built
against a pinned `setuptools`, with pip's build isolation off so no unchecked
build backend can take its place.

**Why the engine is built rather than installed straight from git.** `pipx
install git+...` builds the source distribution, and pip's build isolation
fetches a build backend for that build from PyPI without checking it against
anything; `--no-deps` does not turn isolation off. The two build commands above
move that build somewhere the backend is already pinned and verified, and what
pipx then installs is a wheel, which needs no backend at all. The engine is
still the exact commit named above, and nothing else.

`mynah setup` also downloads the speech model, or tells you the one command that does. That command
names a pinned revision of the model repository and checks what arrives against its published
SHA-256, deleting it if it does not match: the file is handed to `whisper-cli`, which parses it as a
native binary format, so it is not taken on trust from a moving URL.

Nothing is uploaded, there is no account and no API key: the model runs on your machine, and the
only thing that leaves mynah is the text it types into the window you were already in.

## Using it

| | |
|---|---|
| <kbd>SUPER</kbd>+<kbd>ALT</kbd>+<kbd>D</kbd> | start dictating, and press again to stop |
| Click the bird | the same thing |
| Right click the bird | dictate now, start it at login, check what is missing, stop the service |
| `mynah config` | what it is set to, and where |
| `mynah set language=uk` | change one setting |

The hotkey setting inside `mynah config` is a macOS thing and says so: here the compositor owns the
key. To use a different one, unbind ours in Hyprland and bind your own to `mynah toggle`.

## Removing it

```bash
omarchy plugin remove reidenxerx.mynah
```

That takes the bar widget and the pill with it, and the key binding goes when the shell
reloads — the plugin registers it at runtime and never writes to your Hyprland config. What it
does not remove is the engine, because that is a separate tool you installed yourself:

```bash
mynah service uninstall     # if you asked for it to start at login
pipx uninstall mynah
rm -rf ~/.config/mynah ~/.local/share/mynah   # settings and the speech model
```

## Settings worth knowing

| Setting | What it does |
|---|---|
| `language` | the language you speak |
| `model` | `base` is about three times faster than `small`; `small` hears you better |
| `vad` | off means the whole session is transcribed at the end, instead of at each pause |
| `frame_energy` | your floor for what counts as speech — lower hears more of the room |
| `auto_stop_silence` | seconds of silence that end a session by themselves |

## Latency, honestly

Whisper encodes a 30-second window whatever you said, so the cost is per utterance rather than per
second of speech. On a 22-core Meteor Lake laptop, CPU only: **`small` takes about 4.2 s** an
utterance and gets the sentence right; **`base` takes about 1.5 s** and makes mistakes on hard
words. Utterances pipeline — the next one is captured while the last is transcribed — but if you
talk faster than your machine transcribes, text arrives further and further behind. Pick the model
for the machine, and check with `mynah set model=base`.

## Privacy

- Speech is transcribed by whisper.cpp on your own hardware. There is no endpoint.
- The utterance is written as a WAV into `$XDG_RUNTIME_DIR/mynah` — tmpfs, mode 0700, wiped at
  logout — and unlinked as soon as whisper exits. It never reaches a disk.
- The control socket lives in that same directory at mode 0600, and the engine refuses to serve a
  directory it does not own: anything that can write there could make the machine dictate, and
  anything that can read it would hear every word typed.
- The pill shows the last sentence for four seconds and then forgets it. The plugin keeps no
  history.

## Support

If Mynah saves you typing, you can put something toward the next one:
**[donatello.to/DuduPhudu](https://donatello.to/DuduPhudu)**.

## Licence

MIT. The bird is Mynah's mark.
