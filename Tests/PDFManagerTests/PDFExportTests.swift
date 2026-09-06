import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import PDFManager

@Suite("PDF export regression tests")
@MainActor
struct PDFExportTests {
    private let manager = PDFManager()
    private let configuration = PDFConfiguration(
        paperSize: CGSize(width: 200, height: 200),
        paperMargin: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    )

    @Test("Repeated titles keep previously exported files intact")
    func repeatedTitlesKeepPreviousFiles() throws {
        let title = "Repeated title \(UUID().uuidString)"
        let first = try export(rows: [ExportRow(height: 50)], title: title)
        defer { removeExport(first) }
        let originalData = try Data(contentsOf: first)

        let second = try export(rows: [ExportRow(height: 50), ExportRow(height: 50)], title: title)
        defer { removeExport(second) }

        #expect(first != second)
        #expect(first.lastPathComponent == second.lastPathComponent)
        #expect(try Data(contentsOf: first) == originalData)
    }

    @Test("An item taller than the printable content area is rejected")
    func oversizedItemIsRejected() {
        #expect(throws: PDFExportError.renderingFailed) {
            let url = try export(rows: [ExportRow(height: 300)])
            removeExport(url)
        }
    }

    @Test("Pagination remeasures a header with the actual total page count")
    func headerUsesActualTotalPageCount() throws {
        let rows = (0..<5).map { _ in ExportRow(height: 60) }
        let url = try manager.export(
            rows,
            config: configuration,
            metadata: PDFMetadata(title: UUID().uuidString),
            header: { page, total in
                ExportHeader(height: total > 1 ? 80 : 20, currentPage: page, totalPages: total)
            },
            content: { ExportContent(items: $0) },
            footer: { _, _ in ExportFooter(height: 10) }
        )
        defer { removeExport(url) }

        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 5)
    }

    @Test("Pagination measures headers on later pages")
    func laterPageHeadersAreMeasured() throws {
        let url = try manager.export(
            (0..<5).map { _ in ExportRow(height: 60) },
            config: configuration,
            metadata: PDFMetadata(title: UUID().uuidString),
            header: { page, total in
                ExportHeader(height: page > 1 ? 80 : 20, currentPage: page, totalPages: total)
            },
            content: { ExportContent(items: $0) },
            footer: { _, _ in ExportFooter(height: 10) }
        )
        defer { removeExport(url) }

        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 5)
    }

    @Test("Pagination remeasures footers with the actual page count")
    func footerUsesActualTotalPageCount() throws {
        let url = try manager.export(
            (0..<5).map { _ in ExportRow(height: 60) },
            config: configuration,
            metadata: PDFMetadata(title: UUID().uuidString),
            header: { _, _ in ExportHeader(height: 10) },
            content: { ExportContent(items: $0) },
            footer: { page, total in
                ExportFooter(height: total > 1 ? 80 : 20, currentPage: page, totalPages: total)
            }
        )
        defer { removeExport(url) }

        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 5)
    }

    @Test("Unsupported encryption lengths cannot silently fall back to weaker encryption")
    func invalidEncryptionLengthIsRejected() {
        #expect(throws: PDFExportError.contextCreationFailed) {
            let url = try export(
                rows: [ExportRow(height: 50)],
                metadata: PDFMetadata(
                    title: UUID().uuidString,
                    ownerPassword: "owner-password",
                    userPassword: "reader-password",
                    encryptionKeyLength: 256
                )
            )
            removeExport(url)
        }
    }

    @Test("A password is never silently truncated")
    func overlongPasswordIsRejected() {
        #expect(throws: PDFExportError.contextCreationFailed) {
            let url = try export(
                rows: [ExportRow(height: 50)],
                metadata: PDFMetadata(
                    title: UUID().uuidString,
                    ownerPassword: String(repeating: "a", count: 40)
                )
            )
            removeExport(url)
        }
    }

    @Test("A user password without an owner password cannot produce an unprotected PDF")
    func userPasswordWithoutOwnerIsRejected() {
        #expect(throws: PDFExportError.contextCreationFailed) {
            let url = try export(
                rows: [ExportRow(height: 50)],
                metadata: PDFMetadata(title: UUID().uuidString, userPassword: "reader-password")
            )
            removeExport(url)
        }
    }

    @Test(
        "Requested permissions and passwords must be enforceable",
        arguments: [
            PDFMetadata(allowsPrinting: false),
            PDFMetadata(allowsCopying: false),
            PDFMetadata(ownerPassword: "", userPassword: "reader-password"),
            PDFMetadata(ownerPassword: "owner", userPassword: "invalid\0password"),
            PDFMetadata(ownerPassword: "caf\u{00E9}"),
        ]
    )
    func invalidSecuritySettingsAreRejected(metadata: PDFMetadata) {
        #expect(throws: PDFExportError.contextCreationFailed) {
            let url = try export(rows: [ExportRow(height: 50)], metadata: metadata)
            removeExport(url)
        }
    }

    @Test("Empty headers do not reserve phantom space")
    func emptyHeadersMeasureZero() {
        #expect(EmptyView().measureHeight(width: 180) == 0)
    }

    @Test("A full page of rows does not create another page", arguments: [1, 2, 3, 4])
    func rowPaginationPreservesPageBoundaries(count: Int) throws {
        let url = try export(rows: (0..<count).map { _ in ExportRow(height: 80) })
        defer { removeExport(url) }
        let document = try #require(CGPDFDocument(url as CFURL))

        #expect(document.numberOfPages == (count + 1) / 2)
        for number in 1...document.numberOfPages {
            let page = try #require(document.page(at: number))
            #expect(page.getBoxRect(.mediaBox) == CGRect(x: 0, y: 0, width: 200, height: 200))
        }
    }

    @Test("An encrypted PDF opens only with the supplied password")
    func passwordProtectedPDFOpens() throws {
        let url = try export(
            rows: [ExportRow(height: 50)],
            metadata: PDFMetadata(
                title: UUID().uuidString,
                ownerPassword: "owner-password",
                userPassword: "reader-password",
                allowsPrinting: false,
                allowsCopying: false
            )
        )
        defer { removeExport(url) }
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.isEncrypted)
        #expect(!document.isUnlocked)
        #expect(!document.unlockWithPassword("wrong-password"))
        #expect(document.unlockWithPassword("reader-password"))
        #expect(!document.allowsCopying)
        #expect(!document.allowsPrinting)
    }

    @Test(
        "Invalid paper dimensions and margins are rejected before rendering",
        arguments: [
            PDFConfiguration(paperSize: CGSize(width: 0, height: 200), paperMargin: EdgeInsets()),
            PDFConfiguration(paperSize: CGSize(width: 200, height: -1), paperMargin: EdgeInsets()),
            PDFConfiguration(paperSize: CGSize(width: CGFloat.infinity, height: 200), paperMargin: EdgeInsets()),
            PDFConfiguration(paperSize: CGSize(width: 200, height: CGFloat.nan), paperMargin: EdgeInsets()),
            PDFConfiguration(
                paperSize: CGSize(width: 200, height: 200),
                paperMargin: EdgeInsets(top: -1, leading: 0, bottom: 0, trailing: 0)
            ),
            PDFConfiguration(
                paperSize: CGSize(width: 200, height: 200),
                paperMargin: EdgeInsets(top: 100, leading: 0, bottom: 100, trailing: 0)
            ),
            PDFConfiguration(
                paperSize: CGSize(width: 200, height: 200),
                paperMargin: EdgeInsets(top: 0, leading: .infinity, bottom: 0, trailing: 0)
            ),
        ]
    )
    func invalidConfigurationIsRejected(config: PDFConfiguration) {
        #expect(throws: PDFExportError.renderingFailed) {
            let url = try manager.export(
                [ExportRow(height: 50)],
                config: config,
                header: { _, _ in ExportHeader(height: 10) },
                content: { ExportContent(items: $0) },
                footer: { _, _ in ExportFooter(height: 10) }
            )
            removeExport(url)
        }
    }

    @Test("Headers that consume the whole page are rejected")
    func oversizedHeaderIsRejected() {
        #expect(throws: PDFExportError.renderingFailed) {
            let url = try manager.export(
                [ExportRow(height: 50)],
                config: configuration,
                header: { _, _ in ExportHeader(height: 180) },
                content: { ExportContent(items: $0) },
                footer: { _, _ in ExportFooter(height: 10) }
            )
            removeExport(url)
        }
    }

    @Test("A failed final render removes its partial file and temporary directory")
    func failedRenderCleansUp() throws {
        let title = "Failed-render-\(UUID().uuidString)"
        var headerCalls = 0
        #expect(throws: PDFExportError.renderingFailed) {
            let url = try manager.export(
                [ExportRow(height: 50)],
                config: configuration,
                metadata: PDFMetadata(title: title),
                header: { _, _ in
                    headerCalls += 1
                    return ExportHeader(height: headerCalls > 1 ? 180 : 10)
                },
                content: { ExportContent(items: $0) },
                footer: { _, _ in ExportFooter(height: 10) }
            )
            removeExport(url)
        }
        let directories = try FileManager.default.contentsOfDirectory(
            at: .temporaryDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("PDFManager-") }
        let leftovers = directories.filter {
            FileManager.default.fileExists(atPath: $0.appending(path: "\(title).pdf").path())
        }
        defer { for directory in leftovers { try? FileManager.default.removeItem(at: directory) } }
        #expect(leftovers.isEmpty)
    }

    @Test("Page drawing preserves header, row, footer, margins, and watermark")
    func renderingPreservesSectionHeights() throws {
        let url = try manager.export(
            [ExportRow(height: 80)],
            config: configuration,
            metadata: PDFMetadata(title: UUID().uuidString),
            watermark: { AnyView(Color.black.frame(width: 20, height: 20)) },
            header: { _, _ in ExportHeader(height: 10) },
            content: { ExportContent(items: $0) },
            footer: { _, _ in ExportFooter(height: 10) }
        )
        defer { removeExport(url) }
        let document = try #require(CGPDFDocument(url as CFURL))
        let page = try #require(document.page(at: 1))
        let context = try #require(
            CGContext(
                data: nil,
                width: 200,
                height: 200,
                bitsPerComponent: 8,
                bytesPerRow: 800,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        context.drawPDFPage(page)
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)

        func rowsMatching(x: Int, red: UInt8, green: UInt8, blue: UInt8) -> Int {
            (0..<200).count { row in
                let offset = row * 800 + x * 4
                return data[offset] == red && data[offset + 1] == green && data[offset + 2] == blue
            }
        }
        #expect(rowsMatching(x: 50, red: 255, green: 0, blue: 0) == 10)
        #expect(rowsMatching(x: 50, red: 0, green: 255, blue: 0) == 80)
        #expect(rowsMatching(x: 50, red: 0, green: 0, blue: 255) == 10)
        #expect(rowsMatching(x: 50, red: 255, green: 255, blue: 255) == 100)
        #expect(rowsMatching(x: 100, red: 0, green: 0, blue: 0) == 20)
        #expect(rowsMatching(x: 5, red: 255, green: 255, blue: 255) == 200)
    }

    private func export(
        rows: [ExportRow],
        title: String = UUID().uuidString,
        metadata: PDFMetadata? = nil
    ) throws -> URL {
        try manager.export(
            rows,
            config: configuration,
            metadata: metadata ?? PDFMetadata(title: title),
            header: { _, _ in ExportHeader(height: 10) },
            content: { ExportContent(items: $0) },
            footer: { _, _ in ExportFooter(height: 10) }
        )
    }

    @Test("Nonisolated callers can await the main-actor exporter")
    nonisolated func exportFromNonisolatedCaller() async throws {
        let url = try await MainActor.run {
            try PDFManager().export(
                [ExportRow(height: 50)],
                config: PDFConfiguration(
                    paperSize: CGSize(width: 200, height: 200),
                    paperMargin: EdgeInsets()
                ),
                header: { _, _ in
                    MainActor.assertIsolated()
                    return ExportHeader(height: 10)
                },
                content: {
                    MainActor.assertIsolated()
                    return ExportContent(items: $0)
                },
                footer: { _, _ in
                    MainActor.assertIsolated()
                    return ExportFooter(height: 10)
                }
            )
        }
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 1)
    }

    @Test("Existing stored builder closures remain source compatible")
    func storedBuilderClosuresRemainCompatible() throws {
        let header: (Int, Int) -> ExportHeader = { _, _ in ExportHeader(height: 10) }
        let content: ([ExportRow]) -> ExportContent = { ExportContent(items: $0) }
        let footer: (Int, Int) -> ExportFooter = { _, _ in ExportFooter(height: 10) }
        let watermark: (() -> AnyView)? = { AnyView(Text("DRAFT")) }
        let url = try manager.export(
            [ExportRow(height: 50)],
            config: configuration,
            watermark: watermark,
            header: header,
            content: content,
            footer: footer
        )
        defer { removeExport(url) }
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages == 1)
    }

    private func removeExport(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        let directory = url.deletingLastPathComponent()
        if directory.lastPathComponent.hasPrefix("PDFManager-") {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private struct ExportRow: Identifiable, Sendable {
    let id = UUID()
    let height: CGFloat
}

private struct ExportHeader: PDFHeader {
    let height: CGFloat
    var currentPage = 1
    var totalPages = 1

    var body: some View {
        Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1).frame(height: height)
    }
}

private struct ExportFooter: PDFFooter {
    let height: CGFloat
    var currentPage = 1
    var totalPages = 1

    var body: some View {
        Color(.sRGB, red: 0, green: 0, blue: 1, opacity: 1).frame(height: height)
    }
}

private struct ExportContent: PDFContent {
    let items: [ExportRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { row in
                Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1).frame(height: row.height)
            }
        }
    }
}
