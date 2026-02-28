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
