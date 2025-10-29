//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI
import SimpleLogger
import Observation
import UniformTypeIdentifiers

/// A manager responsible for generating and exporting PDF documents from SwiftUI views.
///
/// `PDFManager` handles layout calculation, pagination, rendering, and file export for structured
/// PDF documents. It combines visual components (headers, content, and footers) into multi-page
/// PDF outputs with optional metadata and layout configuration.
@MainActor
@Observable
public final class PDFManager {

    /// A logging instance used for diagnostic or debugging purposes.
    @ObservationIgnored private let logger: SimpleLogger

    /// A structure representing the measured layout dimensions of a PDF page.
    ///
    /// This includes the height of the header, footer, and available content area.
    internal struct PageLayout {

        /// The rendered height of the page header.
        let headerHeight: CGFloat

        /// The rendered height of the page footer.
        let footerHeight: CGFloat

        /// The remaining vertical space available for content.
        let contentHeight: CGFloat
    }

    /// Creates a new instance of `PDFManager` with a default logging configuration.
    public init() {
        self.logger = SimpleLogger(category: .pdfProcessing)
        logger.info("PDFManager initialized")
    }
}

// MARK: - Public API

extension PDFManager {

    /// Exports a collection of renderable items into a multi-page PDF document.
    ///
    /// The method paginates content automatically based on available layout space
    /// and combines a header, content, and footer view for each page.
    ///
    /// - Parameters:
    ///   - items: The data elements to render into the PDF.
    ///   - config: The PDF layout configuration defining paper size and margins.
    ///   - metadata: Optional metadata to embed into the PDF file (e.g., title, author).
    ///   - header: A view builder returning the header for each page. Receives the current and total page numbers.
    ///   - content: A view builder rendering the main content from the provided items.
    ///   - footer: A view builder returning the footer for each page. Receives the current and total page numbers.
    ///
    /// - Returns: The URL of the generated PDF file, or `nil` if the export fails.
    public func export<T, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        _ items: [T],
        config: PDFConfiguration,
        metadata: PDFMetadata? = nil,
        @ViewBuilder header: @escaping (_ currentPage: Int, _ totalPages: Int) -> H,
        @ViewBuilder content: @escaping (_ items: [T]) -> C,
        @ViewBuilder footer: @escaping (_ currentPage: Int, _ totalPages: Int) -> F
    ) -> URL? {

        logger.info("Starting PDF export with \(items.count) items, paper size: \(config.paperSize.width)x\(config.paperSize.height)")

        guard !items.isEmpty else {
            logger.error("No items to export; skipping PDF generation.")
            return nil
        }

        let url = generateTempURL()
        let metadata = metadata ?? PDFMetadata()
        var box = CGRect(origin: .zero, size: config.paperSize)

        guard let pdf = createPDFContext(url: url, box: &box, metadata: metadata) else {
            logger.error("Failed to create PDF context")
            return nil
        }

        let layout = calculatePageLayout(
            config: config,
            header: header,
            footer: footer
        )

        let pages = paginateItems(
            items,
            availableWidth: config.maxContentWidth,
            availableHeight: layout.contentHeight,
            content: content
        )

        renderPages(
            pages: pages,
            pdf: pdf,
            config: config,
            header: header,
            content: content,
            footer: footer
        )

        pdf.closePDF()
        logger.info("PDF export complete: \(pages.count) pages written to \(url.lastPathComponent)")

        return url
    }
}

// MARK: - Private Methods

extension PDFManager {

    // MARK: URL Generation

    /// Creates a unique temporary file URL for the generated PDF.
    ///
    /// - Returns: A temporary `.pdf` file URL.
    internal func generateTempURL() -> URL {
        let url = URL.temporaryDirectory.appendingPathComponent(
            "\(UUID().uuidString).pdf",
            conformingTo: .pdf
        )
        logger.debug("Generated temporary PDF path: \(url.path(percentEncoded: false))")
        return url
    }

    // MARK: PDF Setup

    /// Creates a new PDF graphics context for rendering.
    ///
    /// - Parameters:
    ///   - url: The destination file URL for the PDF.
    ///   - box: The bounding rectangle defining the PDF page size.
    ///   - metadata: Optional metadata to embed in the PDF document.
    /// - Returns: A configured `CGContext` instance or `nil` if creation fails.
    internal func createPDFContext(
        url: URL,
        box: inout CGRect,
        metadata: PDFMetadata?
    ) -> CGContext? {
        let pdfMetadata = metadata?.asDictionary
        guard let context = CGContext(url as CFURL, mediaBox: &box, pdfMetadata) else {
            logger.error("Failed to create CGContext for PDF at \(url.lastPathComponent)")
            return nil
        }
        return context
    }

    // MARK: - Calculation Logic

    /// Measures the layout heights for the header, footer, and content areas of a PDF page.
    ///
    /// - Parameters:
    ///   - config: The PDF layout configuration defining available size and margins.
    ///   - header: A view builder returning the header view.
    ///   - footer: A view builder returning the footer view.
    /// - Returns: A `PageLayout` structure containing height metrics for layout computation.
    internal func calculatePageLayout<H: PDFHeader, F: PDFFooter>(
        config: PDFConfiguration,
        header: @escaping (_ currentPage: Int, _ totalPages: Int) -> H,
        footer: @escaping (_ currentPage: Int, _ totalPages: Int) -> F
    ) -> PageLayout {
        logger.debug("Calculating layout for paper size: \(config.paperSize.width)x\(config.paperSize.height)")

        let sampleHeader = header(1, 1)
        let sampleFooter = footer(1, 1)

        let headerHeight = sampleHeader.measureHeight(width: config.maxContentWidth)
        let footerHeight = sampleFooter.measureHeight(width: config.maxContentWidth)
        let contentHeight = config.maxContentHeight - headerHeight - footerHeight

        logger.debug("Calculated layout - header: \(headerHeight.rounded())")
        logger.debug("Calculated layout - content: \(contentHeight.rounded())")
        logger.debug("Calculated layout - footer: \(footerHeight.rounded())")

        return PageLayout(
            headerHeight: headerHeight,
            footerHeight: footerHeight,
            contentHeight: contentHeight
        )
    }

    /// Determines the maximum number of items that can fit on a single PDF page.
    ///
    /// Uses binary search to optimise layout measurement and reduce rendering overhead.
    ///
    /// - Parameters:
    ///   - items: The slice of items to evaluate.
    ///   - usableWidth: The width available for rendering content.
    ///   - usableHeight: The maximum vertical space for content.
    ///   - content: A view builder used to measure content height.
    /// - Returns: The maximum number of items that fit within the given height constraint.
    internal func maxItemsThatFitOnPage<T, C: PDFContent>(
        for items: ArraySlice<T>,
        usableWidth: CGFloat,
        usableHeight: CGFloat,
        content: @escaping (_ items: [T]) -> C
    ) -> Int {

        guard !items.isEmpty else {
            logger.info("Ignoring empty item array for pagination calculation.")
            return 0
        }

        var low = 1
        var high = items.count
        var bestFit = 1

        while low <= high {
            let mid = (low + high) / 2
            let candidate = Array(items.prefix(mid))
            let height = content(candidate).measureHeight(width: usableWidth)

            if height <= usableHeight {
                bestFit = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        logger.debug("Max items that fit: \(bestFit) of \(items.count) (height limit: \(usableHeight.rounded()))")

        return bestFit
    }

    // MARK: Pagination

    /// Divides an array of items into pages based on available layout space.
    ///
    /// - Parameters:
    ///   - items: The complete list of renderable items.
    ///   - availableWidth: The width available for content rendering.
    ///   - availableHeight: The vertical space available for each page’s content.
    ///   - content: A view builder used for measuring content height.
    /// - Returns: A two-dimensional array where each inner array represents one page of content.
    internal func paginateItems<T, C: PDFContent>(
        _ items: [T],
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        content: @escaping (_ items: [T]) -> C
    ) -> [[T]] {
        var remaining = ArraySlice(items)
        var pages: [[T]] = []

        while !remaining.isEmpty {
            let itemCount = maxItemsThatFitOnPage(
                for: remaining,
                usableWidth: availableWidth,
                usableHeight: availableHeight,
                content: content
            )
            let chunk = Array(remaining.prefix(itemCount))
            pages.append(chunk)
            remaining.removeFirst(itemCount)
        }

        logger.info("Pagination complete: \(pages.count) pages generated.")
        for (index, chunk) in pages.enumerated() {
            logger.debug("Page \(index + 1): \(chunk.count) items")
        }

        return pages
    }

    // MARK: - Rendering

    /// Renders all pages of a PDF document sequentially.
    ///
    /// - Parameters:
    ///   - pages: The grouped content items for each page.
    ///   - pdf: The current PDF drawing context.
    ///   - config: The layout configuration defining page size and margins.
    ///   - header: A view builder rendering each page’s header.
    ///   - content: A view builder rendering the page’s main content.
    ///   - footer: A view builder rendering each page’s footer.
    internal func renderPages<T, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        pages: [[T]],
        pdf: CGContext,
        config: PDFConfiguration,
        header: @escaping (_ currentPage: Int, _ totalPages: Int) -> H,
        content: @escaping (_ items: [T]) -> C,
        footer: @escaping (_ currentPage: Int, _ totalPages: Int) -> F
    ) {
        let totalPages = pages.count
        logger.info("Rendering \(pages.count) total pages.")

        for (index, chunk) in pages.enumerated() {
            let currentPage = index + 1

            logger.debug("Rendering page \(currentPage)/\(totalPages) with \(chunk.count) items")

            renderSinglePage(
                pdf: pdf,
                items: chunk,
                currentPage: currentPage,
                totalPages: totalPages,
                config: config,
                header: header,
                content: content,
                footer: footer
            )
        }
    }

    /// Renders a single PDF page with header, content, and footer.
    ///
    /// - Parameters:
    ///   - pdf: The active PDF graphics context.
    ///   - items: The renderable items for this page.
    ///   - currentPage: The current page index.
    ///   - totalPages: The total number of pages in the document.
    ///   - config: The PDF layout configuration.
    ///   - header: A view builder rendering the header.
    ///   - content: A view builder rendering the page’s main content.
    ///   - footer: A view builder rendering the footer.
    internal func renderSinglePage<T, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        pdf: CGContext,
        items: [T],
        currentPage: Int,
        totalPages: Int,
        config: PDFConfiguration,
        header: @escaping (_ currentPage: Int, _ totalPages: Int) -> H,
        content: @escaping (_ items: [T]) -> C,
        footer: @escaping (_ currentPage: Int, _ totalPages: Int) -> F
    ) {
        pdf.beginPDFPage(nil)
        logger.debug("Begin render for page \(currentPage)/\(totalPages)")

        let pageView = PDFPage {
            header(currentPage, totalPages)
        } content: {
            content(items)
        } footer: {
            footer(currentPage, totalPages)
        }
            .padding(config.paperMargin)
            .frame(width: config.paperSize.width, height: config.paperSize.height)

        let renderer = ImageRenderer(content: pageView)
        renderer.render { _, context in context(pdf) }

        pdf.endPDFPage()
        logger.debug("Completed render for page \(currentPage)/\(totalPages)")
    }
}
