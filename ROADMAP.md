# Pow2 roadmap

What is planned next. Dates are not promised.

## v1.2.0 (done)

- Four themes: Midnight, Daylight, Ocean and Candy
- Sound and vibration on merges, both can be switched off
- Stats screen: best score, biggest tile, games played, total moves
- Settings screen

## v1.3.0 (done)

- Board sizes: 3x3, 5x5 and 6x6 next to the classic 4x4
- Game modes: Timed (3 minutes) and Zen (no game over)
- Up to 3 undo steps

## v1.4.0 (this release)

- Achievements, saved on the device
- Daily challenge with a board made from the date (no internet)
- Share your score as an image

## Later, not promised

- Hint for the next good move
- Backup and restore as copied text
- More languages

## Release checklist

1. Extract the zip into the project folder
2. `flutter gen-l10n` (only when texts changed)
3. `flutter analyze`
4. `flutter test`
5. Commit and push
6. Tag the new version, for example `v1.4.0`, and push the tag
