# TestFlight

Apple Developer Program enrollment for this project is an **Individual** account and it is **pending**. Nothing in this repo can be uploaded to TestFlight until that enrollment is active. Do not commit certificates, `.p8` keys, `.p12` files, provisioning profiles, or Expo tokens.

## Identifiers

| | |
| --- | --- |
| App name | sonicrift |
| Bundle ID | `app.sonicrift.player` |
| URL scheme | `sonicrift` |
| EAS slug | `sonicrift` |
| Production profile | `production` in `eas.json` (`distribution: store`, iOS, `autoIncrement`) |

`eas.json` does not contain an Apple Team ID or an App Store Connect app id. Add those in the EAS project or a local untracked override after the developer account exists. Do not commit them if you treat them as private, and never commit signing material.

## When the Individual account is approved

1. Accept the Apple Developer agreement and finish enrollment.
2. In [App Store Connect](https://appstoreconnect.apple.com), create an iOS app named sonicrift with bundle id `app.sonicrift.player`.
3. On a trusted machine, `npx eas-cli@latest login`. Link the Expo project with `npx eas-cli@latest init` if it is not linked yet.
4. `npx eas-cli@latest credentials --platform ios` and let EAS create the distribution certificate and provisioning profile.
5. `npx eas-cli@latest build --platform ios --profile production`
6. `npx eas-cli@latest submit --platform ios --profile production`
7. Add internal testers in TestFlight.

The production build is a store build. It installs through TestFlight, not as a sideload.

## What Frog still needs to provide

- Approval of the Apple Developer Individual account.
- The Apple Team ID, once the account exists.
- The App Store Connect app Apple ID (`ascAppId`), after the app record exists.
- The Expo account that should own the EAS project.
- Optional: an HTTPS URL for a real track manifest (`EXPO_PUBLIC_TRACK_MANIFEST_URL`). Until then, the app uses the bundled sample manifest plus the public SoundCloud feed.
- A decision on which public SoundCloud uploads stay in the RSS feed. The player drops third-party audio (titles credited to another artist, or descriptions that say the audio belongs to someone else).
- A privacy policy URL if App Store Connect asks for one. The app has no account, no analytics, and no microphone permission.

## Privacy

The app reads SoundCloud’s public oEmbed endpoint and the public RSS feed for sonicrift. It does not use a SoundCloud client id, OAuth token, or undocumented API. Placeholder audio in the repo is original synthesized tones, not a copy of a release.
