# Capture profiles

The finder dial is a genre. Swipe it, or tap a name, until that genre sits on the gold mark in the center. Read, Brief, Evidence, and the older profiles are still the pipeline behind a shot.

## Genres

| Genre | Lens | Master | Copy |
| --- | --- | --- | --- |
| Photography | Unchanged | HEIC, or ProRAW plus a preview | None |
| Portrait | 2× when that stop is inside the depth range | HEIC with the depth map | `portrait.jpg`. Depth blur, lighting, and the chosen f-stop. Skin is not sharpened |
| Landscape | Widest stop | HEIC | `landscape.jpg`. Straightens a measured horizon |
| Nature | Widest stop | HEIC | `nature.jpg`. Modest edge contrast |
| Food | Widest stop | HEIC | `food.jpg`. A warmer, slightly richer copy of the plate |
| Wildlife | Longest optical stop | HEIC | `subject.jpg`. No reconstructed fur or feathers |
| Sport | Stop nearest 2× | Sharpest frame of a four-frame burst on a tap. A held shutter uses the same rule, up to 12 frames | Other frames as burst files, plus `subject.jpg` |
| Cinematic | Unchanged | MOV, 24 fps when the format allows it, cinematic stabilization, original audio | `letterbox.jpg`. The video is not graded |

Choosing a genre sets the lens, continuous focus, and an exposure bias. Camera Assistant can hold the current lens, snap a pinch to the nearest optical stop, or bias focus nearer or farther. Food uses the wide lens and writes `food.jpg`. Holding the shutter bursts in every still profile, including Read, Brief, and Evidence. Cinematic and Interview record instead. The sharpest frame is the hashed master. The rest are `burst-N.heic` files. A burst does not write ProRAW. The dial in the finder locks ISO, shutter, focus, and white balance when you leave Auto. Presets named Daylight, Indoor, Action, Vivid, and Mono are built in, and a name you save is stored on the iPhone. Histogram, zebra stripes, and focus peaking run only while they are switched on. A scene card can suggest Portrait, Wildlife, or Landscape from the live reading. It does not describe the picture in words. Sport also caps the shutter at 1/500 when the lens allows it, and a tap in Sport takes four frames without holding. Night mode is separate from the genre. Auto, the default, lets that shutter stay open for 0.5 to 3 seconds when the preview is dark, and turns on low-light boost when the device supports it. A bright scene leaves Auto off. If the lens cannot hold half a second, night mode uses only the boost. While Cinematic is recording, the frame rate still limits the shutter. Sport does not offer its fast-shutter card while a night exposure is engaged. Tap-to-focus shows a box and a sun. Dragging the sun sets the exposure bias inside the device limits.

While the session is running, Vision reads brightness, faces, animals, and horizon from the preview. `SettingAdvisor` turns those readings into one settings change. Apply writes that change into the camera. The language model may restate the sentence; it does not choose the numbers and it does not see the pixels.

The on-device model writes a note from the measurements after the shot: genre, zoom band, horizon angle, and whether a person or animal was detected. An empty reading still does not become a guessed description.

Coach lines live in `GenreCoach` and are covered by `tests/GenreCoachTests.swift`.

## Profiles

| Profile | Master | After the file is saved |
| --- | --- | --- |
| Master | HEIC, or ProRAW plus a preview when the phone supports it | Nothing else |
| Clarity | HEIC | `clarity.jpg`, a sharpened copy |
| Zoom | HEIC | The zoom band recorded in the sidecar |
| Read | HEIC | Text, barcodes, translation |
| Interview | MOV with original audio | Transcript, `captions.srt`, translation, brief |
| Brief | HEIC | Text, then a brief grounded in that text |
| Evidence | HEIC or ProRAW | Hash, optional location, text. No brief and no sharpened copy |

Zoom bands:

- **Optical.** The factor is on a lens switch-over (within 3 percent).
- **Sensor crop.** Up to 2× past that lens, and only when the active format can deliver a high-resolution still (the longest edge is at least 7000 pixels).
- **Digital.** Past the sensor crop.
- **Past sharp crop.** The same region as digital, labeled this way in Zoom and Read so the photographer is told to move closer. The master is still the captured file.
- **Not measured.** An imported still, or the camera session has not started.

The rules live in `Sources/LenscamCore` and are covered by `tests/`.
