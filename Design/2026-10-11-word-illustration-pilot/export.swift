import AppKit
import ImageIO
import CryptoKit

// Deterministic slicing/resizing only. All illustrations originate from image_gen.
let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : fm.currentDirectoryPath)
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("manifest.json"))) as! [String: Any]
let atlases = manifest["atlases"] as! [[String: Any]]
let settings = manifest["exports"] as! [String: Any]
let cap = settings["max_bytes_per_tile"] as! Int
let output = root.appendingPathComponent("tiles")
try fm.createDirectory(at: output, withIntermediateDirectories: true)
try fm.createDirectory(at: root.appendingPathComponent("sources"), withIntermediateDirectories: true)

func read(_ url: URL) throws -> CGImage {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { throw NSError(domain: "Invalid image: \(url.path)", code: 1) }
    return image
}
func resized(_ image: CGImage, _ size: Int) -> CGImage {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    c.interpolationQuality = .high
    c.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return c.makeImage()!
}
func png(_ image: CGImage) -> Data {
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest))
    return data as Data
}
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func writeChecked(_ data: Data, _ url: URL) throws {
    if fm.fileExists(atPath: url.path) {
        guard try Data(contentsOf: url) == data else { throw NSError(domain: "Refusing to replace differing file: \(url.path)", code: 2) }
    } else { try data.write(to: url, options: .withoutOverwriting) }
}

var tiles: [(word: String, meaning: String, atlas: String, index: Int, image: CGImage)] = []
var sourceRecords: [[String: Any]] = []
for atlas in atlases {
    let source = root.appendingPathComponent(atlas["source"] as! String)
    if !fm.fileExists(atPath: source.path) {
        try fm.copyItem(at: URL(fileURLWithPath: atlas["original_generated"] as! String), to: source)
    }
    let data = try Data(contentsOf: source)
    let image = try read(source)
    guard image.width == image.height && image.width % 2 == 0 else { throw NSError(domain: "Atlas must be even and square", code: 3) }
    sourceRecords.append(["path": atlas["source"]!, "width": image.width, "height": image.height, "bytes": data.count, "sha256": digest(data)])
    let side = image.width / 2
    for cell in atlas["cells"] as! [[String: Any]] {
        let i = cell["index"] as! Int
        let tile = image.cropping(to: CGRect(x: (i % 2) * side, y: (i / 2) * side, width: side, height: side))!
        tiles.append((cell["word"] as! String, cell["meaning"] as! String, atlas["id"] as! String, i, tile))
    }
}
var size = settings["preferred_size"] as! Int
var data = tiles.map { png(resized($0.image, size)) }
if data.contains(where: { $0.count > cap }) {
    size = settings["fallback_size"] as! Int
    data = tiles.map { png(resized($0.image, size)) }
}
guard data.allSatisfy({ $0.count <= cap }) else { throw NSError(domain: "PNG exceeds byte budget; adjust dimensions after review", code: 4) }
var records: [[String: Any]] = []
for (i, tile) in tiles.enumerated() {
    let path = "tiles/\(tile.word).png"
    try writeChecked(data[i], root.appendingPathComponent(path))
    let check = try read(root.appendingPathComponent(path))
    precondition(check.width == size && check.height == size)
    records.append(["word": tile.word, "meaning": tile.meaning, "path": path, "width": size, "height": size,
                    "bytes": data[i].count, "sha256": digest(data[i]), "atlas": tile.atlas, "cell_index": tile.index,
                    "review_status": "pilot_pending_user_style_review"])
}

// Contact sheet is a review artifact; labels are not embedded into vocabulary tiles.
let width = 1040, height = 1044
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                          samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                          bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
func text(_ value: String, _ rect: NSRect, _ font: CGFloat, _ color: NSColor = .labelColor, center: Bool = false) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = center ? .center : .left
    (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: font, weight: .medium),
                                                        .foregroundColor: color, .paragraphStyle: paragraph])
}
text("新概念英语 · 单词插画首批样图", NSRect(x: 32, y: 988, width: 976, height: 32), 25, .black)
text("12 个词 · 墨线水彩 · \(size) × \(size) PNG · 无内嵌文字", NSRect(x: 32, y: 958, width: 976, height: 24), 16, .darkGray)
for (i, tile) in tiles.enumerated() {
    let x = 24 + (i % 4) * 254, y = 650 - (i / 4) * 306
    let file = root.appendingPathComponent("tiles/\(tile.word).png")
    NSImage(contentsOf: file)!.draw(in: NSRect(x: x + 19, y: y + 76, width: 216, height: 216))
    text(tile.word, NSRect(x: x, y: y + 45, width: 254, height: 28), 20, .black, center: true)
    text(tile.meaning, NSRect(x: x, y: y + 19, width: 254, height: 23), 16, .darkGray, center: true)
    text(String(format: "%.1f KB", Double(data[i].count) / 1000), NSRect(x: x, y: y - 3, width: 254, height: 21), 13, .gray, center: true)
}
NSGraphicsContext.restoreGraphicsState()
try writeChecked(rep.representation(using: .png, properties: [:])!, root.appendingPathComponent("preview.png"))
let total = data.reduce(0) { $0 + $1.count }
let report: [String: Any] = ["format_version": 1, "format": "PNG", "lossy_compression": false,
    "tile_count": tiles.count, "width": size, "height": size, "total_tile_bytes": total,
    "average_tile_bytes": total / tiles.count, "largest_tile_bytes": data.map(\.count).max()!,
    "limit_bytes_per_tile": cap, "all_tiles_within_limit": true, "sources": sourceRecords, "tiles": records]
let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
try writeChecked(reportData, root.appendingPathComponent("report.json"))
print("Exported \(tiles.count) PNG tiles at \(size)x\(size); total \(total) bytes, max \(data.map(\.count).max()!) bytes.")
