import SwiftUI

public struct CancelButton: View {
  var title: String
  var action: () -> Void
  public init(title: String = "Cancel", action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }
  public var body: some View {
    if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
      Button(role: .cancel, action: action) {
        Image(systemName: "multiply")
      }
      .accessibilityAction(.escape, action)
    } else {
      Button(title, role: .cancel, action: action)
        .accessibilityAction(.escape, action)
    }
  }
}
