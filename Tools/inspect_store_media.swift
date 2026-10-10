import Foundation
import Vision
import ImageIO

let root = URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
let output = URL(fileURLWithPath:CommandLine.arguments[2]).standardizedFileURL
let devices = CommandLine.arguments.count > 3 ? Array(CommandLine.arguments.dropFirst(3)) : ["iphone", "ipad"]
let locales = ["zh-Hans", "zh-Hant", "ja", "ko", "en-US"]
let scenes = ["01-home", "02-lesson", "03-word", "04-practice", "05-wordbook"]
let languages = ["zh-Hans": ["zh-Hans", "en-US"], "zh-Hant": ["zh-Hant", "en-US"],
                 "ja": ["ja-JP", "en-US"], "ko": ["ko-KR", "en-US"], "en-US": ["en-US", "zh-Hans"]]
var records: [[String: Any]] = []
var warnings: [String] = []

func inspect(_ url: URL, locale: String, scene: String, previewFrame: Bool) throws {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = languages[locale]!
    let handler = VNImageRequestHandler(url: url)
    try handler.perform([request])
    let observations = request.results ?? []
    let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    if text.lowercased().contains("rdar") || text.contains("载入中") || text.contains("載入中") {
        warnings.append("Warning or loading text: \(url.path)")
    }
    if observations.count < 3 { warnings.append("Too little readable text: \(url.path)") }
    if !previewFrame && scene == "03-word" && !text.lowercased().contains("umbrella") {
        warnings.append("Unexpected vocabulary page: \(url.path)")
    }
    if !previewFrame && scene == "02-lesson" && !text.lowercased().contains("excuse") {
        warnings.append("Unexpected lesson page: \(url.path)")
    }
    if locale == "ko" && !text.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) {
        warnings.append("Korean glyphs missing: \(url.path)")
    }
    if locale == "ja" && ["02-lesson", "05-wordbook"].contains(scene) && !text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) {
        warnings.append("Japanese kana missing: \(url.path)")
    }
    records.append(["path": String(url.path.dropFirst(root.path.count + 1)), "locale": locale, "scene": scene,
                    "preview_frame": previewFrame, "recognized_text": text,
                    "text_boxes": observations.compactMap { observation -> [String: Any]? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        let box = observation.boundingBox
                        return ["text": candidate.string, "confidence": candidate.confidence,
                                "normalized_box": [box.minX, box.minY, box.width, box.height]]
                    }])
}

for locale in locales {
    for device in devices {
        if locale != "en-US" {
            for scene in scenes {
                let url = root.appendingPathComponent("upload/\(locale)/\(device)/\(scene).png")
                try inspect(url, locale: locale, scene: scene, previewFrame: false)
            }
        }
        for (index, scene) in scenes.enumerated() {
            let name = String(format: "frame-%02d.png", index + 1)
            let url = root.appendingPathComponent("review/\(locale)/\(device)/\(name)")
            try inspect(url, locale: locale, scene: scene, previewFrame: true)
        }
    }
}
let report: [String: Any] = ["format_version": 1, "checked_images": records.count,
                           "status": warnings.isEmpty ? "passed" : "needs_review", "warnings": warnings,
                           "editorial_translation_approval": false, "images": records]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output)
print("Inspected \(records.count) screenshots and preview frames; \(warnings.count) OCR review flags.")
for warning in warnings { print(warning) }
