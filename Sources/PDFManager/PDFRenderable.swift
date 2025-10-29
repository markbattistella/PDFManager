//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

// MARK: - Renderable

/// A type that can be rendered as part of a PDF document.
///
/// `PDFRenderable` combines the requirements of SwiftUI’s `View` protocol and `Hashable`,
/// ensuring that conforming types can both render visual content and be uniquely identified
/// within a PDF layout.
public protocol PDFRenderable: View, Hashable {}

// MARK: - Header

/// A type representing the header section of a PDF page.
///
/// `PDFHeader` conforms to `PDFRenderable` and provides metadata for pagination. Conforming types
/// define the content displayed at the top of each PDF page.
public protocol PDFHeader: PDFRenderable {

    /// The index of the current page being rendered.
    var currentPage: Int { get }

    /// The total number of pages in the PDF document.
    var totalPages: Int { get }
}

// MARK: - Body content

/// A type representing the main content section of a PDF page.
///
/// `PDFContent` conforms to `PDFRenderable` and defines the primary body area of
/// a generated PDF page.
public protocol PDFContent: PDFRenderable {}

// MARK: - Footer

/// A type representing the footer section of a PDF page.
///
/// `PDFFooter` conforms to `PDFRenderable` and provides metadata for pagination.
/// Conforming types define the content displayed at the bottom of each PDF page.
public protocol PDFFooter: PDFRenderable {

    /// The index of the current page being rendered.
    var currentPage: Int { get }

    /// The total number of pages in the PDF document.
    var totalPages: Int { get }
}
