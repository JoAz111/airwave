import SwiftUI

struct FloatingHeaderSpacer: View {
    var body: some View {
        Color.clear
            .frame(height: 116)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }
}
