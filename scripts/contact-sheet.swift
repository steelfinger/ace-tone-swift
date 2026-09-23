// Usage: swift contact-sheet.swift out.png a.png b.png ...
// Lays the images side by side at a common height with their file names below.
import AppKit

let args = CommandLine.arguments.dropFirst()
let out = URL(fileURLWithPath: args.first!)
let inputs = args.dropFirst().map { URL(fileURLWithPath: $0) }
let images = inputs.compactMap { NSImage(contentsOf: $0) }

let height: CGFloat = 1400, gap: CGFloat = 40, caption: CGFloat = 60
let widths = images.map { height * $0.size.width / $0.size.height }
let size = NSSize(width: widths.reduce(0, +) + gap * CGFloat(images.count + 1),
                  height: height + caption + gap * 2)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()

var x = gap
for (i, img) in images.enumerated() {
    img.draw(in: NSRect(x: x, y: caption + gap, width: widths[i], height: height))
    let name = inputs[i].deletingPathExtension().lastPathComponent.replacingOccurrences(of: "-", with: " ")
    (name as NSString).draw(at: NSPoint(x: x, y: gap / 2),
                            withAttributes: [.font: NSFont.systemFont(ofSize: 36, weight: .semibold)])
    x += widths[i] + gap
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: out)
