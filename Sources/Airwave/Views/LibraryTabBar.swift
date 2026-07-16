import SwiftUI

struct LibraryTabBar: View {
    let model: AppModel
    @Namespace private var selectionGlass

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(LibraryMode.allCases) { mode in
                    Button {
                        Task { await model.activate(mode) }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(model.libraryMode == mode ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if model.libraryMode == mode {
                            Capsule()
                                .fill(.black)
                                .glassEffect(
                                    .regular.tint(.black).interactive(),
                                    in: .capsule
                                )
                                .glassEffectID("library-selection", in: selectionGlass)
                        }
                    }
                    .accessibilityIdentifier("library.\(mode.id)")
                }
            }
            .padding(3)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(width: 300)
        .animation(.smooth(duration: 0.28), value: model.libraryMode)
        .accessibilityLabel("Library")
    }
}
