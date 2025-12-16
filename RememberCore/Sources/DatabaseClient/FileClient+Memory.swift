import FileClient
import RememberCore
import Foundation
import UIKit
import IssueReporting

struct MemoryFile: Equatable, Codable {
  var id: String
  var created: String
  var items: [String]?
  var tags: [String]?
  var location: [String: Double]?
  var notes: String?
  var detectedTextInPhoto: String?
  init(memory: Memory) {
    id = memory.id
    created = Self.dateFormatter.string(from: memory.created)
    items = memory.items.nonEmpty?.map(\.name)
    tags = memory.tags.nonEmpty?.map(\.label)
    notes = memory.notes.nonEmpty
    location = memory.location.map({ location in
      ["latitude": location.lat, "longitude": location.long]
    })
    detectedTextInPhoto = memory.recognizedText?.text
  }
  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
  }()
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()
}

extension FileClient {
  @discardableResult
  func saveMemory(_ memory: Memory, image: UIImage, previewImage: UIImage) async throws -> Bool {
    let memoryFile = MemoryFile(memory: memory)
    let data = try MemoryFile.encoder.encode(memoryFile)
    createFile(data, memory.textFileURL, true)
    createFile(image.jpegData(compressionQuality: 0.8), memory.originalImageURL, true)
    createFile(previewImage.jpegData(compressionQuality: 0.8), memory.previewImageURL, true)
    if let thumbnailImage = await previewImage.thumbnailImage() {
      createFile(thumbnailImage.pngData(), memory.thumbnailImageURL, true)
      return true
    } else {
      reportIssue("Couldn't generate thumbnail for image: \(previewImage)")
      return false
    }
  }
}
