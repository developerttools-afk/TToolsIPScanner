import SwiftUI

/// Stable glass plate. It does not observe the scanner, so progress ticks do not resample it.
struct ScannerGlassPlate: View, Equatable {
    var cornerRadius: CGFloat = 18
    
    var body: some View {
        Color.clear
            .scannerGlass(cornerRadius: cornerRadius)
    }
}

/// Soft color field so glass and materials have something to refract.
struct ScannerBackdrop: View {
    var body: some View {
        ZStack {
            Color.clear
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.22),
                    Color.blue.opacity(0.10),
                    Color.cyan.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.cyan.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: -220, y: -180)
            Circle()
                .fill(Color.indigo.opacity(0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: 240, y: 160)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Liquid Glass on OS 26, frosted material on earlier systems.
    @ViewBuilder
    func scannerGlass(cornerRadius: CGFloat = 18) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .transaction { $0.disablesAnimations = true }
        } else {
            self
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }
    
    @ViewBuilder
    func scannerGlassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
    
    /// Groups nearby glass shapes so they can blend on OS 26.
    @ViewBuilder
    func scannerGlassGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 8, content: content)
        } else {
            content()
        }
    }
}
