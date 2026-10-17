# dit. — Learn Morse code

A Flutter app for Android and web. Explore the full Morse tree, tap for a dot,
hold for a dash, and pause to write a letter. Includes five learning chapters,
practice with progress tracking, an alphabet reference, light/dark themes,
optional sound and vibration, and adjustable input timing.
Quick taps play at least 100ms of tone so dots remain audible. Rapid signals
queue with 100ms of silence between them; dashes play for at least 300ms.
Two fast taps remain two distinct dots, even with no pause between taps.
Input and letter recognition stay immediate. Cancelling input or leaving the
app stops audio and clears pending signals.
Listen/recognition playback prepares a complete device-scheduled sound and
vibration pattern with 150ms of silent startup time. Its 100ms gaps are encoded
in the audio buffer, so cold audio startup or delayed UI frames cannot join dots.

Learn and Practice also offer **Recognize signals**: identify a character from
visible dots/dashes and a flashing light, sound, vibration, or a combination.
Type a letter/number or choose from four distinct answers. Replay or skip a
signal and retry mistakes. Correct answers advance automatically after 650ms.
Practice has two icon toggles: Listening and Sending. Each mode can use typed
answers or four choices. Sending choices ask you to identify the Morse code for
each target letter. Listening and Sending share Settings, the eye button, group
selection, and stats. Practice groups include all letters, numbers, short
lessons, 100 real words, and 100 short sentences; word and sentence prompts are
answered character by character when sending and as complete phrases when
listening.
Typed answers keep the keyboard open across questions until you dismiss it.
Four choices fill the available width in a large 2×2 grid.
Lesson shortcuts use that chapter's characters; short chapters fill their four
answer choices with other letters or numbers. Answers count toward saved
practice progress. Playback stops when leaving the exercise or backgrounding.

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
Settings displays the installed app version and build number (also on web).

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

Playback scheduler checks: `node tests/web_pattern_test.mjs`. In this workspace,
`python3 tools/verify_signal_pattern.py` uses the cached Kotlin compiler to test
the actual Android PCM/haptic generator and export an A/I waveform preview.

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
