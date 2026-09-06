//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import Observation
import SimpleLogger
import SwiftUI
import UniformTypeIdentifiers

/// Generates PDF documents by measuring and rendering SwiftUI views on the main actor.
///
/// Export is synchronous. Content builders must provide fully loaded, deterministic views whose
/// height does not decrease when more items are added. Items are kept together on each page;
/// an item that cannot fit on a page causes export to throw rather than silently lose content.
@MainActor
@Observable
public final class PDFManager {
    @ObservationIgnored
    private let logger: SimpleLogger

    /// Space reserved for each section, shared by every page in one export.
    internal struct PageLayout: Sendable {
        let headerHeight: CGFloat
        let footerHeight: CGFloat
        let contentHeight: CGFloat
    }

    public init() {
        self.logger = SimpleLogger(category: .pdfProcessing)
        logger.info("PDFManager initialized")
    }
}

// MARK: - Public API

extension PDFManager {
    /// Exports items to a PDF with repeating headers, footers, and an optional watermark.
    ///
    /// Layout is measured at the printable width in a light colour scheme. Header and footer
    /// builders receive one-based page numbers and the final page count. They may be evaluated
    /// more than once while pagination settles. Content builders are also evaluated repeatedly
    /// to find the largest prefix of items that fits each page.
    ///
    /// - Parameters:
    ///   - items: The identifiable data elements to render.
    ///   - config: Paper dimensions and nonnegative margins, expressed in points.
    ///   - metadata: Optional document information and password settings.
    ///   - watermark: An optional view overlaid across the entire page.
    ///   - header: A builder for each page's header.
    ///   - content: A builder for a candidate group of items or a final page of content.
    ///   - footer: A builder for each page's footer.
    /// - Returns: A PDF URL in a unique temporary directory. Repeated titles retain the same
    ///   filename but never overwrite a previously returned export. The caller owns cleanup.
    /// - Throws: `noItems` for an empty collection, `renderingFailed` for invalid or overflowing
    ///   layouts, or `contextCreationFailed` when the file or PDF context cannot be created.
    public func export<T: Identifiable, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        _ items: [T],
        config: PDFConfiguration,
        metadata: PDFMetadata? = nil,
        watermark: (() -> AnyView)? = nil,
        @ViewBuilder header: @escaping (_ currentPage: Int, _ totalPages: Int) -> H,
        @ViewBuilder content: @escaping (_ items: [T]) -> C,
        @ViewBuilder footer: @escaping (_ currentPage: Int, _ totalPages: Int) -> F
    ) throws(PDFExportError) -> URL where C.T == T {
        guard !items.isEmpty else {
            throw .noItems
        }
        guard config.isValid else {
            logger.error("Paper size and margins must leave a finite, positive printable area")
            throw .renderingFailed
        }

        let metadata = metadata ?? PDFMetadata()
        guard metadata.hasValidSecuritySettings else {
            logger.error("Unsupported PDF password or encryption key length")
            throw .contextCreationFailed
        }

        let (pages, layout) = try preparePages(
            items,
            config: config,
            header: header,
            content: content,
            footer: footer
        )

        let url = generateTempURL(fileName: metadata.title)
        let directory = url.deletingLastPathComponent()
        var succeeded = false
        defer {
            if !succeeded {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        catch {
            logger.error("Failed to create the temporary export directory")
            throw .contextCreationFailed
        }

        var box = CGRect(origin: .zero, size: config.paperSize)
        guard let pdf = createPDFContext(url: url, box: &box, metadata: metadata) else {
            throw .contextCreationFailed
        }
        // Registered after directory cleanup so the context closes before a failed file is removed.
        defer { pdf.closePDF() }

        try renderPages(
            pages: pages,
            pdf: pdf,
            config: config,
            layout: layout,
            watermark: watermark,
            header: header,
            content: content,
            footer: footer
        )

        succeeded = true
        logger.info("PDF export complete: \(pages.count) pages at \(url.lastPathComponent)")
        return url
    }
}

// MARK: - File creation

extension PDFManager {
    /// Creates a unique path without creating a file or directory.
    ///
    /// Keeping the title in the filename makes sharing useful while a unique parent directory
    /// prevents later exports with the same title from overwriting earlier files.
    internal func generateTempURL(fileName: String? = nil) -> URL {
        let baseName: String
        if let name = fileName?.sanitizeURL.deletingPDFExtension, !name.isEmpty {
            baseName = name
        }
        else {
            baseName = UUID().uuidString
        }

        return URL.temporaryDirectory
            .appending(path: "PDFManager-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appendingPathComponent("\(baseName).pdf", conformingTo: .pdf)
    }

    internal func createPDFContext(
        url: URL,
        box: inout CGRect,
        metadata: PDFMetadata?
    ) -> CGContext? {
        CGContext(url as CFURL, mediaBox: &box, metadata?.asDictionary)
    }
}

// MARK: - Measurement and pagination

extension PDFManager {
    /// Repeats pagination when the actual page count changes header or footer sizes.
    ///
    /// Reservations only grow between passes, preventing a layout that alternates between two
    /// page counts. There can be at most one page per item before an oversized item is rejected.
    private func preparePages<T: Identifiable, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        _ items: [T],
        config: PDFConfiguration,
        header: (Int, Int) -> H,
        content: ([T]) -> C,
        footer: (Int, Int) -> F
    ) throws(PDFExportError) -> ([[T]], PageLayout) where C.T == T {
        var totalPages = 1
        var headerHeight: CGFloat = 0
        var footerHeight: CGFloat = 0

        for _ in 0..<items.count {
            let measured = try calculatePageLayout(
                config: config,
                totalPages: totalPages,
                header: header,
                footer: footer
            )
            headerHeight = max(headerHeight, measured.headerHeight)
            footerHeight = max(footerHeight, measured.footerHeight)
            let contentHeight = config.maxContentHeight - headerHeight - footerHeight
            guard contentHeight.isFinite, contentHeight > 0 else {
                throw .renderingFailed
            }
            let layout = PageLayout(
                headerHeight: headerHeight,
                footerHeight: footerHeight,
                contentHeight: contentHeight
            )
            let pages = try paginateItems(
                items,
                availableWidth: config.maxContentWidth,
                availableHeight: contentHeight,
                content: content
            )
            if pages.count == totalPages {
                return (pages, layout)
            }
            guard pages.count > totalPages else {
                logger.error("Content measurement changed unexpectedly between pagination passes")
                throw .renderingFailed
            }
            totalPages = pages.count
        }

        throw .renderingFailed
    }

    /// Measures the tallest header and footer across the proposed page count.
    internal func calculatePageLayout<H: PDFHeader, F: PDFFooter>(
        config: PDFConfiguration,
        totalPages: Int = 1,
        header: (Int, Int) -> H,
        footer: (Int, Int) -> F
    ) throws(PDFExportError) -> PageLayout {
        guard totalPages > 0 else { throw .renderingFailed }
        var headerHeight: CGFloat = 0
        var footerHeight: CGFloat = 0

        for page in 1...totalPages {
            let measuredHeader = header(page, totalPages).measureHeight(width: config.maxContentWidth)
            let measuredFooter = footer(page, totalPages).measureHeight(width: config.maxContentWidth)
            guard measuredHeader.isFinite, measuredHeader >= 0,
                measuredFooter.isFinite, measuredFooter >= 0
            else {
                throw .renderingFailed
            }
            headerHeight = max(headerHeight, measuredHeader)
            footerHeight = max(footerHeight, measuredFooter)
        }

        let contentHeight = config.maxContentHeight - headerHeight - footerHeight
        guard contentHeight.isFinite, contentHeight > 0 else {
            logger.error("Headers and footers leave no room for content")
            throw .renderingFailed
        }
        return PageLayout(
            headerHeight: headerHeight,
            footerHeight: footerHeight,
            contentHeight: contentHeight
        )
    }

    /// Finds the largest fitting prefix using binary search.
    ///
    /// The content's measured height must be nondecreasing as items are added. A zero result means
    /// that even the first item cannot fit; the caller must reject it instead of forcing it onto a page.
    internal func maxItemsThatFitOnPage<T: Identifiable, C: PDFContent>(
        for items: ArraySlice<T>,
        usableWidth: CGFloat,
        usableHeight: CGFloat,
        content: ([T]) -> C
    ) throws(PDFExportError) -> Int where C.T == T {
        guard usableWidth.isFinite, usableWidth > 0,
            usableHeight.isFinite, usableHeight > 0
        else {
            throw .renderingFailed
        }
        guard !items.isEmpty else { return 0 }

        var low = 1
        var high = items.count
        var bestFit = 0

        while low <= high {
            let mid = low + (high - low) / 2
            let height = content(Array(items.prefix(mid))).measureHeight(width: usableWidth)
            guard height.isFinite, height >= 0 else { throw .renderingFailed }
            if height <= usableHeight {
                bestFit = mid
                low = mid + 1
            }
            else {
                high = mid - 1
            }
        }
        return bestFit
    }

    internal func paginateItems<T: Identifiable, C: PDFContent>(
        _ items: [T],
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        content: ([T]) -> C
    ) throws(PDFExportError) -> [[T]] where C.T == T {
        var remaining = ArraySlice(items)
        var pages: [[T]] = []

        while !remaining.isEmpty {
            let count = try maxItemsThatFitOnPage(
                for: remaining,
                usableWidth: availableWidth,
                usableHeight: availableHeight,
                content: content
            )
            guard count > 0 else {
                logger.error("An item is taller than the available content area")
                throw .renderingFailed
            }
            pages.append(Array(remaining.prefix(count)))
            remaining.removeFirst(count)
        }
        return pages
    }
}

// MARK: - Rendering

extension PDFManager {
    internal func renderPages<T: Identifiable, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        pages: [[T]],
        pdf: CGContext,
        config: PDFConfiguration,
        layout: PageLayout,
        watermark: (() -> AnyView)? = nil,
        header: (Int, Int) -> H,
        content: ([T]) -> C,
        footer: (Int, Int) -> F
    ) throws(PDFExportError) where C.T == T {
        for (index, chunk) in pages.enumerated() {
            try renderSinglePage(
                pdf: pdf,
                items: chunk,
                currentPage: index + 1,
                totalPages: pages.count,
                config: config,
                layout: layout,
                watermark: watermark,
                header: header,
                content: content,
                footer: footer
            )
        }
    }

    internal func renderSinglePage<T: Identifiable, H: PDFHeader, F: PDFFooter, C: PDFContent>(
        pdf: CGContext,
        items: [T],
        currentPage: Int,
        totalPages: Int,
        config: PDFConfiguration,
        layout: PageLayout,
        watermark: (() -> AnyView)? = nil,
        header: (Int, Int) -> H,
        content: ([T]) -> C,
        footer: (Int, Int) -> F
    ) throws(PDFExportError) where C.T == T {
        let pageHeader = header(currentPage, totalPages)
        let pageContent = content(items)
        let pageFooter = footer(currentPage, totalPages)

        // Check the final views too: a builder must not grow after pagination and be silently clipped.
        let heights = [
            (pageHeader.measureHeight(width: config.maxContentWidth), layout.headerHeight),
            (pageContent.measureHeight(width: config.maxContentWidth), layout.contentHeight),
            (pageFooter.measureHeight(width: config.maxContentWidth), layout.footerHeight),
        ]
        guard heights.allSatisfy({ $0.0.isFinite && $0.0 >= 0 && $0.0 <= $0.1 }) else {
            throw .renderingFailed
        }

        let page = PDFPage(layout: layout) {
            pageHeader
        } content: {
            pageContent
        } footer: {
            pageFooter
        }
        .padding(config.paperMargin)
        .frame(width: config.paperSize.width, height: config.paperSize.height)
        .overlay {
            if let watermark {
                watermark().allowsHitTesting(false)
            }
        }
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: page)
        var didRender = false
        renderer.render { size, draw in
            guard size.width.isFinite, size.width > 0,
                size.height.isFinite, size.height > 0
            else { return }
            pdf.beginPDFPage(nil)
            pdf.saveGState()
            draw(pdf)
            pdf.restoreGState()
            pdf.endPDFPage()
            didRender = true
        }
        guard didRender else { throw .renderingFailed }
    }
}
