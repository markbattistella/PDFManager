//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI


/// A container view representing a single PDF page with a header, content area, and footer.
///
/// `PDFPage` composes three view sections—`header`, `content`, and `footer`—to render a complete
/// PDF page layout. Each section is supplied using a SwiftUI view builder closure.
///
/// - Note: `PDFPage` is intended for internal PDF rendering and layout composition.
internal struct PDFPage<Header: PDFHeader, Content: PDFContent, Footer: PDFFooter>: View {

    /// A closure returning the header view for the PDF page.
    private let header: () -> Header

    /// A closure returning the main content view for the PDF page.
    private let content: () -> Content

    /// A closure returning the footer view for the PDF page.
    private let footer: () -> Footer

    /// Creates a PDF page layout composed of a header, content, and footer.
    ///
    /// - Parameters:
    ///   - header: A view builder providing the page header.
    ///   - content: A view builder providing the main page content.
    ///   - footer: A view builder providing the page footer.
    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.header = header
        self.content = content
        self.footer = footer
    }

    /// The content and layout composition of the PDF page.
    var body: some View {
        PDFPageLayout {
            Section {
                content()
            } header: {
                header()
            } footer: {
                footer()
            }
        }
    }
}

/// A layout container that vertically arranges a header, content, and footer section for PDF
/// rendering.
///
/// `PDFPageLayout` manages layout spacing and environment configuration for rendering consistent,
/// light-mode PDF output.
private struct PDFPageLayout<Content: View>: View {

    /// A view builder defining the complete page content, including sections.
    @ViewBuilder var content: () -> Content

    /// The structured vertical layout of the page sections.
    var body: some View {
        VStack(spacing: 0) {
            Group(sections: content()) { sections in
                ForEach(sections) { section in
                    section.header
                    section.content
                    Spacer(minLength: 0)
                    section.footer
                }
            }
        }
        .environment(\.colorScheme, .light)
    }
}
