import SwiftUI

// MARK: - PalettePreview (Cyber Monet / Premium Glass + Misty Typography)
struct PalettePreview: View {
    @State private var selected: Palette = .neoTokyoPremium

    var body: some View {
        ZStack {
            selected.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                calendarMock
                addGoalButton
                goalsCards
                Spacer(minLength: 0)
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("目标")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .mistyPrimary(selected.textPrimary, glow: selected.accent)

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                    Text("未来感")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(selected.accent.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected.glass(corner: 999))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("色系预览（点这里切换）")
                    .font(.system(size: 12, weight: .medium))
                    .mistySecondary(selected.textSecondary, glow: selected.accent)

                Picker("Palette", selection: $selected) {
                    ForEach(Palette.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Calendar mock
    private var calendarMock: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(selected.textSecondary.opacity(0.75))
                Spacer()
                HStack(spacing: 6) {
                    Text("2026年 2月")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .mistyPrimary(selected.textPrimary, glow: selected.accent)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected.textSecondary.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(selected.textSecondary.opacity(0.75))
            }

            HStack {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .mistyTertiary(selected.textSecondary, glow: selected.accent)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let day = row * 7 + col + 8
                            ZStack {
                                if day == 28 {
                                    Circle()
                                        .fill(selected.accent.opacity(0.70))
                                        .frame(width: 34, height: 34)
                                        .background(
                                            Circle()
                                                .fill(selected.accent.opacity(0.28))
                                                .blur(radius: 12)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                        )
                                }

                                Text("\(day)")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(day == 28 ? selected.bg0 : selected.textPrimary.opacity(0.92))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                            }
                            .overlay(
                                VStack {
                                    Spacer()
                                    Circle()
                                        .fill(selected.accent.opacity(day % 2 == 0 ? 0.70 : 0.22))
                                        .frame(width: 4, height: 4)
                                        .background(
                                            Circle()
                                                .fill(selected.accent.opacity(0.16))
                                                .blur(radius: 6)
                                        )
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            selected.glass(corner: selected.cornerL)
                .shadow(color: selected.glow.opacity(0.14), radius: 26, x: 0, y: 12)
        )
    }

    private var addGoalButton: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("添加新目标")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .mistySecondary(selected.textSecondary, glow: selected.accent)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .background(
            selected.glass(corner: selected.cornerL)
                .shadow(color: selected.glow.opacity(0.11), radius: 22, x: 0, y: 10)
        )
    }

    // MARK: - Goal cards
    private var goalsCards: some View {
        VStack(spacing: 12) {
            goalCard(title: "读完10本书", tag: "学习", percent: 0.77, rightNote: "306天", tint: selected.accent2)
            goalCard(title: "学会基础西班牙语", tag: "技能", percent: 0.35, rightNote: "214天", tint: selected.accent)
            goalCard(title: "每天健身", tag: "健康", percent: 0.33, rightNote: "15天", tint: selected.accent.opacity(0.75))
        }
    }

    private func goalCard(title: String, tag: String, percent: Double, rightNote: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                RoundedRectangle(cornerRadius: 99)
                    .fill(tint.opacity(0.82))
                    .frame(width: 4, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 99)
                            .fill(tint.opacity(0.18))
                            .blur(radius: 10)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(tag)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .mistySecondary(selected.textSecondary, glow: selected.accent)

                    Text(title)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .mistyPrimary(selected.textPrimary, glow: selected.accent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .mistyPrimary(selected.textPrimary, glow: selected.accent)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                        Text(rightNote)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .mistySecondary(selected.textSecondary, glow: selected.accent)
                    }
                }
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)

                Capsule()
                    .fill(tint.opacity(0.82))
                    .frame(width: max(18, CGFloat(percent) * 260), height: 6)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.20))
                            .blur(radius: 12)
                    )
            }

            HStack(spacing: 12) {
                Text("• 阅读")
                Text("• 读书笔记")
                Spacer()
                Text("30min")
            }
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .mistyTertiary(selected.textSecondary, glow: selected.accent)
        }
        .padding(16)
        .background(
            selected.glass(corner: selected.cornerXL)
                .shadow(color: selected.glow.opacity(0.12), radius: 28, x: 0, y: 14)
        )
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabItem("目标", "scope", isActive: true)
            tabItem("今日", "checkmark.circle", isActive: false)
            tabItem("计划", "calendar", isActive: false)
            tabItem("我的", "chart.bar", isActive: false)
            tabItem("灵感", "sparkles", isActive: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            selected.glass(corner: 999)
                .shadow(color: selected.glow.opacity(0.10), radius: 24, x: 0, y: 10)
        )
        .padding(.bottom, 10)
    }

    private func tabItem(_ title: String, _ system: String, isActive: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isActive ? selected.accent.opacity(0.92) : selected.textSecondary.opacity(0.55))
    }
}

// MARK: - Palettes
enum Palette: CaseIterable, Hashable {
    case neoTokyoPremium
    case monetTealPremium
    case auroraMistPremium
    case graphiteMintPremium

    var displayName: String {
        switch self {
        case .neoTokyoPremium:     return "Neo Tokyo"
        case .monetTealPremium:    return "Monet Teal"
        case .auroraMistPremium:   return "Aurora Mist"
        case .graphiteMintPremium: return "Graphite Mint"
        }
    }

    var bg0: Color {
        switch self {
        case .neoTokyoPremium:     return Color(hex: "#04060C")
        case .monetTealPremium:    return Color(hex: "#0A1014")
        case .auroraMistPremium:   return Color(hex: "#070A10")
        case .graphiteMintPremium: return Color(hex: "#0B0F12")
        }
    }

    var bg1: Color {
        switch self {
        case .neoTokyoPremium:     return Color(hex: "#0A1326")
        case .monetTealPremium:    return Color(hex: "#14222A")
        case .auroraMistPremium:   return Color(hex: "#121A2A")
        case .graphiteMintPremium: return Color(hex: "#151C22")
        }
    }

    var cardTint: Color {
        switch self {
        case .neoTokyoPremium:     return Color(hex: "#0D1624")
        case .monetTealPremium:    return Color(hex: "#111B22")
        case .auroraMistPremium:   return Color(hex: "#0E1622")
        case .graphiteMintPremium: return Color(hex: "#121A20")
        }
    }

    var textPrimary: Color {
        switch self {
        case .auroraMistPremium: return Color(hex: "#EAF0FF")
        default:                 return Color(hex: "#EAF0F4")
        }
    }

    var textSecondary: Color {
        switch self {
        case .auroraMistPremium: return Color(hex: "#A8B3C7")
        default:                 return Color(hex: "#A9B6BE")
        }
    }

    var accent: Color {
        switch self {
        case .neoTokyoPremium:     return Color(hex: "#26F0D7")
        case .monetTealPremium:    return Color(hex: "#3FF1D0")
        case .auroraMistPremium:   return Color(hex: "#63F6D2")
        case .graphiteMintPremium: return Color(hex: "#59E8C9")
        }
    }

    var accent2: Color {
        switch self {
        case .neoTokyoPremium:     return Color(hex: "#FF5ACD").opacity(0.85)
        case .monetTealPremium:    return Color(hex: "#D6B57A")
        case .auroraMistPremium:   return Color(hex: "#B59BFF")
        case .graphiteMintPremium: return Color(hex: "#93A4B8")
        }
    }

    var glow: Color { accent.opacity(0.35) }
    var cornerXL: CGFloat { 28 }
    var cornerL: CGFloat { 20 }

    var background: some View {
        ZStack {
            LinearGradient(colors: [bg0, bg1], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.22), .clear], center: .topTrailing, startRadius: 30, endRadius: 480)
            RadialGradient(colors: [accent2.opacity(0.14), .clear], center: .bottomLeading, startRadius: 20, endRadius: 620)
            RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .topLeading, startRadius: 10, endRadius: 340)
            NoiseOverlay().opacity(0.20).blendMode(.overlay)
        }
    }

    func glass(corner: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: corner).fill(cardTint.opacity(0.38))
            RoundedRectangle(cornerRadius: corner).fill(
                LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center)
            )
            RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

// MARK: - Misty text style (works for any View)
private struct MistyTextStyle: ViewModifier {
    enum Level { case primary, secondary, tertiary }
    let level: Level
    let base: Color
    let glow: Color

    func body(content: Content) -> some View {
        switch level {
        case .primary:
            content
                .foregroundStyle(base.opacity(0.88))
                .shadow(color: .white.opacity(0.11), radius: 1.2, x: 0, y: 0.6)
                .shadow(color: glow.opacity(0.12), radius: 10, x: 0, y: 0)
        case .secondary:
            content
                .foregroundStyle(base.opacity(0.64))
                .shadow(color: .white.opacity(0.07), radius: 1.0, x: 0, y: 0.6)
                .shadow(color: glow.opacity(0.07), radius: 8, x: 0, y: 0)
        case .tertiary:
            content
                .foregroundStyle(base.opacity(0.50))
                .shadow(color: .white.opacity(0.05), radius: 0.8, x: 0, y: 0.5)
        }
    }
}

extension View {
    func mistyPrimary(_ base: Color, glow: Color) -> some View {
        modifier(MistyTextStyle(level: .primary, base: base, glow: glow))
    }
    func mistySecondary(_ base: Color, glow: Color) -> some View {
        modifier(MistyTextStyle(level: .secondary, base: base, glow: glow))
    }
    func mistyTertiary(_ base: Color, glow: Color) -> some View {
        modifier(MistyTextStyle(level: .tertiary, base: base, glow: glow))
    }
}

// MARK: - Noise overlay
struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let count = 12000
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let r = Double.random(in: 0.2...0.9)
                let a = Double.random(in: 0.02...0.08)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(a))
                )
            }
        }
    }
}

// MARK: - Hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8:
            (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

#Preview {
    PalettePreview()
        .preferredColorScheme(.dark)
}
