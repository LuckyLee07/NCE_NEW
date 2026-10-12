#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

enum ExportError: Error {
    case invalidImage(String)
    case invalidRatio(String)
    case cannotWrite(String)
    case conflictingIconSize(String)
}

let files = FileManager.default
let root = URL(fileURLWithPath:CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : files.currentDirectoryPath)
let pipeline = root.appendingPathComponent("ContentPipeline/branding")
let iconsOnly = CommandLine.arguments.contains("--icons-only")
let docs = root.appendingPathComponent("Docs/branding")
let backup = pipeline.appendingPathComponent("previous")
let isRepeatExport = files.fileExists(atPath:docs.appendingPathComponent("asset-report.json").path)

func digest(_ url: URL) throws -> String {
    SHA256.hash(data:try Data(contentsOf:url)).map { String(format:"%02x", $0) }.joined()
}

func readImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ExportError.invalidImage(url.path)
    }
    return image
}

func resized(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
    let sourceRatio = Double(image.width) / Double(image.height)
    guard abs(sourceRatio - Double(width) / Double(height)) < 0.002 else {
        throw ExportError.invalidRatio("\(image.width)x\(image.height) -> \(width)x\(height)")
    }
    // RGB without an alpha channel is required for the App Store icon.
    guard let context = CGContext(data:nil, width:width, height:height, bitsPerComponent:8,
                                  bytesPerRow:0, space:CGColorSpace(name:CGColorSpace.sRGB)!,
                                  bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw ExportError.invalidImage("Cannot allocate RGB bitmap")
    }
    context.interpolationQuality = .high
    context.draw(image, in:CGRect(x:0, y:0, width:width, height:height))
    guard let result = context.makeImage() else { throw ExportError.invalidImage("Cannot resize bitmap") }
    return result
}

func writeImage(_ image: CGImage, to url: URL, jpeg: Bool) throws {
    try files.createDirectory(at:url.deletingLastPathComponent(), withIntermediateDirectories:true)
    let type = jpeg ? UTType.jpeg.identifier : UTType.png.identifier
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil) else {
        throw ExportError.cannotWrite(url.path)
    }
    let options: CFDictionary = jpeg ? [kCGImageDestinationLossyCompressionQuality:0.84] as CFDictionary : [:] as CFDictionary
    CGImageDestinationAddImage(destination, image, options)
    guard CGImageDestinationFinalize(destination) else { throw ExportError.cannotWrite(url.path) }
}

func preserve(_ relative: String) throws {
    let current = root.appendingPathComponent(relative)
    let original = backup.appendingPathComponent(relative)
    if !isRepeatExport, files.fileExists(atPath:current.path), !files.fileExists(atPath:original.path) {
        try files.createDirectory(at:original.deletingLastPathComponent(), withIntermediateDirectories:true)
        try files.copyItem(at:current, to:original)
    }
}

var assets: [[String:Any]] = []
var sources: [[String:Any]] = []
for name in (iconsOnly ? ["icon"] : ["icon", "book1", "book2", "book3", "book4"]) {
    let source = pipeline.appendingPathComponent("source/\(name).png")
    let image = try readImage(source)
    sources.append(["path":"ContentPipeline/branding/source/\(name).png", "sha256":try digest(source),
                    "width":image.width, "height":image.height])
}

func export(_ source: CGImage, relative: String, width: Int, height: Int, jpeg: Bool) throws {
    try preserve(relative)
    let target = root.appendingPathComponent(relative)
    try writeImage(resized(source, width:width, height:height), to:target, jpeg:jpeg)
    assets.append(["path":relative, "sha256":try digest(target), "width":width, "height":height,
                   "bytes":try Data(contentsOf:target).count, "format":jpeg ? "JPEG" : "PNG"])
}

let iconDirectory = root.appendingPathComponent("NCE_ALL/Images.xcassets/AppIcon.appiconset")
let catalog = try JSONSerialization.jsonObject(with:Data(contentsOf:iconDirectory.appendingPathComponent("Contents.json"))) as! [String:Any]
var iconSizes: [String:Int] = [:]
for slot in catalog["images"] as! [[String:String]] {
    let filename = slot["filename"]!
    let size = Double(slot["size"]!.components(separatedBy:"x")[0])!
    let scale = Double(slot["scale"]!.dropLast())!
    let pixels = Int((size * scale).rounded())
    if let previous = iconSizes[filename], previous != pixels { throw ExportError.conflictingIconSize(filename) }
    iconSizes[filename] = pixels
}
let icon = try readImage(pipeline.appendingPathComponent("source/icon.png"))
for filename in iconSizes.keys.sorted() {
    let pixels = iconSizes[filename]!
    try export(icon, relative:"NCE_ALL/Images.xcassets/AppIcon.appiconset/\(filename)", width:pixels, height:pixels, jpeg:false)
}
for book in (iconsOnly ? [] : Array(1...4)) {
    let source = try readImage(pipeline.appendingPathComponent("source/book\(book).png"))
    try export(source, relative:"NCE_ALL/images/book\(book).jpg", width:540, height:756, jpeg:true)
    try export(source, relative:"NCE_ALL/images/book\(book)_iPad.png", width:630, height:882, jpeg:false)
}

var originals: [[String:Any]] = []
for asset in assets {
    let relative = asset["path"] as! String
    let original = backup.appendingPathComponent(relative)
    if files.fileExists(atPath:original.path) {
        originals.append(["path":"ContentPipeline/branding/previous/\(relative)", "sha256":try digest(original),
                          "bytes":try Data(contentsOf:original).count])
    }
}
let report: [String:Any] = [
    "format_version":1, "design_spec":"ContentPipeline/branding/design-spec.json",
    "app_interface_languages":["zh-Hans", "zh-Hant", "ja", "ko"],
    "english_interface_added":false, "home_layout_changed":false,
    "store_assets_uploaded":false, "sources":sources, "assets":assets, "previous_assets":originals,
    "total_app_asset_bytes":assets.reduce(0) { $0 + ($1["bytes"] as! Int) },
    "previous_app_asset_bytes":originals.reduce(0) { $0 + ($1["bytes"] as! Int) }
]
try files.createDirectory(at:docs, withIntermediateDirectories:true)
var data = try JSONSerialization.data(withJSONObject:report, options:[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
data.append(0x0a)
try data.write(to:docs.appendingPathComponent(iconsOnly ? "icon-asset-report.json" : "asset-report.json"), options:.atomic)
print("Exported \(assets.count) opaque icon/cover assets; \(report["total_app_asset_bytes"]!) bytes bundled. Original bitmaps retained outside the app.")
