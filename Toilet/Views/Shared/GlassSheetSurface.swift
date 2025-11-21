import SwiftUI

struct GlassSheetSurface<Content: View>: View {
    @ViewBuilder private var content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 16)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 28)
    }
    
    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.08))
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.9)
                .blendMode(.overlay)
        }
    }
}
