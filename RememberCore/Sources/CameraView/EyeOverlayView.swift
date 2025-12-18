import UIKit

final class EyeOverlayView: UIView {
  private let maskLayer = CAShapeLayer()
  private let outlineLayer = CAShapeLayer()

  private(set) var openness: CGFloat = 0 // 0...1
  private var didOpen = false

  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    isUserInteractionEnabled = false
    backgroundColor = UIColor.systemBackground

    // Mask: full rect minus eye-hole
    maskLayer.fillRule = .evenOdd
    layer.mask = maskLayer

    // Eye outline
    outlineLayer.fillColor = UIColor.clear.cgColor
    outlineLayer.strokeColor = UIColor.label.withAlphaComponent(0.6).cgColor
    outlineLayer.lineWidth = 4
    outlineLayer.lineJoin = .round
    outlineLayer.lineCap = .round
    layer.addSublayer(outlineLayer)

    setOpenness(0, animated: false)
    alpha = 1
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updatePaths(openness: openness)
  }

  // MARK: - Public API

  func setOpenness(_ value: CGFloat, animated: Bool, duration: CFTimeInterval = 0.55) {
    let clamped = max(0, min(1, value))
    if animated {
      animatePaths(from: openness, to: clamped, duration: duration)
    } else {
      openness = clamped
      updatePaths(openness: clamped)
    }
  }

  /// Opens the eye, then fades out and removes itself.
  func openAndDismiss(openDuration: CFTimeInterval = 0.6, fadeDelay: TimeInterval = 0.5, fadeDuration: TimeInterval = 0.4) {
    guard didOpen == false else { return }
    didOpen = true

    setOpenness(1, animated: true, duration: openDuration)

    UIView.animate(withDuration: fadeDuration, delay: fadeDelay, options: [.beginFromCurrentState, .curveEaseOut]) {
      self.transform = .init(scaleX: 4, y: 4)
      self.alpha = 0
    } completion: { _ in
      self.removeFromSuperview()
    }
  }

  // MARK: - Drawing

  private func updatePaths(openness: CGFloat) {
    maskLayer.frame = bounds
    outlineLayer.frame = bounds

    maskLayer.path = makeMaskPath(in: bounds, openness: openness).cgPath
    outlineLayer.path = makeOutlinePath(in: bounds, openness: openness).cgPath
  }

  private func animatePaths(from: CGFloat, to: CGFloat, duration: CFTimeInterval) {
    layoutIfNeeded()

    let fromMask = makeMaskPath(in: bounds, openness: from).cgPath
    let toMask = makeMaskPath(in: bounds, openness: to).cgPath

    let maskAnim = CABasicAnimation(keyPath: "path")
    maskAnim.fromValue = fromMask
    maskAnim.toValue = toMask
    maskAnim.duration = duration
    maskAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
    maskLayer.path = toMask
    maskLayer.add(maskAnim, forKey: "eyeMaskPath")

    let fromOutline = makeOutlinePath(in: bounds, openness: from).cgPath
    let toOutline = makeOutlinePath(in: bounds, openness: to).cgPath

    let outlineAnim = CABasicAnimation(keyPath: "path")
    outlineAnim.fromValue = fromOutline
    outlineAnim.toValue = toOutline
    outlineAnim.duration = duration
    outlineAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
    outlineLayer.path = toOutline
    outlineLayer.add(outlineAnim, forKey: "eyeOutlinePath")

    openness = to
  }

  private func makeMaskPath(in bounds: CGRect, openness: CGFloat) -> UIBezierPath {
    let full = UIBezierPath(rect: bounds)
    let hole = makeEyeLidPath(in: bounds, openness: openness)
    full.append(hole)
    full.usesEvenOddFillRule = true
    return full
  }

  private func makeOutlinePath(in bounds: CGRect, openness: CGFloat) -> UIBezierPath {
    makeEyeLidPath(in: bounds, openness: openness)
  }
  
  private func makeEyeLidPath(in bounds: CGRect, openness: CGFloat) -> UIBezierPath {
    let maxWidth = bounds.width - 32//min(bounds.width * 0.78, 340)
    let center = CGPoint(x: bounds.midX, y: bounds.midY)

    // Openness controls how “tall” the eyelids curve
    let o = max(0, min(1, openness))
    let minLift: CGFloat = 2
    let maxLift: CGFloat = maxWidth * 0.6
    let lift = minLift + (maxLift - minLift) * o

    let left = CGPoint(x: center.x - maxWidth / 2, y: center.y)
    let right = CGPoint(x: center.x + maxWidth / 2, y: center.y)

    // Control points: one above, one below -> gives you ( )
    let upperCP = CGPoint(x: center.x, y: center.y - lift)
    let lowerCP = CGPoint(x: center.x, y: center.y + lift)

    let path = UIBezierPath()
    path.move(to: left)
    path.addQuadCurve(to: right, controlPoint: upperCP)
    path.addQuadCurve(to: left, controlPoint: lowerCP)
    path.close()

    return path
  }

  private func makeEyeRect(in bounds: CGRect, openness: CGFloat) -> CGRect {
    let maxWidth = min(bounds.width * 0.72, 320)
    let minHeight: CGFloat = 6
    let maxHeight = maxWidth * 0.38

    let o = max(0, min(1, openness))
    let height = max(minHeight, maxHeight * o)

    return CGRect(
      x: bounds.midX - maxWidth / 2,
      y: bounds.midY - height / 2,
      width: maxWidth,
      height: height
    )
  }
}
