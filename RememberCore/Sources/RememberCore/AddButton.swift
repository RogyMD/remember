import SwiftUI

public struct AddButton: View {
  var action: () -> Void
  public init(action: @escaping () -> Void) {
    self.action = action
  }
  public var body: some View {
    if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
      Button {
        action()
      } label: {
        Image(systemName: "plus")
      }
      .tint(Color.blue)
      .buttonStyle(.glassProminent)
    } else {
      Button {
        action()
      } label: {
        Image(systemName: "plus")
      }
    }
  }
}
