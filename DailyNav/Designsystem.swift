import SwiftUI

// ============================================================
// MARK: - DesignSystem  —  Misty Typography & Type Scale
// Philosophy: "glass-light reflection" — never harsh, never grey.
// Primary text is clear but slightly veiled (0.88 opacity).
// White shadow hairline simulates glass highlight.
// Accent glow is whisper-quiet — Monet, not neon.
// ============================================================

// ─────────────────────────────────────────────────────────────
// MARK: 1.  Type Scale  (single source of truth)
// ─────────────────────────────────────────────────────────────
enum DSTSize {
    /// Page hero title  —  34 pt  medium
    static let pageLarge:    CGFloat = 34
    /// Section / card title  —  18 pt  medium
    static let cardTitle:    CGFloat = 18
    /// Sub-section label  —  15 pt  regular
    static let body:         CGFloat = 15
    /// Small body  —  14 pt  regular
    static let bodySmall:    CGFloat = 14
    /// Caption / helper  —  12 pt  regular
    static let caption:      CGFloat = 12
    /// Micro label / tab  —  11 pt  regular
    static let micro:        CGFloat = 11
    /// Large numeric (stats / %) — 28 pt  medium  monospaced
    static let numberLarge:  CGFloat = 28
    /// Medium numeric (card stats) — 20 pt  medium  monospaced
    static let numberMid:    CGFloat = 20
    /// Small numeric (inline) — 15 pt  medium  monospaced
    static let numberSmall:  CGFloat = 15
}

// ─────────────────────────────────────────────────────────────
// MARK: 2.  Text Tier  (opacity layer)
// ─────────────────────────────────────────────────────────────
enum DSTextTier {
    /// Clear but slightly veiled — main content
    case primary
    /// Lighter — labels, card sub-text
    case secondary
    /// Softest — hints, timestamps, micro-labels
    case tertiary

    /// Base opacity applied to the text colour
    var opacity: Double {
        switch self {
        case .primary:   return 0.90
        case .secondary: return 0.66
        case .tertiary:  return 0.50
        }
    }

    /// Hairline glass-highlight shadow intensity
    var shadowOpacity: Double {
        switch self {
        case .primary:   return 0.22
        case .secondary: return 0.12
        case .tertiary:  return 0.06
        }
    }

    /// Accent glow intensity (ultra-subtle)
    var glowOpacity: Double {
        switch self {
        case .primary:   return 0.04
        case .secondary: return 0.02
        case .tertiary:  return 0.0
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: 3.  MistyText ViewModifier
// ─────────────────────────────────────────────────────────────
/// Apply as  .misty(.primary)  /  .misty(.secondary)  /  .misty(.tertiary)
struct MistyTextModifier: ViewModifier {
    let tier: DSTextTier
    let baseColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(baseColor.opacity(tier.opacity))
            // ── Glass highlight: single-pixel white shadow above ──
            .shadow(color: Color.white.opacity(tier.shadowOpacity), radius: 0, x: 0, y: 0.5)
            // ── Accent glow: barely-there coloured bloom ──
            .shadow(color: AppTheme.accent.opacity(tier.glowOpacity), radius: 2, x: 0, y: 0)
    }
}

extension View {
    /// Applies Misty Typography tier to any Text or view.
    func misty(_ tier: DSTextTier, color: Color = AppTheme.textPrimary) -> some View {
        modifier(MistyTextModifier(tier: tier, baseColor: color))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: 3b.  CyberGlass Card modifier
// Usage: .cyberGlass(color: goal.color)
// ─────────────────────────────────────────────────────────────
struct CyberGlassModifier: ViewModifier {
    var accentColor: Color = AppTheme.accent
    var cornerRadius: CGFloat = AppTheme.cornerL
    var isActive: Bool = false    // highlighted / selected state
    var isGlowing: Bool = false   // drag / focus glow

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Layer 1: Deep silicon base
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.bg1)
                    // Layer 2: Thin frosted glass film
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.18)
                    // Layer 3: Diagonal specular sheen (top-left corner)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.055), Color.clear],
                                startPoint: .topLeading, endPoint: .center
                            )
                        )
                    // Layer 4: Colour ambient bloom (goal hue)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(isGlowing ? 0.22 : isActive ? 0.12 : 0.06),
                                    Color.clear
                                ],
                                center: .topLeading, startRadius: 0, endRadius: 130
                            )
                        )
                    // Layer 5: Scan-line texture (ultra-subtle, very high frequency)
                    ScanlineOverlay(cornerRadius: cornerRadius)
                        .opacity(AppTheme.scanlineOpacity)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isGlowing
                            ? accentColor.opacity(0.65)
                            : isActive
                                ? accentColor.opacity(0.30)
                                : Color.white.opacity(AppTheme.glassBorder),
                        lineWidth: isGlowing ? 1.2 : 0.7
                    )
            )
            .shadow(
                color: isGlowing
                    ? accentColor.opacity(AppTheme.neonGlow * 0.85)
                    : accentColor.opacity(0.08),
                radius: isGlowing ? 16 : 4,
                x: 0, y: isGlowing ? 6 : 2
            )
    }
}

/// Thin horizontal scan-lines — renders as a faint texture on cards
struct ScanlineOverlay: View {
    var cornerRadius: CGFloat = AppTheme.cornerL
    var spacing: CGFloat = 3      // line every N points

    var body: some View {
        GeometryReader { geo in
            let lineCount = Int(geo.size.height / spacing) + 1
            Canvas { ctx, size in
                for i in 0..<lineCount {
                    let y = CGFloat(i) * spacing
                    ctx.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)),
                        with: .color(.white.opacity(1.0))
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func cyberGlass(
        color: Color = AppTheme.accent,
        cornerRadius: CGFloat = AppTheme.cornerL,
        isActive: Bool = false,
        isGlowing: Bool = false
    ) -> some View {
        modifier(CyberGlassModifier(
            accentColor: color,
            cornerRadius: cornerRadius,
            isActive: isActive,
            isGlowing: isGlowing
        ))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: 4.  Pre-built Text Styles
// Usage:  Text("Hello").dsPageTitle()
//         Text("Card").dsCardTitle()
//         Text("body").dsBody()
// ─────────────────────────────────────────────────────────────
extension Text {
    // ── Page hero title  (34 medium)
    func dsPageTitle() -> some View {
        self
            .font(.system(size: DSTSize.pageLarge, weight: .medium, design: .default))
            .misty(.primary)
    }

    // ── Card / section title  (18 medium)
    func dsCardTitle() -> some View {
        self
            .font(.system(size: DSTSize.cardTitle, weight: .medium, design: .default))
            .misty(.primary)
    }

    // ── Standard body  (15 regular)
    func dsBody() -> some View {
        self
            .font(.system(size: DSTSize.body, weight: .regular, design: .default))
            .misty(.primary)
    }

    // ── Small body  (14 regular, secondary)
    func dsBodySmall() -> some View {
        self
            .font(.system(size: DSTSize.bodySmall, weight: .regular, design: .default))
            .misty(.secondary)
    }

    // ── Caption / label  (12 regular, secondary)
    func dsCaption() -> some View {
        self
            .font(.system(size: DSTSize.caption, weight: .regular, design: .default))
            .misty(.secondary)
    }

    // ── Micro / tab  (11 regular, tertiary)
    func dsMicro() -> some View {
        self
            .font(.system(size: DSTSize.micro, weight: .regular, design: .default))
            .misty(.tertiary)
    }

    // ── Section header label  (11 medium, kerned, tertiary)
    func dsSectionHeader() -> some View {
        self
            .font(.system(size: DSTSize.micro, weight: .medium, design: .default))
            .kerning(1.4)
            .misty(.tertiary)
    }

    // ── Large numeric stat  (28 medium, monospaced, primary)
    func dsNumberLarge(color: Color = AppTheme.textPrimary) -> some View {
        self
            .font(.system(size: DSTSize.numberLarge, weight: .medium, design: .rounded).monospacedDigit())
            .misty(.primary, color: color)
    }

    // ── Mid numeric  (20 medium, monospaced, primary)
    func dsNumberMid(color: Color = AppTheme.textPrimary) -> some View {
        self
            .font(.system(size: DSTSize.numberMid, weight: .medium, design: .rounded).monospacedDigit())
            .misty(.primary, color: color)
    }

    // ── Small inline numeric  (15 medium, monospaced)
    func dsNumberSmall(color: Color = AppTheme.textPrimary) -> some View {
        self
            .font(.system(size: DSTSize.numberSmall, weight: .medium, design: .rounded).monospacedDigit())
            .misty(.secondary, color: color)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: 5.  Convenience Modifiers for accent/coloured text
// ─────────────────────────────────────────────────────────────
extension View {
    /// Accent-coloured caption (e.g. chip labels, tags)
    func dsAccentCaption() -> some View {
        self
            .font(.system(size: DSTSize.caption, weight: .medium))
            .foregroundColor(AppTheme.accent.opacity(0.88))
            .shadow(color: AppTheme.accent.opacity(0.18), radius: 3, x: 0, y: 0)
    }

    /// Gold / warm semantic text (e.g. pending, caution)
    func dsGoldCaption() -> some View {
        self
            .font(.system(size: DSTSize.caption, weight: .medium))
            .foregroundColor(AppTheme.gold.opacity(0.88))
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: 6.  Spacing / Corner Tokens (extend AppTheme)
// ─────────────────────────────────────────────────────────────
extension AppTheme {
    // Corner radii
    static let cornerXL:  CGFloat = 24
    static let cornerL:   CGFloat = 18
    static let cornerM:   CGFloat = 14
    static let cornerS:   CGFloat = 10

    // Spacing
    static let cardPad:   CGFloat = 16
    static let cardGap:   CGFloat = 12
    static let sectionGap: CGFloat = 20

    // Hairline
    static let hairline:  CGFloat = 0.5
}


// ─────────────────────────────────────────────────────────────
// MARK: 7.  Dream Glass — Inspire page components
// Philosophy: Monet's garden through cathedral glass.
//             Glow breathes. Art whispers. Words shine.
// ─────────────────────────────────────────────────────────────

// ── 7a.  BreathingGlow  ─────────────────────────────────────
/// Adds a slow sine-wave glow pulse to any view.
/// Period: 3 s  |  Amplitude: very low  |  Zero flicker guarantee.
struct BreathingGlowModifier: ViewModifier {
    var color: Color = AppTheme.dreamGlow
    var radius: CGFloat = 22
    @State private var phase: Bool = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(phase ? 0.42 : 0.16),
                radius: phase ? radius : radius * 0.55,
                x: 0, y: 0
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 3.2)
                    .repeatForever(autoreverses: true)
                ) { phase = true }
            }
    }
}

extension View {
    /// Attaches a slow, low-intensity breathing glow.
    func breathingGlow(color: Color = AppTheme.dreamGlow, radius: CGFloat = 22) -> some View {
        modifier(BreathingGlowModifier(color: color, radius: radius))
    }
}

// ── 7b.  DreamGlassCard  ────────────────────────────────────
/// The main quote card: layered frosted glass + art ambient bloom.
struct DreamGlassCard<Content: View>: View {
    var artVisible: Bool = true           // toggleable for low-perf devices
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            // ─ Layer 0: deep silicon base ─────────────────────
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(AppTheme.dreamCardFill)

            // ─ Layer 1: frosted glass material ───────────────
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(.ultraThinMaterial)
                .opacity(AppTheme.glassBase)

            // ─ Layer 2: teal ambient bloom (top-left arc) ────
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.dreamGlow, Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .opacity(artVisible ? 1.0 : 0.7)

            // ─ Layer 3: violet counterpoint bloom (bottom-right) ─
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.dreamBloom, Color.clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .opacity(artVisible ? 0.85 : 0.5)

            // ─ Layer 4: vertical depth fog (top lighter → bottom deeper) ─
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.028),
                            Color.clear,
                            Color(red: 0.059, green: 0.067, blue: 0.090).opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // ─ Layer 5: specular highlight hairline ──────────
            RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            // ─ Content ────────────────────────────────────────
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerXL))
        // ─ Outer border: dual-layer glass edge ─────────────
        .overlay(
            ZStack {
                // Inner glow line
                RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                    .padding(0.5)
                // Outer accent edge
                RoundedRectangle(cornerRadius: AppTheme.cornerXL)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.22),
                                AppTheme.cyberPurple.opacity(0.10),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        // ─ Ambient shadow ─────────────────────────────────
        .shadow(color: AppTheme.accent.opacity(0.06), radius: 28, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.32), radius: 12, x: 0, y: 4)
    }
}

// ── 7c.  DecoQuoteMark  ──────────────────────────────────────
/// Large decorative opening quote — low opacity watermark.
struct DecoQuoteMark: View {
    var body: some View {
        Text("\u{201C}")
            .font(.system(size: 88, weight: .ultraLight, design: .serif))
            .foregroundColor(AppTheme.accent.opacity(0.13))
            .shadow(color: AppTheme.accent.opacity(0.10), radius: 16, x: 0, y: 0)
    }
}

// ── 7d.  GlassActionButton  ──────────────────────────────────
/// Pill / square glass button for the inspire action bar.
struct GlassActionButton: View {
    var icon: String
    var label: String = ""
    var isActive: Bool = false
    var activeColor: Color = AppTheme.accent
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.2)) { pressed = false }
            }
            action()
        }) {
            HStack(spacing: label.isEmpty ? 0 : 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .regular))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 12, weight: .light))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, label.isEmpty ? 13 : 16)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive
                              ? activeColor.opacity(0.15)
                              : Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.22)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive
                            ? activeColor.opacity(0.35)
                            : Color.white.opacity(0.09),
                        lineWidth: 0.7
                    )
            )
            .foregroundColor(isActive ? activeColor : AppTheme.textSecondary)
            .scaleEffect(pressed ? 0.94 : 1.0)
            .brightness(pressed ? 0.06 : 0)
        }
        .buttonStyle(.plain)
        // Ensure minimum 44pt hit target
        .frame(minHeight: 44)
    }
}

// ── 7e.  ArtAtmosphereLayer  ─────────────────────────────────
/// Generates a purely-code atmospheric "painting" background —
/// zero assets required, based on layered gradients + noise sim.
/// Visually evokes impressionist watercolours at near-zero opacity.
struct ArtAtmosphereLayer: View {
    var visible: Bool = true
    @State private var drift: CGFloat = 0  // slow parallax y-offset

    var body: some View {
        if visible {
            ZStack {
                // Pond surface — horizontal teal wash
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.55, blue: 0.62).opacity(0.55),
                        Color(red: 0.18, green: 0.38, blue: 0.52).opacity(0.35),
                        Color(red: 0.12, green: 0.22, blue: 0.38).opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Lily radials — soft bloom clusters
                RadialGradient(
                    colors: [
                        Color(red: 0.48, green: 0.80, blue: 0.68).opacity(0.28),
                        Color.clear
                    ],
                    center: .init(x: 0.28, y: 0.35),
                    startRadius: 0,
                    endRadius: 180
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.62, green: 0.52, blue: 0.88).opacity(0.18),
                        Color.clear
                    ],
                    center: .init(x: 0.72, y: 0.65),
                    startRadius: 0,
                    endRadius: 160
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.32, green: 0.70, blue: 0.82).opacity(0.16),
                        Color.clear
                    ],
                    center: .init(x: 0.80, y: 0.22),
                    startRadius: 0,
                    endRadius: 120
                )

                // Vignette — pull attention inward
                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(AppTheme.vignetteDepth * 0.92)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 320
                )
            }
            .blur(radius: 28)
            .opacity(AppTheme.artOpacity * 22)  // ≈ 0.99 max, set artOpacity=0 to disable
            .offset(y: drift)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
                ) { drift = 6 }
            }
            .allowsHitTesting(false)
            .clipped()
        }
    }
}
