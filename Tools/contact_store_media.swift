import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let locales = ["zh-Hans", "zh-Hant", "ja", "ko", "en-US"]
let devices = CommandLine.arguments.count > 2 ? Array(CommandLine.arguments.dropFirst(2)) : ["iphone", "ipad"]
let scenes = ["01-home", "02-lesson", "03-word", "04-practice", "05-wordbook"]

for locale in locales {
    for device in devices {
        let thumbnailWidth: CGFloat = device == "iphone" ? 280 : 320
        let thumbnailHeight: CGFloat = device == "iphone" ? 608 : 427
        let rowHeight = thumbnailHeight + 36
        let canvasSize = NSSize(width: thumbnailWidth * 5, height: rowHeight * 2 + 50)
        let canvas = NSImage(size: canvasSize)
        canvas.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.black]
        ("\(locale) / \(device): native screenshots, then video frames" as NSString).draw(at: NSPoint(x: 12, y: canvasSize.height - 32), withAttributes: attributes)
        for row in 0..<2 {
            for (index, scene) in scenes.enumerated() {
                let path = row == 0 ? "upload/\(locale)/\(device)/\(scene).png" : String(format: "review/%@/%@/frame-%02d.png", locale, device, index + 1)
                guard let image = NSImage(contentsOf: root.appendingPathComponent(path)) else {
                    fatalError("Missing image: \(path)")
                }
                let slot = NSRect(x: CGFloat(index) * thumbnailWidth + 8,
                                  y: canvasSize.height - 50 - CGFloat(row + 1) * rowHeight + 30,
                                  width: thumbnailWidth - 16, height: thumbnailHeight)
                let scale = min(slot.width / image.size.width, slot.height / image.size.height)
                let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                image.draw(in: NSRect(x: slot.midX - size.width / 2, y: slot.maxY - size.height,
                                      width: size.width, height: size.height))
                (scene as NSString).draw(at: NSPoint(x: slot.minX, y: slot.minY - 24), withAttributes: attributes)
            }
        }
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode review sheet") }
        let output = root.appendingPathComponent("review/\(locale)/\(device)/contact-sheet.png")
        try png.write(to: output)
        print(output.path)
    }
}
