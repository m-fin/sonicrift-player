# Install on iPhone

The native app installs from Xcode onto a paired iPhone. TestFlight comes later, after the Apple Developer enrollment is active. Do not commit certificates, `.p8` keys, `.p12` files, or provisioning profiles.

## Identifiers

| | |
| --- | --- |
| App name | Matthew Finley Music Player |
| Bundle ID | `com.matthewfinley.musicplayer` |
| Widget bundle ID | `com.matthewfinley.musicplayer.widgets` |
| App group | `group.com.matthewfinley.musicplayer` |
| URL scheme | `mfmusic` |
| Deployment target | iOS 17.0 |

Signing uses Automatic, with the team selected on the Mac. This repo does not store a team id.

## Direct install

```bash
brew install xcodegen
xcodegen generate
open MatthewFinleyMusicPlayer.xcodeproj
```

Select the team, choose the iPhone 15 Pro as the destination, and press Run. The command-line equivalent is in the README.

## When a store build is possible

1. Finish Apple Developer enrollment and accept the agreement.
2. In App Store Connect, create an iOS app named Matthew Finley Music Player with bundle id `com.matthewfinley.musicplayer`.
3. Archive the Xcode scheme MatthewFinleyMusicPlayer and upload it with the Organizer.

The phone build does not need an account, analytics, or a microphone permission. Playback continues in the background because the audio background mode is on.
