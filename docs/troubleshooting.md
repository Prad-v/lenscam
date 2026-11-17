# Troubleshooting

## Voice shutter does nothing

Speech recognition is off, the on-device speech model is missing, or a video is recording. The voice shutter only accepts cheese, shoot, capture, and smile, and it waits two seconds between shots.

## Palm gesture does nothing

It runs on the front camera, and only while Camera Assistant has Palm on. The hand has to stay open in the frame for a short moment.

## A filter file was refused

The file has to be JSON with a title, or with saturation, contrast, temperature, and grain. Values outside -1 to 1 are pulled back into that range. Grain stays between 0 and 1.

## The shutter does nothing

The camera permission is off, or this device has no camera. Import a still, or allow the camera in Settings.

## Translation stays in the original language

The language pack is not installed. Open the capture and tap Translate. iOS asks to download the pair. You can change the target language from the library, using the speech-bubble menu.

## The brief says nothing readable

Vision did not find text, and the transcript was empty. Lenscam will not ask the model to invent a description of the picture. Move closer, fill the frame with the page, or record the interview again with the microphone enabled.

## Apple Intelligence is off

Capture, zoom, reading, and translation keep working. Briefs wait until Apple Intelligence is turned on and the model is ready. The camera screen says which of those is missing.

## Evidence has no location

Location permission was declined, or a fix was not available at the shutter press. The master and the hash are still saved.

## The interview has no transcript

The speech model may still be downloading the first time, or the recording had no audio track. The video master remains. The capture note explains the failure.

## Simulator

The iOS Simulator often has no camera, and its SDK does not include the Visual Intelligence framework. Import a still to exercise Read, Brief, Clarity, and Evidence. Siri shortcuts still open the app in Read or Evidence.

## Building

The project expects the iOS 26 SDK.

```bash
make sim
make device
```

`make sim` uses the iPhone 17 simulator. Pass `SIMULATOR='iPhone 17 Pro'` to pick another one. `make device` uses the first connected iPhone, or `DEVICE_ID` when more than one is plugged in. The phone build turns code signing on and uses the development team already set on the Lenscam target. Unlock the phone and trust this Mac if installation stops. A locked phone still receives the install; unlock it and open Lenscam, or run `make device` again to launch.
