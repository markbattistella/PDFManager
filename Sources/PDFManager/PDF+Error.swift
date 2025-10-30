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

extension PDFExportError: LocalizedError {

    /// A short, human-readable title suitable for use in alerts or logs.
    public var errorTitle: String {
        switch self {
            case .noItems:
                return "No Entries Found"
            case .contextCreationFailed:
                return "PDF Context Error"
            case .renderingFailed:
                return "Rendering Error"
        }
    }

    /// A descriptive message explaining the error.
    public var errorDescription: String? {
        switch self {
            case .noItems:
                return "There are no records available in the selected date range. Try choosing a different date or range to export."
            case .contextCreationFailed:
                return "The PDF export could not start because the rendering context failed to initialise."
            case .renderingFailed:
                return "An unexpected problem occurred while generating or paginating the PDF document."
        }
    }

    /// A short label suitable for developer logs or analytics.
    public var failureReason: String? {
        switch self {
            case .noItems:
                return "Empty data set"
            case .contextCreationFailed:
                return "Failed to create PDF context"
            case .renderingFailed:
                return "Rendering or pagination failure"
        }
    }

    /// Suggested recovery steps for the user, if applicable.
    public var recoverySuggestion: String? {
        switch self {
            case .noItems:
                return "Select a different date range that contains entries."
            case .contextCreationFailed:
                return "Check file permissions or try exporting again."
            case .renderingFailed:
                return "Try re-exporting or restarting the app."
        }
    }
}
