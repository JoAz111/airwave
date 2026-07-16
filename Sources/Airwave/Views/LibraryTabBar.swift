import SwiftUI

struct LibraryTabBar: View {
    let model: AppModel
    @Namespace private var glassNamespace
    @State private var visualSelection: LibraryMode?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryMode.allCases) { mode in
                Button {
                    select(mode)
                } label: {
                    Text(mode.rawValue)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 8)
                        .contentShape(.capsule)
                        .background {
                            if selectedMode == mode {
                                Capsule()
                                    .fill(.clear)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .glassEffectID("library-selection", in: glassNamespace)
                                    .glassEffectTransition(.matchedGeometry)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Library")
    }

    private var selectedMode: LibraryMode {
        visualSelection ?? model.libraryMode
    }

    private func select(_ mode: LibraryMode) {
        guard mode != selectedMode else { return }
        withAnimation(.spring(duration: 0.34, bounce: 0.18)) {
            visualSelection = mode
        }
        Task {
            await model.activate(mode)
            visualSelection = nil
        }
    }
}
