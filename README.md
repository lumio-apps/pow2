# Pow2

A simple, addictive swipe-and-merge number puzzle. Slide the tiles, merge equal numbers and keep growing. Fully offline.

Part of [Lumio Apps](https://github.com/lumio-apps).

## Features

- Swipe anywhere on the screen to move the tiles
- Smooth slide, merge and spawn animations
- Four themes: Midnight, Daylight, Ocean and Candy
- Sound and vibration on merges (both can be turned off in Settings)
- Stats: best score, biggest tile, games played and total moves
- Short congratulation messages when you reach big tiles
- Undo up to 3 moves
- Board sizes 3x3, 4x4, 5x5 and 6x6
- Modes: Classic, Timed (3 minutes) and Zen (no game over)
- Daily challenge: one 4x4 board per day, same for everyone, with a streak
- 17 achievements, saved on the device
- Share your score as a picture
- Update the app from inside the app (Check for updates, from GitHub Releases)
- Best score and the running game are saved on the device
- Endless: play as long as you can make a move

## Privacy

Pow2 has no ads, no analytics and no accounts. It uses the internet only when you tap **Check for updates**: it asks GitHub for the newest release and, if you agree, downloads the APK from GitHub Releases. Nothing about you or your phone is sent. The best score and the current game are stored only on your device.

## Build

```sh
flutter pub get
flutter run
```

Run the checks with `flutter analyze` and `flutter test`.

## Release

Push a version tag (for example `v1.0.0`). GitHub Actions builds the APK, signs it with the key stored in the repository secrets and attaches it to the GitHub release.

Required secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

## License

MIT, see [LICENSE](LICENSE).
