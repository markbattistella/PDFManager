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
                return String(
                    localized: "No Entries Found",
                    bundle: .module, 
                    comment: "Error title shown when no data is available to export."
                )

            case .contextCreationFailed:
                return String(
                    localized: "PDF Context Error",
                    bundle: .module,
                    comment: "Error title shown when the PDF rendering context could not be created."
                )

            case .renderingFailed:
                return String(
                    localized: "Rendering Error",
                    bundle: .module,
                    comment: "Error title shown when PDF rendering or pagination fails."
                )
        }
    }

    /// A descriptive message explaining the error.
    public var errorDescription: String? {
        switch self {
            case .noItems:
                return String(
                    localized: "There are no records available in the selected date range. Try choosing a different date or range to export.",
                    bundle: .module,
                    comment: "Detailed explanation shown when the user tries to export with no data."
                )

            case .contextCreationFailed:
                return String(
                    localized: "The PDF export could not start because the rendering context failed to initialise.",
                    bundle: .module,
                    comment: "Detailed explanation shown when the PDF context cannot be created."
                )

            case .renderingFailed:
                return String(
                    localized: "An unexpected problem occurred while generating or paginating the PDF document.",
                    bundle: .module,
                    comment: "Detailed explanation shown when PDF rendering or pagination fails."
                )
        }
    }

    /// A short label suitable for developer logs or analytics.
    public var failureReason: String? {
        switch self {
            case .noItems:
                return String(
                    localized: "Empty data set",
                    bundle: .module,
                    comment: "Technical reason logged when export failed due to no data."
                )

            case .contextCreationFailed:
                return String(
                    localized: "Failed to create PDF context",
                    bundle: .module,
                    comment: "Technical reason logged when PDF context creation fails."
                )

            case .renderingFailed:
                return String(
                    localized: "Rendering or pagination failure",
                    bundle: .module,
                    comment: "Technical reason logged when rendering or pagination fails."
                )
        }
    }

    /// Suggested recovery steps for the user, if applicable.
    public var recoverySuggestion: String? {
        switch self {
            case .noItems:
                return String(
                    localized: "Select a different date range that contains entries.",
                    bundle: .module,
                    comment: "Suggestion shown when no data is available for export."
                )

            case .contextCreationFailed:
                return String(
                    localized: "Check file permissions or try exporting again.",
                    bundle: .module,
                    comment: "Suggestion shown when PDF context could not be created."
                )

            case .renderingFailed:
                return String(
                    localized: "Try re-exporting or restarting the app.",
                    bundle: .module,
                    comment: "Suggestion shown when PDF rendering fails."
                )
        }
    }
}
