//
//  VisionOCRService.swift
//  MDWriter
//
//  On-device Apple Vision text recognition (OCR) and multimodal vision-to-markdown processing.
//

import AppKit
import Foundation
import Vision

/// Result of an OCR or vision recognition pass.
struct VisionOCRResult: Sendable {
    let recognizedText: String
    let lineCount: Int
    let confidence: Float
}

/// Service managing on-device Apple Vision text recognition and vision-to-markdown workflows.
final class VisionOCRService: Sendable {
    static let shared = VisionOCRService()

    private init() {}

    // MARK: - Native On-Device OCR

    /// Performs fast, on-device OCR on an NSImage using Apple Vision framework.
    func recognizeText(from image: NSImage) async throws -> VisionOCRResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "VisionOCRService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert NSImage to CGImage."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: VisionOCRResult(recognizedText: "", lineCount: 0, confidence: 1.0))
                    return
                }

                // Sort observations vertically from top to bottom (macOS Vision Y coordinates go from 0 at bottom to 1 at top)
                let sortedObservations = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                }

                var recognizedLines: [String] = []
                var totalConfidence: Float = 0.0
                var count = 0

                for observation in sortedObservations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let line = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !line.isEmpty {
                        recognizedLines.append(line)
                        totalConfidence += topCandidate.confidence
                        count += 1
                    }
                }

                let fullText = recognizedLines.joined(separator: "\n\n")
                let avgConfidence = count > 0 ? (totalConfidence / Float(count)) : 0.0

                continuation.resume(returning: VisionOCRResult(
                    recognizedText: fullText,
                    lineCount: count,
                    confidence: avgConfidence
                ))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Performs OCR from a local image file path or file URL.
    func recognizeText(fromFileURL fileURL: URL) async throws -> VisionOCRResult {
        guard let image = NSImage(contentsOf: fileURL) else {
            throw NSError(domain: "VisionOCRService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot load image from file URL: \(fileURL.path)"])
        }
        return try await recognizeText(from: image)
    }

    // MARK: - Multimodal Vision-to-Markdown (via Local LLM)

    /// Converts an image to Base64 data URL for OpenAI-compatible multimodal requests.
    func encodeImageToBase64DataURL(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        let base64String = pngData.base64EncodedString()
        return "data:image/png;base64,\(base64String)"
    }
}
