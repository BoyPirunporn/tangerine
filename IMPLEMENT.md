# IMPLEMENT.md — Tangerine Phased Plan

Scope: **MVP (P0–P6) = images, PDF, Word (.docx)**. **Post-MVP (P7) = audio/video** (MP3, MP4, etc.). Personal use first; later free open source on GitHub (users fork/build themselves).

## Overall flow
```
P0 Setup → P1 Core Engine → P2 UI → P3 Image/PDF → P3.5 Spike → P3.6 Radial UI
        → P4 Word → P5 Polish & Test → P6 MVP Release → P7 Audio/Video (post-MVP)
        (every arrow = user verifies the gate first)
```

## App runtime flow
```
App runs in the menu bar. User drags a file (Shift held by default) → radial menu appears at
the cursor with only the formats that file can become → drop on a wedge → matching Converter
→ write new file → notification / reveal in Finder. The main window shows queue + settings.
```

---

## Phase 0 — Setup  (agent: `architect`)
- [x] Verify Xcode + `swift --version`
- [x] Create Xcode project "Tangerine" (SwiftUI, macOS 14+)
- [x] Create folders per CLAUDE.md, `git init`, `.gitignore`
- **Gate:** Run shows an empty window

## Phase 1 — Core Engine  (agents: `architect`, `converter-engine`)
- [x] `protocol Converter` (`supportedInputs`, `outputs`, `convert(...)`)
- [x] `ConversionJob`, `ConversionError`, progress + cancel
- [x] Registry that picks a Converter by UTType
- [x] Sample converter: PNG ↔ JPEG (ImageIO)
- **Gate:** unit tests pass; PNG→JPEG works from code

## Phase 2 — UI  (agent: `ui-swiftui`)
- [x] Drop zone (files/folders)
- [x] Queue list with progress + cancel
- [x] Format/quality picker, output folder
- [x] Tangerine orange theme, Dark mode
- **Gate:** drop file → convert → result visible in Finder

## Phase 3 — Image & PDF  (agent: `converter-engine`)
- [x] HEIC, WebP, TIFF, GIF, BMP ↔ PNG/JPEG (WebP is read-only: ImageIO can't write it)
- [x] Images → PDF, PDF → images (PDFKit)
- [x] Merge/split PDF pages (toolbar "PDF Tools" menu)
- **Gate:** all fixture types convert correctly

## Phase 3.5 — Spike: global drag detection  (agent: `ui-swiftui`)
Prove the risky part before building the radial UI.
- [x] Menu-bar agent app (`LSUIElement`, `MenuBarExtra`, Open / Quit)
- [x] Detect a file drag started in any app (global mouse monitors + drag pasteboard, no special permissions expected)
- [x] Floating non-activating panel appears at the cursor and accepts the drop
- [x] Panel shows file name, size, count and the formats valid for those files
- [x] Trigger mode switch: Shift held (default) / always
- **Gate:** drag a file from Finder, hold Shift → panel appears at cursor with correct info; drop shows a confirmation; releasing elsewhere hides it. Record what did NOT work (permissions, thumbnails, fullscreen apps).
- **Findings:** global mouse monitors + drag pasteboard work with no permissions. Name/size/type are readable mid-drag. SwiftUI `dropDestination` never fired in the floating panel; use an AppKit `NSView` drop target. The global mouse-up arrives before the panel's drop callback, so hide the panel ~0.5s late.

## Phase 3.6 — Radial UI  (agent: `ui-swiftui`)
- [x] Radial wedge menu with the valid formats for the dragged file type, orange→purple gradient style
- [ ] Drop on a wedge → enqueue job with that format; quality/output folder from settings
- [ ] Notification when done (click reveals in Finder); main window = queue + settings
- [ ] Settings: trigger (Shift / always / global shortcut), launch at login
- [x] Add AVIF as an output (ImageIO can write it); WebP output stays hidden
- **Gate:** the full flow works from Finder: drag → wedge → converted file next to the original

## Phase 4 — Word  (agent: `converter-engine`)
- [x] **DOCX → PDF** (priority; native AppKit `NSAttributedString` + PDF render; no bundled tools)
- [x] **PDF → DOCX** (priority; text extraction via PDFKit, written as DOCX; layout/images are lost, show this limit in UI)
- [x] Nice-to-have: DOCX → TXT/HTML, TXT/HTML → DOCX
- [ ] Fallback: bundle `pandoc` only if native output is unacceptable (not needed so far; only revisit if real Word files look bad)
- **Gate:** fixture DOCX converts; limits visible in UI

## Phase 5 — Polish & Test  (agent: `qa-tester`)
- [x] Batch, filename collisions, corrupt files, unwritable output folder (disk-full is in `docs/manual-test.md`: can't be simulated safely)
- [x] Shortcuts (⌃⌥T), localization TH/EN (`Tangerine/Localizable.xcstrings`)
- [x] Main window opens in front; stays hidden when launched at login (login case unverified)
- [~] "Dock drop" dropped: the app has no Dock icon (menu-bar agent). "Open With" from Finder not done
- [x] Performance: 300-page DOCX→PDF 0.65s (UI stalls ≤0.6s); 300-page PDF→DOCX 2.2s (UI stall cut from 2.2s to 0.3s)
- [ ] Manual pass of `docs/manual-test.md` (full screen, two displays, Safari/Mail, login launch, notifications)
- **Gate:** test suite green; manual checklist has no crashes

## Phase 6 — MVP Release (open source)  (agent: `release-packager`)
- [ ] App icon, bundle ID (App Sandbox is OFF by design: "next to original" output needs folder write access; revisit if ever sandboxing)
- [ ] README build steps so anyone can fork and run in Xcode
- [ ] LICENSE file
- [ ] Optional: ad-hoc signed `.zip` on GitHub Releases (users right-click → Open)
- [ ] Later, if distributing widely: Developer ID + notarize
- **Gate:** fresh clone builds and runs on a clean machine

## Phase 7 — Audio / Video (post-MVP)  (agent: `converter-engine`)
- [ ] Bundle `ffmpeg` (arm64) + `Process` wrapper (resolve from `Bundle.main`, not PATH)
- [ ] Video: MP4, MOV, MKV; audio: MP3, WAV, M4A, FLAC; video → audio extract
- [ ] Parse ffmpeg progress (`-progress pipe:1`); kill process on cancel
- [ ] Check ffmpeg license/size impact before bundling (GPL vs LGPL build) for the GitHub release
- **Gate:** one file per type converts; cancel leaves no partial file

---

## Decisions made
- Native Swift/SwiftUI, macOS only (not Electron)
- UX: menu-bar app; radial menu on file drag, formats chosen by file type. Trigger default = Shift held while dragging
- "Press and hold a file without dragging" dropped from MVP (needs Finder automation permission, unreliable)
- Distribution: future, free, GitHub, fork-friendly
- MVP file types: image, PDF, Word. Audio/video (ffmpeg) deferred to Phase 7, not dropped

## Open questions
1. License: MIT (permissive, my suggestion) or something else?
2. ~~Word directions~~ — decided: PDF → Word and Word → PDF.
