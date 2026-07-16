import SwiftUI

struct FloatingSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .tint(AirwaveStyle.accent)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .glassEffect(searchGlass, in: .capsule)
        .accessibilityElement(children: .contain)
    }

    private var searchGlass: Glass {
        if isFocused {
            return .regular.tint(AirwaveStyle.accent.opacity(0.18)).interactive()
        }
        return .regular.interactive()
    }
}
