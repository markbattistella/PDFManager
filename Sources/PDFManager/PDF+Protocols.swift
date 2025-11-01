//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

// MARK: - Header

/// A view type that defines the header section for each page in a generated PDF. Conforming types
/// render content displayed at the top of each PDF page.
public protocol PDFHeader: View {

    /// The index of the page currently being rendered in the PDF output.
    ///
    /// Use this value to display page-specific information, such as a page number or contextual
    /// header content.
    var currentPage: Int { get }

    /// The total number of pages in the generated PDF document.
    ///
    /// Use this value in conjunction with `currentPage` to display pagination details, for
    /// example, “Page 1 of 10”.
    var totalPages: Int { get }
}

extension PDFHeader {

    /// Default implementation returning `0` when no page context is provided.
    var currentPage: Int { 0 }

    /// Default implementation returning `0` when total page count is unavailable.
    var totalPages: Int { 0 }
}

// MARK: - Body content

/// A view type that defines the main content section for a page in a generated PDF. Conforming
/// types render the core page body content.
public protocol PDFContent: View {
    associatedtype T: Identifiable
    init(items: [T])
}

// MARK: - Footer

/// A view type that defines the footer section for each page in a generated PDF. Conforming
/// types render content displayed at the bottom of each PDF page.
public protocol PDFFooter: View {

    /// The index of the page currently being rendered in the PDF output.
    ///
    /// Use this value to show dynamic or contextual footer content per page.
    var currentPage: Int { get }

    /// The total number of pages in the generated PDF document.
    ///
    /// Use this value to render pagination or document-wide context information.
    var totalPages: Int { get }
}
