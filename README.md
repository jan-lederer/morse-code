# dit. — Learn Morse code

A Flutter app for Android and web. Explore the full Morse tree, tap for a dot,
hold for a dash, and pause to write a letter. Includes five learning chapters,
practice with progress tracking, an alphabet reference, light/dark themes,
optional sound and vibration, and adjustable input timing.

On phones and tablets, the full tree and touch key share a fixed viewport.
Every branch stays visible in portrait and landscape, and the path previews a
dot immediately and switches to a dash while holding. Numbers fit in the same
view when enabled. Practice also fits a single viewport, with the target, hint,
touch key, feedback, and stats visible together. Correct answers advance to a
different letter after 650ms of success feedback; incorrect answers stay for a
retry. Navigation, group changes, dialogs, and backgrounding handle the pending
advance safely. The eye button’s hint preference is saved on the device and
kept across automatic advancement, skips, chapter changes, navigation, and app
restarts until you toggle it again.

Settings and practice progress are stored locally. Android runs offline.
Vibration requires compatible hardware; browser vibration support varies.

## Build and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web --release --no-web-resources-cdn
```

The Android package is `studio.dit.dit_morse`. Version/build number comes from
`pubspec.yaml`. Release builds currently use the generated Android debug signing
key, so retain that key for updates. Configure a private release key before a
store release. An update requires the same package and signing key and a higher
build number than the installed app.

The Android device bridge provides local preferences, a 620 Hz tone, and optional
one-shot vibration. Web uses Web Audio and browser-local storage. No account or
backend is required. No deployment target is saved for this project.

## App icon

The coral dot/dash icon matches the in-app brand. Android includes legacy PNGs,
adaptive icons, and Android 13 themed icons. Web includes standard and maskable
icons plus a favicon. The foreground stays within Android’s 66dp safe circle.

Regenerate assets with `python3 tools/generate_icons.py`, or verify only icon
assets and resource references with `python3 tools/generate_icons.py --check`.
The editable vector source is `assets/branding/app-icon.svg`.
