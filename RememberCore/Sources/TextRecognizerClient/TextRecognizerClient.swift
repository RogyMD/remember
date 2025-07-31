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

    let screenScale = await MainActor.run {
      UIScreen.main.scale
    }

    var allText = ""
    var recognizedNouns: Set<String> = []
    let frames: [RecognizedTextFrame] = observations.flatMap { observation -> [RecognizedTextFrame] in
      guard let topCandidate = observation.topCandidates(1).first else { return [] }
      let fullText = topCandidate.string
      let cleanedText = fullText.replacingOccurrences(
        of: "[^\\p{L}\\p{N}\\s]",
        with: "",
        options: .regularExpression
      )
      allText += cleanedText + " "

      var result: [RecognizedTextFrame] = []

      let tagger = NLTagger(tagSchemes: [.lexicalClass])
      tagger.string = fullText

      tagger.enumerateTags(in: fullText.startIndex..<fullText.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
        guard let tag = tag, (tag == .noun || tag == .organizationName) else { return true }

        let word = String(fullText[tokenRange])
        let rect = VNImageRectForNormalizedRect(observation.boundingBox, cgImage.width, cgImage.height)
        let convertedRect = CGRect(
          x: rect.origin.x / screenScale,
          y: (CGFloat(cgImage.height) - rect.origin.y - rect.height) / screenScale,
          width: rect.width / screenScale,
          height: rect.height / screenScale
        )
        let (inserted, _) = recognizedNouns.insert(word)
        if inserted {
          result.append(RecognizedTextFrame(text: word, frame: convertedRect))
        }
        return true
      }

      return result
    }

    return .init(text: allText.trimmingCharacters(in: .whitespacesAndNewlines), textFrames: frames)
  })
}
