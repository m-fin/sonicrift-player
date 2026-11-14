# sonicrift

Native iPhone player for [sonicrift](https://soundcloud.com/sonicrift), Frog Finley’s music project. The name is always styled **sonicrift**.

Private repository. No API keys, certificates, or account secrets belong here.

## What it plays

Tracks come from pluggable sources in `src/sources`:

1. **SoundCloud public feed.** The app calls the official oEmbed endpoint for `https://soundcloud.com/sonicrift`, reads the user id from the official widget URL, and requests `https://feeds.soundcloud.com/users/soundcloud:users:{id}/sounds.rss`. Playback uses the feed’s public stream URL inside `expo-audio`, with lock screen controls.
2. **Official widget.** The artist page embeds `w.soundcloud.com/player`. On the web, where the feed response is not readable from a browser, public tracks open in that same widget.
3. **JSON manifest.** A sample file lives at `src/sources/sample-manifest.json`. Every entry is marked `placeholder: true` and titled `PLACEHOLDER`. The audio files are short original tones synthesized for this app. They are not sonicrift releases. Set `EXPO_PUBLIC_TRACK_MANIFEST_URL` to an HTTPS JSON file Frog controls (`schema`: `sonicrift.tracks/v1`) to add real files they host.

Third-party audio is not queued. A title credited to another artist, or a description that says the recording is someone else’s, is skipped. That includes uploads whose notes say “no copyright infringement intended.”

If the live feed cannot be fetched, the app shows a public metadata snapshot captured 2026-11-14 (`src/sources/soundcloud-snapshot.json`). The snapshot does not contain audio files.

## Scripts

```bash
npm test
npx tsc --noEmit
npx expo export
```

`npm start` runs the Expo dev server. iPhone playback, background audio, and the lock screen need a dev client or a TestFlight build because those are native audio-session features. See `TESTFLIGHT.md`. Apple Developer enrollment (Individual) is pending.

## Stack

Expo SDK 58, TypeScript, expo-router, expo-audio. Bundle id `app.sonicrift.player`. Production EAS profile is `production` in `eas.json`.
