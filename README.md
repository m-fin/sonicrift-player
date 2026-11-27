# Matthew Finley Music Player

Native SwiftUI player for Matthew Finley’s music. It runs on iPhone, iOS 17 and later, and it plays with no network on the first launch.

The core catalog, queue, and generative audio math live in the `PlayerCore` Swift package, so `swift test` runs on Linux and macOS without UIKit. The iOS app, lock screen controls, and widgets are Xcode targets described by `project.yml`.

## Listen on an iPhone 15 Pro

On a Mac with Xcode 15 or newer:

```bash
brew install xcodegen
xcodegen generate
open MatthewFinleyMusicPlayer.xcodeproj
```

In Xcode, select the MatthewFinleyMusicPlayer target, open Signing & Capabilities, and choose your Apple team. The app group `group.com.matthewfinley.musicplayer` is already in the entitlements. Automatic signing creates it for the team the first time you build.

Plug in the iPhone 15 Pro, select it as the run destination, and press Run.

The same build from the command line, after the device is paired and a team is selected in the project:

```bash
xcodegen generate
xcodebuild \
  -project MatthewFinleyMusicPlayer.xcodeproj \
  -scheme MatthewFinleyMusicPlayer \
  -destination 'platform=iOS,name=iPhone 15 Pro' \
  -allowProvisioningUpdates \
  -configuration Debug \
  build
```

`xcodebuild` prints the `.app` path under DerivedData. Install that build with Xcode’s Run button, or with:

```bash
xcrun devicectl device install app --device <DEVICE_UDID> <path-to-MatthewFinleyMusicPlayer.app>
```

No certificates, keys, or provisioning profiles belong in this repo. Signing stays on the Mac.

## Tests

```bash
swift test --package-path PlayerCore
```

GitHub Actions runs that command on every pull request.

## What’s in the app

- **Library.** Latest drops, albums, favorites, downloads, and the full catalog. A download button stores a remote track under Application Support/OfflineAudio. The toolbar filter keeps only audio that is already on the phone.
- **Moods.** Focus, Late Night, Sleep, Ambient, Driving, and Electronic.
- **Generative.** A live synthesizer with Deep Focus, Warm Drift, Night Drive, Sleep Halo, and Microtonal Bloom. Density, warmth, tempo, drift, and New Seed change the piece. The bass stays mono and under 120 Hz. One audio session is active at a time, so catalog playback and generative playback do not run together.
- **Queue.** Up Next can be reordered and removed. Shuffle and repeat (off, one, all) sit on the Now Playing sheet.
- **Lock screen.** Playback uses `AVAudioSession` category `.playback`, with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`. Background audio keeps playing while the phone is locked.
- **Widgets.** Small and medium Home Screen widgets, plus Lock Screen accessories, read the shared app group and open `mfmusic://play/...` or `mfmusic://generative/...`.

The four tracks in `App/Audio` are original pieces synthesized by `Scripts/render_demo_audio.py`. They are not commercial releases. Re-render them with:

```bash
python3 Scripts/render_demo_audio.py
```

## Catalog

Tracks come from three places, in order:

1. The bundled demo manifest, so the player always has something to play.
2. An HTTPS JSON manifest. The default URL is `https://matthewfinley.org/music/manifest.json`. Change it in Library → link. The schema is `matthewfinley.tracks/v1`. The parser also accepts the previous player’s schema.
3. The public SoundCloud RSS feed for the artist’s catalog. Titles credited to someone else, and notes that say the recording belongs to someone else, are not queued. If the live feed fails, a small metadata snapshot shipped with the app is used. The snapshot does not contain audio.

A manifest entry looks like this:

```json
{
  "schema": "matthewfinley.tracks/v1",
  "tracks": [
    {
      "id": "amber-room",
      "title": "Amber Room",
      "artist": "Matthew Finley",
      "album": "Studio Demos",
      "placeholder": false,
      "moods": ["Focus", "Ambient"],
      "audioUrl": "https://example.com/amber-room.mp3",
      "releasedAt": "2026-11-01T00:00:00Z",
      "durationMs": 180000
    }
  ]
}
```

`placeholder` is required. `audioUrl` may be an `https` file or `bundled:<name>` for a wav in the app bundle.

## Layout

| Path | What it is |
| --- | --- |
| `PlayerCore/` | Swift package. Catalog, queue, moods, offline metadata, generative DSP. |
| `App/` | SwiftUI app, audio session, downloads, bundled audio. |
| `Widgets/` | WidgetKit extension. |
| `project.yml` | XcodeGen project. `xcodegen generate` writes `MatthewFinleyMusicPlayer.xcodeproj`. |

Bundle ids: `com.matthewfinley.musicplayer` and `com.matthewfinley.musicplayer.widgets`. Deployment target iOS 17.0.

## Legacy Expo client

`src/` is the earlier Expo player. It still runs with Node.js 22 (`npm install`, `npm start`, `npm test`). The native app is the one to install on iPhone.

## License

Player source code is [MIT](LICENSE), copyright 2026 Matthew Finley.

Matthew Finley’s recordings are not covered by that license. They remain all rights reserved, copyright 2026 Matthew Finley. The synthesized demos in `App/Audio` are original pieces made for offline playback, not commercial releases.
