import Foundation

public enum Localized {
  
}

public extension Localized {
  static let remember = NSLocalizedString("Remember", bundle: .module, comment: "No comment")
  static let title: LocalizedStringResource = "Cancel a Timer"
  static let subtitle: LocalizedStringResource = "Cancel"
}
