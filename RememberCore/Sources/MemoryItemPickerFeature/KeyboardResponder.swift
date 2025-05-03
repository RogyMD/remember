import SwiftUI
import Combine

struct KeyboardAdaptive: ViewModifier {
  @StateObject private var keyboard = KeyboardResponder()
  @Binding var keyboardFrame: CGRect
  
  func body(content: Content) -> some View {
    content
      .onChange(of: keyboard.keyboardFrame) { oldValue, newValue in
        withAnimation(.linear(duration: keyboard.animationDuration)) {
          keyboardFrame = newValue
        }
      }
  }
}

final class KeyboardResponder: ObservableObject {
  @Published var keyboardFrame: CGRect = .zero
  @Published var animationDuration: TimeInterval = .zero
  
  var keyboardWillShowNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
  var keyboardWillChangeFrameNotification = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
  
  init() {
    keyboardWillChangeFrameNotification.compactMap { notification in
      (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)
    }
    .assign(to: \.keyboardFrame, on: self)
    .store(in: &cancellableSet)
    
    keyboardWillShowNotification.map { notification in
      (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0
    }
    .assign(to: \.animationDuration, on: self)
    .store(in: &cancellableSet)
  }
  
  private var cancellableSet: Set<AnyCancellable> = []
}
