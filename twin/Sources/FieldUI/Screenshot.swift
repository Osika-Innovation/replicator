import SwiftUI
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// The screenshot harness (§21). Two capture paths composited into one image,
/// both working with no Xcode, no window server and no screen-recording
/// permission:
///   - UI chrome  -> SwiftUI ImageRenderer
///   - viewport   -> the same Metal renderer drawing into an offscreen texture,
///                   handed in as a CGImage
///
/// Because the viewport image comes from the renderer that draws on screen, a
/// screenshot cannot diverge from what a user sees.
public enum Screenshot {

    @MainActor
    public static func render(_ state: AppState, width: Int, height: Int,
                              scale: CGFloat = 2.0) -> CGImage? {
        let view = AppShell(state).frame(width: CGFloat(width), height: CGFloat(height))
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Screenshot", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "cannot create \(url.path)"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "Screenshot", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
        }
    }

    /// One labelled PNG grid of every scene. §21: this is the deliverable —
    /// how a reviewer inspects the entire application in a single look.
    public static func contactSheet(images: [(String, CGImage)],
                                    columns: Int = 2,
                                    theme: Theme) throws -> CGImage? {
        guard !images.isEmpty else { return nil }
        let cellW = 640, cellH = 400, label = 26, pad = 12
        let rows = (images.count + columns - 1) / columns
        let W = columns * (cellW + pad) + pad
        let H = rows * (cellH + label + pad) + pad + 34

        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let bg: CGFloat = theme.isDark ? 0.07 : 0.95
        ctx.setFillColor(red: bg, green: bg, blue: bg + 0.01, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let fg: CGFloat = theme.isDark ? 0.85 : 0.12
        let title = "Field Compiler — \(images.count) scenes — \(theme.isDark ? "dark" : "light")"
        drawText(ctx, title, at: CGPoint(x: CGFloat(pad), y: CGFloat(H - 24)),
                 size: 14, gray: fg)

        for (i, entry) in images.enumerated() {
            let col = i % columns, row = i / columns
            let x = pad + col * (cellW + pad)
            let yTop = H - 34 - (row + 1) * (cellH + label + pad)
            let rect = CGRect(x: CGFloat(x), y: CGFloat(yTop + label),
                              width: CGFloat(cellW), height: CGFloat(cellH))
            ctx.draw(entry.1, in: rect)
            ctx.setStrokeColor(red: fg, green: fg, blue: fg, alpha: 0.25)
            ctx.setLineWidth(1)
            ctx.stroke(rect)
            drawText(ctx, entry.0, at: CGPoint(x: CGFloat(x), y: CGFloat(yTop + 6)),
                     size: 11, gray: fg)
        }
        return ctx.makeImage()
    }

    private static func drawText(_ ctx: CGContext, _ s: String, at p: CGPoint,
                                 size: CGFloat, gray: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium),
            .foregroundColor: NSColor(white: gray, alpha: 1),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: s, attributes: attrs))
        ctx.textPosition = p
        CTLineDraw(line, ctx)
    }
}
