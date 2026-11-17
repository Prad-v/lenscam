# Privacy

Lenscam stores captures on the iPhone. The app does not contain a network client, an API key, or an upload of the master.

| Permission | When it is used |
| --- | --- |
| Camera | Shooting a master |
| Microphone | Interview audio, and the voice shutter when that switch is on |
| Speech recognition | On-device transcription after an interview. The voice shutter uses the on-device speech model and does not send the audio away |
| Location when in use | An optional mark on an Evidence sidecar |
| Add to Photos | Only after you tap Save master to Photos |

Palm-gesture selfies look at the camera frames already on the phone. They are not uploaded. The on-device foundation model writes briefs from text that Vision or SpeechAnalyzer already produced. Translation uses the system Translation framework. If a language pack is missing, the system download UI is the one that fetches it.

Evidence does not attach a brief. The PDF report repeats the hash, the zoom band, the location if there is one, and the text that was read. It states that the master was not modified.

Visual Intelligence, when the system offers Lenscam, receives the labels the system already produced and opens Read. Lenscam does not run its own upload from that handoff.
