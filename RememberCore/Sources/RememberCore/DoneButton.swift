import SwiftUI

public struct DoneButton: View {
  var title: String
  var isBold: Bool
  var action: () -> Void
  public init(title: String = "Done", isBold: Bool = true, action: @escaping () -> Void) {
    self.title = title
    self.isBold = isBold
    self.action = action
  }
  public var body: some View {
    if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
      Button(action: action) {
        Image(systemName: "checkmark")
      }
      .tint(Color.blue)
      .when(isBold, then: { $0.buttonStyle(.glassProminent) },
            else: { $0.buttonStyle(.plain) })
    } else {
      Button(title, action: action)
        .bold(isBold)
    }
  }
}
