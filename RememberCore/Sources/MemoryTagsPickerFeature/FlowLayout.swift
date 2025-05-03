import SwiftUI

struct FlowLayout: Layout {
  var horizontalSpacing: CGFloat
  var verticalSpacing: CGFloat
  
  init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
    self.horizontalSpacing = horizontalSpacing
    self.verticalSpacing = verticalSpacing
  }
  
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    var totalSize = CGSize.zero
    var currentLineWidth: CGFloat = 0
    var currentLineHeight: CGFloat = 0
    let maxWidth = proposal.width ?? .infinity
    
    for subview in subviews {
      let subviewSize = subview.sizeThatFits(.unspecified)
      if currentLineWidth + horizontalSpacing + subviewSize.width > maxWidth {
        // Move to next line
        totalSize.width = max(totalSize.width, currentLineWidth)
        totalSize.height += verticalSpacing + currentLineHeight
        currentLineWidth = subviewSize.width
        currentLineHeight = subviewSize.height
      } else {
        currentLineWidth += horizontalSpacing + subviewSize.width
        currentLineHeight = max(currentLineHeight, subviewSize.height)
      }
    }
    // Final line
    totalSize.width = max(totalSize.width, currentLineWidth)
    totalSize.height += verticalSpacing + currentLineHeight
    return totalSize
  }
  
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var currentLineHeight: CGFloat = 0
    
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX {
        // Wrap to next line
        x = bounds.minX
        y += verticalSpacing + currentLineHeight
        currentLineHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y),
                    proposal: .unspecified)
      x += horizontalSpacing + size.width
      currentLineHeight = max(currentLineHeight, size.height)
    }
  }
}
