import UIKit

class FocusTargetView: UIView {
  
  let color: UIColor = .green
  
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.sublayers?.forEach { $0.removeFromSuperlayer() } // Clean up
    
    drawDottedCircle()
    drawCenterDot()
  }
  
  private func drawDottedCircle() {
    let radius: CGFloat = 60
    let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
    let circlePath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
    
    
    let shape = CAShapeLayer()
    shape.path = circlePath.cgPath
    shape.strokeColor = color.cgColor
    shape.fillColor = nil
    shape.lineDashPattern = [3, 4]
    shape.lineWidth = 2
    
    layer.addSublayer(shape)
  }
  
  private func drawCenterDot() {
    let dotRadius: CGFloat = 5
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let dotPath = UIBezierPath(arcCenter: center, radius: dotRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
    
    let dot = CAShapeLayer()
    dot.path = dotPath.cgPath
    dot.fillColor = color.cgColor
    dot.strokeColor = nil
    
    layer.addSublayer(dot)
  }
}
