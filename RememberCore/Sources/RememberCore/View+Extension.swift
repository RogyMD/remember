import SwiftUI

public extension View {
  func frame(size: CGSize, alignment: Alignment = .center) -> some View {
    frame(width: size.width, height: size.height, alignment: alignment)
  }
  func disabledAnimation() -> some View {
    animation(nil, value: UUID())
  }
  @ViewBuilder
  func ifLet<V: View, T>(_ value: T?, @ViewBuilder apply: (Self, T) -> V) -> some View {
    if let value {
      apply(self, value)
    } else {
      self
    }
  }
  @ViewBuilder
  func when<V: View>(_ value: Bool, @ViewBuilder apply: (Self) -> V) -> some View {
    if value {
      apply(self)
    } else {
      self
    }
  }
  @ViewBuilder
  func when<V1: View, V2: View>(_ value: Bool, @ViewBuilder then: (Self) -> V1, `else`: (Self) -> V2) -> some View {
    if value {
      then(self)
    } else {
      `else`(self)
    }
  }
  @ViewBuilder
  func scrollableContent(_ scrollable: Bool = true) -> some View{
    if scrollable {
      ScrollView(.vertical) {
        self
      }
    } else {
      self
    }
  }
  @ViewBuilder
  func glassEffect(
    isInteractive: Bool = false,
    isClear: Bool = true,
    tint: Color? = nil,
    in shape: some Shape = Circle(),
    noGlassEffect: (Self) -> some View
  ) -> some View {
    if #available(iOS 26.0, *), #available(watchOS 26.0, *) {
      glassEffect(
        isClear ? .clear.interactive(isInteractive).tint(tint) : .regular.interactive(isInteractive).tint(tint),
        in: shape
      )
    } else {
      noGlassEffect(self)
    }
  }
}

#if os(iOS)
import UIKit

public extension View {
  func onReceiveApplicationDidBecomeActionNotification(_ run: @escaping () -> Void) -> some View {
    onReceive(NotificationCenter.default.publisher(
      for: UIApplication.didBecomeActiveNotification)
    ) { _ in run() }
  }
  
  func textFieldClearButtonMode(_ mode: UITextField.ViewMode) -> some View {
    when(mode != UITextField.appearance().clearButtonMode) {
      $0.onAppear {
        UITextField.appearance().clearButtonMode = mode
      }
    }
  }
}
#endif
