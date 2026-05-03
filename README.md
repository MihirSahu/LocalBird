# LocalBird

LocalBird is a native macOS utility that captures screen context locally, runs Vision OCR, stores activity evidence in SQLite, and generates daily routine packets that can be summarized with `opencode run`.

## Build

```sh
xcodebuild -project LocalBird.xcodeproj -scheme LocalBird -configuration Debug -destination 'platform=macOS' build
```

## Test

```sh
xcodebuild -project LocalBird.xcodeproj -scheme LocalBird -configuration Debug -destination 'platform=macOS' test
```

The first MVP slice includes:

- SwiftUI macOS app and menu bar controls.
- ScreenCaptureKit screenshot capture for the main display.
- Vision OCR and average-hash duplicate detection.
- SQLite storage for captures, activity blocks, routine runs, and settings.
- Daily routine packet generation under Application Support.
- `opencode run` integration behind a swappable `RoutineSummarizer` protocol.

Screenshots, OCR, packets, summaries, and logs are stored under the app's Application Support directory. When a routine is generated with opencode, selected packet contents may be sent to the model provider configured in opencode.
