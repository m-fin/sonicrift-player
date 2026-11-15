# sonicrift

Player for [sonicrift](https://soundcloud.com/sonicrift), Matthew Finley’s music project. He also goes by Frog. The name is always written **sonicrift**, in lowercase.

Version 1 runs in a browser and in Expo Go. An iPhone build for TestFlight comes later, after the Apple Developer enrollment is active. See [TESTFLIGHT.md](TESTFLIGHT.md).

## Run it

You need Node.js 22.

```bash
npm install
npm start
```

- **Web.** In the Expo terminal, press `w`, or run `npm run web`. Open the localhost URL it prints.
- **Expo Go.** Install Expo Go for the same SDK (58) on a phone, then scan the QR code from `npm start`. The phone and the computer have to be on the same network.

```bash
npm test
npm run typecheck
```

No API keys, certificates, or account secrets belong in this repo.

## What you can do

- Home lists the public catalog, the newest drop from the last three weeks, and two offline placeholder tones.
- Tap a track. It opens now playing, with play, pause, seek, previous, next, shuffle, and repeat. A mini player stays on the other tabs.
- On the web, space toggles play and pause. The left and right arrow keys seek by five seconds.
- Queue shows what plays next. Remove a track if you do not want to hear it.
- Artist is a short bio, links, and the official SoundCloud embed.
- Share sends the title and the SoundCloud link. In a browser without the share sheet, it copies the link instead.

## Where the audio comes from

Tracks come from pluggable sources in `src/sources`.

1. **SoundCloud public feed** (Expo Go and other native builds). The app calls the official oEmbed endpoint for `https://soundcloud.com/sonicrift`, reads the user id from the official widget URL, and requests `https://feeds.soundcloud.com/users/soundcloud:users:{id}/sounds.rss`. Playback uses that feed’s public stream URL inside `expo-audio`, with lock screen controls. There is no SoundCloud client id and no OAuth token.
2. **Public snapshot.** Browsers cannot read that RSS feed, because SoundCloud does not send an open CORS header. When the live feed fails, the app uses metadata captured on 2026-11-14 in `src/sources/soundcloud-snapshot.json`, including the public stream URLs, and plays those. The snapshot file itself contains no audio.
3. **Official widget.** The artist page embeds `w.soundcloud.com/player`. If a stream does not start, now playing can open that same player for the track.
4. **JSON manifest.** `src/sources/sample-manifest.json` is a sample. Every entry is marked `placeholder: true` and titled `PLACEHOLDER`. The files in `assets/audio` are short original tones synthesized for this app. They are not sonicrift releases. Set `EXPO_PUBLIC_TRACK_MANIFEST_URL` to an HTTPS JSON file with `"schema": "sonicrift.tracks/v1"` to add files you host.

Third-party audio is not queued. A title credited to another artist, or a description that says the recording belongs to someone else, is skipped. That includes uploads whose notes say “no copyright infringement intended.”

## Stack

Expo SDK 58, TypeScript, expo-router, and expo-audio. Bundle id `app.sonicrift.player`. The production EAS profile is `production` in `eas.json`. iOS background audio is configured for the later native build. Web and Expo Go do not need a dev client.

## License

The player source code is [MIT](LICENSE), copyright 2026 Matthew Finley.

The sonicrift music tracks are not covered by that license. Recordings published as sonicrift, including those on SoundCloud, remain **all rights reserved**, copyright 2026 Matthew Finley. The MIT license does not grant any right to copy, perform, distribute, or adapt those recordings.

The tones in `assets/audio` are original synthesized placeholders so the player runs offline. They are not sonicrift releases.
