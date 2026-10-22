import SwiftUI
import UniformTypeIdentifiers

private struct WedgeShape: Shape {
    let layout: RadialLayout
    let index: Int

    func path(in rect: CGRect) -> Path {
        let (points, radius) = layout.outline(index, center: CGPoint(x: rect.midX, y: rect.midY))
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        guard radius > 0 else { return path }
        // Growing the inset polygon by `radius` with round joins rounds every corner.
        return path.union(path.strokedPath(StrokeStyle(lineWidth: radius * 2, lineJoin: .round)))
    }
}

/// A frosted-glass wheel around the dragged file; dropping on a wedge converts to that format.
struct RadialMenuView: View {
    /// Room around the disc for its shadow and the caption.
    static let size: CGFloat = 460
    private static let discDiameter: CGFloat = 368

    private static let pink = Color(red: 0.95, green: 0.32, blue: 0.40)
    private static let purple = Color(red: 0.55, green: 0.40, blue: 0.88)

    let urls: [URL]
    let formats: [UTType]
    /// Called with the dropped files and the chosen format.
    let choose: ([URL], UTType) -> Void
    let finished: () -> Void

    @State private var hovered: Int?
    @State private var chosen: UTType?
    @State private var thumbnail: NSImage
    @State private var appeared = false
    private let inputType: UTType?

    init(
        urls: [URL],
        formats: [UTType],
        initiallyHovered: Int? = nil,
        choose: @escaping ([URL], UTType) -> Void,
        finished: @escaping () -> Void
    ) {
        _hovered = State(initialValue: initiallyHovered)
        self.urls = urls
        self.formats = formats
        self.choose = choose
        self.finished = finished
        inputType = try? urls.first?.resourceValues(forKeys: [.contentTypeKey]).contentType
        _thumbnail = State(initialValue: urls.first.map(Thumbnails.icon(for:)) ?? NSImage())
    }

    private var center: CGPoint { CGPoint(x: Self.size / 2, y: Self.size / 2) }
    private var layout: RadialLayout { RadialLayout(count: formats.count, inner: 70, outer: 170) }

    var body: some View {
        ZStack {
            disc
            ForEach(formats.indices, id: \.self) { index in
                wedge(index)
            }
            hub
            VStack {
                Spacer()
                captionPill
            }
            .padding(.bottom, 6)
        }
        .frame(width: Self.size, height: Self.size)
        .scaleEffect(appeared ? 1 : 0.86)
        .opacity(appeared ? 1 : 0)
        .overlay {
            DropTarget(
                onMove: { point in hovered = point.flatMap { layout.index(at: $0, center: center) } },
                onDrop: handleDrop
            )
        }
        .task {
            if let url = urls.first, let preview = await Thumbnails.preview(for: url, side: 96) {
                thumbnail = preview
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appeared = true }
        }
    }

    // MARK: Pieces

    /// Light frosted glass tinted with the Tangerine gradient. The glass is forced light so the colours
    /// stay bright over a dark desktop instead of turning muddy brown, while the desktop still shows through.
    private var disc: some View {
        Circle()
            .fill(.regularMaterial)
            .environment(\.colorScheme, .light)
            .overlay {
                Circle().fill(LinearGradient(
                    colors: [Theme.tangerine.opacity(0.78), Self.pink.opacity(0.62), Self.purple.opacity(0.68)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            }
            .overlay {
                // soft highlight along the top edge, like light on glass
                Circle().fill(RadialGradient(
                    colors: [.white.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.35, y: 0.1), startRadius: 0, endRadius: Self.discDiameter * 0.6
                ))
            }
            .overlay {
                Circle().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.2
                )
            }
            .frame(width: Self.discDiameter, height: Self.discDiameter)
            .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
    }

    /// A thin glass segment. The active one fills with the accent gradient, glows and grows around its own centre.
    private func wedge(_ index: Int) -> some View {
        let isActive = chosen == nil ? hovered == index : chosen == formats[index]
        let label = layout.labelPoint(index, center: center)
        let shape = WedgeShape(layout: layout, index: index)
        return ZStack {
            shape.fill(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.07)], startPoint: .top, endPoint: .bottom))
            shape.stroke(.white.opacity(0.28), lineWidth: 0.8)
            shape
                .fill(LinearGradient(colors: [Theme.tangerine, Self.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(isActive ? 0.92 : 0)
            shape.stroke(.white.opacity(isActive ? 0.9 : 0), lineWidth: 1.5)
            Text(QueueViewModel.label(for: formats[index]))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .position(label)
        }
        .scaleEffect(
            isActive ? 1.1 : 1,
            anchor: UnitPoint(x: label.x / Self.size, y: label.y / Self.size)
        )
        .shadow(color: Theme.tangerine.opacity(isActive ? 0.7 : 0), radius: 16)
        .zIndex(isActive ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
    }

    private var hub: some View {
        VStack(spacing: 5) {
            if let chosen {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Theme.tangerine, .white)
                Text(QueueViewModel.label(for: chosen)).font(.caption.weight(.semibold))
            } else {
                Image(nsImage: thumbnail)
                    .resizable().scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(.rect(cornerRadius: 9))
                    .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.7), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                Text(summary)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(width: layout.inner * 1.7, height: layout.inner * 1.7)
        .background(.black.opacity(0.08), in: .circle)
        .background {
            Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .light)
        }
        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private var captionPill: some View {
        Text(caption)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.28), in: .capsule)
            .background(.ultraThinMaterial, in: .capsule)
            .frame(maxWidth: 400)
            .animation(.easeOut(duration: 0.15), value: caption)
    }

    // MARK: Behaviour

    /// A limitation note for the wedge under the pointer, otherwise a hint.
    private var caption: String {
        if chosen != nil { return String(localized: "Converting…") }
        if let hovered, let note = ConversionLimits.note(from: inputType, to: formats[hovered]) { return note }
        return String(localized: "Drop on a format")
    }

    private var summary: String {
        let bytes = urls.reduce(Int64(0)) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return urls.count == 1 ? size : "\(urls.count) files · \(size)"
    }

    private func handleDrop(_ dropped: [URL], at point: CGPoint) -> Bool {
        guard chosen == nil, let index = layout.index(at: point, center: center) else { return false }
        chosen = formats[index]
        choose(dropped, formats[index])
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            finished()
        }
        return true
    }
}
