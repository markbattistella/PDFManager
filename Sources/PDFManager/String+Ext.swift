//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import Foundation

extension String {

  /// Returns a filesystem-safe version of the string by replacing characters that are invalid
  /// in file names with underscores and trimming whitespace.
  internal var sanitizeURL: String {
    guard !isEmpty else { return self }
    let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let cleaned = components(separatedBy: invalidChars).joined(separator: "_")
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Returns the string without a trailing `.pdf` extension, preserving other filename content.
  internal var deletingPDFExtension: String {
    guard lowercased().hasSuffix(".pdf") else { return self }
    return String(dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
