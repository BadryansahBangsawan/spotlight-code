# Spotlight Code

Index local source folders and search them from the menu bar, with optional Spotlight donations.

Menu extra for macOS 14+. It lives in the menu bar and does not show a Dock icon.

## Features

- Add one or more roots; **Index now** builds `index.json`.
- Search by filename and content; open the hit in your editor.
- Hard cap of 5000 files (`Index capped at 5000 files` is success, not a crash).
- Skips `node_modules`, `.git`, `.build`, `DerivedData`, `dist`, `.next`, `Pods`.
- Exclude globs (defaults `*.generated.swift`, `*.min.js`).
- Core Spotlight: after indexing, Cmd-Space can find filenames.
- App Intent `SearchCodeIntent` for system search.

## Requirements

- macOS 14 Sonoma or later
- Swift 5.9 or later

## Install

```bash
git clone https://github.com/BadryansahBangsawan/spotlight-code.git
cd spotlight-code
bash package-app.sh
open dist/SpotlightCode.app
```

`package-app.sh` builds a release binary, wraps `dist/SpotlightCode.app`, and ad-hoc codesigns it (`codesign -s -`). Unsigned is fine for local use.

Enable **Open at Login** from Settings if you want it after reboot.

## Usage

- Add a folder of source, then **Index now**.
- Type in Search. Click a hit to open it.
- If Core Spotlight fails, the panel shows that error and still keeps `index.json`.

## Permissions

- Folder access via the open panel. Spotlight donation uses Core Spotlight on this Mac.

Denied permissions must not crash the app. You should see a banner and a button to open System Settings.

## Privacy

No source is uploaded. Index lives in `~/Library/Application Support/Spotlight Code/index.json`.

Bundle ID: `engineer.badry.spotlightcode`.

## Development

```bash
swift build
swift build -c release --product SpotlightCode
```

Layout: `Sources/` (SwiftPM executable), `Info.plist`, `Assets/AppIcon.icns`, `package-app.sh`.

## License

[MIT](LICENSE)
