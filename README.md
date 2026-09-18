<div align="center">

# Spotlight Code

**Spotlight-style fuzzy search over local source files.**  
macOS menu extra — lives in the menu bar, no Dock icon.

<br/>

[![Latest Release](https://img.shields.io/github/v/release/BadryansahBangsawan/spotlight-code?style=flat-square&color=76B900&label=latest)](https://github.com/BadryansahBangsawan/spotlight-code/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)](https://github.com/BadryansahBangsawan/spotlight-code/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)

<br/>

</div>

---

## Download

| Platform | File |
|---|---|
| **macOS** (Apple Silicon & Intel, macOS 14+) | `SpotlightCode-*-macos.zip` |

[Go to Releases](https://github.com/BadryansahBangsawan/spotlight-code/releases/latest)

---

## Installation

### Homebrew (recommended)

```bash
brew tap BadryansahBangsawan/mac-menu-apps
brew install --cask spotlight-code
```

A **Spotlight Code** icon appears in the menu bar. If Gatekeeper blocks it on first launch:

```bash
xattr -cr /Applications/SpotlightCode.app && open /Applications/SpotlightCode.app
```

Or: right-click the app, Open, then Open again. Still blocked? **System Settings → Privacy & Security → Open Anyway**.

### GitHub Releases

1. Download `SpotlightCode-*-macos.zip` from [Releases](https://github.com/BadryansahBangsawan/spotlight-code/releases/latest)
2. Unzip and drag **SpotlightCode** into Applications
3. On first launch, run the xattr command above if Gatekeeper blocks it

### Build from source

```bash
git clone https://github.com/BadryansahBangsawan/spotlight-code.git
cd spotlight-code
bash package-app.sh
open dist/SpotlightCode.app
```

Requires Xcode Command Line Tools and Swift 5.9+.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Control+Shift+F` | Open search panel |

---

## Notes

– Add folders to watch in Settings; FSEvents keeps the index live.
– Opens results in the default editor for each file type.
– No Dock icon; lives entirely in the menu bar.
– Large `node_modules` / `.git` trees can be excluded in Settings to keep the index lean on monorepos.

## Troubleshooting

**Search results stop updating after a system restart**
Spotlight Code registers FSEvents watchers at launch. If a watched folder lives on an external drive that mounts after the app starts, FSEvents won't track it until you re-add the folder in Settings or restart the app after the drive mounts.

**Results open in the wrong editor**
The app respects macOS default-app associations per file type. Change the default in Finder: right-click any file of that type → Get Info → Open With → Change All.

---

<div align="center">

Made with ♥ for developers who prefer staying in the flow.

</div>
