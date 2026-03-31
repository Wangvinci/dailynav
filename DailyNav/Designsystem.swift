import SwiftUI

// ============================================================
// MARK: - DesignSystem  —  Misty Typography & Type Scale
// Philosophy: "glass-light reflection" — never harsh, never grey.
// Primary text is clear but slightly veiled (0.88 opacity).
// White shadow hairline simulates glass highlight.
// Accent glow is whisper-quiet — Monet, not neon.
// ============================================================

// ─────────────────────────────────────────────────────────────
// MARK: 1.  Type Scale  —  SINGLE SOURCE OF TRUTH
//
// Philosophy: 8-stop harmonic scale, .rounded design everywhere.
// Numbers always monospacedDigit(). No raw pt values elsewhere.
//
//   Display   ──  72 / 36   hero stats (full-page numerals)
//   Title     ──  20        page hero title
//   Heading   ──  16        prominent card heading
//   Label     ──  13        section titles, card labels  ← primary UI text
//   Body      ──  13        body / insight / content     (same size, diff weight)
//   Caption   ──  11        secondary labels, sub-text
//   Micro     ──  10        badges, counters, tiny icons
//   Nano      ──   8        chart axis ticks, divider marks (use sparingly)
//
// Colour guidance:
//   Label / Body  →  textPrimary .opacity(0.88)   weight .regular / .medium
//   Caption       →  textSecondary .opacity(0.66)  weight .regular
//   Micro         →  textTertiary  .opacity(0.50)  weight .regular
//   Nano          →  textTertiary  .opacity(0.35)  weight .regular
//   Numbers       →  accent / gold / textSecondary  weight .light
// ─────────────────────────────────────────────────────────────
enum DSTSize {

    // ── Numeric display  (hero stats, big %s) ─────────────────
    /// Full-page hero number  —  72 pt  ultraLight  rounded
    static let displayHero:  CGFloat = 72
    /// Large card stat  —  36 pt  ultraLight  rounded
    static let displayLarge: CGFloat = 36
    /// Medium card stat  —  21 pt  light  rounded
    static let displayMid:   CGFloat = 21
    /// Inline stat / date number  —  16 pt  light  rounded
    static let displaySmall: CGFloat = 16

    // ── Prose hierarchy ───────────────────────────────────────
    /// Page hero title  —  20 pt  semibold  rounded
    static let titlePage:    CGFloat = 20
    /// Card / section heading  —  16 pt  semibold  rounded
    static let titleCard:    CGFloat = 16
    /// Primary label — section titles, card headers  —  13 pt  semibold  rounded
    static let label:        CGFloat = 13
    /// Body / content text  —  13 pt  regular  rounded
    static let body:         CGFloat = 13
    /// Secondary labels, sub-text  —  11 pt  regular  rounded
    static let caption:      CGFloat = 11
    /// Badges, counters, tab labels  —  10 pt  regular  rounded
    static let micro:        CGFloat = 10
    /// Chart ticks, hairline marks  —   8 pt  regular  rounded  (use sparingly)
    static let nano:         CGFloat = 8

    // ── Legacy aliases  (do not add new usages) ───────────────
    // These keep backward compatibility with code already using old names.
    static var pageLarge:    CGFloat { titlePage }
    static var cardTitle:    CGFloat { titleCard }
    static var bodySmall:    CGFloat { body }
    static var numberLarge:  CGFloat { displayLarge }
    static var numberMid:    CGFloat { displayMid }
    static var numberSmall:  CGFloat { displaySmall }

    // ── MyPage card system  (mapped to canonical scale) ───────
    static var sectionTitle: CGFloat { label }       // 13 semibold
    static var sectionSub:   CGFloat { caption }     // 11 regular
    static var statValue:    CGFloat { displayMid }  // 21 light
    static var cardBody:     CGFloat { body }        // 13 regular
    static var cardCaption:  CGFloat { caption }     // 11 regular
    static var cardMicro:    CGFloat { micro }       // 10 regular
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
    // Corner radii — 4-stop scale
    static let cornerXL:  CGFloat = 24   // modal sheets, large cards
    static let cornerL:   CGFloat = 16   // standard cards, sections
    static let cornerM:   CGFloat = 12   // input fields, buttons
    static let cornerS:   CGFloat = 8    // chips, badges, small elements

    // Spacing — 4-stop scale
    static let cardPad:   CGFloat = 14   // internal card padding
    static let inputPad:  CGFloat = 13   // text field padding
    static let sheetPad:  CGFloat = 20   // sheet/modal outer padding
    static let cardGap:   CGFloat = 12   // gap between cards
    static let sectionGap: CGFloat = 20  // gap between sections

    // Hairline
    static let hairline:  CGFloat = 0.5

    // Border stroke widths — 3-stop scale
    static let strokeSubtle:  CGFloat = 0.5   // dividers, inactive
    static let strokeNormal:  CGFloat = 1.0   // default borders
    static let strokeEmphasis: CGFloat = 1.5  // selected, focus

    // Animation — 3-stop spring responses
    static let animQuick:    Double = 0.22  // toggle, color select
    static let animStandard: Double = 0.30  // expand/collapse, sheets
    static let animSlow:     Double = 0.42  // page transitions
    // Standard damping
    static let animDamping:  Double = 0.82

    // Minimum tap target (Apple HIG)
    static let tapMin: CGFloat = 44
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
/// Refined decorative opening quote — subtle, atmospheric.
struct DecoQuoteMark: View {
    var size: CGFloat = 42
    var opacity: Double = 0.10
    var body: some View {
        Text("\u{201C}")
            .font(.system(size: size, weight: .thin, design: .serif))
            .foregroundColor(AppTheme.accent.opacity(opacity))
            .shadow(color: AppTheme.accent.opacity(0.06), radius: 12, x: 0, y: 0)
    }
}

// ── 7c-ext.  QuoteTypography  ────────────────────────────────
/// Adaptive typography for the literary quote card.
///
/// Design principle: text should feel like a page from a beautiful book,
/// not a UI label. Short quotes breathe like posters; long quotes compress
/// gracefully but never feel cramped.
///
/// All font weights are .light — heavier weights kill the quiet mood.
struct QuoteTypography {
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let topPadding: CGFloat
    let authorSpacing: CGFloat
    let maxWidthRatio: CGFloat  // fraction of card width

    static func forText(_ text: String) -> QuoteTypography {
        let len = text.count
        if len <= 35 {
            // Very short — poster impact
            return QuoteTypography(fontSize: 19, lineSpacing: 11, topPadding: 8, authorSpacing: 26, maxWidthRatio: 0.68)
        } else if len <= 70 {
            // Short — spacious literary page
            return QuoteTypography(fontSize: 17, lineSpacing: 9, topPadding: 5, authorSpacing: 22, maxWidthRatio: 0.70)
        } else if len <= 120 {
            // Medium — balanced and elegant
            return QuoteTypography(fontSize: 15.5, lineSpacing: 8, topPadding: 3, authorSpacing: 20, maxWidthRatio: 0.72)
        } else if len <= 180 {
            // Long — tighter but preserving rhythm
            return QuoteTypography(fontSize: 14.5, lineSpacing: 7, topPadding: 2, authorSpacing: 18, maxWidthRatio: 0.74)
        } else {
            // Very long — compact, still dignified
            return QuoteTypography(fontSize: 13.5, lineSpacing: 5.5, topPadding: 0, authorSpacing: 14, maxWidthRatio: 0.76)
        }
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

// ─────────────────────────────────────────────────────────────
// MARK: 8.  Glass Imprint Title  — "OW quality" page header
// Philosophy: Overwatch-style chrome lettering.
// Dark base → inner shadow (depth) → outer glow (edge light).
// Two stroke layers simulate glass edge refraction.
// No blur on the fill — crisp base keeps readability absolute.
// ─────────────────────────────────────────────────────────────

// ── 8a.  Design Tokens ──────────────────────────────────────
enum GlassTitleToken {
    // Font — reduced from 38 to 28 for a more mature, restrained feel.
    // 28pt semibold rounded is confident without being loud.
    static let size:     CGFloat = 28
    static let weight:   Font.Weight = .semibold
    static let tracking: CGFloat = -0.3            // slightly tighter = premium

    // Fill opacity (base text colour)
    static let fillOpacity:      Double = 0.90    // crisp but not harsh

    // Inner shadow — simulates pressed-into-surface depth
    static let innerShadowY:     CGFloat = 1.0
    static let innerShadowR:     CGFloat = 0       // 0 = sharp edge
    static let innerShadowOp:    Double  = 0.40    // softer

    // Outer surface glow — the chrome/neon edge highlight
    static let glowRadius:       CGFloat = 2.5
    static let glowOpacity:      Double  = 0.40    // quieter accent glow

    // Specular sheen highlight (white edge at top)
    static let shineRadius:      CGFloat = 0
    static let shineY:           CGFloat = -0.8   // above the glyph
    static let shineOpacity:     Double  = 0.35   // restrained — not a beacon

    // Ambient bloom (ultra-wide, very soft — barely there)
    static let bloomRadius:      CGFloat = 10
    static let bloomOpacity:     Double  = 0.18
}

// ── 8b.  GlassImprintTitle view ──────────────────────────────
/// Full-bleed glass-imprint page title.
/// Usage: GlassImprintTitle(store.t(key: L10n.goals))
struct GlassImprintTitle: View {
    let text: String
    var accentColor: Color = AppTheme.accent
    var fontSize: CGFloat = GlassTitleToken.size      // override for compact/nav use

    var body: some View {
        Text(text)
            // ── Typographic base ──
            .font(.system(size: fontSize,
                          weight: GlassTitleToken.weight,
                          design: .default))
            .tracking(GlassTitleToken.tracking)
            .foregroundColor(AppTheme.textPrimary.opacity(GlassTitleToken.fillOpacity))

            // ── Layer 1: inner shadow (depth impression) ──
            // Simulates the "pressed" inset by darkening top edge
            .shadow(
                color: Color.black.opacity(GlassTitleToken.innerShadowOp),
                radius: GlassTitleToken.innerShadowR,
                x: 0, y: GlassTitleToken.innerShadowY
            )
            // ── Layer 2: specular sheen highlight ──
            // Thin bright line along upper edge = glass refraction
            .shadow(
                color: Color.white.opacity(GlassTitleToken.shineOpacity),
                radius: GlassTitleToken.shineRadius,
                x: 0, y: GlassTitleToken.shineY
            )
            // ── Layer 3: neon edge glow (accent colour) ──
            .shadow(
                color: accentColor.opacity(GlassTitleToken.glowOpacity),
                radius: GlassTitleToken.glowRadius,
                x: 0, y: 0
            )
            // ── Layer 4: ambient bloom ──
            .shadow(
                color: accentColor.opacity(GlassTitleToken.bloomOpacity),
                radius: GlassTitleToken.bloomRadius,
                x: 0, y: 0
            )
    }
}

// ── 8c.  PageHeaderView ──────────────────────────────────────
/// Full page header block: glass title + optional subtitle.
/// Provides uniform top-padding, left-alignment, and spacing.
/// Usage: PageHeaderView(title: store.t(key: L10n.goals), subtitle: "3 active")
struct PageHeaderView: View {
    let title: String
    var subtitle: String = ""
    var accentColor: Color = AppTheme.accent

    // Uniform layout tokens
    static let topPad:    CGFloat = 4     // below nav bar safe area
    static let sidePad:   CGFloat = 20    // left/right content margin
    static let botPad:    CGFloat = 6     // space before first content card

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GlassImprintTitle(text: title, accentColor: accentColor)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: DSTSize.caption, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.65))
                    .tracking(0.2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top,  PageHeaderView.topPad)
        .padding(.horizontal, PageHeaderView.sidePad)
        .padding(.bottom, PageHeaderView.botPad)
    }
}


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

// ─────────────────────────────────────────────────────────────
// MARK: 9.  Unified Section Header — single source, all modules
//
// Every card header in Today/My page MUST use this component.
// Tokens: icon=cardMicro/medium, title=sectionTitle/semibold,
//         color=accent.0.60 / textPrimary.0.88
// ─────────────────────────────────────────────────────────────
struct DSCardHeader: View {
    let icon: String          // SF Symbol name
    let title: String
    var trailing: AnyView? = nil   // optional right-side content

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: DSTSize.cardMicro, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.accent.opacity(0.60))
            Text(title)
                .font(.system(size: DSTSize.sectionTitle, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                .kerning(0.3)
            Spacer()
            if let t = trailing { t }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
    }
}
