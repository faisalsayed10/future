<p align="center">
  <img src=".github/app-icon.png" width="128" height="128" style="border-radius: 24px;" alt="Future app icon" />
</p>

<h1 align="center">Future</h1>

<p align="center">Send links to your future self.</p>

<p align="center">
  <img src=".github/share-sheet.png" width="250" />
  <img src=".github/time-picker.png" width="250" />
  <img src=".github/inbox.png" width="250" />
</p>

## About

Future is a lightweight iOS app that lives in your share sheet. Save a link from any app, pick when you want to see it again, and forget about it. Future will notify you when it's time.

## Features

- **Share extension** — send links from Safari, Reddit, Twitter, or any app
- **Natural language time picker** — type "tomorrow", "3 days", "aug 7" or pick from presets
- **On-device AI fallback** — uses FoundationModels to parse ambiguous time inputs
- **Scheduled notifications** — get notified exactly when your link is ready
- **Auto-labeling** — on-device LLM categorizes your links automatically
- **URL thumbnails** — fetches og:image previews via `LPMetadataProvider`
- **"Never" mode** — save links without a delivery date as bookmarks
- **Snooze** — reschedule delivered links from the notification itself

## Requirements

- iOS 26.0+
- Xcode 26+

## Architecture

```
Future/                     Main app target
FutureShareExtension/       Share extension target
Packages/FutureShared/      Shared Swift package (models, storage, notifications)
```

Both targets share data through an App Group container via `UserDefaults` and file-based thumbnail storage.

## License

MIT
