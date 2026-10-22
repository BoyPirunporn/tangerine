import CoreGraphics
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Tangerine

struct RadialLayoutTests {
    let center = CGPoint(x: 200, y: 200)

    @Test func hubIsNotAWedge() {
        let layout = RadialLayout(count: 4, inner: 70, outer: 170)
        #expect(layout.index(at: center, center: center) == nil)
        #expect(layout.index(at: CGPoint(x: 200, y: 150), center: center) == nil) // 50 from centre
    }

    @Test func wedgesRunClockwiseFromTheTop() {
        let layout = RadialLayout(count: 4, inner: 70, outer: 170)
        // up-right, down-right, down-left, up-left
        #expect(layout.index(at: CGPoint(x: 260, y: 140), center: center) == 0)
        #expect(layout.index(at: CGPoint(x: 260, y: 260), center: center) == 1)
        #expect(layout.index(at: CGPoint(x: 140, y: 260), center: center) == 2)
        #expect(layout.index(at: CGPoint(x: 140, y: 140), center: center) == 3)
    }

    @Test func straightUpBelongsToTheFirstWedge() {
        let layout = RadialLayout(count: 8, inner: 70, outer: 170)
        #expect(layout.index(at: CGPoint(x: 200, y: 100), center: center) == 0)
        // just left of straight up wraps to the last wedge
        #expect(layout.index(at: CGPoint(x: 195, y: 100), center: center) == 7)
    }

    @Test func twoWedgesSplitLeftAndRight() {
        let layout = RadialLayout(count: 2, inner: 70, outer: 170)
        #expect(layout.index(at: CGPoint(x: 300, y: 200), center: center) == 0)
        #expect(layout.index(at: CGPoint(x: 100, y: 200), center: center) == 1)
    }

    @Test func labelsSitInsideTheirWedge() {
        let layout = RadialLayout(count: 6, inner: 70, outer: 170)
        for index in 0..<6 {
            let label = layout.labelPoint(index, center: center)
            #expect(layout.index(at: label, center: center) == index)
        }
    }

    @Test(arguments: [2, 3, 5, 7, 8])
    func outlinesStayInsideTheirWedgeWithAGap(_ count: Int) {
        let layout = RadialLayout(count: count, inner: 70, outer: 170)
        let half = Double(layout.gap) / 2 - 0.1
        for index in 0..<count {
            let (points, radius) = layout.outline(index, center: center)
            #expect(radius > 0, "wedge \(index) of \(count) lost its rounded corners")
            let start = Double(index) * layout.sweep
            let end = start + layout.sweep
            for point in points {
                let dx = Double(point.x - center.x), dy = Double(point.y - center.y)
                let rho = hypot(dx, dy)
                var phi = atan2(dx, -dy) * 180 / .pi
                if phi < 0 { phi += 360 }
                #expect(rho >= Double(layout.inner) + half && rho <= Double(layout.outer) - half)
                #expect(phi >= start - 0.01 && phi <= end + 0.01)
                // distance from each straight edge
                #expect(rho * sin((phi - start) * .pi / 180) >= half)
                #expect(rho * sin((end - phi) * .pi / 180) >= half)
            }
        }
    }

    @Test func bothArcsAreSmoothEvenForWideWedges() {
        let layout = RadialLayout(count: 3, inner: 70, outer: 170)
        let (points, radius) = layout.outline(0, center: center)
        let d = layout.gap / 2 + radius
        func pointsNear(_ r: CGFloat) -> Int {
            points.filter { abs(hypot($0.x - center.x, $0.y - center.y) - r) < 0.5 }.count
        }
        // A 120° wedge sampled every 2° has dozens of points on each arc, not a straight chord.
        #expect(pointsNear(layout.inner + d) >= 25)
        #expect(pointsNear(layout.outer - d) >= 25)
    }

    @Test func aSingleWedgeIsAPlainRing() {
        let layout = RadialLayout(count: 1, inner: 70, outer: 170)
        let (points, radius) = layout.outline(0, center: center)
        #expect(radius == 0)
        #expect(!points.isEmpty)
    }

    @Test func narrowWedgesGiveUpCornerRadiusBeforeCollapsing() {
        let layout = RadialLayout(count: 24, inner: 70, outer: 170)
        let (points, radius) = layout.outline(3, center: center)
        #expect(!points.isEmpty)
        #expect(radius < layout.cornerRadius)
    }

    @Test func emptyLayoutHasNoWedges() {
        #expect(RadialLayout(count: 0, inner: 70, outer: 170).index(at: CGPoint(x: 300, y: 200), center: center) == nil)
    }
}

@MainActor
struct RadialIntegrationTests {
    let dir: URL

    init() throws {
        dir = try TestImages.makeTempDir()
    }

    @Test func formatsAreOrderedForDisplay() {
        let ordered = QueueViewModel.ordered([.pdf, .bmp, .png, .jpeg, .heic])
        #expect(ordered == [.jpeg, .png, .heic, .bmp, .pdf])
    }

    @Test func jpegIsLabelledJPG() {
        #expect(QueueViewModel.label(for: .jpeg) == "JPG")
        #expect(QueueViewModel.label(for: .png) == "PNG")
    }

    @Test func avifIsOfferedWhenTheSystemCanWriteIt() {
        let offered = ConverterRegistry.standard.allOutputs.contains(ImageFormats.avif)
        #expect(offered == ImageFormats.writable.contains(ImageFormats.avif))
        #expect(offered, "this Mac can't write AVIF")
    }

    @Test func radialDropUsesTheChosenFormatNotTheWindowSetting() async throws {
        let input = try TestImages.make("r.png", type: .png, in: dir)
        let model = QueueViewModel()
        model.targetType = .jpeg
        model.add([input], as: .tiff)
        await model.waitUntilIdle()
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("r.tiff").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("r.jpg").path))
    }

    @Test func batchCallbackFiresOncePerRun() async throws {
        let good = try TestImages.make("g.png", type: .png, in: dir)
        let bad = dir.appendingPathComponent("bad.png")
        try Data("nope".utf8).write(to: bad)
        let model = QueueViewModel()
        var batches: [[QueueItem.State]] = []
        model.onBatchFinished = { batches.append($0) }
        model.add([good, bad])
        await model.waitUntilIdle()

        #expect(batches.count == 1)
        let summary = try #require(BatchSummary(batches[0]))
        #expect(summary.reveal == [dir.appendingPathComponent("g.jpg")])
        #expect(summary.message.contains("g.jpg"))
        #expect(summary.message.contains("1 failed"))
    }

    @Test func cancelledOnlyRunsDoNotNotify() {
        #expect(BatchSummary([.cancelled]) == nil)
        #expect(BatchSummary([]) == nil)
    }

    @Test func summaryDescribesSeveralFiles() {
        let a = URL(fileURLWithPath: "/tmp/a.jpg")
        let b = URL(fileURLWithPath: "/tmp/b.jpg")
        let summary = BatchSummary([.done(a), .done(b)])
        #expect(summary?.message == "Converted 2 files")
        #expect(summary?.reveal == [a, b])
    }
}
