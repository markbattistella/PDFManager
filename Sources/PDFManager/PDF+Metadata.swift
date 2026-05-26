//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

/// A structure that encapsulates metadata and security settings for a generated PDF document.
///
/// `PDFMetadata` defines descriptive information (such as author, title, and subject) and optional
/// access restrictions (such as passwords and printing or copying permissions) to be embedded
/// into a PDF file.
public struct PDFMetadata: Sendable {

  /// The name of the document’s author.
  internal let author: String?

  /// The name of the application or process that created the PDF.
  internal let creator: String?

  /// The title of the PDF document.
  internal let title: String?

  /// A brief description or subject of the document’s content.
  internal let subject: String?

  /// A list of keywords associated with the document, used for indexing or searching.
  internal let keywords: String?

  /// The password required for full access to the document, including permission changes.
  internal let ownerPassword: String?

  /// The password required for opening the document with restricted access.
  internal let userPassword: String?

  /// Indicates whether the PDF allows printing when opened.
  internal let allowsPrinting: Bool?

  /// Indicates whether the PDF allows content copying when opened.
  internal let allowsCopying: Bool?

  /// The encryption key length (in bits) used to secure the PDF.
  internal let encryptionKeyLength: Int?

  /// Creates a new PDF metadata configuration with optional descriptive and security properties.
  ///
  /// - Parameters:
  ///   - author: The author name. Defaults to the app display name if available.
  ///   - creator: The process or app responsible for PDF generation.
  ///   - title: The title of the document.
  ///   - subject: The subject or description of the document.
  ///   - keywords: Comma-separated keywords for indexing or searching.
  ///   - ownerPassword: A password granting full access rights to the PDF.
  ///   - userPassword: A password required for opening the PDF with limited access.
  ///   - allowsPrinting: A Boolean indicating whether printing is permitted.
  ///   - allowsCopying: A Boolean indicating whether content copying is permitted.
  ///   - encryptionKeyLength: The bit length of the encryption key.
  public init(
    author: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
    creator: String? = "PDFManager by Mark Battistella",
    title: String? = nil,
    subject: String? = nil,
    keywords: String? = nil,
    ownerPassword: String? = nil,
    userPassword: String? = nil,
    allowsPrinting: Bool? = true,
    allowsCopying: Bool? = true,
    encryptionKeyLength: Int? = 128
  ) {
    self.author = author
    self.creator = creator
    self.title = title
    self.subject = subject
    self.keywords = keywords
    self.ownerPassword = ownerPassword
    self.userPassword = userPassword
    self.allowsPrinting = allowsPrinting
    self.allowsCopying = allowsCopying
    self.encryptionKeyLength = encryptionKeyLength
  }
}

extension PDFMetadata {

  /// Returns the metadata as a Core Foundation dictionary suitable for use with PDF context
  /// creation.
  ///
  /// Keys correspond to Core Graphics PDF context constants (e.g., `kCGPDFContextAuthor`,
  /// `kCGPDFContextTitle`).
  internal var asDictionary: CFDictionary {
    let values: [CFString: Any?] = [
      kCGPDFContextAuthor: author,
      kCGPDFContextCreator: creator,
      kCGPDFContextTitle: title,
      kCGPDFContextSubject: subject,
      kCGPDFContextKeywords: keywords,
      kCGPDFContextOwnerPassword: ownerPassword,
      kCGPDFContextUserPassword: userPassword,
      kCGPDFContextAllowsPrinting: allowsPrinting,
      kCGPDFContextAllowsCopying: allowsCopying,
      kCGPDFContextEncryptionKeyLength: encryptionKeyLength,
    ]
    return values.compactMapValues { $0 } as CFDictionary
  }
}
