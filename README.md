<!-- markdownlint-disable MD024 MD033 MD041 -->
<div align="center">

# PDFManager

![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarkbattistella%2FPDFManager%2Fbadge%3Ftype%3Dswift-versions)

![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmarkbattistella%2FPDFManager%2Fbadge%3Ftype%3Dplatforms)

![Licence](https://img.shields.io/badge/Licence-MIT-white?labelColor=blue&style=flat)

</div>

`PDFManager` is a Swift package that exports multi-page PDF documents directly from SwiftUI views. It handles layout measurement, automatic pagination, and file generation — letting you define header, content, and footer views declaratively and get a ready-to-share PDF in return.

## Features

- **SwiftUI-native:** Define pages using ordinary SwiftUI views — no UIKit or AppKit wrappers needed.
- **Automatic pagination:** Content is measured and split across pages based on available space.
- **Header and footer support:** Receive current and total page numbers in each header and footer view.
- **Watermark overlay:** Optionally overlay any view (e.g. a "DRAFT" stamp) across every page.
- **PDF metadata:** Embed title, author, subject, keywords, and encryption settings into the file.
- **Typed errors:** `PDFExportError` provides localised titles, descriptions, and recovery suggestions.

## Requirements

- Swift 6.0+
- iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+

## Installation

Add `PDFManager` to your Swift project using Swift Package Manager.

```swift
dependencies: [
  .package(url: "https://github.com/markbattistella/PDFManager", from: "1.0.8")
]
```

Then add it to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "PDFManager", package: "PDFManager")
    ]
)
```

## Usage

### 1. Define your data

Your data model must conform to `Identifiable`:

```swift
struct InvoiceLine: Identifiable {
    let id = UUID()
    let description: String
    let quantity: Int
    let unitPrice: Double
}
```

### 2. Implement the view protocols

Conform to `PDFHeader`, `PDFContent`, and `PDFFooter` to describe how each section looks.

#### Header

```swift
struct InvoiceHeader: PDFHeader {
    var currentPage: Int = 0
    var totalPages: Int = 0

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Invoice #1042")
                    .font(.title2.bold())
                Spacer()
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
        }
    }
}
```

#### Content

`PDFContent` requires an `init(items:)` initialiser. The supplied content builder is called repeatedly with candidate groups during measurement, then with the final items for each page. Keep builders deterministic and free of side effects. Their height must not decrease as more items are added, because pagination uses binary search.

```swift
struct InvoiceContent: PDFContent {
    typealias T = InvoiceLine
    let items: [InvoiceLine]

    init(items: [InvoiceLine]) {
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { line in
                HStack {
                    Text(line.description).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(line.quantity)").frame(width: 40, alignment: .trailing)
                    Text(line.unitPrice, format: .currency(code: "USD")).frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .padding(.vertical, 4)
                Divider()
            }
        }
    }
}
```

#### Footer

```swift
struct InvoiceFooter: PDFFooter {
    var body: some View {
        VStack(spacing: 4) {
            Divider()
            HStack {
                Text("Acme Corp — Confidential")
                Spacer()
                Text(Date.now, format: .dateTime.month().year())
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
```

### 3. Configure the PDF layout

`PDFConfiguration` defines the paper dimensions and margins (in points):

```swift
let config = PDFConfiguration(
    paperSize: CGSize(width: 595, height: 842),  // A4
    paperMargin: EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36)
)
```

### 4. Export

Create a `PDFManager` instance and call `export` on the main actor. Layout, view builders, and rendering are main-actor isolated. Export is synchronous: wrapping it in a `Task` does not move it off the main actor. `PDFConfiguration` and `PDFMetadata` are `Sendable` values.

The returned PDF is in a unique subdirectory of the system's temporary directory. Exports with the same title keep the same readable filename without overwriting previous files. Keep that directory while a preview or share operation needs the file, then remove it when you are finished.

```swift
@State private var manager = PDFManager()

func generatePDF() {
    do {
        let url = try manager.export(
            lines,
            config: config,
            metadata: PDFMetadata(title: "Invoice #1042"),
            header: { page, total in InvoiceHeader(currentPage: page, totalPages: total) },
            content: { items in InvoiceContent(items: items) },
            footer: { _, _ in InvoiceFooter() }
        )
        // Share or save the URL
    } catch {
        // Handle PDFExportError
    }
}
```

### Watermarks

Pass a closure returning `AnyView` to overlay a view on every page:

```swift
let url = try manager.export(
    lines,
    config: config,
    watermark: { AnyView(
        Text("DRAFT")
            .font(.system(size: 120, weight: .black))
            .foregroundStyle(.red.opacity(0.12))
            .rotationEffect(.degrees(-45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    )},
    header: { page, total in InvoiceHeader(currentPage: page, totalPages: total) },
    content: { items in InvoiceContent(items: items) },
    footer: { _, _ in InvoiceFooter() }
)
```

### Metadata and security

`PDFMetadata` lets you embed document information and optional access restrictions:

```swift
PDFMetadata(
    author: "Acme Corp",
    title: "Invoice #1042",
    subject: "Monthly services",
    keywords: "invoice, services, 2025",
    ownerPassword: "owner-secret",
    userPassword: "open-secret",
    allowsPrinting: true,
    allowsCopying: false,
    encryptionKeyLength: 128
)
```

All parameters are optional. By default the author is pulled from `CFBundleDisplayName` and printing and copying are both allowed.

An owner password is required when you request a user password or disable printing or copying. Core Graphics does not encrypt the document without an owner password, so PDFManager rejects those combinations instead of returning an unprotected file.

The underlying Core Graphics PDF API accepts ASCII passwords of at most 32 bytes. PDFManager rejects longer, non-ASCII, or NUL-containing passwords instead of allowing truncation or a context creation failure. An explicit encryption key length must be a multiple of eight between 40 and 128; PDFManager defaults to 128. Passing `nil` uses the Core Graphics default of 40. These are constraints of this PDF context API, not a general encryption recommendation. See Apple's [password documentation](https://developer.apple.com/documentation/coregraphics/kcgpdfcontextownerpassword) and [key-length documentation](https://developer.apple.com/documentation/coregraphics/kcgpdfcontextencryptionkeylength).

### Error handling

`PDFExportError` conforms to `LocalizedError` and provides:

| Case | Meaning |
| --- | --- |
| `.noItems` | The items array was empty |
| `.contextCreationFailed` | The temporary directory or PDF context could not be created, or password settings were invalid |
| `.renderingFailed` | Page geometry was invalid, content could not fit, or layout/rendering failed |

Each case exposes `errorTitle`, `errorDescription`, `failureReason`, and `recoverySuggestion` for use in alerts or logs.

```swift
} catch let error as PDFExportError {
    print(error.errorTitle)          // "No Entries Found"
    print(error.errorDescription!)   // "There are no records available..."
}
```

## Layout limits

- Paper dimensions must be finite and positive. Margins must be finite and nonnegative and leave a positive printable area.
- Header and footer heights are checked for each page at the actual page count. Pagination repeats if their required space grows, reserving the largest measured height for each section across all pages.
- An item taller than the remaining content area throws `.renderingFailed`. Split that item in your data or change the document layout; the exporter does not crop it or shrink it silently.
- Measurement and rendering use the same light colour scheme and printable width. Supply any additional environment settings consistently in your document views.
- Use eager stacks and already-loaded data and images. `ImageRenderer` cannot capture every view, including many web, media, UIKit, and AppKit views; unsupported content can produce a placeholder.
- Large documents still require main-actor layout and drawing. This API does not currently provide progress or asynchronous cancellation.

## Contributing

Contributions are always welcome! Feel free to submit a pull request or open an issue for any suggestions or improvements you have.

## License

`PDFManager` is licensed under the MIT License. See the LICENSE file for more details.
