import SwiftUI

struct LibraryTabBar: View {
    let model: AppModel

    var body: some View {
        Picker(
            "Library",
            selection: Binding(
                get: { model.libraryMode },
                set: { mode in Task { await model.activate(mode) } }
            )
        ) {
            ForEach(LibraryMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Library")
    }
}
