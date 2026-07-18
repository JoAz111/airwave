import AppKit
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
                Label(mode.rawValue, systemImage: symbolName(for: mode))
                    .labelStyle(.titleAndIcon)
                    .tag(mode)
            }
        }
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
                guard let selector = containingSegmentedControl(for: self) else { return }

                for (index, symbolName) in symbolNames.enumerated() {
                    selector.setImage(
                        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
                        forSegment: index
                    )
                    selector.setImageScaling(.scaleProportionallyDown, forSegment: index)
                }
            }

            private func containingSegmentedControl(for view: NSView) -> NSSegmentedControl? {
                var ancestor: NSView? = view
                while let current = ancestor {
                    if let selector = segmentedControl(in: current) { return selector }
                    ancestor = current.superview
                }
                return nil
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
