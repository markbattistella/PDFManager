//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import Foundation

/// Errors that can occur during the PDF export process.
///
/// The `PDFExportError` enumeration defines failure cases thrown by the
/// ``PDFManager/export(_:config:metadata:header:content:footer:)`` method when PDF generation
/// cannot complete successfully.
public enum PDFExportError: Error {

    /// Indicates that the export was attempted with an empty data set.
    ///
    /// This error occurs when no items are available to render into the PDF.
    case noItems

    /// Indicates that the Core Graphics PDF context could not be created.
    ///
    /// This may occur due to invalid file paths, insufficient permissions,
    /// or internal Core Graphics errors.
    case contextCreationFailed

    /// Indicates that the PDF rendering or pagination process failed.
    ///
    /// This is typically thrown if page generation or drawing could not complete.
    case renderingFailed
}
