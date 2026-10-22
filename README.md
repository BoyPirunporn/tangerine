# 🍊 Tangerine

A small, native macOS file converter that lives in your menu bar. Start dragging a file, hold **Shift**, and a radial menu appears at your cursor showing only the formats that file can become. Drop it on one and the converted file lands next to the original.

Everything runs on your Mac. No uploads, no accounts, no network.

## What it converts

| Family | Formats |
|---|---|
| Image | PNG, JPEG, HEIC, AVIF, TIFF, GIF, BMP. WebP can be read but not written (macOS can't encode it). Animated GIFs and multi-page TIFFs keep their first frame |
| PDF | image → PDF; PDF → PNG/JPEG (a multi-page PDF becomes a folder of images); merge PDFs and images into one PDF; split a PDF into pages |
| Word | DOCX → PDF / TXT / HTML; TXT / HTML → DOCX; PDF → DOCX **text only** (layout, images and tables are not kept; scanned PDFs have no text and are rejected) |

Your original files are never modified or deleted. If the output name exists, ` (1)`, ` (2)`… is added instead of overwriting.

Audio and video (MP3, MP4…) are planned for a later version.

## Install

Requires **macOS 14 (Sonoma) or later**.

### Download
1. Get `Tangerine-<version>.zip` from the [Releases](https://github.com/BoyPirunporn/tangerine/releases) page, unzip it and drag **Tangerine** to Applications.
2. Tangerine is not notarized (that needs a paid Apple Developer account), so macOS blocks the first launch. To allow it:
   - **macOS 15 or later:** try to open it once, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   - **macOS 14:** right-click the app and choose **Open**.
   - Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Tangerine.app`

### Build it yourself
You need **Xcode 26 or later** (the code uses Swift 6.2 features). No Apple ID or paid account is needed.

```sh
git clone https://github.com/BoyPirunporn/tangerine.git
cd tangerine
open Tangerine.xcodeproj   # then press ⌘R
```

Build a zip like the one on the Releases page with `scripts/make-release.sh` (output in `build/`).
If you fork this, change the bundle identifier (`com.tangerine.converter`) to your own.

## Using it

Tangerine has no Dock icon: look for the 🔄 icon in the menu bar.

1. In Finder (or Safari, Mail…), start dragging a file and **hold Shift**.
2. A glass wheel appears at the cursor. Drop the file on a format. A notification tells you when it's done; click it to reveal the file.
3. Pick how the wheel is triggered from the menu-bar menu: *only while holding Shift* (default), *always when dragging a file*, or the global shortcut **⌃⌥T** pressed during a drag. You can also turn on **Launch at login** there.

The main window (menu bar → *Open Tangerine*) works too: drop files or folders, choose the format and quality, choose an output folder, watch the queue and cancel any job. **PDF Tools** merges and splits PDFs.

The interface is in English and Thai, following the system language.

### Permissions
- **Notifications:** to tell you when a batch is done.
- **Files:** Tangerine is not sandboxed so it can save next to the original. macOS asks the first time you convert something in Desktop, Documents or Downloads.
- **Launch at login** may need your approval in System Settings → General → Login Items.

## Development

```sh
xcodebuild test -project Tangerine.xcodeproj -scheme Tangerine -destination 'platform=macOS'
```

```
Tangerine/
  App/      app entry, menu bar, notifications, login item
  UI/       main window, queue, settings
  Drag/     system-wide drag watcher, floating panel, radial menu
  Engine/   Converter protocol, registry and the converters
TangerineTests/   unit tests (fixtures are generated in code)
scripts/          make-release.sh, make-icon.swift (draws the app icon)
docs/manual-test.md   what unit tests can't cover
```

Each file family is one `Converter` (inputs, outputs, `convert`); add a converter to `ConverterRegistry.standard` and the radial menu, window and notifications pick it up. See [CLAUDE.md](CLAUDE.md) for the conventions and [IMPLEMENT.md](IMPLEMENT.md) for the phased plan.

Issues and pull requests are welcome. Please keep `xcodebuild test` green.

## License

MIT, see [LICENSE](LICENSE).
