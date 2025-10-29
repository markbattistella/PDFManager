//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

extension View {

    /// Measures the rendered height of a SwiftUI view for a given width.
    ///
    /// This method uses an `ImageRenderer` to draw the view off-screen and determine its resulting
    /// height when constrained to a specified width. It is primarily used to calculate layout metrics
    /// for PDF rendering.
    ///
    /// - Parameter width: The fixed width used to measure the view’s height.
    /// - Returns: The rendered height of the view at the specified width.
    internal func measureHeight(width: CGFloat) -> CGFloat {
        var output: CGFloat = 0
        ImageRenderer(content: self.frame(width: width))
            .render { size, _ in output = size.height }
        return output
    }
}
