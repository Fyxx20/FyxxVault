import SwiftUI

struct AdaptiveLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if sizeClass == .regular {
            // iPad: constrain content width with sidebar feel
            content
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    func fvAdaptive() -> some View {
        AdaptiveLayout { self }
    }
}
