import SwiftUI

extension Button where Label == Image {
  public init(systemImage: String, action: @escaping () -> Void) {
    self.init(action: action, label: { Image(systemName: systemImage) })
  }
}
