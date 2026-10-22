# Manual test checklist

Things unit tests can't cover: real drags, other apps, multiple displays, system dialogs.
Run with the app built from Xcode (⌘R). Tick items as you go and note what failed.

## Radial menu (drag a file, hold Shift)
- [ ] Finder → appears at the cursor, formats match the file type, drop converts next to the original
- [ ] Dragging a PDF shows PNG / JPG / DOCX; a DOCX shows PDF / TXT / HTML
- [ ] Hovering DOCX on a PDF shows "Text only…"; hovering a Word → PDF shows the layout note
- [ ] Release outside the menu → it disappears, nothing is converted
- [ ] Drop in the centre hub → nothing is converted
- [ ] Several files of different types → only formats valid for all are offered
- [ ] Menu stays inside the screen when dragging near an edge or the Dock
- [ ] Another app in **full screen** → menu still appears
- [ ] **Two displays** → menu appears on the display with the cursor
- [ ] Drag from **Safari** (image), **Mail** (attachment), **Desktop**, a **zip** preview
- [ ] Over a bright (white) window and over a dark one → labels readable
- [ ] Trigger modes: Shift / always / ⌃⌥T while dragging; changing it in the menu applies immediately

## Main window and queue
- [ ] Opens in front when launched; "Open Tangerine" in the menu bar brings it forward
- [ ] Launch at login → starts in the menu bar without opening the window
- [ ] Drop files and folders; progress, cancel, and "Show in Finder" work
- [ ] Output folder chosen → files land there; "use original folder" resets it
- [ ] Notification after a batch finishes while another app is in front; clicking reveals the file
- [ ] Converting files on the Desktop / Documents: macOS permission prompt appears once and works

## Files that should fail politely
- [ ] Corrupt image, password-protected PDF, scanned PDF → PDF → DOCX, empty file
- [ ] Output folder you can't write to (e.g. a read-only volume)
- [ ] Disk (almost) full → readable error, no half-written file left behind
- [ ] Same name already exists → " (1)" is added, the original is untouched
- [ ] Cancel in the middle of a large PDF → no partial files

## Audio and video
- [ ] Drag an MP4 / MOV → the wheel offers MOV or MP4, M4A, WAV, FLAC; the result plays in QuickTime
- [ ] A real phone video (HEVC, large) → MOV and → M4A; progress moves; cancel mid-way leaves no partial file
- [ ] WAV / FLAC / M4A / MP3 files convert between each other (MP3 only as an input without ffmpeg)
- [ ] A video without sound → M4A shows a clear error
- [ ] Without ffmpeg: no MP3 / MKV wedges, and the menu-bar menu shows the install hint
- [ ] With ffmpeg (`brew install ffmpeg`): MP3 and MKV appear after restarting Tangerine; MP4 → MP3, MKV → MP4, MP4 → MKV work and play; cancel stops ffmpeg (check Activity Monitor)

## Language
- [ ] System language Thai → window, menu bar menu, radial menu, notifications and errors are in Thai
- [ ] System language English → same in English
