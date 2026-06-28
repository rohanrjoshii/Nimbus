import SwiftUI

/// Shared button style used by TimerWidgetView and any other widget
/// that wants a hover-scale + press-dim effect.
struct ControlButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isHovering ? 1.12 : 1.0)
            .opacity(configuration.isPressed ? 0.65 : (isHovering ? 1.0 : 0.88))
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isHovering)
            .onHover { hovering in isHovering = hovering }
    }
}
