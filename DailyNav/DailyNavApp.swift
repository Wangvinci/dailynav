import SwiftUI

// ============================================================
// MARK: - App Entry
// ============================================================

@main
struct DailyNavApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView().opacity(showSplash ? 0 : 1)
                if showSplash {
                    SplashView { withAnimation(.easeIn(duration: 0.55)) { showSplash = false } }
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.55), value: showSplash)
        }
    }
}

// ============================================================
// MARK: - Splash Screen  总停留约 2.8 秒，留足读句子时间
// ============================================================

struct SplashView: View {
    let onFinish: () -> Void

    // 读系统语言（启动时 AppStore 尚未初始化）
    // 优先用 preferredLanguages[0]（更准确反映用户 App 语言设置）
    private var isChinese: Bool {
        let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
        return lang.hasPrefix("zh")
    }

    // 每次启动随机语录
    private var todayQuote: Quote {
        let seed = Int(Date().timeIntervalSince1970 * 100) % quoteLibrary.count
        return quoteLibrary[abs(seed) % quoteLibrary.count]
    }

    private let inkDark = Color(red: 0.15, green: 0.12, blue: 0.09)
    private let paperLight = Color(red: 0.97, green: 0.95, blue: 0.89)
    private let paperDark  = Color(red: 0.92, green: 0.87, blue: 0.75)

    @State private var bgAlpha:     Double = 0   // 底色
    @State private var paintAlpha:  Double = 0   // 山水
    @State private var quoteAlpha:  Double = 0   // 语录
    @State private var markAlpha:   Double = 0   // 引号
    @State private var authorAlpha: Double = 0   // 作者 + app名
    @State private var exitAlpha:   Double = 1   // 退出淡出

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // ── 底色 ──────────────────────────────────
                LinearGradient(colors: [paperLight, paperDark],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .opacity(bgAlpha)

                // ── 山水画（Canvas 纯代码）────────────────
                Canvas { ctx, size in drawShanshui(ctx: ctx, size: size) }
                    .ignoresSafeArea()
                    .opacity(paintAlpha * 0.19)

                // ── 纸纹噪点 ─────────────────────────────
                Canvas { ctx, size in
                    var rng = SplashRNG(seed: 99)
                    for _ in 0..<240 {
                        let x = rng.next() * size.width
                        let y = rng.next() * size.height
                        let r = rng.next() * 0.85 + 0.15
                        let a = rng.next() * 0.022 + 0.004
                        ctx.fill(Path(ellipseIn: CGRect(x:x-r,y:y-r,width:r*2,height:r*2)),
                                 with: .color(inkDark.opacity(a)))
                    }
                }
                .ignoresSafeArea()
                .opacity(bgAlpha * 0.65)

                // ── 正文区 ───────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // 开引号（装饰）
                    Text("\u{201C}")
                        .font(.system(size: 72, weight: .ultraLight, design: .serif))
                        .foregroundColor(inkDark.opacity(0.12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 46).padding(.bottom, -16)
                        .opacity(markAlpha)

                    // 语录正文
                    Text(isChinese ? todayQuote.zh : todayQuote.en)
                        .font(.system(size: isChinese ? 21 : 17,
                                      weight: .light, design: .serif))
                        .foregroundColor(inkDark.opacity(0.78))
                        .lineSpacing(isChinese ? 10 : 7)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 46)
                        .opacity(quoteAlpha)

                    Spacer().frame(height: 24)

                    // 作者
                    Text("— " + (isChinese ? todayQuote.author : todayQuote.authorEn))
                        .font(.system(size: 12, weight: .light, design: .serif))
                        .foregroundColor(inkDark.opacity(0.34))
                        .tracking(isChinese ? 2 : 1.2)
                        .opacity(authorAlpha)

                    Spacer()

                    // App 署名
                    VStack(spacing: 7) {
                        Rectangle().fill(inkDark.opacity(0.08)).frame(width: 30, height: 0.5)
                        Text("DailyNav")
                            .font(.system(size: 11, weight: .light, design: .serif))
                            .foregroundColor(inkDark.opacity(0.20))
                            .tracking(4)
                    }
                    .padding(.bottom, 56)
                    .opacity(authorAlpha)
                }
            }
            .opacity(exitAlpha)
            .onAppear { runSequence() }
            .onTapGesture { dismissNow() }  // 单击立即退出
        }
    }

    private func dismissNow() {
        NSObject.cancelPreviousPerformRequests(withTarget: RunLoop.main)
        withAnimation(.easeIn(duration: 0.22)) { exitAlpha = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onFinish() }
    }

    // ── 动画序列 ───────────────────────────────────────────
    private func runSequence() {
        // 0.00s 底色淡入 (0.5s)
        withAnimation(.easeIn(duration: 0.50))              { bgAlpha    = 1 }
        // 0.20s 山水渐现 (0.9s)
        withAnimation(.easeIn(duration: 0.90).delay(0.20)) { paintAlpha = 1 }
        // 0.30s 引号渐现 (0.6s)
        withAnimation(.easeIn(duration: 0.60).delay(0.30)) { markAlpha  = 1 }
        // 0.55s 语录淡入 (0.9s) ← 最重要，慢一点让眼睛跟上
        withAnimation(.easeIn(duration: 0.90).delay(0.55)) { quoteAlpha = 1 }
        // 1.10s 作者/app名淡入 (0.6s)
        withAnimation(.easeIn(duration: 0.60).delay(1.10)) { authorAlpha = 1 }
        // 4.20s 整体淡出，多 1.4s 让用户读语录
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.20) {
            withAnimation(.easeIn(duration: 0.40)) { exitAlpha = 0 }
        }
        // 4.65s 完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.65) { onFinish() }
    }

    // ── 山水画（Canvas 纯代码，零图片依赖）─────────────────
    private func drawShanshui(ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        var rng = SplashRNG(seed: 77)
        let ink = inkDark

        // 远山三层（从浅到深）
        for layer in 0..<3 {
            let yBase = h * (0.42 + Double(layer) * 0.09)
            let alpha = 0.50 - Double(layer) * 0.10
            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))
            var x: CGFloat = 0
            while x <= w + 20 {
                let noise = rng.next() * 48 - 24
                let pH = h * (0.16 + rng.next() * 0.13) * (1 - Double(layer) * 0.20)
                let cx = x + rng.next() * 52 + 26
                let midX = x + (cx - x) / 2
                path.addQuadCurve(to: CGPoint(x: cx, y: yBase - pH + noise),
                                  control: CGPoint(x: midX, y: yBase - pH * 1.28 + noise * 0.5))
                x = cx
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
            ctx.fill(path, with: .color(ink.opacity(alpha)))
        }

        // 近景山石
        for _ in 0..<3 {
            let bx = rng.next() * w * 0.72
            let by = h * (0.73 + rng.next() * 0.09)
            let bw = rng.next() * w * 0.24 + w * 0.09
            let bh = h * (0.05 + rng.next() * 0.07)
            var rock = Path()
            rock.move(to: CGPoint(x: bx, y: h))
            rock.addQuadCurve(to: CGPoint(x: bx + bw, y: h),
                              control: CGPoint(x: bx + bw * 0.5, y: by - bh))
            rock.closeSubpath()
            ctx.fill(rock, with: .color(ink.opacity(0.58)))
        }

        // 水面横线（留白感）
        for i in 0..<11 {
            let ly = h * 0.62 + CGFloat(i) * (h * 0.023)
            let lw = w * (0.26 + rng.next() * 0.46)
            let lx = rng.next() * (w - lw)
            var line = Path()
            line.move(to: CGPoint(x: lx, y: ly))
            line.addQuadCurve(to: CGPoint(x: lx + lw, y: ly + rng.next() * 1.8 - 0.9),
                              control: CGPoint(x: lx + lw / 2, y: ly - rng.next() * 2.5))
            ctx.stroke(line, with: .color(ink.opacity(0.065 + rng.next() * 0.075)),
                       style: StrokeStyle(lineWidth: 0.3 + rng.next() * 0.55))
        }

        // 松树
        drawPine(ctx: ctx, x: w * 0.80, base: h * 0.57, height: h * 0.155, rng: &rng)
        drawPine(ctx: ctx, x: w * 0.16, base: h * 0.60, height: h * 0.082, rng: &rng)
    }

    private func drawPine(ctx: GraphicsContext, x: CGFloat, base: CGFloat,
                          height: CGFloat, rng: inout SplashRNG) {
        let ink = inkDark
        var trunk = Path()
        trunk.move(to: CGPoint(x: x, y: base))
        trunk.addLine(to: CGPoint(x: x, y: base - height))
        ctx.stroke(trunk, with: .color(ink.opacity(0.48)),
                   style: StrokeStyle(lineWidth: 1.1))
        for i in 0..<5 {
            let t = CGFloat(i) / 5
            let ly = base - height * (0.30 + t * 0.60)
            let lw = height * (0.37 - t * 0.20) * (1 + rng.next() * 0.14)
            var b = Path()
            b.move(to: CGPoint(x: x, y: ly - height * 0.09))
            b.addLine(to: CGPoint(x: x - lw, y: ly))
            b.addLine(to: CGPoint(x: x + lw, y: ly))
            b.closeSubpath()
            ctx.fill(b, with: .color(ink.opacity(0.33 + rng.next() * 0.14)))
        }
    }
}

// ── 确定性 RNG ──────────────────────────────────────────────
private struct SplashRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(0xFFFFFFFF)
    }
}
