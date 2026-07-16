import SwiftUI

enum AirwaveStyle {
    static let accent = Color(red: 0.33, green: 0.34, blue: 1)
    static let signalGradient = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.78, blue: 1),
            Color(red: 0.34, green: 0.31, blue: 1),
            Color(red: 1, green: 0.49, blue: 0.31)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
