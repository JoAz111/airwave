import AppKit
import SwiftUI

struct LibraryTabBar: View {
    private static let selectorAccessibilityIdentifier = "airwave.library-selector"

    let model: AppModel

    var body: some View {
        NativeLibrarySelector(
            model: model,
            symbolNames: LibraryMode.allCases.map(symbolName(for:))
        )
        .frame(width: 390)
    }

    private func symbolName(for mode: LibraryMode) -> String {
        switch mode {
        case .explore: "rectangle.grid.2x2"
        case .countries: "globe.americas.fill"
        case .favorites: "star"
        case .recent: "clock"
        }
    }

    private struct NativeLibrarySelector: NSViewRepresentable {
        let model: AppModel
        let symbolNames: [String]

        func makeCoordinator() -> Coordinator {
            Coordinator { mode in
                Task { await model.activate(mode) }
            }
        }

        func makeNSView(context: Context) -> NSSegmentedControl {
            let modes = LibraryMode.allCases
            let control = NSSegmentedControl(
                labels: modes.map(\.rawValue),
                trackingMode: .selectOne,
                target: context.coordinator,
                action: #selector(Coordinator.selectionChanged(_:))
            )
            control.controlSize = .large
            control.setAccessibilityLabel("Library")
            control.setAccessibilityIdentifier(LibraryTabBar.selectorAccessibilityIdentifier)

            for (index, symbolName) in symbolNames.enumerated() {
                control.setImage(
                    NSImage(
                        systemSymbolName: symbolName,
                        accessibilityDescription: symbolName
                    ),
                    forSegment: index
                )
                control.setImageScaling(.scaleProportionallyDown, forSegment: index)
            }
            control.selectedSegment = modes.firstIndex(of: model.libraryMode) ?? 0
            return control
        }

        func updateNSView(_ control: NSSegmentedControl, context: Context) {
            context.coordinator.onSelectionChanged = { mode in
                Task { await model.activate(mode) }
            }
            control.controlSize = .large
            control.selectedSegment = LibraryMode.allCases.firstIndex(of: model.libraryMode) ?? 0
        }

        @MainActor
        final class Coordinator: NSObject {
            var onSelectionChanged: (LibraryMode) -> Void

            init(onSelectionChanged: @escaping (LibraryMode) -> Void) {
                self.onSelectionChanged = onSelectionChanged
            }

            @objc func selectionChanged(_ sender: NSSegmentedControl) {
                guard LibraryMode.allCases.indices.contains(sender.selectedSegment) else { return }
                onSelectionChanged(LibraryMode.allCases[sender.selectedSegment])
            }
        }
    }
}
