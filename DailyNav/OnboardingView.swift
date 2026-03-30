import SwiftUI

// ============================================================
// MARK: - 首次启动引导（3 步）
// ============================================================

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, color: Color)] = [
        ("target",               AppTheme.accent),
        ("checkmark.circle.fill", AppTheme.cyberBlue),
        ("sparkles",             AppTheme.gold),
    ]

    var body: some View {
        ZStack {
            AppTheme.bg0.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── 图标 ────────────────────────────────
                ZStack {
                    Circle()
                        .fill(pages[currentPage].color.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(pages[currentPage].color)
                }
                .padding(.bottom, 32)

                // ── 标题 ────────────────────────────────
                Text(pageTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 12)

                // ── 描述 ────────────────────────────────
                Text(pageDescription)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 48)

                Spacer()

                // ── 页面指示器 ──────────────────────────
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? pages[i].color : AppTheme.textTertiary.opacity(0.3))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 32)

                // ── 按钮 ────────────────────────────────
                Button(action: {
                    HapticManager.impact(.medium)
                    if currentPage < 2 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                        UserDefaults.standard.set(true, forKey: "dn_onboardingDone")
                    }
                }) {
                    Text(currentPage < 2
                         ? store.t("继续", "Continue")
                         : store.t("开始使用", "Get Started"))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(pages[currentPage].color)
                        .foregroundColor(AppTheme.bg0)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)

                // ── 跳过按钮 ────────────────────────────
                if currentPage < 2 {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
                        UserDefaults.standard.set(true, forKey: "dn_onboardingDone")
                    }) {
                        Text(store.t("跳过", "Skip"))
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.top, 12)
                }

                Spacer().frame(height: 40)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 && currentPage < 2 {
                        withAnimation { currentPage += 1 }
                    } else if value.translation.width > 50 && currentPage > 0 {
                        withAnimation { currentPage -= 1 }
                    }
                }
        )
    }

    // ── 多语言文案 ──────────────────────────────────────────
    private var pageTitle: String {
        let titles: [[String]] = [
            ["设定目标，掌控方向", "Set Goals, Take Control", "目標を設定、方向を掌握", "목표를 설정하고 방향을 잡으세요", "Establece metas, toma el control"],
            ["每日打卡，养成习惯", "Daily Check-in, Build Habits", "毎日チェックイン、習慣を作ろう", "매일 체크인, 습관을 만드세요", "Check-in diario, crea hábitos"],
            ["回顾成长，遇见更好的自己", "Reflect & Grow", "振り返りと成長", "성장을 돌아보세요", "Reflexiona y crece"],
        ]
        let langIdx: Int
        switch store.language {
        case .chinese: langIdx = 0; case .english: langIdx = 1
        case .japanese: langIdx = 2; case .korean: langIdx = 3; case .spanish: langIdx = 4
        }
        return titles[currentPage][langIdx]
    }

    private var pageDescription: String {
        let descs: [[String]] = [
            [
                "创建长期或短期目标，拆解为每日可执行的小任务，在日历上追踪进度。",
                "Create long-term or short-term goals, break them into daily tasks, and track progress on the calendar.",
                "長期・短期の目標を作成し、毎日のタスクに分解してカレンダーで進捗を追跡。",
                "장기 또는 단기 목표를 만들고 매일 실행 가능한 작은 작업으로 나누세요.",
                "Crea metas a largo o corto plazo, divídelas en tareas diarias y sigue tu progreso."
            ],
            [
                "记录心情，完成每日挑战，通过打卡积累成就感和连续记录。",
                "Log your mood, complete daily challenges, and build streaks through consistent check-ins.",
                "気分を記録し、毎日のチャレンジを完了、チェックインでストリークを築きましょう。",
                "기분을 기록하고 매일 도전을 완료하며 꾸준한 체크인으로 연속 기록을 쌓으세요.",
                "Registra tu estado de ánimo, completa desafíos diarios y construye rachas."
            ],
            [
                "用数据洞察你的成长轨迹，AI 智能总结助你看清每一步进步。",
                "Use data insights to see your growth journey. AI summaries help you understand every step.",
                "データで成長の軌跡を把握。AIサマリーが一歩一歩の進歩を見せてくれます。",
                "데이터로 성장 궤적을 파악하세요. AI 요약이 모든 진전을 보여줍니다.",
                "Usa datos para ver tu trayectoria de crecimiento. Los resúmenes de IA te ayudan."
            ],
        ]
        let langIdx: Int
        switch store.language {
        case .chinese: langIdx = 0; case .english: langIdx = 1
        case .japanese: langIdx = 2; case .korean: langIdx = 3; case .spanish: langIdx = 4
        }
        return descs[currentPage][langIdx]
    }
}
