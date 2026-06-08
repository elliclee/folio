import SwiftUI

/// Find-in-document bar, equivalent to the find UI in the React header.
struct FindBarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @FocusState private var isFindFieldFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = viewModel.palette
        let matchCount = viewModel.findResult?.matchCount ?? 0

        HStack(spacing: 6) {
            SwiftUI.Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(palette.textSecondary)

            TextField("Find", text: $viewModel.findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
                .focused($isFindFieldFocused)
                .frame(maxWidth: 320)
                .onSubmit {
                    viewModel.moveFindMatch(direction: 1)
                }
                .onKeyPress(.escape) {
                    viewModel.closeFind()
                    return .handled
                }

            Text(matchLabel(matchCount: matchCount))
                .font(.system(size: 11))
                .foregroundStyle(palette.textMuted)
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)

            Button {
                viewModel.moveFindMatch(direction: -1)
            } label: {
                SwiftUI.Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(matchCount == 0)
            .keyboardShortcut(.return, modifiers: .shift)
            .help("Previous Match (⇧↩)")

            Button {
                viewModel.moveFindMatch(direction: 1)
            } label: {
                SwiftUI.Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .disabled(matchCount == 0)
            .help("Next Match (↩)")

            Button {
                viewModel.closeFind()
            } label: {
                SwiftUI.Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .help("Close Find (esc)")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.header)
        .onAppear {
            isFindFieldFocused = true
        }
    }

    private func matchLabel(matchCount: Int) -> String {
        guard !viewModel.findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        guard matchCount > 0 else {
            return "No results"
        }

        return "\(viewModel.findMatchIndex + 1)/\(matchCount)"
    }
}
