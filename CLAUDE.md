# CLAUDE.md — Tangerine (macOS File Converter)

Native macOS file converter for MacBook (Apple Silicon first). Fully offline.

## Rules
- Work one phase at a time per `IMPLEMENT.md`. Never start the next phase before the user approves the gate.
- Read only files relevant to the current phase (save context).
- Prefer native frameworks (ImageIO, AVFoundation, PDFKit). Use external CLIs only when necessary.
- Never modify or delete user files. Always write output to a new file.
- App Sandbox is OFF (decided in Phase 2) so output can be saved next to the original; hardened runtime stays on.

## Stack (decided)
- Language: **Swift 6** + **SwiftUI** (macOS 14+)
- Build: Xcode project + Swift Package Manager
- Engine: one `Converter` protocol implementation per file family (image / pdf / word / audio-video)
- MVP scope: images, PDF, Word. Audio/video (MP3, MP4…) is Phase 7, post-MVP, via bundled `ffmpeg`
- No bundled CLIs during MVP; `pandoc` only as a Phase 4 fallback
- Distribution: personal use now; later free on GitHub (fork/build from source)

## Layout
```
Tangerine/
  App/      # entry, scene, menu
  UI/       # SwiftUI views (drop zone, queue, settings)
  Drag/     # menu-bar drag watcher, floating drop panel, radial menu (Phase 3.5–3.6)
  Engine/   # Converter protocol + implementations
  Tools/    # ffmpeg wrapper (Phase 7)
  (TangerineTests/ at repo root: unit tests, fixtures generated in code)
scripts/    # zsh: build, notarize, dmg
docs/       # plans, decision log
```

## Agents (`.claude/agents/`, each < 100 lines)
| Agent | Role | Phase |
|---|---|---|
| `architect` | structure, protocols, tech decisions | 0–1 |
| `ui-swiftui` | screens, queue UI, menu-bar drag watcher, radial menu | 2, 3.5–3.6 |
| `converter-engine` | image, PDF, Word (MVP); audio/video (P7) | 1, 3–4, 7 |
| `qa-tester` | tests, fixtures, edge cases | all |
| `release-packager` | icon, README build steps, license, optional zip | 6 |

## Code conventions
- Swift API Design Guidelines; `async/await` with `Task` cancellation
- No force unwrap (`!`) in production code
- All errors via `enum ConversionError: LocalizedError`
- One file = one responsibility, ~300 lines max

## Handoff
At the end of each phase: summary ≤10 lines (what was done, how to run, how to verify, open issues), then wait for user approval.
