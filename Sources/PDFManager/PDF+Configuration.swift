//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

/// A structure that defines the configuration parameters for generating a PDF document.
///
/// `PDFConfiguration` specifies the paper dimensions and margins used when rendering PDF content.
/// It provides convenience properties for determining the maximum usable content area within the
/// defined paper size and margins.
public struct PDFConfiguration {
    
    /// The full dimensions of the PDF page, in points.
    internal let paperSize: CGSize

    /// The margin insets applied to the PDF page, defining the printable area.
    internal let paperMargin: EdgeInsets

    /// Creates a new PDF configuration with the specified paper size and margins.
    ///
    /// - Parameters:
    ///   - paperSize: The total dimensions of the PDF page, in points.
    ///   - paperMargin: The margins applied to the page content area.
    public init(paperSize: CGSize, paperMargin: EdgeInsets) {
        self.paperSize = paperSize
        self.paperMargin = paperMargin
    }
}

extension PDFConfiguration {
    
    /// The maximum vertical space available for content after subtracting the top and bottom
    /// margins.
    internal var maxContentHeight: CGFloat {
        paperSize.height - (paperMargin.top + paperMargin.bottom)
    }
    
    /// The maximum horizontal space available for content after subtracting the leading and
    /// trailing margins.
    internal var maxContentWidth: CGFloat {
        paperSize.width - (paperMargin.leading + paperMargin.trailing)
    }
}
