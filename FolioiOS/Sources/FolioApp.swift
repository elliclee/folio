import SwiftUI

@main
struct FolioApp: App {
    @State private var viewModel = ReaderViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                // "Open with Folio" from other apps / the Files app.
                .onOpenURL { url in
                    viewModel.open(url: url)
                }
        }
    }
}
