#!/usr/bin/env swift
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Inspect actual simulator recordings, including frames before the app is accessible.
// A nearly black content area is distinct from the app's #14191F dark appearance.
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let asset = AVURLAsset(url: input)
let duration = CMTimeGetSeconds(asset.duration)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: 160, height: 320)
var samples: [[String: Any]] = []
var blackTimes: [Double] = []
for index in 0..<Int(duration * 12) {
    let time = Double(index) / 12
    let image = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
    var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
    }
    var black = 0
    for y in 6..<58 { for x in 6..<58 {
        let offset = (y * 64 + x) * 4
        if pixels[offset] < 12 && pixels[offset+1] < 12 && pixels[offset+2] < 12 { black += 1 }
    }}
    let fraction = Double(black) / Double(52 * 52)
    samples.append(["seconds": time, "blackContentFraction": fraction])
    if fraction > 0.95 { blackTimes.append(time) }
}
// Keep a compact visual sample of the first seconds at the original resolution.
generator.maximumSize = .zero
for time in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0] where time < duration {
    guard let image = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else { continue }
    let url = output.appendingPathComponent(String(format: "frame-%.1f.png", time))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not save frame") }
}
let report: [String: Any] = ["video": input.path, "duration": duration, "samplingFPS": 12,
    "blackFrameSampleCount": blackTimes.count, "blackSampleTimes": blackTimes, "samples": samples]
guard !samples.isEmpty else { fatalError("No frames decoded; this is not a successful inspection") }
let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("analysis.json"))
print("\(input.lastPathComponent): \(samples.count) samples; \(blackTimes.count) near-black samples; times \(blackTimes)")
