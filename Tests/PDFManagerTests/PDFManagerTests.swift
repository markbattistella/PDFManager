//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import CoreGraphics
import SwiftUI
import Testing

@testable import PDFManager

@Suite("PDFManager")
struct PDFManagerTests {

  @Test("String sanitization replaces unsafe filename characters")
  func sanitizeURLReplacesUnsafeFilenameCharacters() {
    #expect(" Invoice/Report: Q1 ".sanitizeURL == "Invoice_Report_ Q1")
    #expect("safe-name".sanitizeURL == "safe-name")
    #expect("   ".sanitizeURL.isEmpty)
  }

  @Test("PDF extension normalization removes existing extension")
  func deletingPDFExtensionRemovesCaseInsensitiveExtension() {
    #expect("Report.pdf".deletingPDFExtension == "Report")
    #expect("Report.PDF".deletingPDFExtension == "Report")
    #expect("Report.final".deletingPDFExtension == "Report.final")
  }

  @Test("Generated temporary URLs normalize file names")
  @MainActor
  func generateTempURLNormalizesFileName() {
    let manager = PDFManager()

    let url = manager.generateTempURL(fileName: " Expense/Report.pdf ")

    #expect(url.deletingPathExtension().lastPathComponent == "Expense_Report")
    #expect(url.pathExtension == "pdf")
  }

  @Test("Configuration calculates usable content dimensions")
  func configurationCalculatesUsableContentDimensions() {
    let configuration = PDFConfiguration(
      paperSize: CGSize(width: 200, height: 300),
      paperMargin: EdgeInsets(top: 10, leading: 20, bottom: 30, trailing: 40)
    )

    #expect(configuration.maxContentWidth == 140)
    #expect(configuration.maxContentHeight == 260)
  }

  @Test("Metadata dictionary omits nil values and preserves false booleans")
  func metadataDictionaryOmitsNilValuesAndPreservesFalseBooleans() {
    let metadata = PDFMetadata(
      author: nil,
      creator: nil,
      title: "Quarterly Report",
      subject: nil,
      keywords: nil,
      ownerPassword: nil,
      userPassword: nil,
      allowsPrinting: false,
      allowsCopying: nil,
      encryptionKeyLength: nil
    )
    let dictionary = metadata.asDictionary as NSDictionary

    #expect(dictionary[kCGPDFContextTitle] as? String == "Quarterly Report")
    #expect(dictionary[kCGPDFContextAllowsPrinting] as? Bool == false)
    #expect(dictionary[kCGPDFContextAuthor] == nil)
    #expect(dictionary[kCGPDFContextAllowsCopying] == nil)
  }

  @Test("Export throws noItems for empty item collections")
  @MainActor
  func exportThrowsNoItemsForEmptyItems() {
    let manager = PDFManager()
    let configuration = PDFConfiguration(
      paperSize: CGSize(width: 200, height: 300),
      paperMargin: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    )

    #expect {
      _ = try manager.export(
        [PDFTestRow](),
        config: configuration,
        header: { _, _ in PDFTestHeader() },
        content: { items in PDFTestContent(items: items) },
        footer: { _, _ in PDFTestFooter() }
      )
    } throws: { error in
      error as? PDFExportError == .noItems
    }
  }
}

private struct PDFTestRow: Identifiable {
  let id = UUID()
}

private struct PDFTestHeader: PDFHeader {
  var body: some View {
    EmptyView()
  }
}

private struct PDFTestContent: PDFContent {
  typealias T = PDFTestRow

  let items: [PDFTestRow]

  init(items: [PDFTestRow]) {
    self.items = items
  }

  var body: some View {
    EmptyView()
  }
}

private struct PDFTestFooter: PDFFooter {
  var body: some View {
    EmptyView()
  }
}
