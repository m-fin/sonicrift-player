import SwiftUI
import UIKit

enum Studio {
    static let background = Color(red: 0.067, green: 0.055, blue: 0.047)
    static let surface = Color(red: 0.125, green: 0.102, blue: 0.086)
    static let raised = Color(red: 0.176, green: 0.145, blue: 0.114)
    static let amber = Color(red: 0.910, green: 0.651, blue: 0.290)
    static let gold = Color(red: 0.965, green: 0.855, blue: 0.675)
    static let text = Color(red: 0.965, green: 0.937, blue: 0.890)
    static let muted = Color(red: 0.655, green: 0.580, blue: 0.490)
    static let line = Color.white.opacity(0.08)

    static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

struct StudioScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Studio.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 8) {
                MiniPlayerBar()
            }
    }
}
