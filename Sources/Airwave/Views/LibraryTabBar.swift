import AppKit
import SwiftUI

struct LibraryTabBar: View {
    private static let selectorAccessibilityIdentifier = "airwave.library-selector"

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
                Label(mode.rawValue, systemImage: symbolName(for: mode))
                    .labelStyle(.titleAndIcon)
                    .tag(mode)
            }
        }
        .accessibilityIdentifier(Self.selectorAccessibilityIdentifier)
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .frame(width: 390)
        .imageScale(.medium)
        .background(
            SegmentedControlImageConfigurator(
                symbolNames: LibraryMode.allCases.map(symbolName(for:))
            )
        )
        .accessibilityLabel("Library")
    }

    private func symbolName(for mode: LibraryMode) -> String {
        switch mode {
        case .explore: "rectangle.grid.2x2"
        case .countries: "globe.americas.fill"
        case .favorites: "star"
        case .recent: "clock"
        }
    }

    private struct SegmentedControlImageConfigurator: NSViewRepresentable {
        let symbolNames: [String]

        func makeNSView(context: Context) -> ImageConfiguratorView {
            ImageConfiguratorView(symbolNames: symbolNames)
        }

        func updateNSView(_ view: ImageConfiguratorView, context: Context) {
            view.symbolNames = symbolNames
            view.configure()
        }

        final class ImageConfiguratorView: NSView {
            var symbolNames: [String]

            init(symbolNames: [String]) {
                self.symbolNames = symbolNames
                super.init(frame: .zero)
            }

            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override func layout() {
                super.layout()
                configure()
            }

            func configure() {
                guard let selector = siblingSegmentedControl() else { return }

                selector.setAccessibilityIdentifier(LibraryTabBar.selectorAccessibilityIdentifier)
                guard selector.accessibilityIdentifier() == LibraryTabBar.selectorAccessibilityIdentifier,
                      selector.segmentCount == 4,
                      symbolNames.count == 4 else { return }

                for (index, symbolName) in symbolNames.enumerated() {
                    selector.setImage(
                        NSImage(
                            systemSymbolName: symbolName,
                            accessibilityDescription: symbolName
                        ),
                        forSegment: index
                    )
                    selector.setImageScaling(.scaleProportionallyDown, forSegment: index)
                }
            }

            private func siblingSegmentedControl() -> NSSegmentedControl? {
                guard let configuratorHost = superview,
                      let pickerContainer = configuratorHost.superview else { return nil }

                let selectors = pickerContainer.subviews
                    .filter { $0 !== configuratorHost }
                    .compactMap(segmentedControl(in:))
                guard selectors.count == 1 else { return nil }
                return selectors[0]
            }

            private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
                if let selector = view as? NSSegmentedControl { return selector }
                for subview in view.subviews {
                    if let selector = segmentedControl(in: subview) { return selector }
                }
                return nil
            }
        }
    }
}
