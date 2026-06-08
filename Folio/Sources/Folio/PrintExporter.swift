import AppKit
import FolioCore

/// Native print/PDF export via `NSPrintOperation` — replaces the Tauri
/// version's hidden print-window + `window.print()` dance. The native
/// print panel includes "Save as PDF", and the job title (which seeds
/// the PDF filename) mirrors `getPrintDocumentTitle`.
@MainActor
enum PrintExporter {
    /// Headless PDF export (no panels) — used by the
    /// `FOLIO_EXPORT_PDF=/path.pdf` dev hook and future CLI export.
    static func exportPDF(markdown: String, fileName: String?, to url: URL) {
        printDocument(markdown: markdown, fileName: fileName, window: nil, savePDFTo: url)
    }

    static func printDocument(
        markdown: String,
        fileName: String?,
        window: NSWindow?,
        savePDFTo pdfURL: URL? = nil
    ) {
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        // @page margin: 14mm 12mm (≈ 40pt / 34pt).
        printInfo.topMargin = 40
        printInfo.bottomMargin = 40
        printInfo.leftMargin = 34
        printInfo.rightMargin = 34
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        let contentWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 1))
        textView.drawsBackground = true
        textView.backgroundColor = .white  // print page is always white
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0

        textView.textStorage?.setAttributedString(PrintRenderer().render(markdown))

        // Lay out the full document so pagination sees the real height.
        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container)
            textView.setFrameSize(NSSize(width: contentWidth, height: ceil(used.height)))
        }

        if let pdfURL {
            printInfo.jobDisposition = .save
            printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = pdfURL
        }

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.jobTitle = printDocumentTitle(fileName)
        operation.showsPrintPanel = pdfURL == nil
        operation.showsProgressPanel = pdfURL == nil

        if let window, pdfURL == nil {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
