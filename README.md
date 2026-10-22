# 🍊 Tangerine

A native macOS file converter for MacBook. Drop files in, pick a format, get new files out. Runs fully offline; your files never leave your Mac.

> **Status:** planning. The app is not built yet. Sections below describe the intended behavior; see [IMPLEMENT.md](IMPLEMENT.md) for progress by phase.

## Requirements
- macOS 14 (Sonoma) or later, Apple Silicon recommended
- To build from source: Xcode 16+ and Command Line Tools

## Supported formats (planned)

| Family | Formats | Phase |
|---|---|---|
| Image | PNG, JPEG, HEIC, TIFF, GIF, BMP (read-only: WebP). Animated GIF / multi-page TIFF keep the first frame | 1, 3 |
| PDF | image → PDF; PDF → PNG/JPEG (multi-page → a folder); merge PDFs/images; split into pages | 3 |
| Word | DOCX → PDF / TXT / HTML; TXT / HTML → DOCX; PDF → DOCX (text only: layout, images and tables are not kept; scanned PDFs have no text and are rejected) | 4 |
| Audio *(post-MVP)* | MP3, WAV, M4A, FLAC | 7 |
| Video *(post-MVP)* | MP4, MOV, MKV | 7 |

## How to use
1. Open Tangerine. It lives in the menu bar.
2. Drag a file in Finder and hold **Shift**: a radial menu appears at the cursor showing the formats that file can become. Drop it on one. The converted file lands next to the original and a notification tells you when it's done. In the menu-bar menu you can switch the trigger to *always* or to the global shortcut **⌃⌥T** (press it while dragging), and turn on launch at login.
3. Or use the main window: drop files or folders, choose the target format and quality.
4. Pick an output folder (default: next to the original).
5. Watch progress in the queue. Cancel any job at any time.
6. When a job finishes, click **Show in Finder** to see the result.

Your original files are never modified or deleted. If a file with the same name exists, Tangerine adds ` (1)`, ` (2)`, … instead of overwriting.

## How it works
```
Drop files → detect type (UTType) → pick target format
  → enqueue → matching Converter → write new file → notify / reveal in Finder
```

- **Registry** picks a `Converter` based on the input type and chosen output.
- **Converters** are one per file family (image, PDF, Word). The MVP families use Apple frameworks (ImageIO, PDFKit, AppKit), so nothing extra to install. Audio/video (post-MVP) will use a bundled `ffmpeg`.
- **Safe writes:** output goes to a temp file first, then is moved into place, so a cancel or crash never leaves a half-written file.
- **Queue** runs jobs concurrently with cancellation and per-job progress.

## Project layout
```
Tangerine/
  App/      # entry, scene, menu
  UI/       # SwiftUI views
  Engine/   # Converter protocol + implementations
  (tests live in TangerineTests/)
scripts/    # helper scripts (zsh)
docs/       # plans, decision log
```

## Build from source (once Phase 0 is done)
```sh
open Tangerine.xcodeproj          # then press ⌘R
xcodebuild test -scheme Tangerine -destination 'platform=macOS'
```

## Development workflow
Work is split into phases (0–6) with a verification gate after each. Specialized agents in `.claude/agents/` handle each area. See [CLAUDE.md](CLAUDE.md) for rules and [IMPLEMENT.md](IMPLEMENT.md) for the checklist.

## Distribution
Personal use for now. Plan: free and open source on GitHub; fork it and build it yourself in Xcode.

## License
MIT — see [LICENSE](LICENSE).
