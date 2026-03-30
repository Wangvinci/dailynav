import SwiftUI
import StoreKit

// ============================================================
// MARK: - 付费墙（三层：Free → Plus 买断 → Pro 订阅）
// ============================================================

struct ProPaywallSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore

    // ── 颜色常量 ──────────────────────────────────────────────
    private let plusColor = AppTheme.accent

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── 顶部标题 ──────────────────────────────
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(plusColor.opacity(0.12)).frame(width: 72, height: 72)
                            Image(systemName: "star.fill").font(.system(size: 30)).foregroundColor(plusColor)
                        }.padding(.top, 24)
                        Text("DailyNav Plus").font(.title2).fontWeight(.bold).foregroundColor(AppTheme.textPrimary)
                        Text(store.t("一次购买，永久解锁全部功能", "Buy once, unlock everything forever."))
                            .font(.subheadline).foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }.padding(.horizontal)

                    // ── Plus 功能列表 ────────────────────────
                    plusContent

                    // ── Pro 预告（不透露具体功能）──────────
                    HStack(spacing: 10) {
                        Image(systemName: "crown.fill").font(.caption).foregroundColor(AppTheme.gold.opacity(0.6))
                        Text(store.t("Pro 订阅即将推出，敬请期待", "Pro subscription coming soon"))
                            .font(.caption2).foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(AppTheme.bg2).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.gold.opacity(0.10), lineWidth: 0.6))
                    .padding(.horizontal)

                    // ── 恢复购买 + 条款 ──────────────────────
                    VStack(spacing: 8) {
                        Button(action: { Task { await pro.restore() } }) {
                            Text(store.t("恢复购买", "Restore Purchase"))
                                .font(.caption).foregroundColor(AppTheme.textTertiary)
                                .underline()
                        }

                        HStack(spacing: 16) {
                            Button(action: { openURL("https://Wangvinci.github.io/dailynav/terms.html") }) {
                                Text(store.t("服务条款", "Terms of Service"))
                                    .font(.caption2).foregroundColor(AppTheme.textTertiary.opacity(0.7))
                            }
                            Button(action: { openURL("https://Wangvinci.github.io/dailynav/privacy.html") }) {
                                Text(store.t("隐私政策", "Privacy Policy"))
                                    .font(.caption2).foregroundColor(AppTheme.textTertiary.opacity(0.7))
                            }
                        }
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 20)
                }
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t("关闭", "Close")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .overlay {
                if pro.isLoading {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.2)
                }
            }
        }
    }

    // ── Plus 买断内容 ─────────────────────────────────────────
    private var plusContent: some View {
        VStack(spacing: 16) {
            // 功能列表
            VStack(spacing: 0) {
                PaywallFeatureRow(icon: "target",              color: plusColor, text: store.t("无限目标（免费版仅1个）", "Unlimited goals (free: 1 only)"), tier: "Plus")
                PaywallFeatureRow(icon: "checklist",           color: plusColor, text: store.t("无限任务（免费版每目标2个）", "Unlimited tasks (free: 2/goal)"), tier: "Plus")
                PaywallFeatureRow(icon: "book.fill",           color: plusColor, text: store.t("今日心得 + 历史回顾", "Daily journal + history"), tier: "Plus")
                PaywallFeatureRow(icon: "quote.bubble.fill",   color: plusColor, text: store.t("灵感语录无限解锁", "Unlimited inspiration quotes"), tier: "Plus")
                PaywallFeatureRow(icon: "square.and.arrow.up", color: plusColor, text: store.t("分享目标成就卡片", "Share goal achievement cards"), tier: "Plus")
                PaywallFeatureRow(icon: "chart.bar.fill",      color: plusColor, text: store.t("月度/年度数据分析", "Monthly & yearly analytics"), tier: "Plus", isLast: true)
            }
            .background(AppTheme.bg1).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 1))
            .padding(.horizontal)

            // 价格 + 购买按钮
            VStack(spacing: 12) {
                // 显示 StoreKit 本地化价格，否则用回退价
                let priceText = pro.plusProduct?.displayPrice ?? store.t("¥28", "$3.99")
                Text(store.t("一次购买，永久使用", "Buy once, use forever"))
                    .font(.caption).foregroundColor(AppTheme.textSecondary)

                Button(action: { Task { await pro.purchasePlus() } }) {
                    HStack {
                        Image(systemName: "star.fill").font(.subheadline)
                        Text(store.t("购买 Plus · \(priceText)", "Get Plus · \(priceText)"))
                            .font(.headline).fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [plusColor, plusColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16).foregroundColor(AppTheme.bg0)
                }
            }.padding(.horizontal)
        }
    }

    // Pro 订阅内容暂时隐藏，等后续版本推出
    // private var proContent: some View { ... }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// ── 功能行 ──────────────────────────────────────────────────
struct PaywallFeatureRow: View {
    let icon: String; let color: Color; let text: String; let tier: String
    var isLast: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(color).frame(width: 20).padding(8)
                    .background(color.opacity(0.12)).cornerRadius(8)
                Text(text).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Image(systemName: "checkmark.circle.fill").foregroundColor(color).font(.body)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            if !isLast { Divider().background(AppTheme.border0).padding(.leading, 52) }
        }
    }
}

struct PlanOption: View {
    let isSelected: Bool; let badge: String?; let title: String; let price: String; let sub: String; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(AppTheme.textPrimary)
                        if let b = badge {
                            Text(b).font(.caption2).padding(.horizontal, 7).padding(.vertical, 3)
                                .background(AppTheme.gold.opacity(0.2))
                                .foregroundColor(AppTheme.gold).cornerRadius(5)
                        }
                    }
                    Text(sub).font(.caption2).foregroundColor(AppTheme.textTertiary)
                }
                Spacer()
                Text(price).font(.headline).fontWeight(.semibold).foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textTertiary).padding(.leading, 8)
            }
            .padding(16).background(isSelected ? AppTheme.accentSoft : AppTheme.bg2).cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isSelected ? AppTheme.accent.opacity(0.4) : AppTheme.border0, lineWidth: 1.5))
        }
    }
}

// ── 锁定组件（支持指定最低层级）────────────────────────────
struct ProLockedOverlay: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let message: String
    var requiredTier: UserTier = .plus

    private var tierIcon: String { requiredTier == .pro ? "crown.fill" : "star.fill" }
    private var tierColor: Color { requiredTier == .pro ? AppTheme.gold : AppTheme.accent }
    private var tierLabel: String {
        requiredTier == .pro
            ? store.t("升级 Pro 解锁", "Upgrade to Pro")
            : store.t("升级 Plus 解锁", "Upgrade to Plus")
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tierIcon).font(.title2).foregroundColor(tierColor)
            Text(message).font(.subheadline).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
            Button(action: { pro.showPaywall = true }) {
                Text(tierLabel)
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal, 20).padding(.vertical, 9)
                    .background(tierColor.opacity(0.15))
                    .foregroundColor(tierColor).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(tierColor.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
        .background(AppTheme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border0, lineWidth: 1))
    }
}

// ============================================================
// MARK: - 分享卡片
// ============================================================

struct ShareGoalCard: View {
    let goal: Goal
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DailyNav").font(.caption2).foregroundColor(goal.color).kerning(2)
                    Text(goal.title).font(.title3).fontWeight(.semibold).foregroundColor(.white)
                    Text(goal.category.uppercased()).font(.caption2).foregroundColor(.white.opacity(0.5)).kerning(1.5)
                }
                Spacer()
                ZStack {
                    Circle().stroke(goal.color.opacity(0.3), lineWidth: 3).frame(width: 56, height: 56)
                    Circle().trim(from: 0, to: goal.progress)
                        .stroke(goal.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 56, height: 56).rotationEffect(.degrees(-90))
                    Text("\(Int(goal.progress * 100))%").font(.system(size: 12, weight: .bold)).foregroundColor(goal.color)
                }
            }
            VStack(spacing: 5) {
                ForEach(goal.tasks.prefix(4)) { task in
                    HStack(spacing: 8) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption).foregroundColor(task.isCompleted ? goal.color : .white.opacity(0.3))
                        Text(task.title).font(.caption).foregroundColor(task.isCompleted ? .white.opacity(0.9) : .white.opacity(0.5))
                            .strikethrough(task.isCompleted)
                        Spacer()
                    }
                }
            }
            HStack {
                if goal.goalType == .longterm {
                    HStack(spacing: 4) { Image(systemName: "flame").font(.caption2); Text(store.t("坚持 \(goal.daysSinceStart) 天", "\(goal.daysSinceStart) day streak")).font(.caption2) }.foregroundColor(goal.color)
                } else {
                    HStack(spacing: 4) { Image(systemName: "clock").font(.caption2); Text(store.t("还有 \(goal.daysLeft) 天", "\(goal.daysLeft) days left")).font(.caption2) }.foregroundColor(goal.color)
                }
                Spacer()
                Text(formatDate(Date(), format: "yyyy.M.d")).font(.caption2).foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), goal.color.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(goal.color.opacity(0.3), lineWidth: 1))
        .frame(width: 300)
    }
}

struct ShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let goal: Goal

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(store.t("分享目标卡片", "Share Goal Card")).font(.headline).foregroundColor(AppTheme.textPrimary).padding(.top, 20)
                ShareGoalCard(goal: goal)
                VStack(spacing: 12) {
                    ShareRow(icon: "message.fill", color: .green, label: store.t("发送给朋友", "Send to a Friend"), action: { dismiss() })
                    ShareRow(icon: "photo.fill", color: Color(red: 0.5, green: 0.7, blue: 1), label: store.t("保存到相册", "Save to Photos"), action: { dismiss() })
                    ShareRow(icon: "square.and.arrow.up", color: AppTheme.accent, label: store.t("更多分享方式", "More Options"), action: { dismiss() })
                }
                .background(AppTheme.bg1).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 1))
                .padding(.horizontal)
                Spacer()
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t("关闭", "Close")) { dismiss() }.foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}

struct ShareRow: View {
    let icon: String; let color: Color; let label: String; let action: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: icon).foregroundColor(color).frame(width: 20).padding(8).background(color.opacity(0.12)).cornerRadius(8)
                    Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppTheme.textTertiary)
                }.padding(.horizontal, 16).padding(.vertical, 12)
            }
            Divider().background(AppTheme.border0).padding(.leading, 52)
        }
    }
}

// ============================================================
// MARK: - 设置页
// ============================================================

struct SettingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // ── 会员状态横幅 ──────────────────────────
                    memberBanner

                    // ── 语言选择 ──────────────────────────────
                    SettingsSection(title: store.t(key: L10n.language)) {
                        VStack(spacing: 0) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                LanguageRow(
                                    lang: lang,
                                    isSelected: store.language == lang,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            store.language = lang
                                        }
                                        store.logCurrentLocale()
                                    }
                                )
                                if lang != AppLanguage.allCases.last {
                                    Divider().background(AppTheme.border0).padding(.leading, 16)
                                }
                            }
                        }
                        .background(AppTheme.bg1).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    // ── 每日提醒 ─────────────────────────────
                    NotificationSettingsSection()

                    // ── 数据管理 ─────────────────────────────
                    SettingsSection(title: store.t("数据管理", "Data")) {
                        VStack(spacing: 0) {
                            SRow2(icon: "square.and.arrow.up", label: store.t("导出数据 (JSON)", "Export Data (JSON)"), action: {
                                exportData()
                            })
                        }
                        .background(AppTheme.bg1).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    // ── 购买 & 支持 ───────────────────────────
                    SettingsSection(title: store.t(key: L10n.support)) {
                        VStack(spacing: 0) {
                            // 恢复购买
                            SRow2(icon: "arrow.clockwise", label: store.t("恢复购买", "Restore Purchase"), action: {
                                Task { await pro.restore() }
                            })
                            SRowDivider()
                            // 给我们评分 → 使用新 API（iOS 18+）兼容旧版
                            SRow2(icon: "star", label: store.t(key: L10n.rateUs), action: {
                                if let scene = UIApplication.shared.connectedScenes
                                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                    if #available(iOS 18.0, *) {
                                        StoreKit.AppStore.requestReview(in: scene)
                                    } else {
                                        SKStoreReviewController.requestReview(in: scene)
                                    }
                                }
                            })
                            SRowDivider()
                            // 联系我们 → 邮件
                            SRow2(icon: "envelope", label: store.t(key: L10n.contactUs), action: {
                                if let url = URL(string: "mailto:support@dailynav.app?subject=DailyNav%20Feedback") {
                                    UIApplication.shared.open(url)
                                }
                            })
                            SRowDivider()
                            // 隐私政策 → Safari
                            SRow2(icon: "doc.text", label: store.t(key: L10n.privacyPolicy), action: {
                                if let url = URL(string: "https://Wangvinci.github.io/dailynav/privacy.html") {
                                    UIApplication.shared.open(url)
                                }
                            })
                            SRowDivider()
                            // 服务条款 → Safari
                            SRow2(icon: "doc.plaintext", label: store.t("服务条款", "Terms of Service"), action: {
                                if let url = URL(string: "https://Wangvinci.github.io/dailynav/terms.html") {
                                    UIApplication.shared.open(url)
                                }
                            })
                            SRowDivider()
                            SRow2(icon: "info.circle", label: "Version 1.0.0", action: nil)
                        }
                        .background(AppTheme.bg1).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    // ── Coming Soon ───────────────────────────
                    SettingsSection(title: store.t(key: L10n.comingSoon)) {
                        VStack(spacing: 0) {
                            ComingSoonRow(icon: "icloud", label: store.t(key: L10n.cloudSync))
                            SRowDivider()
                            ComingSoonRow(icon: "timer", label: store.t(key: L10n.focusMode))
                            SRowDivider()
                            ComingSoonRow(icon: "rectangle.on.rectangle", label: store.t(key: L10n.homeWidget))
                        }
                        .background(AppTheme.bg1).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(key: L10n.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(key: L10n.done)) { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
    }

    // ── 会员状态横幅 ──────────────────────────────────────────
    @ViewBuilder
    private var memberBanner: some View {
        switch pro.tier {
        case .pro:
            tierBadge(
                icon: "crown.fill",
                title: "DailyNav Pro",
                subtitle: store.t(key: L10n.activeSubscription),
                color: AppTheme.gold
            )
        case .plus:
            tierBadge(
                icon: "star.fill",
                title: "DailyNav Plus",
                subtitle: store.t("永久会员", "Lifetime Member"),
                color: AppTheme.accent
            )
        case .free:
            Button(action: { pro.showPaywall = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 40, height: 40)
                        Image(systemName: "star.fill").font(.system(size: 16)).foregroundColor(AppTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.t("升级 Plus", "Upgrade to Plus"))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
                        Text(store.t("一次买断，永久解锁", "Buy once, unlock forever"))
                            .font(.system(size: 11)).foregroundColor(AppTheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(AppTheme.textTertiary)
                }
                .padding(16).background(AppTheme.bg1).cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.gold.opacity(0.22), lineWidth: 0.8))
            }
        }
    }

    private func tierBadge(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppTheme.textPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16).background(AppTheme.bg1).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.18), lineWidth: 0.8))
    }
}

// ── Settings sub-components ──────────────────────────────

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textTertiary)
                .kerning(1.2)
                .padding(.leading, 4)
            content
        }
    }
}

struct LanguageRow: View {
    let lang: AppLanguage
    let isSelected: Bool
    let onTap: () -> Void
    var langDisplayFull: String { lang.displayName }
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textTertiary)
                    .frame(width: 20)
                Text(langDisplayFull)
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

struct SRow2: View {
    let icon: String
    let label: String
    let action: (() -> Void)?
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .disabled(action == nil)
    }
}

struct SRowDivider: View {
    var body: some View {
        Divider().background(AppTheme.border0).padding(.leading, 16)
    }
}

struct ComingSoonRow: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(AppTheme.textTertiary.opacity(0.6))
                .frame(width: 20)
            Text(label).font(.system(size: 15)).foregroundColor(AppTheme.textTertiary)
            Spacer()
            Text("Soon").font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(AppTheme.bg2).cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SRow: View {
    let icon: String; let color: Color; let label: String; let action: (() -> Void)?
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action ?? {}) {
                HStack(spacing: 12) {
                    Image(systemName: icon).foregroundColor(color).frame(width: 20).padding(8).background(color.opacity(0.12)).cornerRadius(8)
                    Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if action != nil { Image(systemName: "chevron.right").font(.caption2).foregroundColor(AppTheme.textTertiary) }
                }.padding(.horizontal, 16).padding(.vertical, 13)
            }.disabled(action == nil)
            Divider().background(AppTheme.border0).padding(.leading, 56)
        }
    }
}

struct GPTextField: View {
    let placeholder: String; @Binding var text: String
    var keyboardType: UIKeyboardType = .default; var isSecure: Bool = false
    var body: some View {
        Group {
            if isSecure { SecureField(placeholder, text: $text) }
            else { TextField(placeholder, text: $text).keyboardType(keyboardType).autocapitalization(.none) }
        }
        .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12)
        .foregroundColor(AppTheme.textPrimary)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border1, lineWidth: 1))
    }
}

// ============================================================
// MARK: - 通知设置区块
// ============================================================

struct NotificationSettingsSection: View {
    @ObservedObject private var nm = NotificationManager.shared
    @EnvironmentObject var store: AppStore

    var body: some View {
        SettingsSection(title: store.t("每日提醒", "Daily Reminders")) {
            VStack(spacing: 0) {
                if !nm.isAuthorized {
                    // 未授权状态
                    Button(action: {
                        Task {
                            _ = await nm.requestPermission()
                            HapticManager.impact(.light)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.t("开启每日提醒", "Enable Daily Reminders"))
                                    .font(.system(size: 15)).foregroundColor(AppTheme.textPrimary)
                                Text(store.t("帮你养成每日打卡的习惯", "Build a daily check-in habit"))
                                    .font(.system(size: 11)).foregroundColor(AppTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                } else {
                    // 已授权：显示开关
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(AppTheme.textSecondary).frame(width: 20)
                        Text(store.t("早间提醒 \(String(format:"%02d:%02d", nm.morningHour, nm.morningMinute))",
                                     "Morning \(String(format:"%02d:%02d", nm.morningHour, nm.morningMinute))"))
                            .font(.system(size: 15)).foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $nm.morningEnabled)
                            .tint(AppTheme.accent)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)

                    SRowDivider()

                    HStack(spacing: 12) {
                        Image(systemName: "moon")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(AppTheme.textSecondary).frame(width: 20)
                        Text(store.t("晚间回顾 \(String(format:"%02d:%02d", nm.eveningHour, nm.eveningMinute))",
                                     "Evening \(String(format:"%02d:%02d", nm.eveningHour, nm.eveningMinute))"))
                            .font(.system(size: 15)).foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Toggle("", isOn: $nm.eveningEnabled)
                            .tint(AppTheme.accent)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
            .background(AppTheme.bg1).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
        }
    }
}

// ============================================================
// MARK: - 数据导出
// ============================================================

extension SettingsSheet {
    func exportData() {
        let data = store.exportAIData(days: 9999)  // 导出全部
        guard let json = try? JSONEncoder().encode(data),
              let jsonString = String(data: json, encoding: .utf8) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DailyNav_Export_\(Date().formatted(.iso8601)).json")
        try? jsonString.write(to: tempURL, atomically: true, encoding: .utf8)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        HapticManager.impact(.light)
    }
}
