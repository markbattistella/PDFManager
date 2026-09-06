//
// Project: PDFManagerExample
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI
import PDFManager

// MARK: - Data model

fileprivate struct ExpenseEntry: Identifiable {
    nonisolated let id = UUID()
    let date: Date
    let description: String
    let category: String
    let amount: Double
}

// MARK: - PDF Header

fileprivate struct ExpenseReportHeader: PDFHeader {
    var currentPage: Int = 0
    var totalPages: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expense Report")
                        .font(.title2.bold())
                    Text(Date.now, format: .dateTime.month(.wide).year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
        }
    }
}

// MARK: - PDF Content

fileprivate struct ExpenseReportContent: PDFContent {
    typealias T = ExpenseEntry
    let items: [ExpenseEntry]

    init(items: [ExpenseEntry]) {
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Date")
                    .frame(width: 70, alignment: .leading)
                Text("Category")
                    .frame(width: 100, alignment: .leading)
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Amount")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.caption.bold())
            .padding(.vertical, 6)
            Divider()

            ForEach(items) { entry in
                HStack {
                    Text(entry.date, format: .dateTime.month(.abbreviated).day())
                        .frame(width: 70, alignment: .leading)
                    Text(entry.category)
                        .frame(width: 100, alignment: .leading)
                    Text(entry.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.amount, format: .currency(code: "USD"))
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
                .padding(.vertical, 5)
                Divider()
            }
        }
    }
}

// MARK: - PDF Footer

fileprivate struct ExpenseReportFooter: PDFFooter {
    var body: some View {
        VStack(spacing: 4) {
            Divider()
            HStack {
                Text("PDFManager — Example App")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Confidential")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Watermark

fileprivate struct DraftWatermark: View {
    var body: some View {
        Text("DRAFT")
            .font(.system(size: 120, weight: .black))
            .foregroundStyle(.red.opacity(0.12))
            .rotationEffect(.degrees(-45))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var manager = PDFManager()
    @State private var exportedURL: URL?
    @State private var isDraft = false
    @State private var exportError: Error?
    @State private var showError = false

    private let entries: [ExpenseEntry] = {
        let descriptions = [
            "Team lunch", "Flight to conference", "Hotel (3 nights)", "Conference ticket",
            "Software licence", "Office supplies", "Client dinner", "Taxi to airport",
            "Printing costs", "Mobile bill"
        ]
        let categories = [
            "Meals", "Travel", "Accommodation", "Events",
            "Software", "Office", "Meals", "Travel", "Office", "Utilities"
        ]
        let amounts: [Double] = [45.50, 380.00, 630.00, 599.00, 149.99, 32.75, 215.00, 28.50, 67.20, 89.00]

        return (0..<30).map { i in
            ExpenseEntry(
                date: Calendar.current.date(byAdding: .day, value: -i, to: .now) ?? .now,
                description: descriptions[i % descriptions.count],
                category: categories[i % categories.count],
                amount: amounts[i % amounts.count]
            )
        }
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Options") {
                    Toggle("Draft Watermark", isOn: $isDraft)
                }

                Section {
                    Button("Generate PDF") {
                        exportPDF()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if let url = exportedURL {
                    Section("Last Export") {
                        ShareLink(
                            item: url,
                            preview: SharePreview(
                                url.lastPathComponent,
                                image: Image(systemName: "doc.richtext")
                            )
                        ) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        LabeledContent("File", value: url.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("PDFManager Demo")
            .alert("Export Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError?.localizedDescription ?? "Unknown error")
            }
        }
    }

    private func exportPDF() {
        do {
            let config = PDFConfiguration(
                paperSize: CGSize(width: 595, height: 842),
                paperMargin: EdgeInsets(top: 36, leading: 36, bottom: 36, trailing: 36)
            )

            let watermark: (() -> AnyView)? = isDraft
                ? { AnyView(DraftWatermark()) }
                : nil

            exportedURL = try manager.export(
                entries,
                config: config,
                metadata: PDFMetadata(title: "Expense Report"),
                watermark: watermark,
                header: { page, total in
                    ExpenseReportHeader(currentPage: page, totalPages: total)
                },
                content: { items in
                    ExpenseReportContent(items: items)
                },
                footer: { _, _ in
                    ExpenseReportFooter()
                }
            )
        } catch {
            exportError = error
            showError = true
        }
    }
}

#Preview {
    ContentView()
}
