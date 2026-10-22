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
- Scope: images, PDF, Word (MVP) and audio/video (Phase 7): macOS APIs first; MP3 output and MKV use the user's own `ffmpeg` if installed
- Never bundle CLIs or third-party binaries (licences, repo size); `pandoc` only as a Phase 4 fallback
- Distribution: personal use now; later free on GitHub (fork/build from source)

## Layout
```
Tangerine/
  App/      # entry, scene, menu
  UI/       # SwiftUI views (drop zone, queue, settings)
  Drag/     # menu-bar drag watcher, floating drop panel, radial menu (Phase 3.5–3.6)
  Engine/   # Converter protocol + implementations
  (TangerineTests/ at repo root: unit tests, fixtures generated in code)
scripts/    # zsh: build, notarize, dmg
docs/       # plans, decision log
```

## Agents (local helper briefs in `.claude/agents/`, each < 100 lines; not committed to the repo)
| Agent | Role | Phase |
|---|---|---|
| `architect` | structure, protocols, tech decisions | 0–1 |
| `ui-swiftui` | screens, queue UI, menu-bar drag watcher, radial menu | 2, 3.5–3.6 |
| `converter-engine` | image, PDF, Word, audio/video converters | 1, 3–4, 7 |
| `qa-tester` | tests, fixtures, edge cases | all |
| `release-packager` | icon, README build steps, license, optional zip | 6 |

## Code conventions
- Swift API Design Guidelines; `async/await` with `Task` cancellation
- No force unwrap (`!`) in production code
- All errors via `enum ConversionError: LocalizedError`
- One file = one responsibility, ~300 lines max

## Handoff
At the end of each phase: summary ≤10 lines (what was done, how to run, how to verify, open issues), then wait for user approval.
