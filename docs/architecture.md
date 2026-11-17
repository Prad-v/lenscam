# Architecture

Lenscam is an iPhone app. The capture policy is a Swift package so it can be tested on a Mac without a camera. The app links that package and adds AVFoundation, Vision, Translation, Speech, and the Foundation Models framework.

```
LenscamCore          genres, profiles, zoom meter, hash, sidecar, captions
ios/Lenscam          camera, library, reading, translation, transcription, briefs
tests                package tests, run with swift test
```

## Capture path

1. The session runs on a background queue. Choosing a genre sets lens, focus, and exposure there, unless Camera Assistant is set to hold the lens. Night mode, in every genre, raises the longest shutter the lens may use when the preview is dark. It is not Apple's private Night mode. Manual ISO and shutter replace that while they are locked. A tap focuses that point, and the sun beside the box sets exposure bias unless exposure is manual. Holding the shutter takes a burst and keeps the sharpest frame as the master. Histogram, zebra, and focus peaking run only while those guides are on. Palm and voice shutters are optional and stay on the device. A preview frame is measured a few times a second, and one settings card is offered. The shutter does not wait for a language model.
2. Bytes are written to `Application Support/Lenscam/Captures/<id>/`.
3. SHA-256 is computed from the file on disk and stored in `sidecar.json`.
4. Later saves of the sidecar are rejected if the master filename or hash would change.
5. OCR, translation, a labeled genre copy, transcription, and the brief run after that write. The copy is a new file. The master bytes stay as hashed.

Interview audio is transcribed after the recording stops. The take itself is not blocked by SpeechAnalyzer.

## What the model is allowed to see

On iOS 26.5, `Prompt` in the Foundation Models framework takes text. Lenscam does not send the pixel buffer to the model. Vision reads the still. SpeechAnalyzer reads the audio. The model writes a brief from that text only. If the text is empty, Lenscam records a guard note and does not ask the model to describe the picture.

Evidence skips the model entirely.

## Why there is no container or chart

The product runs on the iPhone. Camera, speech, translation, and the on-device model are system frameworks. They are not a backend service, so the repo has no `docker-compose.yml` and no Helm chart. Shipping is an Xcode archive to the App Store, with a development team set in the Lenscam target. The checked-in project signs with an ad-hoc identity so the simulator build does not need a team.

`swift test` is the automated check. It covers the zoom meter, night mode, the exposure dial, burst limits, manual exposure, filters, imported looks, Camera Assistant, presets, scene suggestions, the evidence lock, the hash, the sidecar round trip, and SRT captions.
