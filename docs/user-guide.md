# User guide

Lenscam keeps the photograph or video you actually captured, then reads it on the iPhone. A translation, transcript, or brief is saved next to that file. It is not written into the master.

## Shoot

1. Open Lenscam. The bolt cycles flash through off, auto, and on. The moon is night mode, in every genre. Auto lets the shutter stay open when the scene is dark, up to 3 seconds. Off and a chosen time are in that panel. The dial is manual ISO, shutter, white balance, and focus, plus saved presets. The aperture icon is Camera Assistant. The rotating arrows switch between the back and front cameras. Tap the picture to focus. A box appears, with a sun beside it. Drag the sun up to brighten or down to darken. Above the shutter, swipe the genre dial until the one you want sits on the gold mark: Photography, Portrait, Landscape, Nature, Food, Wildlife, Sport, or Cinematic. Tap a name to bring it to the center.
2. The pill at the top is the zoom meter. It says Optical, Sensor crop, Digital, Past sharp crop, or Not measured. Not measured means the camera session is not running yet.
3. A coach line appears only when the frame is not ready for that genre. A clean frame stays quiet.
4. Tap the sliders icon for filters (None, Vivid, Warm, Cool, Fade, Drama, Grain, Mono), the strength of that filter, and Exposure through Grain and Mono. Import filter reads a JSON file with `title`, `saturation`, `contrast`, `temperature`, and `grain`. Enhance copy, when it is on, writes `enhance.jpg` beside the master. It does not change the master, and it does not invent detail. Evidence never writes that copy. The dial icon opens manual ISO, shutter, focus, and white balance (Day, Cloud, Shade, Tungsten, Fluor, or a kelvin slider), ProRAW when the phone supports it, saved presets, and the histogram, zebra, and focus peaking guides. The aperture icon is Camera Assistant. Scene, on by default, can offer Portrait, Wildlife, or Landscape when the frame matches. In Portrait, the same sliders panel also holds the lighting and the f-stop.
5. Tap the shutter for one photo. Hold it to take a burst in any still genre. The count shows on the shutter, and it stops when you let go, at 12 frames, or at 4 frames while night mode is holding a long shutter. The sharpest frame is the master. The others are labeled burst frames. Sport still takes a four-frame burst on a tap. Cine records; press again to stop. A burst master is HEIC. A single Photography tap can still be ProRAW.
6. Open the library for the master, the hash, and any labeled copy.

The more menu holds Read, Brief, and Evidence. Those leave the genre dial until you tap the chip or swipe a genre back to the center.

## Camera Assistant

Open it from the aperture icon.

- **Quick tap.** A tap on the picture takes the photo after it focuses.
- **Palm.** On the front camera, an open hand held in the frame fires the shutter.
- **Voice.** Listens on the device for cheese, shoot, capture, or smile. It pauses while a video is recording.
- **Float.** A second shutter you can drag.
- **Lens.** Auto follows the genre. Hold leaves the current lens. Nearest snaps a pinch to an optical stop.
- **Focus.** Nearer, Standard, or Farther. Manual focus in the dial still wins.

A filter file looks like this:

```json
{"title":"Plate","saturation":0.3,"contrast":0.2,"temperature":0.4,"grain":0.35}
```

Saturation, contrast, and temperature run from -1 to 1. Grain runs from 0 to 1. A list of those objects imports together. The master file is still the camera original. The look is the finder and the labeled copy.

The simulator often has no camera. Use Import to bring in a still. Cine does not import a still.

## Genres

The master is the file the camera wrote. A genre copy is a second file, named for the genre, and the sidecar says so.

- **Photography.** Largest still. ProRAW when the phone supports it. No copy.
- **Portrait.** Depth blur in the finder, with Natural, Studio, Contour, Stage, Mono, and High-Key light, plus an f-stop. The master keeps the original pixels and the depth map. `portrait.jpg` is the blurred copy. Skin is not sharpened.
- **Landscape.** Widest lens, with a level line in the finder. The copy can straighten a measured horizon.
- **Nature.** Close, wide lens. A little edge contrast on the copy. Detail is not invented.
- **Food.** Wide lens, a slightly brighter plate, and the Warm look in the finder when you have not already chosen one. `food.jpg` is a warmer copy. The master is not changed.
- **Wildlife.** Longest optical stop. Digital zoom is called out. Fur and feathers are not reconstructed.
- **Sport.** A tap takes a four-frame burst. The sharpest frame is the master. The others are labeled burst frames. Holding the shutter bursts here too, the same as the other still genres.
- **Cinematic.** Records at 24 frames per second when the lens allows it, with cinematic stabilization. The video master stays ungraded. A letterboxed still is a separate file.

## Choose a translation language

Open the library and tap the speech bubble. Pick the language Lenscam should translate into. The language pack has to be on the iPhone. If it is missing, open the capture and tap Translate. iOS will offer the download. The original text stays in the sidecar.

## Tools

Read, Brief, and Evidence stay off the dial. Open them from the more menu, or ask Siri.

- **Master.** Largest still the camera will give. On a phone that supports Apple ProRAW, the hashed master is the raw file and a preview sits beside it.
- **Clarity.** Saves the master, then a sharpened JPEG named `clarity.jpg`. The master is unchanged.
- **Zoom.** Shows whether the current factor is the lens, a high-resolution crop, digital zoom, or past the sharp crop. It does not invent detail.
- **Read.** Extracts text and barcodes, then translates when the language is installed.
- **Interview.** Records video and the original audio. After you stop, Lenscam transcribes on device, writes `captions.srt`, and drafts a brief from the transcript.
- **Brief.** Reads the frame and asks the on-device model for a title, summary, and next steps. The model sees the text, not a generated description of things that were not read.
- **Evidence.** Hashes the master, can attach a location mark, and reads text. It does not write a brief or a sharpened copy. Share the evidence report from the capture.

## After the shot

- **Copy hash** copies the SHA-256 of the master.
- **Translate** downloads a language if needed and stores the translation in the sidecar.
- **Write brief from the text** runs only outside Evidence.
- **Save master to Photos** copies the master. The hashed file stays in Lenscam.
- **Share sidecar** and **Share master** hand the files to another app.

## Siri

You can say "Start an evidence shoot in Lenscam" or "Read text with Lenscam". Those shortcuts open the matching profile.

On an iPhone where Visual Intelligence is available to apps, pointing the system camera at something can offer "Read in Lenscam". The simulator SDK does not include that framework, so the handoff is compiled only where the framework is present.
