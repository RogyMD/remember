import Dependencies
import DependenciesMacros
import UIKit
import NaturalLanguage

public struct RecognizedTextFrame {
  public var text: String
  public var frame: CGRect
}

extension TextRecognizerClient {
  public struct Result {
    public let text: String
    public let textFrames: [RecognizedTextFrame]
  }
}

@DependencyClient
public struct TextRecognizerClient: Sendable {
  @DependencyEndpoint
  public var recognizeTextInImage: @Sendable (UIImage) async throws -> Result
}

extension DependencyValues {
  public var textRecognizer: TextRecognizerClient {
    get { self[TextRecognizerClient.self] }
    set { self[TextRecognizerClient.self] = newValue }
  }
}

extension TextRecognizerClient: TestDependencyKey {
  public static let testValue = Self()
}

// MARK: - Live

import Vision

extension TextRecognizerClient: DependencyKey {
  public static let liveValue: Self = Self(recognizeTextInImage: { image in
    guard let cgImage = image.cgImage else {
      return .init(text: "", textFrames: [])
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    guard let observations = request.results else {
      return .init(text: "", textFrames: [])
    }

    var allText = ""
    let frames: [RecognizedTextFrame] = observations.flatMap { observation -> [RecognizedTextFrame] in
      guard let topCandidate = observation.topCandidates(1).first else { return [] }
      let fullText = topCandidate.string
      allText += fullText + " "

      var result: [RecognizedTextFrame] = []

      let tagger = NLTagger(tagSchemes: [.lexicalClass])
      tagger.string = fullText

      tagger.enumerateTags(in: fullText.startIndex..<fullText.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
        let word = String(fullText[tokenRange])
        guard word.isCJKOrKorean || word.count > 2 else { return true }
        let boundingBox = (try? topCandidate.boundingBox(for: tokenRange))?.boundingBox ?? observation.boundingBox
        let rect = VNImageRectForNormalizedRect(boundingBox, cgImage.width, cgImage.height)
        let convertedRect = CGRect(
          x: rect.origin.x,
          y: (CGFloat(cgImage.height) - rect.origin.y - rect.height),
          width: rect.width,
          height: rect.height
        )
        result.append(RecognizedTextFrame(text: word, frame: convertedRect))
        return true
      }

      return result
    }

    return .init(text: allText.trimmingCharacters(in: .whitespacesAndNewlines), textFrames: frames)
  })
}

extension String {
  var isCJKOrKorean: Bool {
      guard let scalar = unicodeScalars.first else { return false }
      switch scalar.value {
      case 0x4E00...0x9FFF,       // CJK Unified (Chinese, Kanji)
           0x3040...0x309F,       // Hiragana
           0x30A0...0x30FF,       // Katakana
           0xAC00...0xD7AF,       // Hangul Syllables
           0x1100...0x11FF:       // Hangul Jamo (rare)
          return true
      default:
          return false
      }
  }
}
