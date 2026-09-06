//
// Project: PDFManager
// Author: Mark Battistella
// Website: https://markbattistella.com
//

import SwiftUI

/// Composes one page using the same section heights reserved during pagination.
internal struct PDFPage<Header: PDFHeader, Content: PDFContent, Footer: PDFFooter>: View {
  let layout: PDFManager.PageLayout
  @ViewBuilder let header: Header
  @ViewBuilder let content: Content
  @ViewBuilder let footer: Footer

  var body: some View {
    VStack(spacing: 0) {
      header
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: layout.headerHeight, alignment: .top)
      content
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: layout.contentHeight, alignment: .top)
      footer
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: layout.footerHeight, alignment: .bottom)
    }
  }
}
