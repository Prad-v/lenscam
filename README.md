# Lenscam

Lenscam is an iPhone camera for work. Each shutter press keeps an unmodified master and writes the reading beside it: text, translation, transcript, captions, and a brief. Apple Intelligence runs on the device after the file is safe. Evidence mode stores a hash and does not write a model brief.

## Open the app

Requirements: Xcode 26.5 or newer, iOS 26, an iPhone that can run the camera. The simulator can import a still when it has no camera.

```bash
make sim
make device
swift test
```

`make sim` builds Lenscam and launches it on the iPhone 17 simulator. `make device` builds it and installs it on the connected iPhone. The phone needs to be unlocked and trusted. The first launch asks for the camera, microphone, and, in Evidence, location.

## What a capture contains

| Layer | File | What it is |
| --- | --- | --- |
| Master | `master.heic`, `master.dng`, or `interview.mov` | The camera original. Lenscam does not write generated pixels into it. |
| Reading | `sidecar.json`, `captions.srt` | Text, barcodes, transcript, translation, and the SHA-256 of the master. |
| Brief | field inside `sidecar.json` | A note from the on-device model, grounded in the reading. Evidence omits it. |

Captures live in the app's local storage, under `Lenscam/Captures`. Nothing is uploaded.

## Genres

Swipe the finder dial until Photography, Portrait, Landscape, Nature, Food, Wildlife, Sport, or Cinematic sits in the center. You can also tap a name. Choosing one sets the lens, focus, and exposure. The moon turns on night mode for whichever genre is selected. Tap the picture to focus, then drag the sun beside the box to set exposure. A live reading can offer one more change; it is applied only if you accept it. After the master is hashed, a genre may write a labeled copy. Hold the shutter for a burst in any still genre. The sharpest frame is the master. The dial icon locks ISO, shutter, focus, and white balance, and stores presets. Filters and an optional enhance copy are saved beside the master, which stays the camera file. Sport takes that four-frame burst on a tap. Cinematic records an ungraded take.

## Profiles

Read, Brief, and Evidence stay in the more menu. The pipeline profiles are Master, Clarity, Zoom, Read, Interview, Brief, and Evidence. The behavior of each profile is in [docs/capture-profiles.md](docs/capture-profiles.md). The user guide is [docs/user-guide.md](docs/user-guide.md) and the same guide is the static page in [site/index.html](site/index.html).

## Tests

Policy, zoom, hash, sidecar, and caption tests live in `tests/` and run with:

```bash
swift test
```

They do not need a device. GitHub Actions runs them on every push and pull request.

The camera itself is an on-device iOS app. It is not a service, so there is no Docker Compose stack and no Helm chart. AVFoundation, Vision, Speech, Translation, and the Foundation Models framework are Apple frameworks and do not run in a Linux container.

## Further reading

- [Architecture](docs/architecture.md)
- [Privacy](docs/privacy.md)
- [Troubleshooting](docs/troubleshooting.md)
