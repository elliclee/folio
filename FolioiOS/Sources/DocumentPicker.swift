import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Thin wrapper over `UIDocumentPickerViewController`. SwiftUI's
/// `.fileImporter` didn't reliably deliver its completion on device, so we
/// use the UIKit picker, whose delegate callback is dependable.
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // asCopy: the system hands back a temporary copy we can read
        // immediately — no security-scoped lifetime / coordination dance,
        // which is the most robust path for a re-signed sideloaded app.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
