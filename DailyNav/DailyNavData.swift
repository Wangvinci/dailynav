import SwiftUI
import Combine
import StoreKit
import Security

// ============================================================
// MARK: - 语言  (AppLanguage is defined in L10n.swift)
// ============================================================
// AppLanguage: zh / en / ja / ko / es — all localization in L10n.swift

// ============================================================
// MARK: - 付费系统（三层：Free / Plus 买断 / Pro 订阅）
// ============================================================

// ── 我的成长层级数据结构 ────────────────────────────────────
struct GrowthDayEntry   { let date: Date; let review: DayReview }
struct GrowthWeekEntry  { let label: String; let key: String; let dates: [Date] }
struct GrowthMonthEntry { let label: String; let key: String; let dates: [Date] }
struct GrowthYearEntry  { let year: Int; let label: String; let dates: [Date] }

// ── 用户等级 ─────────────────────────────────────────────────
enum UserTier: String, Codable, Comparable {
    case free = "free"
    case plus = "plus"     // 买断：解锁完整功能
    case pro  = "pro"      // 订阅：Plus 全部 + AI 智能分析

    static func < (lhs: UserTier, rhs: UserTier) -> Bool {
        let order: [UserTier] = [.free, .plus, .pro]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// ── Keychain 工具（无需第三方库）────────────────────────────
private enum Keychain {
    static let service = "com.dailynav.prostore"

    static func write(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// ── ProStore（管理三层付费状态）─────────────────────────────
@MainActor
class ProStore: ObservableObject {

    // ── 对外状态 ──────────────────────────────────────────────
    @Published var tier: UserTier = .free
    @Published var showPaywall: Bool = false
    @Published var isLoading: Bool = false

    // ── 老用户认定（首次运行新版时写入 Keychain）─────────────
    // 已有 userTier 记录 = 老版用户 → 永久 Plus 权限（不受限）
    @Published private(set) var isLegacyUser: Bool = false

    // ── 有效权限：老用户 Free → 等同 Plus ───────────────────
    var effectiveTier: UserTier {
        isLegacyUser && tier == .free ? .plus : tier
    }

    // ── 向后兼容：isPro = Plus 或 Pro 均为 true ──────────────
    var isPro: Bool {
        get { effectiveTier >= .plus }
        set { tier = newValue ? .plus : .free }
    }
    var isProSubscriber: Bool { effectiveTier == .pro }

    // ── 新用户：首次启动显示付费墙 ───────────────────────────
    var needsInitialPaywall: Bool { !isLegacyUser && tier == .free }

    // ── 产品 ID（必须与 App Store Connect 中创建的完全一致）──
    // 前缀 = Bundle ID (com.vince.dailynav)
    // 买断（非消耗型）
    static let plusProductID      = "com.vince.dailynav.plus.lifetime"
    // 订阅（自动续期）
    static let proMonthlyID      = "com.vince.dailynav.pro.monthly"
    static let proYearlyID       = "com.vince.dailynav.pro.yearly"

    static let allProductIDs: Set<String> = [
        plusProductID, proMonthlyID, proYearlyID
    ]

    // ── 免费版限制 ────────────────────────────────────────────
    static let freeGoalLimit  = 2    // 免费版最多 2 个目标
    static let freeTaskLimit  = 2    // 免费版每个目标最多 2 个任务
    static let freeQuoteLimit = 1    // 免费版每天 1 条语录

    // ── StoreKit 产品对象（用于展示本地化价格）────────────────
    @Published var plusProduct: Product? = nil
    @Published var proMonthly: Product? = nil
    @Published var proYearly: Product? = nil

    // ── Transaction 监听任务 ──────────────────────────────────
    private var transactionListener: Task<Void, Never>? = nil

    // ── 初始化 ────────────────────────────────────────────────
    init() {
        // 1. 老用户认定（只需判断一次，结果写入 Keychain 持久化）
        if let saved = Keychain.read("isLegacyUser") {
            // 已写入过 → 直接读取
            isLegacyUser = (saved == "true")
        } else {
            // 首次运行新版本：有 userTier 记录 = 老用户
            let hadPriorSession = Keychain.read("userTier") != nil
            isLegacyUser = hadPriorSession
            Keychain.write("isLegacyUser", value: hadPriorSession ? "true" : "false")
        }
        // 2. 快速恢复上次 tier（避免启动白屏）
        if let saved = Keychain.read("userTier"),
           let t = UserTier(rawValue: saved) {
            tier = t
        }
        // 3. 启动后台校验 + 监听
        transactionListener = listenForTransactions()
        Task { await initialize() }
    }

    deinit { transactionListener?.cancel() }

    // ── 后台监听 Transaction 更新（续费/退款/家庭共享）────────
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }

    // ── 启动校验 ──────────────────────────────────────────────
    func initialize() async {
        // 1. 加载全部产品信息
        do {
            let products = try await Product.products(for: Self.allProductIDs)
            for p in products {
                switch p.id {
                case Self.plusProductID: plusProduct = p
                case Self.proMonthlyID: proMonthly = p
                case Self.proYearlyID:  proYearly  = p
                default: break
                }
            }
        } catch {
            #if DEBUG
            print("[ProStore] Failed to fetch products: \(error)")
            #endif
        }
        // 2. 校验当前 entitlements
        await refreshEntitlements()
        // 3. 新用户首次启动 → 弹出付费墙
        if needsInitialPaywall {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s 等启动动画完成
            showPaywall = true
        }
    }

    // ── 刷新权益状态 ──────────────────────────────────────────
    func refreshEntitlements() async {
        var hasPlus = false
        var hasPro  = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result,
                  tx.revocationDate == nil else { continue }
            switch tx.productID {
            case Self.plusProductID:
                hasPlus = true
            case Self.proMonthlyID, Self.proYearlyID:
                // 订阅需要检查是否过期
                if let expiry = tx.expirationDate, expiry > Date() {
                    hasPro = true
                } else if tx.expirationDate == nil {
                    hasPro = true  // 非过期类型
                }
            default: break
            }
        }

        // Pro 包含 Plus 全部权益
        let newTier: UserTier = hasPro ? .pro : (hasPlus ? .plus : .free)
        tier = newTier
        Keychain.write("userTier", value: newTier.rawValue)
    }

    // ── 购买 Plus（买断）────────────────────────────────────
    func purchasePlus() async {
        guard let product = plusProduct else { return }
        await doPurchase(product)
    }

    // ── 购买 Pro 订阅 ─────────────────────────────────────────
    func purchasePro(yearly: Bool) async {
        let product = yearly ? proYearly : proMonthly
        guard let product else { return }
        await doPurchase(product)
    }

    // ── 通用购买流程 ──────────────────────────────────────────
    private func doPurchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlements()
                    showPaywall = false
                }
            case .userCancelled: break
            case .pending: break
            @unknown default: break
            }
        } catch {
            #if DEBUG
            print("[ProStore] purchase error: \(error)")
            #endif
        }
    }

    // ── 恢复购买（Apple 审核必须有）──────────────────────────
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await StoreKit.AppStore.sync()
        await refreshEntitlements()
        if tier >= .plus { showPaywall = false }
    }

    // ── 权限检查方法 ──────────────────────────────────────────

    /// 要求 Plus 或以上才能使用
    func requirePlus(action: @escaping () -> Void) {
        if effectiveTier >= .plus { action() } else { showPaywall = true }
    }

    /// 要求 Pro 订阅才能使用（AI 功能）
    func requirePro(action: @escaping () -> Void) {
        if effectiveTier >= .pro { action() } else { showPaywall = true }
    }

    /// 检查是否有某功能的权限
    func hasAccess(to feature: Feature) -> Bool {
        feature.minimumTier <= effectiveTier
    }

    // ── 功能权限定义 ──────────────────────────────────────────
    enum Feature {
        // Plus（买断）— 解锁完整功能
        case unlimitedGoals        // 无限目标（免费版最多 2 个）
        case unlimitedTasks        // 无限任务（免费版每目标最多 2 个）
        case unlimitedQuotes       // 无限语录
        case journalHistory        // 心得历史回顾
        case shareCards            // 分享成就卡片
        case monthlyYearlyStats    // 月度/年度数据分析

        // Pro（订阅）— Plus 全部 + AI 智能功能
        case aiWeeklySummary       // AI 智能周报
        case aiMonthlySummary      // AI 智能月报
        case aiYearlySummary       // AI 智能年报
        case aiInsights            // AI 个性化成长洞察
        case aiSuggestions         // AI 目标/习惯建议
        case cloudSync             // iCloud 同步 (Coming Soon)

        var minimumTier: UserTier {
            switch self {
            case .unlimitedGoals, .unlimitedTasks, .unlimitedQuotes,
                 .journalHistory, .shareCards,
                 .monthlyYearlyStats:
                return .plus
            case .aiWeeklySummary, .aiMonthlySummary, .aiYearlySummary,
                 .aiInsights, .aiSuggestions, .cloudSync:
                return .pro
            }
        }
    }

    /// 检查目标数量是否超限
    func canAddGoal(currentCount: Int) -> Bool {
        effectiveTier >= .plus || currentCount < Self.freeGoalLimit
    }

    /// 检查任务数量是否超限
    func canAddTask(currentTaskCount: Int) -> Bool {
        effectiveTier >= .plus || currentTaskCount < Self.freeTaskLimit
    }
}

// ============================================================
// MARK: - 模型
// ============================================================

// ── Color Codable 桥接 ─────────────────────────────────────
struct CodableColor: Codable, Equatable {
    var r: Double; var g: Double; var b: Double; var a: Double
    init(_ color: Color) {
        let ui = UIColor(color)
        var rv: CGFloat = 0, gv: CGFloat = 0, bv: CGFloat = 0, av: CGFloat = 0
        ui.getRed(&rv, green: &gv, blue: &bv, alpha: &av)
        r = Double(rv); g = Double(gv); b = Double(bv); a = Double(av)
    }
    var color: Color { Color(red: r, green: g, blue: b, opacity: a) }
}

enum TaskPriority: Int, Codable, CaseIterable {
    case none = 0, low = 1, medium = 2, high = 3

    var label: String {
        switch self { case .none: "—"; case .low: "Low"; case .medium: "Med"; case .high: "High" }
    }
    var icon: String {
        switch self { case .none: "minus"; case .low: "flag"; case .medium: "flag.fill"; case .high: "flag.fill" }
    }
    var color: Color {
        switch self {
        case .none:   return Color.clear
        case .low:    return Color(red:0.230, green:0.660, blue:0.960)  // blue
        case .medium: return Color(red:0.960, green:0.640, blue:0.320)  // orange
        case .high:   return Color(red:0.960, green:0.380, blue:0.420)  // red
        }
    }
}

struct GoalTask: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var estimatedMinutes: Int?
    var progress: Double = 0.0
    var pinnedDate: Date? = nil       // 非nil时只在该天显示（单日任务）
    var timeSlot: Int? = nil          // 0=上午 1=下午 2=晚上 nil=未分配
    var priority: TaskPriority = .none
    var isCompleted: Bool { progress >= 1.0 }
}

enum GoalType: String, CaseIterable, Equatable, Codable {
    case deadline = "deadline"; case longterm = "longterm"
}

enum GoalRecurrence: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekdays = "weekdays"     // Mon-Fri
    case weekends = "weekends"     // Sat-Sun
}

struct GoalMilestone: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var targetDate: Date? = nil
    var isCompleted: Bool = false
    var completedDate: Date? = nil
}

struct GoalPhase: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date
    var description: String = ""
}

struct Goal: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var category: String
    private var _color: CodableColor
    var color: Color {
        get { _color.color }
        set { _color = CodableColor(newValue) }
    }
    var goalType: GoalType
    var startDate: Date
    var endDate: Date?
    var tasks: [GoalTask]
    var showCalendarDot: Bool = true
    var recurrence: GoalRecurrence = .none
    var milestones: [GoalMilestone] = []
    var phases: [GoalPhase] = []

    init(id: UUID = UUID(), title: String, category: String, color: Color,
         goalType: GoalType, startDate: Date, endDate: Date? = nil,
         tasks: [GoalTask] = [], showCalendarDot: Bool = true,
         recurrence: GoalRecurrence = .none,
         milestones: [GoalMilestone] = [], phases: [GoalPhase] = []) {
        self.id = id; self.title = title; self.category = category
        self._color = CodableColor(color)
        self.goalType = goalType; self.startDate = startDate
        self.endDate = endDate; self.tasks = tasks
        self.showCalendarDot = showCalendarDot
        self.recurrence = recurrence
        self.milestones = milestones; self.phases = phases
    }

    enum CodingKeys: String, CodingKey {
        case id, title, category, _color = "color", goalType, startDate, endDate, tasks, showCalendarDot
        case recurrence, milestones, phases
    }

    func covers(_ date: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date), s = cal.startOfDay(for: startDate)
        guard d >= s else { return false }
        // Check date range first
        let inRange: Bool
        if goalType == .longterm { inRange = true }
        else if let e = endDate { inRange = d <= cal.startOfDay(for: e) }
        else { inRange = false }
        guard inRange else { return false }
        // Apply recurrence filter
        switch recurrence {
        case .none, .daily: return true
        case .weekdays:
            let wd = cal.component(.weekday, from: date)
            return wd >= 2 && wd <= 6  // Mon=2..Fri=6
        case .weekends:
            let wd = cal.component(.weekday, from: date)
            return wd == 1 || wd == 7  // Sun=1, Sat=7
        }
    }

    /// Current phase based on today's date
    var currentPhase: GoalPhase? {
        let today = Calendar.current.startOfDay(for: Date())
        return phases.first { p in
            let s = Calendar.current.startOfDay(for: p.startDate)
            let e = Calendar.current.startOfDay(for: p.endDate)
            return today >= s && today <= e
        }
    }

    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return tasks.map(\.progress).reduce(0,+) / Double(tasks.count)
    }

    var daysLeft: Int {
        guard let e = endDate else { return -1 }
        return Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: Date()),
            to:   Calendar.current.startOfDay(for: e)).day ?? 0
    }

    var daysSinceStart: Int {
        Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: startDate),
            to:   Calendar.current.startOfDay(for: Date())).day ?? 0
    }
}

struct DailyRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID; var progress: Double
}

// 跨天移动的任务记录（目标本身不覆盖该天时使用）
struct ExtraTaskEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID
}

// 周/月/年总结（结构化：情绪/收获/困难/展望 + 关键词 + 困难跟踪）
struct PeriodSummary: Identifiable, Codable {
    var id = UUID()
    var periodType: Int          // 0=周 1=月 2=年
    var periodLabel: String      // "2026年第10周" / "2026年2月" / "2026年"
    var startDate: Date
    var mood: Int = 0            // 1-5 情绪评分
    var gains: String = ""       // 收获详细
    var challenges: String = ""  // 困难详细
    // 关键词（3-5词）
    var gainKeywords: [String] = []
    var challengeKeywords: [String] = []
    // 困难跟踪：记录下层（日/周）哪些困难关键词已被标为已解决
    var resolvedChallenges: Set<String> = []
    var text: String = ""        // 旧版自由文本（兼容）
    var submittedAt: Date = Date()
    var hasContent: Bool { mood > 0 || !gains.isEmpty || !challenges.isEmpty || !gainKeywords.isEmpty }
    var avgCompletion: Double = 0
}

struct PlanTaskOverride: Identifiable, Codable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID
    var overrideTitle: String?; var overrideMinutes: Int?
    var isSkipped: Bool
}

// 每日困难追踪条目（独立于日记，可跨天继承）
struct DailyChallengeEntry: Identifiable, Equatable, Codable {
    var id = UUID()
    var date: Date                          // 归属日期（首次出现）
    var keyword: String                     // 困难关键词
    var resolvedOnDate: Date? = nil         // 被解决的日期（nil=未解决）
    var resolvedNote: String = ""           // 解决心得（可选）
}

// 每日回顾（提交后才保存）
struct DayReview: Identifiable, Equatable, Codable {
    var id = UUID()
    var date: Date
    var rating: Int = 0
    var feedbackNote: String = ""
    var journalGains: String = ""       // 收获详细文本
    var journalChallenges: String = ""  // 困难详细文本
    // 关键词（3-5词，用于智能总结 + 上层汇总）
    var gainKeywords: [String] = []
    var challengeKeywords: [String] = []
    var isSubmitted: Bool = false
}

enum AchievementLevel: String, CaseIterable, Codable {
    case good = "基本完成"; case great = "优秀完成"
    case perfect = "完美完成"; case milestone = "里程碑"
}

struct Achievement: Identifiable, Codable {
    var id = UUID()
    var goalId: UUID; var goalTitle: String
    private var _goalColor: CodableColor
    var goalColor: Color {
        get { _goalColor.color }
        set { _goalColor = CodableColor(newValue) }
    }
    var level: AchievementLevel; var completionRate: Double
    var date: Date; var streakDays: Int?; var description: String

    init(id: UUID = UUID(), goalId: UUID, goalTitle: String, goalColor: Color,
         level: AchievementLevel, completionRate: Double, date: Date,
         streakDays: Int? = nil, description: String) {
        self.id = id; self.goalId = goalId; self.goalTitle = goalTitle
        self._goalColor = CodableColor(goalColor)
        self.level = level; self.completionRate = completionRate
        self.date = date; self.streakDays = streakDays; self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, goalId, goalTitle, _goalColor = "goalColor", level, completionRate, date, streakDays, description
    }

    var emoji: String {
        switch level { case .good:"🎯"; case .great:"⭐"; case .perfect:"🏆"; case .milestone:"🔥" }
    }
    var levelColor: Color {
        switch level {
        case .good:      return .teal
        case .great:     return Color(red:1,green:0.85,blue:0.2)
        case .perfect:   return Color(red:1,green:0.75,blue:0.2)
        case .milestone: return AppTheme.danger
        }
    }
}

// ============================================================
// MARK: - 奖励记录（日/周/月/年 — 递增强度）
// ============================================================

enum RewardLevel: String, CaseIterable, Codable {
    case day   = "day"
    case week  = "week"
    case month = "month"
    case year  = "year"

    var symbol: String {
        switch self {
        case .day:   return "sparkle"
        case .week:  return "crown.fill"
        case .month: return "seal.fill"
        case .year:  return "laurel.leading"
        }
    }
    var emoji: String {
        switch self { case .day: return "✦"; case .week: return "❋"; case .month: return "◈"; case .year: return "✺" }
    }
    var color: Color {
        switch self {
        case .day:   return AppTheme.accent.opacity(0.90)
        case .week:  return AppTheme.gold.opacity(0.92)
        case .month: return Color(red:0.780, green:0.490, blue:0.780)
        case .year:  return Color(red:0.960, green:0.640, blue:0.320)
        }
    }
    var hapticStrength: Int {
        switch self { case .day: return 1; case .week: return 2; case .month: return 3; case .year: return 3 }
    }
}

struct RewardRecord: Identifiable, Codable {
    var id = UUID()
    var level: RewardLevel
    var date: Date
    var periodLabel: String
    var completionRate: Double
}

// ============================================================
// MARK: - 计划心得（Plan Journal Entry）
// ============================================================

struct PlanJournalEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var goalId: UUID
    var goalTitle: String
    var taskId: UUID?
    var taskTitle: String?
    var note: String
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

// ============================================================
// MARK: - 颜色主题
// ============================================================

struct AppTheme {
    // ═══════════════════════════════════════════════════════════
    // DESIGN SYSTEM v4  —  Cyber·Monet  「赛博·莫奈」
    // Philosophy: Giverny garden seen through a neural lens.
    //   Dark silicon base, watercolour pigment accents.
    //   Glass has depth. Neon has restraint. Typography breathes.
    //   Reference: Water Lilies + Ghost in the Shell + Blade Runner 2049
    // ═══════════════════════════════════════════════════════════

    // ── 背景层：深宇宙，带极微蓝调 ──────────────────────────
    // bg0: #0F1117  近黑，深宇宙底
    static let bg0 = Color(red:0.059, green:0.067, blue:0.090)
    // bg1: #181D27  卡片底，深夜硅基
    static let bg1 = Color(red:0.094, green:0.114, blue:0.153)
    // bg2: #1F2535  次层面板
    static let bg2 = Color(red:0.122, green:0.145, blue:0.208)
    // bg3: #2A3248  hover / 选中态
    static let bg3 = Color(red:0.165, green:0.196, blue:0.282)

    // ── 边框：发光玻璃边缘 ────────────────────────────────────
    static let border0    = Color.white.opacity(0.055)               // 静止态极淡
    static let border1    = Color.white.opacity(0.110)               // 焦点态
    static let borderGlow = Color(red:0.400, green:0.860, blue:0.720).opacity(0.22)  // 接近碰撞发光

    // ── 文字：冷象牙，带电气感 ───────────────────────────────
    static let textPrimary   = Color(red:0.920, green:0.930, blue:0.945)  // 冷白象牙
    static let textSecondary = Color(red:0.580, green:0.620, blue:0.680)  // 金属灰蓝
    static let textTertiary  = Color(red:0.320, green:0.360, blue:0.420)  // 深宇宙灰

    // ── 主调：莫奈荷叶绿·赛博化 — 提亮0.05，更有发光感 ──────
    static let accent      = Color(red:0.380, green:0.820, blue:0.700)   // #61D1B3 电光荷影
    static let accentSoft  = Color(red:0.380, green:0.820, blue:0.700).opacity(0.12)
    static let accentGlow  = Color(red:0.380, green:0.820, blue:0.700).opacity(0.18)
    // 赛博蓝 — 次要强调色
    static let cyberBlue   = Color(red:0.230, green:0.660, blue:0.960)   // #3BA8F5 深海蓝 (aligns with palette[2])
    static let cyberPurple = Color(red:0.630, green:0.550, blue:0.960)   // #A08CF5 雾霭紫 (aligns with palette[7])
    // 莫奈雾紫·赛博混血
    static let monetMauve  = Color(red:0.720, green:0.480, blue:0.820)   // 发光紫藤

    // ── 目标调色板：光谱收敛 十色 ────────────────────────────
    // 设计原则：围绕"碧玉–海洋"冷轴，暖系(橙/珊瑚)形成呼应
    // 去掉孤立的饱和纯紫；紫色统一偏蓝调以保持光谱和谐
    // Group A — 冷系（海洋·碧玉）
    // Group B — 暖系（琥珀·珊瑚）
    // Group C — 桥接（雾紫·樱粉·嫩绿）
    static let palette: [Color] = [
        // ── Group A: 冷系 ──
        Color(red:0.380, green:0.820, blue:0.700),   // #61D1B3 荷影绿  Waterlily Cyan
        Color(red:0.300, green:0.750, blue:0.850),   // #4DBFD9 冰川青  Glacier Teal
        Color(red:0.230, green:0.660, blue:0.960),   // #3BA8F5 深海蓝  Deep Ocean
        Color(red:0.420, green:0.750, blue:0.670),   // #6ABFAA 薄荷绿  Soft Mint
        // ── Group B: 暖系 ──
        Color(red:0.960, green:0.640, blue:0.320),   // #F5A352 琥珀橙  Amber Pulse
        Color(red:0.940, green:0.440, blue:0.380),   // #F07060 珊瑚红  Coral Neon
        Color(red:0.960, green:0.780, blue:0.260),   // #F5C842 柠檬黄  Lemon Zest
        // ── Group C: 桥接 ──
        Color(red:0.630, green:0.550, blue:0.960),   // #A08CF5 雾霭紫  Mist Violet (蓝调紫，和谐)
        Color(red:0.780, green:0.490, blue:0.780),   // #C87EC8 樱花玫  Sakura Rose
        Color(red:0.480, green:0.800, blue:0.540),   // #7ACC8A 嫩芽绿  Spring Shoot
    ]

    // ── 语义色 ────────────────────────────────────────────────
    static let gold    = Color(red:0.980, green:0.820, blue:0.380)  // 钛金黄
    static let danger  = Color(red:0.960, green:0.380, blue:0.420)  // 警戒红
    static let success = Color(red:0.380, green:0.900, blue:0.560)  // 确认绿

    // ── 渐变辅助 ──────────────────────────────────────────────
    static let gradientTop    = Color(red:0.380, green:0.820, blue:0.700).opacity(0.10)
    static let gradientBottom = Color.clear

    // ── 扫描线 & 玻璃质感辅助 ────────────────────────────────
    static let scanlineOpacity: Double = 0.028     // 扫描线透明度（极克制）
    static let glassBase:   Double = 0.22          // glass fill base opacity
    static let glassBorder: Double = 0.11          // glass border opacity
    static let neonGlow:    Double = 0.35          // neon glow max opacity

    // ── Inspire page — dream glass tokens ─────────────────────
    /// Ultra-thin frosted card fill (氛围层基底)
    static let dreamCardFill = Color(red:0.094, green:0.114, blue:0.153).opacity(0.82)
    /// Soft teal glow for the breathing pulse (呼吸光 — 主调)
    static let dreamGlow  = Color(red:0.380, green:0.820, blue:0.700).opacity(0.18)
    /// Complementary violet bloom (补色)
    static let dreamBloom = Color(red:0.630, green:0.550, blue:0.960).opacity(0.10)
    /// Art atmosphere base opacity — adjustable for performance
    static let artOpacity: Double = 0.045    // 名画层透明度（0 = 纯色模式降级）
    /// Vignette darkness for art layer
    static let vignetteDepth: Double = 0.72
}

extension Color {
    static func dotColor(count: Int) -> Color {
        switch count {
        case 1: return AppTheme.accent.opacity(0.5)
        case 2: return AppTheme.accent.opacity(0.75)
        default: return AppTheme.accent
        }
    }
}

// ============================================================
// MARK: - AppStore
// ============================================================

@MainActor
class AppStore: ObservableObject {

    // ── 持久化 key 常量 ─────────────────────────────────────
    private enum Key {
        static let goals            = "dn_goals"
        static let dailyRecords     = "dn_dailyRecords"
        static let planOverrides    = "dn_planOverrides"
        static let extraTasks       = "dn_extraTasks"
        static let achievements     = "dn_achievements"
        static let dayReviews       = "dn_dayReviews"
        static let periodSummaries  = "dn_periodSummaries"
        static let dailyChallenges  = "dn_dailyChallenges"
        static let language         = "dn_language"
        static let userBirthYear    = "dn_userBirthYear"
        static let rewardRecords    = "dn_rewardRecords"
        static let planJournals     = "dn_planJournals"
    }

    private let ud = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    // init期间跳过didSet持久化（避免写空数据）
    private var isLoading = true

    // ── 通用存储/读取 helper ────────────────────────────────
    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) { ud.set(data, forKey: key) }
    }
    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = ud.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    init() {
        isLoading = true
        defer { isLoading = false }

        // 读取语言（无存档时按系统语言自动检测）
        if let saved = load(AppLanguage.self, key: Key.language) {
            language = saved
        } else {
            let sysLang = Locale.preferredLanguages.first ?? ""
            if sysLang.hasPrefix("zh")      { language = .chinese  }
            else if sysLang.hasPrefix("ja") { language = .japanese }
            else if sysLang.hasPrefix("ko") { language = .korean   }
            else if sysLang.hasPrefix("es") { language = .spanish  }
            else                            { language = .english  }
        }
        // 读取用户数据
        if let g  = load([Goal].self,                key: Key.goals)           { goals           = g  }
        if let dr = load([DailyRecord].self,         key: Key.dailyRecords)    { dailyRecords    = dr }
        if let po = load([PlanTaskOverride].self,    key: Key.planOverrides)   { planOverrides   = po }
        if let et = load([ExtraTaskEntry].self,      key: Key.extraTasks)      { extraTasks      = et }
        if let ac = load([Achievement].self,         key: Key.achievements)    { achievements    = ac }
        if let rv = load([DayReview].self,           key: Key.dayReviews)      { dayReviews      = rv }
        if let ps = load([PeriodSummary].self,       key: Key.periodSummaries) { periodSummaries = ps }
        if let dc = load([DailyChallengeEntry].self, key: Key.dailyChallenges) { dailyChallenges = dc }
        if let rr = load([RewardRecord].self,        key: Key.rewardRecords)   { rewardRecords   = rr }
        if let pj = load([PlanJournalEntry].self,    key: Key.planJournals)    { planJournals    = pj }
        if let by = ud.object(forKey: Key.userBirthYear) as? Int               { userBirthYear   = by }
        // 仅全新安装时创建1个示例目标：双重判断 + 强制写盘
        let isFirstInstall = ud.object(forKey: "dn_ever_initialized") == nil
                          && ud.data(forKey: Key.goals) == nil
        ud.set(true, forKey: "dn_ever_initialized")
        if isFirstInstall && goals.isEmpty {
            initDefaultGoals()
        }
        save(goals, key: Key.goals)
        ud.synchronize()
    }

    @Published var goals: [Goal] = [] {
        didSet { if !isLoading { save(goals, key: Key.goals) } }
    }
    @Published var dailyRecords: [DailyRecord] = [] {
        didSet { if !isLoading { save(dailyRecords, key: Key.dailyRecords) } }
    }
    @Published var planOverrides: [PlanTaskOverride] = [] {
        didSet { if !isLoading { save(planOverrides, key: Key.planOverrides) } }
    }
    @Published var extraTasks: [ExtraTaskEntry] = [] {
        didSet { if !isLoading { save(extraTasks, key: Key.extraTasks) } }
    }
    @Published var achievements: [Achievement] = [] {
        didSet { if !isLoading { save(achievements, key: Key.achievements) } }
    }
    @Published var dayReviews: [DayReview] = [] {
        didSet { if !isLoading { save(dayReviews, key: Key.dayReviews) } }
    }
    @Published var periodSummaries: [PeriodSummary] = [] {
        didSet { if !isLoading { save(periodSummaries, key: Key.periodSummaries) } }
    }
    @Published var dailyChallenges: [DailyChallengeEntry] = [] {
        didSet { if !isLoading { save(dailyChallenges, key: Key.dailyChallenges) } }
    }
    @Published var rewardRecords: [RewardRecord] = [] {
        didSet { if !isLoading { save(rewardRecords, key: Key.rewardRecords) } }
    }
    @Published var planJournals: [PlanJournalEntry] = [] {
        didSet { if !isLoading { save(planJournals, key: Key.planJournals) } }
    }
    @Published var language: AppLanguage = .chinese {
        didSet {
            if !isLoading { save(language, key: Key.language) }
            logCurrentLocale()  // [DEBUG] prints to console
        }
    }
    @Published var userBirthYear: Int = 0 {
        didSet { if !isLoading { ud.set(userBirthYear, forKey: Key.userBirthYear) } }
    }
    @Published var simulatedDate: Date? = nil  // 调试用：nil = 使用真实今日

    /// 当前「今日」—— 调试时可覆盖
    var today: Date { simulatedDate ?? Date() }

    /// 2-language legacy (zh/en only) — prefer t(key:) for full i18n
    func t(_ zh: String, _ en: String) -> String {
        switch language {
        case .chinese: return zh
        default: return en
        }
    }
    /// 5-language localised string
    func t(zh: String, en: String, ja: String, ko: String, es: String) -> String {
        switch language {
        case .chinese:  return zh
        case .english:  return en
        case .japanese: return ja
        case .korean:   return ko
        case .spanish:  return es
        }
    }

    /// Strongly-typed L10n lookup — called from @MainActor Views (safe)
    func t(key: (AppLanguage) -> String) -> String { key(language) }
    /// Localise a goal category string that was stored in Chinese (legacy)
    func localizeCategory(_ zhCategory: String) -> String {
        let cats = SuggestionProvider.categoryOptions(language)
        let zhCats = SuggestionProvider.categoryOptions(.chinese)
        if let idx = zhCats.firstIndex(of: zhCategory), idx < cats.count {
            return cats[idx]
        }
        return zhCategory  // fallback: return as-is
    }

    /// Debug: prints locale/language/sample to console for verification
    func logCurrentLocale() {
        let sample = SuggestionProvider.defaultGoals(language).first?.title ?? "(none)"
        print("[L10n] lang=\(language.rawValue) | locale=\(language.localeIdentifier) | firstGoal='\(sample)'")
    }

    /// 仅首次启动时创建1个示例目标
    func initDefaultGoals() {
        guard goals.isEmpty else { return }
        logCurrentLocale()
        let defaults = SuggestionProvider.defaultGoals(language)
        guard let first = defaults.first else { return }
        goals = [
            Goal(title: first.title,
                 category: first.category,
                 color: AppTheme.palette[0],
                 goalType: .longterm,
                 startDate: Date(),
                 endDate: nil,
                 tasks: first.tasks.map { GoalTask(title: $0) })
        ]
    }

    // ── 计算年龄（供 AI 分析用）──────────────────────────────
    var userAge: Int? {
        guard userBirthYear > 0 else { return nil }
        return Calendar.current.component(.year, from:Date()) - userBirthYear
    }

    // ── AI 分析数据导出接口 ───────────────────────────────────
    // 这是为未来 AI 梳理用户目标/困难/解决方案预留的接口
    // 格式：日/周/月/年的结构化数据，可直接序列化给 AI
    struct AIInsightData: Codable {
        let exportedAt: Date
        let userAge: Int?
        struct DailyEntry: Codable {
            let date: String
            let mood: Int
            let gainKeywords: [String]
            let challengeKeywords: [String]
            let gainDetail: String
            let challengeDetail: String
            let completionRate: Double
        }
        struct PeriodEntry: Codable {
            let periodType: Int
            let periodLabel: String
            let mood: Int
            let gainKeywords: [String]
            let challengeKeywords: [String]
            let gainDetail: String
            let challengeDetail: String
            let resolvedChallenges: [String]
            let avgCompletion: Double
        }
        var dailyEntries: [DailyEntry]
        var periodEntries: [PeriodEntry]
    }

    func exportAIData(days: Int = 90) -> AIInsightData {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding:.day, value:-days, to:Date()) ?? Date()
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let daily = dayReviews.filter { $0.isSubmitted && $0.date >= cutoff }.map { r in
            AIInsightData.DailyEntry(
                date: fmt.string(from:r.date),
                mood: r.rating,
                gainKeywords: r.gainKeywords,
                challengeKeywords: r.challengeKeywords,
                gainDetail: r.journalGains,
                challengeDetail: r.journalChallenges,
                completionRate: completionRate(for:r.date)
            )
        }
        let periods = periodSummaries.map { p in
            AIInsightData.PeriodEntry(
                periodType: p.periodType,
                periodLabel: p.periodLabel,
                mood: p.mood,
                gainKeywords: p.gainKeywords,
                challengeKeywords: p.challengeKeywords,
                gainDetail: p.gains,
                challengeDetail: p.challenges,
                resolvedChallenges: Array(p.resolvedChallenges),
                avgCompletion: p.avgCompletion
            )
        }
        return AIInsightData(exportedAt:Date(), userAge:userAge, dailyEntries:daily, periodEntries:periods)
    }

    // ── 查询 ──────────────────────────────────────────────

    func goals(for date: Date) -> [Goal] {
        var result = goals.filter { $0.covers(date) }
        let cal = Calendar.current
        // 加入只通过 extraTask 出现的目标
        let extraGoalIds = extraTasks.filter { cal.isDate($0.date,inSameDayAs:date) }.map(\.goalId)
        for gid in extraGoalIds {
            if let g = goals.first(where:{$0.id==gid}), !result.contains(where:{$0.id==gid}) {
                result.append(g)
            }
        }
        // 只过滤掉「只通过 extraTask 存在，但该天没有任何 extra 任务」的目标
        // 注意：不再过滤「本身覆盖该天但任务为空」的目标，否则新建无任务的目标不显示
        result = result.filter { g in
            if isExtraOnly(g.id, on: date) {
                return tasks(for:date, goal:g).count > 0
            }
            return true
        }
        return result
    }

    // 判断某 goal 是否只通过 extraTask 出现在该天（不是 goal 本身覆盖）
    func isExtraOnly(_ goalId: UUID, on date: Date) -> Bool {
        let cal = Calendar.current
        guard let g = goals.first(where:{$0.id==goalId}) else { return false }
        return !g.covers(date) && extraTasks.contains(where:{ $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) })
    }

    func tasks(for date: Date, goal: Goal) -> [GoalTask] {
        let cal = Calendar.current
        let ovs = planOverrides.filter { $0.goalId==goal.id && cal.isDate($0.date,inSameDayAs:date) }
        let skipped = ovs.filter(\.isSkipped).map(\.taskId)

        // 如果目标只通过 extraTask 存在于该天：只返回 extraTask 明确指定的任务
        if isExtraOnly(goal.id, on:date) {
            let extraTaskIds = extraTasks
                .filter { $0.goalId==goal.id && cal.isDate($0.date,inSameDayAs:date) }
                .map(\.taskId)
            return goal.tasks.filter { extraTaskIds.contains($0.id) && !skipped.contains($0.id) }
        }

        // 正常路径：目标本身覆盖该天
        var result: [GoalTask] = goal.tasks.compactMap { task -> GoalTask? in
            guard !skipped.contains(task.id) else { return nil }
            // pinnedDate 任务：只在固定日期显示
            if let pinned = task.pinnedDate {
                guard cal.isDate(pinned, inSameDayAs: date) else { return nil }
            }
            if let ov = ovs.first(where:{ $0.taskId==task.id && !$0.isSkipped }) {
                var m = task
                if let t = ov.overrideTitle   { m.title = t }
                if let n = ov.overrideMinutes { m.estimatedMinutes = n }
                return m
            }
            return task
        }
        // 额外移动过来的 task（目标覆盖该天但某个 task 被从别天拖来）
        let extras = extraTasks.filter { $0.goalId==goal.id && cal.isDate($0.date,inSameDayAs:date) }
        for extra in extras {
            if let task = goal.tasks.first(where:{ $0.id==extra.taskId }), !result.contains(where:{$0.id==task.id}) {
                result.append(task)
            }
        }
        return result
    }

    func progress(for date: Date, taskId: UUID) -> Double {
        dailyRecords.first { $0.taskId==taskId && Calendar.current.isDate($0.date,inSameDayAs:date) }?.progress ?? 0.0
    }

    // ── 进度记录（只写 dailyRecords，不污染 Goal.tasks）──

    func setProgress(for date: Date, taskId: UUID, goalId: UUID, progress: Double) {
        let cal = Calendar.current
        if let i = dailyRecords.firstIndex(where:{ $0.taskId==taskId && cal.isDate($0.date,inSameDayAs:date) }) {
            dailyRecords[i].progress = progress
        } else {
            dailyRecords.append(DailyRecord(date:date,taskId:taskId,goalId:goalId,progress:progress))
        }
        checkMilestones()
        // Check reward unlock whenever a task is updated
        if progress >= 1.0 {
            trackTaskComplete(goalId: goalId, taskId: taskId, date: date)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.checkAllRewards(for: date)
            }
        }
    }

    // 目标今日整体进度（用于目标页百分比显示）
    func goalProgress(for goal: Goal, on date: Date) -> Double {
        let ts = tasks(for: date, goal: goal)
        guard !ts.isEmpty else { return 0 }
        return ts.map { progress(for: date, taskId: $0.id) }.reduce(0,+) / Double(ts.count)
    }

    func completionRate(for date: Date) -> Double {
        let all = goals(for:date).flatMap { tasks(for:date,goal:$0) }
        guard !all.isEmpty else { return 0 }
        return all.map { progress(for:date,taskId:$0.id) }.reduce(0,+) / Double(all.count)
    }

    // ── 奖励记录 ─────────────────────────────────────────────

    func hasReward(level: RewardLevel, periodLabel: String) -> Bool {
        rewardRecords.contains { $0.level == level && $0.periodLabel == periodLabel }
    }

    @discardableResult
    func checkAndGrantDayReward(for date: Date) -> Bool {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let label = fmt.string(from: date)
        guard !hasReward(level: .day, periodLabel: label) else { return false }
        let rate = completionRate(for: date)
        guard rate >= 1.0 else { return false }
        // Only grant for past or today (not future)
        guard cal.startOfDay(for: date) <= cal.startOfDay(for: today) else { return false }
        let tasks = goals(for:date).flatMap { self.tasks(for:date, goal:$0) }
        guard !tasks.isEmpty else { return false }
        rewardRecords.append(RewardRecord(level:.day, date:date, periodLabel:label, completionRate:rate))
        triggerHaptic(level: .day)
        return true
    }

    @discardableResult
    func checkAndGrantWeekReward(for date: Date) -> Bool {
        let wl = weekLabelFor(date)
        guard !hasReward(level: .week, periodLabel: wl) else { return false }
        let wDates = weekDatesFor(date)
        let pastDates = wDates.filter { Calendar.current.startOfDay(for:$0) <= Calendar.current.startOfDay(for:today) }
        guard !pastDates.isEmpty else { return false }
        // Strict: ≥1 past day must have tasks, and ALL task-having days must be 100%
        let taskDays = pastDates.filter { d in
            !goals(for:d).flatMap { self.tasks(for:d, goal:$0) }.isEmpty
        }
        guard !taskDays.isEmpty else { return false }  // no vacuous week badge
        let allPerfect = taskDays.allSatisfy { completionRate(for:$0) >= 1.0 }
        guard allPerfect else { return false }
        let rate = avgCompletion(for: pastDates)
        rewardRecords.append(RewardRecord(level:.week, date:date, periodLabel:wl, completionRate:rate))
        triggerHaptic(level: .week)
        return true
    }

    @discardableResult
    func checkAndGrantMonthReward(for date: Date) -> Bool {
        let ml = monthLabelFor(date)
        guard !hasReward(level: .month, periodLabel: ml) else { return false }
        let mDates = monthDatesFor(date)
        let cal = Calendar.current
        let weeks = splitIntoCalWeeks(mDates)
        // Only complete weeks (all 7 days past)
        let pastCompleteWeeks = weeks.filter { wk in
            wk.allSatisfy { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) }
        }
        guard !pastCompleteWeeks.isEmpty else { return false }
        // Strict: at least one complete week must have task-having days
        let taskWeeks = pastCompleteWeeks.filter { wk in
            wk.contains { d in !goals(for:d).flatMap { self.tasks(for:d, goal:$0) }.isEmpty }
        }
        guard !taskWeeks.isEmpty else { return false }
        // All task-having complete weeks must be perfect
        let allWeeksPerfect = taskWeeks.allSatisfy { isWeekPerfect($0) }
        guard allWeeksPerfect else { return false }
        let rate = avgCompletion(for: mDates.filter { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) })
        rewardRecords.append(RewardRecord(level:.month, date:date, periodLabel:ml, completionRate:rate))
        triggerHaptic(level: .month)
        return true
    }

    @discardableResult
    func checkAndGrantYearReward(for date: Date) -> Bool {
        let yl = yearLabelFor(date)
        guard !hasReward(level: .year, periodLabel: yl) else { return false }
        let yDates = yearDatesFor(date)
        let cal = Calendar.current
        // Year badge requires ALL complete months to have their month badge (all weeks perfect).
        // A "complete month" = all days are in the past.
        let months = monthsInYear(yDates)
        let pastCompleteMonths = months.filter { mDates in
            mDates.allSatisfy { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) }
        }
        guard !pastCompleteMonths.isEmpty else { return false }
        let allMonthsPerfect = pastCompleteMonths.allSatisfy { mDates in
            isMonthPerfect(mDates)
        }
        guard allMonthsPerfect else { return false }
        let rate = avgCompletion(for: yDates.filter { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) })
        rewardRecords.append(RewardRecord(level:.year, date:date, periodLabel:yl, completionRate:rate))
        triggerHaptic(level: .year)
        return true
    }

    // ── Badge query helpers for chart display ────────────────────────
    /// True if a specific calendar day has earned its day badge (100% completion)
    func isDayBadgeEarned(for date: Date) -> Bool {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return hasReward(level: .day, periodLabel: fmt.string(from: date))
    }

    /// True if all 7 days of the given week have 100% completion (for chart overlay)
    func isWeekBadgeEarned(weekDates: [Date]) -> Bool {
        return isWeekPerfect(weekDates)
    }

    /// True if all complete weeks of the given month dates are perfect
    func isMonthBadgeEarned(monthDates: [Date]) -> Bool {
        return isMonthPerfect(monthDates)
    }

    // ── Internal helpers ─────────────────────────────────────────────
    /// True only when: ≥1 past day has tasks AND all past days with tasks are 100%.
    /// Days with no tasks are skipped (not counted as perfect, not counted as imperfect).
    /// Returns false if the entire week has zero task-having days → no vacuous badge.
    private func isWeekPerfect(_ weekDates: [Date]) -> Bool {
        let cal = Calendar.current
        let pastDays = weekDates.filter { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) }
        guard !pastDays.isEmpty else { return false }
        // Separate days that actually have tasks from days that don't
        let taskDays = pastDays.filter { d in
            !goals(for:d).flatMap { self.tasks(for:d, goal:$0) }.isEmpty
        }
        // Strict: there must be at least one day with tasks in this week
        guard !taskDays.isEmpty else { return false }
        // All task-having days must be 100% complete
        return taskDays.allSatisfy { completionRate(for:$0) >= 1.0 }
    }

    /// True only when: ≥1 complete past week has task-having days AND all such weeks are perfect.
    /// A "complete week" means all 7 days are in the past.
    private func isMonthPerfect(_ mDates: [Date]) -> Bool {
        let cal = Calendar.current
        let weeks = splitIntoCalWeeks(mDates)
        // Only consider weeks where all days are in the past (complete weeks)
        let completeWeeks = weeks.filter { wk in
            wk.allSatisfy { cal.startOfDay(for:$0) <= cal.startOfDay(for:today) }
        }
        guard !completeWeeks.isEmpty else { return false }
        // Filter to complete weeks that have at least one day with tasks
        let taskWeeks = completeWeeks.filter { wk in
            wk.contains { d in !goals(for:d).flatMap { self.tasks(for:d, goal:$0) }.isEmpty }
        }
        // Strict: there must be ≥1 task-having complete week
        guard !taskWeeks.isEmpty else { return false }
        // All task-having complete weeks must be perfect
        return taskWeeks.allSatisfy { isWeekPerfect($0) }
    }

    /// Split month dates into calendar-week arrays (Mon–Sun)
    private func splitIntoCalWeeks(_ mDates: [Date]) -> [[Date]] {
        var cal = Calendar.current; cal.firstWeekday = 2
        let sorted = mDates.sorted()
        guard let first = sorted.first, let last = sorted.last else { return [] }
        var weeks: [[Date]] = []
        var current = cal.dateInterval(of: .weekOfYear, for: first)?.start ?? first
        let end = last
        while current <= end {
            let weekEnd = cal.date(byAdding: .day, value: 7, to: current)!
            let wDays = sorted.filter { $0 >= current && $0 < weekEnd }
            if !wDays.isEmpty { weeks.append(wDays) }
            current = weekEnd
        }
        return weeks
    }

    /// Split year dates into month arrays
    private func monthsInYear(_ yDates: [Date]) -> [[Date]] {
        let cal = Calendar.current
        var groups: [String: [Date]] = [:]
        for d in yDates {
            let key = "\(cal.component(.year, from:d))-\(cal.component(.month, from:d))"
            groups[key, default: []].append(d)
        }
        return groups.values.sorted { ($0.first ?? .distantPast) < ($1.first ?? .distantPast) }
    }

    private func triggerHaptic(level: RewardLevel) {
        switch level.hapticStrength {
        case 1: HapticManager.impact(.light)
        case 2: HapticManager.impact(.medium)
        case 3: HapticManager.achievementUnlocked()
        default: break
        }
    }

    func weekLabelFor(_ date: Date) -> String {
        let cal = Calendar.current
        let wk = cal.component(.weekOfYear, from: date)
        let yr = cal.component(.year, from: date)
        return "\(yr)-W\(wk)"
    }
    func monthLabelFor(_ date: Date) -> String {
        let cal = Calendar.current
        let mo = cal.component(.month, from: date)
        let yr = cal.component(.year, from: date)
        return "\(yr)-M\(mo)"
    }
    func yearLabelFor(_ date: Date) -> String {
        "\(Calendar.current.component(.year, from: date))"
    }
    private func weekDatesFor(_ date: Date) -> [Date] {
        var cal = Calendar.current; cal.firstWeekday = 2
        guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { cal.date(byAdding:.day, value:$0, to:start) }
    }
    private func monthDatesFor(_ date: Date) -> [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of:.day, in:.month, for:date),
              let start = cal.date(from: cal.dateComponents([.year,.month], from: date)) else { return [] }
        return (0..<range.count).compactMap { cal.date(byAdding:.day, value:$0, to:start) }
    }
    private func yearDatesFor(_ date: Date) -> [Date] {
        let cal = Calendar.current
        guard let start = cal.date(from: DateComponents(year: cal.component(.year, from:date), month:1, day:1)),
              let end   = cal.date(from: DateComponents(year: cal.component(.year, from:date)+1, month:1, day:1)) else { return [] }
        var d = start; var result: [Date] = []
        while d < end { result.append(d); d = cal.date(byAdding:.day, value:1, to:d)! }
        return result
    }

    // Check all reward levels for today — call after any task completion
    func checkAllRewards(for date: Date) {
        checkAndGrantDayReward(for: date)
        checkAndGrantWeekReward(for: date)
        checkAndGrantMonthReward(for: date)
        checkAndGrantYearReward(for: date)
    }

    func rewards(level: RewardLevel) -> [RewardRecord] {
        rewardRecords.filter { $0.level == level }.sorted { $0.date > $1.date }
    }

    // ── 计划心得 ─────────────────────────────────────────────

    func planJournals(for date: Date, goalId: UUID? = nil) -> [PlanJournalEntry] {
        let cal = Calendar.current
        return planJournals
            .filter { cal.isDate($0.date, inSameDayAs: date) && (goalId == nil || $0.goalId == goalId) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func allPlanJournals(for goalId: UUID) -> [PlanJournalEntry] {
        planJournals.filter { $0.goalId == goalId }.sorted { $0.date > $1.date }
    }

    /// Returns all plan journal entries whose date falls within the given date set
    func planJournalsInPeriod(dates: [Date]) -> [PlanJournalEntry] {
        let cal = Calendar.current
        let starts = Set(dates.map { cal.startOfDay(for: $0) })
        return planJournals
            .filter { starts.contains(cal.startOfDay(for: $0.date)) }
            .sorted { $0.date > $1.date }
    }

    func addPlanJournal(_ entry: PlanJournalEntry) {
        planJournals.append(entry)
    }

    func updatePlanJournal(_ entry: PlanJournalEntry) {
        if let i = planJournals.firstIndex(where: { $0.id == entry.id }) {
            planJournals[i] = entry
        }
    }

    func deletePlanJournal(id: UUID) {
        planJournals.removeAll { $0.id == id }
    }

    // ── 计划页 ────────────────────────────────────────────

    func skipTask(_ taskId: UUID, goalId: UUID, on date: Date) {
        let cal = Calendar.current
        planOverrides.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) }
        planOverrides.append(PlanTaskOverride(date:date,taskId:taskId,goalId:goalId,isSkipped:true))
    }

    // Delete a task from a specific day:
    // - If it's a pinnedDate task (date-scoped): remove it entirely from the goal
    //   and also clean up any ExtraTaskEntry that made the goal visible on this date.
    // - If it's a recurring goal task: skip it only on this date
    func deleteTaskOnDate(_ taskId: UUID, goalId: UUID, on date: Date) {
        let cal = Calendar.current
        if let gi = goals.firstIndex(where:{$0.id==goalId}),
           let ti = goals[gi].tasks.firstIndex(where:{$0.id==taskId}),
           goals[gi].tasks[ti].pinnedDate != nil {
            // Pinned task — remove from goal entirely
            goals[gi].tasks.remove(at: ti)
            // Also remove the ExtraTaskEntry that registered it (if any)
            extraTasks.removeAll {
                $0.taskId == taskId && $0.goalId == goalId
                    && cal.isDate($0.date, inSameDayAs: date)
            }
        } else {
            // Recurring task — hide only on this date
            skipTask(taskId, goalId: goalId, on: date)
        }
    }

    func restoreTask(_ taskId: UUID, goalId: UUID, on date: Date) {
        let cal = Calendar.current
        planOverrides.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) }
    }

    func isSkipped(_ taskId: UUID, goalId: UUID, on date: Date) -> Bool {
        let cal = Calendar.current
        return planOverrides.contains { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) && $0.isSkipped }
    }

    func updateTaskOverride(_ taskId: UUID, goalId: UUID, on date: Date, title: String?, minutes: Int?) {
        let cal = Calendar.current
        planOverrides.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) }
        planOverrides.append(PlanTaskOverride(date:date,taskId:taskId,goalId:goalId,overrideTitle:title,overrideMinutes:minutes,isSkipped:false))
    }

    func moveTask(_ taskId: UUID, goalId: UUID, from: Date, to: Date) {
        let cal = Calendar.current
        // 如果是 pinnedDate 任务，直接更新 pinnedDate 即可（最简单正确）
        if let gi = goals.firstIndex(where:{$0.id==goalId}),
           let ti = goals[gi].tasks.firstIndex(where:{$0.id==taskId}),
           goals[gi].tasks[ti].pinnedDate != nil {
            goals[gi].tasks[ti].pinnedDate = cal.startOfDay(for: to)
            return
        }
        // 普通任务（无 pinnedDate）：skip 原天 + 在目标天恢复
        skipTask(taskId, goalId:goalId, on:from)
        let goal = goals.first { $0.id == goalId }
        if goal?.covers(to) == true {
            // 目标覆盖该天：确保 to 天没有 skip 这个 task
            planOverrides.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:to) && $0.isSkipped }
        } else {
            // 目标不覆盖该天：用 extraTask 记录这一个 task 出现在 to 天
            extraTasks.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:to) }
            extraTasks.append(ExtraTaskEntry(date:to, taskId:taskId, goalId:goalId))
        }
    }

    // ── 目标 CRUD ─────────────────────────────────────────

    func addGoal(_ g: Goal) {
        goals.append(g)
        // 目标添加后，今日/计划页通过 goals(for:date) 自动联动（基于 covers()）
    }

    func deleteGoal(_ g: Goal) {
        goals.removeAll { $0.id == g.id }
        // 同步清理所有关联数据，避免孤立记录
        dailyRecords.removeAll    { $0.goalId == g.id }
        planOverrides.removeAll   { $0.goalId == g.id }
        extraTasks.removeAll      { $0.goalId == g.id }
        achievements.removeAll    { $0.goalId == g.id }
    }

    func toggleGoalCalendarDot(_ goalId: UUID) {
        if let idx = goals.firstIndex(where: { $0.id == goalId }) {
            goals[idx].showCalendarDot.toggle()
        }
    }

    func updateGoal(_ g: Goal) {
        if let i = goals.firstIndex(where:{ $0.id == g.id }) {
            let old = goals[i]
            goals[i] = g
            // 如果任务列表变了（任务被删），清理对应的 dailyRecords / planOverrides
            let removedTaskIds = Set(old.tasks.map(\.id)).subtracting(g.tasks.map(\.id))
            if !removedTaskIds.isEmpty {
                dailyRecords.removeAll  { removedTaskIds.contains($0.taskId) }
                planOverrides.removeAll { removedTaskIds.contains($0.taskId) }
            }
        }
    }
    func deleteTask(_ taskId: UUID, fromGoal goalId: UUID) {
        if let gi=goals.firstIndex(where:{$0.id==goalId}) {
            goals[gi].tasks.removeAll { $0.id==taskId }
        }
    }
    func addTaskToGoal(goalId: UUID, title: String, minutes: Int? = nil) {
        if let gi=goals.firstIndex(where:{$0.id==goalId}) {
            goals[gi].tasks.append(GoalTask(title:title, estimatedMinutes:minutes))
        }
    }

    // 只在指定日期添加任务（单日任务，不影响其他天）
    // 如果该目标本身不覆盖该日期，同时注册 ExtraTaskEntry，
    // 使 goals(for:date) 能正确返回该目标，今日页和目标页也能同步显示。
    func addPinnedTask(goalId: UUID, title: String, minutes: Int? = nil, on date: Date) {
        guard let gi = goals.firstIndex(where: { $0.id == goalId }) else { return }
        let task = GoalTask(title: title, estimatedMinutes: minutes, pinnedDate: date)
        goals[gi].tasks.append(task)
        // If the goal doesn't naturally cover this date, register ExtraTaskEntry
        // so goals(for:date) / TodayView / GoalsView all pick up this goal on this day.
        let cal = Calendar.current
        if !goals[gi].covers(date) {
            let alreadyExists = extraTasks.contains {
                $0.taskId == task.id && $0.goalId == goalId
                    && cal.isDate($0.date, inSameDayAs: date)
            }
            if !alreadyExists {
                extraTasks.append(ExtraTaskEntry(
                    date: cal.startOfDay(for: date),
                    taskId: task.id,
                    goalId: goalId
                ))
            }
        }
    }
    func setGoalDeadline(_ goalId: UUID, to date: Date) {
        if let i=goals.firstIndex(where:{$0.id==goalId}) {
            goals[i].endDate = date
            if goals[i].goalType == .longterm { goals[i].goalType = .deadline }
        }
    }

    // ── 日记（提交后才正式保存）─────────────────────────

    func review(for date: Date) -> DayReview? {
        dayReviews.first { Calendar.current.isDate($0.date,inSameDayAs:date) }
    }

    // 实时自动保存（不标记 isSubmitted）— 防止 Tab 切换丢失 emoji/文字
    func autoSaveReview(_ r: DayReview) {
        // Track if this is a final submission
        if r.isSubmitted { trackReviewSubmitted(r) }
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:r.date) }) {
            // 保留原有的 isSubmitted 状态，只更新内容
            var updated = r
            updated.isSubmitted = dayReviews[i].isSubmitted
            // 保留实时写入的 keywords（由 ChallengeKeywordSection / LiveKeywordSection 直接管理）
            // draft 可能不包含最新的 keywords，用 store 里已有的避免覆盖
            let existing = dayReviews[i]
            if updated.challengeKeywords.isEmpty && !existing.challengeKeywords.isEmpty {
                updated.challengeKeywords = existing.challengeKeywords
            }
            if updated.gainKeywords.isEmpty && !existing.gainKeywords.isEmpty {
                updated.gainKeywords = existing.gainKeywords
            }
            dayReviews[i] = updated
        } else {
            // 新的一天，只在有实质内容时才存（避免空记录污染历史）
            if r.rating > 0 || !r.feedbackNote.isEmpty || !r.journalGains.isEmpty
               || !r.gainKeywords.isEmpty || !r.challengeKeywords.isEmpty {
                dayReviews.append(r)
            }
        }
    }

    func submitReview(_ r: DayReview) {
        var submitted = r; submitted.isSubmitted = true
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:r.date) }) { dayReviews[i]=submitted }
        else { dayReviews.append(submitted) }
    }

    // 内部更新：只修改关键词，不改 isSubmitted 状态（避免覆盖用户正式提交）
    private func updateReviewKeywords(_ r: DayReview) {
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:r.date) }) {
            dayReviews[i].challengeKeywords = r.challengeKeywords
            dayReviews[i].gainKeywords      = r.gainKeywords
        } else {
            dayReviews.append(r)
        }
    }

    // ── 任意日期的收获/计划读写（用于历史编辑）──────────────
    func gainKeywords(for date: Date) -> [String] {
        review(for: date)?.gainKeywords ?? []
    }
    func setGainKeyword(_ kw: String, for date: Date, add: Bool) {
        let cal = Calendar.current
        var r: DayReview
        if let existing = review(for: date) { r = existing }
        else { r = DayReview(date: date) }
        if add {
            if !r.gainKeywords.contains(kw) { r.gainKeywords.append(kw) }
        } else {
            r.gainKeywords.removeAll { $0 == kw }
        }
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:date) }) {
            dayReviews[i].gainKeywords = r.gainKeywords
        } else {
            dayReviews.append(r)
        }
    }
    func replaceGainKeywords(_ kws: [String], for date: Date) {
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:date) }) {
            dayReviews[i].gainKeywords = kws
        } else {
            var r = DayReview(date: date); r.gainKeywords = kws
            dayReviews.append(r)
        }
    }

    // ── 心情频率分布 ──────────────────────────────────────
    func moodDistribution(for dates: [Date]) -> [Int: Int] {
        var dist: [Int: Int] = [:]
        dates.compactMap { review(for:$0) }
             .filter { $0.isSubmitted && $0.rating > 0 }
             .forEach { dist[$0.rating, default:0] += 1 }
        return dist
    }

    // ── 收获/计划聚合（从日记汇总，不依赖PeriodSummary）─
    // ── 收获聚合：日记 + 周/月/年总结（统一来源）────────────
    func allGainKeywords(for dates: [Date]) -> [String] {
        let cal = Calendar.current
        var seen = Set<String>(); var result: [String] = []
        func add(_ kw: String) { if seen.insert(kw).inserted { result.append(kw) } }
        // 1. DayReview
        dates.compactMap { review(for:$0) }.flatMap { $0.gainKeywords }.forEach(add)
        // 2. PeriodSummary：找覆盖这些日期的周/月/年总结
        let years  = Set(dates.map { cal.component(.year, from:$0) })
        let months = Set(dates.map { "\(cal.component(.year,from:$0))-\(cal.component(.month,from:$0))" })
        let weeks  = Set(dates.map { "\(cal.component(.yearForWeekOfYear,from:$0))-W\(cal.component(.weekOfYear,from:$0))" })
        for ps in periodSummaries {
            let psYear  = cal.component(.year, from:ps.startDate)
            let psMonth = cal.component(.month, from:ps.startDate)
            let psWOY   = cal.component(.weekOfYear, from:ps.startDate)
            let psWY    = cal.component(.yearForWeekOfYear, from:ps.startDate)
            let relevant: Bool
            switch ps.periodType {
            case 2: relevant = years.contains(psYear)
            case 1: relevant = months.contains("\(psYear)-\(psMonth)")
            case 0: relevant = weeks.contains("\(psWY)-W\(psWOY)")
            default: relevant = false
            }
            if relevant { ps.gainKeywords.forEach(add) }
        }
        return result
    }


    // ── 所有有收获或计划记录的日期（日记 + PeriodSummary）──
    var datesWithGains: [Date] {
        var set = Set<Date>()
        dayReviews.filter { !$0.gainKeywords.isEmpty }
                  .forEach { set.insert(Calendar.current.startOfDay(for:$0.date)) }
        // PeriodSummary 有收获的，用其 startDate
        periodSummaries.filter { !$0.gainKeywords.isEmpty }
                       .forEach { set.insert(Calendar.current.startOfDay(for:$0.startDate)) }
        return set.sorted(by:>)
    }

    // ── 收获 ──────────────────────────────────────────────
    // ── 收获关键词（实时写 store）────────────────────────────
    func addTodayGainKeyword(_ kw: String) {
        let d = today
        var r = review(for:d) ?? DayReview(date:d)
        guard !r.gainKeywords.contains(kw) else { return }
        r.gainKeywords.append(kw)
        updateReviewKeywords(r)
    }
    func removeTodayGainKeyword(_ kw: String) {
        guard var r = review(for:today) else { return }
        r.gainKeywords.removeAll { $0 == kw }
        updateReviewKeywords(r)
    }
    func renameTodayGainKeyword(from old: String, to new: String) {
        guard var r = review(for:today) else { return }
        if let i = r.gainKeywords.firstIndex(of:old) { r.gainKeywords[i] = new }
        updateReviewKeywords(r)
    }


    var journalEntries: [DayReview] {
        dayReviews.filter {
            $0.isSubmitted && (
                $0.rating > 0 ||
                !$0.gainKeywords.isEmpty || !$0.challengeKeywords.isEmpty ||
                !$0.journalGains.isEmpty || !$0.journalChallenges.isEmpty
            )
        }.sorted { $0.date > $1.date }
    }

    func submitPeriodSummary(_ s: PeriodSummary) {
        periodSummaries.removeAll { $0.periodType==s.periodType && $0.periodLabel==s.periodLabel }
        periodSummaries.append(s)
    }

    func periodSummary(type: Int, label: String) -> PeriodSummary? {
        periodSummaries.first { $0.periodType==type && $0.periodLabel==label }
    }

    // 某时间段平均情绪（1-5）
    func avgMood(for dates: [Date]) -> Double {
        let ratings = dates.compactMap { review(for:$0) }.filter { $0.isSubmitted && $0.rating > 0 }.map(\.rating)
        guard !ratings.isEmpty else { return 0 }
        return Double(ratings.reduce(0,+)) / Double(ratings.count)
    }

    // 某时间段所有收获/困难的文本合集（用于智能总结）
    func journalText(for dates: [Date]) -> (gains:[String], challenges:[String]) {
        let reviews = dates.compactMap { review(for:$0) }.filter(\.isSubmitted)
        return (
            reviews.map(\.journalGains).filter { !$0.isEmpty },
            reviews.map(\.journalChallenges).filter { !$0.isEmpty }
        )
    }

    func aggregateKeywords(for dates: [Date]) -> (gains:[String], challenges:[String]) {
        let reviews = dates.compactMap { review(for:$0) }
        func ordered(_ arr: [[String]]) -> [String] {
            var seen = Set<String>(); var result: [String] = []
            arr.flatMap{$0}.forEach { if seen.insert($0).inserted { result.append($0) } }
            return result
        }
        return (
            ordered(reviews.map(\.gainKeywords)),
            ordered(reviews.map(\.challengeKeywords))
        )
    }

    // 某周期总结汇总下层关键词（周取日，月取周，年取月）
    func aggregateKeywordsFromPeriods(type: Int, dates: [Date]) -> (gains:[String], challenges:[String]) {
        let cal = Calendar.current
        if type == 0 {
            return aggregateKeywords(for: dates)
        } else if type == 1 {
            let weeks = Set(dates.map { cal.component(.weekOfYear, from:$0) })
            let year = cal.component(.year, from: dates.first ?? Date())
            let weekSummaries = weeks.compactMap { w -> PeriodSummary? in
                let label = language == .chinese ? "\(year)年第\(w)周" : "Week \(w), \(year)"
                return periodSummary(type:0, label:label)
            }
            func top(_ arr: [[String]]) -> [String] {
                var f: [String:Int] = [:]; arr.flatMap{$0}.forEach{f[$0,default:0]+=1}
                return f.sorted{$0.value>$1.value}.map(\.key)
            }
            return (
                top(weekSummaries.map(\.gainKeywords)),
                top(weekSummaries.map(\.challengeKeywords))
            )
        } else {
            let months = Set(dates.map { cal.component(.month, from:$0) })
            let year = cal.component(.year, from: dates.first ?? Date())
            let monthSummaries = months.compactMap { m -> PeriodSummary? in
                let label = language == .chinese ? "\(year)年\(m)月" : "\(m)/\(year)"
                return periodSummary(type:1, label:label)
            }
            func top(_ arr: [[String]]) -> [String] {
                var f: [String:Int] = [:]; arr.flatMap{$0}.forEach{f[$0,default:0]+=1}
                return f.sorted{$0.value>$1.value}.map(\.key)
            }
            return (
                top(monthSummaries.map(\.gainKeywords)),
                top(monthSummaries.map(\.challengeKeywords))
            )
        }
    }

    // 智能总结：优先使用关键词，fallback 到全文摘要
    func smartSummary(type: Int, label: String, dates: [Date]) -> String {
        let avg = avgCompletion(for:dates)
        let mood = avgMood(for:dates)
        let activeDays = dates.filter { completionRate(for:$0) > 0 }.count
        let moodEmoji = mood >= 4.5 ? "✨" : mood >= 3.5 ? "🤍" : mood >= 2.5 ? "🙂" : mood >= 1.5 ? "😶" : mood > 0 ? "😞" : ""

        let aggGains  = allGainKeywords(for:dates)
        let baseChallenges: [String]
        if let existing = periodSummary(type:type, label:label) {
            baseChallenges = existing.challengeKeywords
        } else {
            baseChallenges = aggregateKeywordsFromPeriods(type:type, dates:dates).challenges
        }

        var parts: [String] = []
        parts.append(SuggestionProvider.summaryCompletion(
            Int(avg*100), activeDays:activeDays, mood:mood, moodEmoji:moodEmoji, l:language))
        if !aggGains.isEmpty       { parts.append(SuggestionProvider.summaryWins(aggGains, l:language)) }
        if !baseChallenges.isEmpty { parts.append(SuggestionProvider.summaryChallenges(baseChallenges, l:language)) }
        return parts.joined(separator: "\n")
    }

    // 某日期范围内的所有困难关键词（用于周/月总结的「困难追踪」）
    func allChallengeKeywords(for dates: [Date]) -> [String] {
        dates.compactMap { review(for:$0) }.filter(\.isSubmitted)
            .flatMap(\.challengeKeywords)
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }

    // 某周期总结下层的所有困难关键词（周→日，月→周，年→月）
    // 滚动累积困难逻辑：
    // 每周困难 = 上周未解决 + 本周日记新增 - 本周已解决
    // 每月困难 = 上月未解决 + 本月各周新增 - 本月已解决（月层勾选）
    // 每年困难 = 上年未解决 + 本年各月新增 - 本年已解决（年层勾选）
    func allSubChallengeKeywords(type: Int, dates: [Date], includeResolved: Bool = false) -> [String] {
        let cal = Calendar.current
        if type == 0 {
            // 周层：本周困难 = 上周未解决 + 本周新增 - 本周已解决
            let weekChallenges = allChallengeKeywords(for: dates)

            // 找上周未解决的困难
            guard let firstDay = dates.first else { return weekChallenges }
            let prevWeekEnd = cal.date(byAdding:.day, value:-1, to:firstDay)!
            let prevWeekStart = cal.date(byAdding:.day, value:-7, to:prevWeekEnd)!
            let prevWeekDates = (0..<7).compactMap { cal.date(byAdding:.day, value:$0, to:prevWeekStart) }
            let prevWeekYear = cal.component(.year, from:prevWeekEnd)
            let prevWeekNum = cal.component(.weekOfYear, from:prevWeekEnd)
            let prevLabel: String
            switch language {
            case .chinese:  prevLabel = "\(prevWeekYear)年第\(prevWeekNum)周"
            case .japanese: prevLabel = "\(prevWeekYear)年第\(prevWeekNum)週"
            case .korean:   prevLabel = "\(prevWeekYear)년 \(prevWeekNum)주차"
            case .spanish:  prevLabel = "Semana \(prevWeekNum), \(prevWeekYear)"
            case .english:  prevLabel = "Week \(prevWeekNum), \(prevWeekYear)"
            }
            let prevResolved = periodSummary(type:0, label:prevLabel)?.resolvedChallenges ?? []
            let prevChallenges = allChallengeKeywords(for: prevWeekDates)
            let prevUnresolved = prevChallenges.filter { !prevResolved.contains($0) }

            // 合并：上周未解决 + 本周新增（去重）
            var result = prevUnresolved
            for kw in weekChallenges where !result.contains(kw) { result.append(kw) }

            // 减去本周已解决的（在周总结里勾掉的）
            let thisWeekYear = cal.component(.year, from: dates.last ?? today)
            let thisWeekNum = cal.component(.weekOfYear, from: dates.last ?? today)
            let thisWeekLabel: String
            switch language {
            case .chinese:  thisWeekLabel = "\(thisWeekYear)年第\(thisWeekNum)周"
            case .japanese: thisWeekLabel = "\(thisWeekYear)年第\(thisWeekNum)週"
            case .korean:   thisWeekLabel = "\(thisWeekYear)년 \(thisWeekNum)주차"
            case .spanish:  thisWeekLabel = "Semana \(thisWeekNum), \(thisWeekYear)"
            case .english:  thisWeekLabel = "Week \(thisWeekNum), \(thisWeekYear)"
            }
            let thisResolved = periodSummary(type:0, label:thisWeekLabel)?.resolvedChallenges ?? []
            if !includeResolved { result = result.filter { !thisResolved.contains($0) } }
            return result
        }

        let year = cal.component(.year, from: dates.first ?? today)

        if type == 1 {
            // 月层：滚动累积各周困难
            // 按时间顺序处理每周：带入上周未解决，加上本周新增，减去本周已解决
            let weeks = Set(dates.map { cal.component(.weekOfYear, from:$0) }).sorted()
            var accumulated: [String] = []

            // 先加入上月未解决的（如果有月总结）
            let month = cal.component(.month, from: dates.first ?? today)
            let prevMonth = month == 1 ? 12 : month - 1
            let prevYear = month == 1 ? year - 1 : year
            let prevMonthLabel = language == .chinese ? "\(prevYear)年\(prevMonth)月" : "\(prevMonth)/\(prevYear)"
            if let prevMS = periodSummary(type:1, label:prevMonthLabel) {
                let prevUnresolved = prevMS.challengeKeywords.filter { !prevMS.resolvedChallenges.contains($0) }
                accumulated = prevUnresolved
            }

            for w in weeks {
                let label = language == .chinese ? "\(year)年第\(w)周" : "Week \(w), \(year)"
                guard let ws = periodSummary(type:0, label:label) else {
                    // 该周无总结，只加入日记困难
                    let weekDays = dates.filter { cal.component(.weekOfYear, from:$0) == w }
                    let dayKW = allChallengeKeywords(for: weekDays)
                    for kw in dayKW where !accumulated.contains(kw) { accumulated.append(kw) }
                    continue
                }
                // 加入本周总结中的困难（新增的）
                for kw in ws.challengeKeywords where !accumulated.contains(kw) { accumulated.append(kw) }
                // 减去本周已解决的
                if !includeResolved { accumulated = accumulated.filter { !ws.resolvedChallenges.contains($0) } }
            }
            return accumulated
        } else {
            // 年层：滚动累积各月困难
            let months = Set(dates.map { cal.component(.month, from:$0) }).sorted()
            var accumulated: [String] = []

            // 先加入上年未解决的（如果有年总结）
            let prevYearLabel = language == .chinese ? "\(year-1)年" : "\(year-1)"
            if let prevYS = periodSummary(type:2, label:prevYearLabel) {
                let prevUnresolved = prevYS.challengeKeywords.filter { !prevYS.resolvedChallenges.contains($0) }
                accumulated = prevUnresolved
            }

            for m in months {
                let label = language == .chinese ? "\(year)年\(m)月" : "\(m)/\(year)"
                guard let ms = periodSummary(type:1, label:label) else { continue }
                for kw in ms.challengeKeywords where !accumulated.contains(kw) { accumulated.append(kw) }
                if !includeResolved { accumulated = accumulated.filter { !ms.resolvedChallenges.contains($0) } }
            }
            return accumulated
        }
    }

    // ── 每日困难追踪 ─────────────────────────────────────

    // ── 困难追踪核心：唯一数据源 dailyChallenges ────────────
    // 设计原则：
    // - 每条 DailyChallengeEntry.date = 该困难首次出现的日期
    // - resolvedOnDate = 解决日期，nil=未解决
    // - 划掉 = 写今天的 resolvedOnDate，全层联动（日/周/月/年共用）
    // - 跨周期：新周期只继承 active（未解决）的困难，不继承已划掉的

    /// 计算某天的困难状态：active=未解决，resolved=已解决（含entry引用）
    func dailyChallengeState(for date: Date) -> (active: [String], resolved: [String]) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)

        // 该天新增的困难（来自日记 challengeKeywords）
        let dayNewKW = review(for: date)?.challengeKeywords ?? []

        // 昨天的 active 困难（递归，最多回溯90天）
        let yesterday = cal.date(byAdding: .day, value: -1, to: dayStart)!
        let yActive = dailyChallengeActiveRaw(for: yesterday)

        // 该天已解决的（resolvedOnDate == date）
        let resolvedKW = Set(dailyChallenges
            .filter { $0.resolvedOnDate != nil && cal.isDate($0.resolvedOnDate!, inSameDayAs: date) }
            .map { $0.keyword })

        // 合并昨日active + 今日新增（去重）
        var all = yActive
        for kw in dayNewKW where !all.contains(kw) { all.append(kw) }

        return (
            active: all.filter { !resolvedKW.contains($0) },
            resolved: all.filter { resolvedKW.contains($0) }
        )
    }

    /// 某天的 active 困难（内部用，不含已解决，迭代实现避免栈溢出）
    func dailyChallengeActiveRaw(for targetDate: Date) -> [String] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -90, to: cal.startOfDay(for: today))!
        var current = cal.startOfDay(for: targetDate)
        if current < cutoff { return [] }

        // 找最早有意义的起始点（往前找最多90天）
        var dayStack: [Date] = []
        while current >= cutoff {
            dayStack.append(current)
            current = cal.date(byAdding: .day, value: -1, to: current)!
        }

        // 正向计算：从最早到目标日
        var active: [String] = []
        for d in dayStack.reversed() {
            let newKW = review(for: d)?.challengeKeywords ?? []
            for kw in newKW where !active.contains(kw) { active.append(kw) }
            let resolved = Set(dailyChallenges
                .filter { $0.resolvedOnDate != nil && cal.isDate($0.resolvedOnDate!, inSameDayAs: d) }
                .map { $0.keyword })
            active = active.filter { !resolved.contains($0) }
        }
        return active
    }

    /// 某天的 resolved entries（用于显示解决心得）
    func resolvedEntries(on date: Date) -> [DailyChallengeEntry] {
        let cal = Calendar.current
        return dailyChallenges.filter {
            $0.resolvedOnDate != nil && cal.isDate($0.resolvedOnDate!, inSameDayAs: date)
        }
    }

    // ── 今日困难关键词增删改（写入今日日记，自动联动追踪）────────
    func addTodayChallengeKeyword(_ kw: String) {
        let d = today
        if var r = review(for:d) {
            if !r.challengeKeywords.contains(kw) {
                r.challengeKeywords.append(kw)
                updateReviewKeywords(r)  // 不覆盖 isSubmitted
            }
        } else {
            var r = DayReview(date:d)
            r.challengeKeywords = [kw]
            updateReviewKeywords(r)  // 草稿，isSubmitted=false
        }
    }

    func removeTodayChallengeKeyword(_ kw: String) {
        guard var r = review(for:today) else { return }
        r.challengeKeywords.removeAll { $0 == kw }
        updateReviewKeywords(r)
        // 同步移除 unresolved DailyChallengeEntry
        dailyChallenges.removeAll { $0.keyword == kw && $0.resolvedOnDate == nil }
    }

    /// 完全删除今日新增的待决词（含已划掉状态），状态归零
    /// 用于标签框确认删除（今日新增的无论划没划都可删）
    func deleteTodayChallengeKeyword(_ kw: String) {
        // 1. 从今日日记 challengeKeywords 里移除
        if var r = review(for: today) {
            r.challengeKeywords.removeAll { $0 == kw }
            updateReviewKeywords(r)
        }
        // 2. 从 dailyChallenges 里彻底移除（包括已解决的记录）
        let cal = Calendar.current
        dailyChallenges.removeAll { e in
            e.keyword == kw && cal.isDate(e.date, inSameDayAs: today)
        }
    }

    func renameTodayChallengeKeyword(from old: String, to new: String) {
        guard var r = review(for:today) else { return }
        if let idx = r.challengeKeywords.firstIndex(of:old) {
            r.challengeKeywords[idx] = new
            updateReviewKeywords(r)  // 不覆盖 isSubmitted
        }
        // 同步更新 DailyChallengeEntry
        for i in dailyChallenges.indices where dailyChallenges[i].keyword == old {
            dailyChallenges[i].keyword = new
        }
    }


    /// 直接设置今日 challengeKeywords（用于 ChallengeKeywordSection 的 Binding）
    func setChallengeKeywords(_ keywords: [String], for date: Date) {
        let dayStart = Calendar.current.startOfDay(for: date)
        if var r = review(for: date) {
            r.challengeKeywords = keywords
            updateReviewKeywords(r)
        } else {
            var r = DayReview(date: dayStart)
            r.challengeKeywords = keywords
            updateReviewKeywords(r)
        }
        // 同步到 dailyChallenges（新增的词加入追踪）
        let existing = Set(dailyChallenges.map { $0.keyword })
        for kw in keywords where !existing.contains(kw) {
            dailyChallenges.append(DailyChallengeEntry(date: dayStart, keyword: kw))
        }
        // 移除不再存在的今日困难（今日内才删除）
        let kwSet = Set(keywords)
        dailyChallenges.removeAll { e in
            Calendar.current.isDate(e.date, inSameDayAs: dayStart) && !kwSet.contains(e.keyword)
        }
    }

    /// 划掉/取消划掉某困难（今日解决，跨层联动）
    func toggleDailyChallenge(keyword: String, on date: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)

        // 查找已有的解决记录（同keyword同日）
        if let idx = dailyChallenges.firstIndex(where: {
            $0.keyword == keyword &&
            $0.resolvedOnDate != nil &&
            cal.isDate($0.resolvedOnDate!, inSameDayAs: date)
        }) {
            // 取消解决：清除 resolvedOnDate 和 note
            dailyChallenges[idx].resolvedOnDate = nil
            dailyChallenges[idx].resolvedNote = ""
        } else {
            // 标记解决：找或创建 entry
            if let idx = dailyChallenges.firstIndex(where: {
                $0.keyword == keyword && $0.resolvedOnDate == nil
            }) {
                dailyChallenges[idx].resolvedOnDate = dayStart
            } else {
                dailyChallenges.append(DailyChallengeEntry(
                    date: dayStart, keyword: keyword, resolvedOnDate: dayStart))
            }
        }
    }

    /// 更新解决心得
    func updateResolvedNote(keyword: String, on date: Date, note: String) {
        let cal = Calendar.current
        if let idx = dailyChallenges.firstIndex(where: {
            $0.keyword == keyword &&
            $0.resolvedOnDate != nil &&
            cal.isDate($0.resolvedOnDate!, inSameDayAs: date)
        }) {
            dailyChallenges[idx].resolvedNote = note
        }
    }

    /// 本周期（周/月/年）新增的困难关键词（本周期日记中新出现的，排除上周期已有的）
    func periodNewChallengeKW(type: Int, dates: [Date]) -> [String] {
        guard let firstDay = dates.first else { return [] }
        let cal = Calendar.current
        // 上周期最后一天的 active（即本周期继承的起点）
        let dayBefore = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: firstDay))!
        let inherited = Set(dailyChallengeActiveRaw(for: dayBefore))
        // 本周期日记新增的 challengeKeywords
        var periodNew: [String] = []
        for d in dates {
            let kws = review(for: d)?.challengeKeywords ?? []
            for kw in kws where !inherited.contains(kw) && !periodNew.contains(kw) {
                periodNew.append(kw)
            }
        }
        return periodNew
    }

    // ── 联动困难追踪：周/月/年视图用今日困难状态 ────────────

    /// 本周困难状态（以本周最新有困难数据的一天为准，即 dailyChallengeState 最新值）
    // ── 周/月/年困难状态（以本周期最新一天的日困难状态为准）──────
    // 唯一数据源：dailyChallenges，跨层联动，划掉今天=全层同步

    /// 某个周期的困难状态
    /// active  = 本周期第一天继承 + 本周期新增 - 本周期已解决
    /// resolved= 本周期内被解决的（resolvedOnDate 在该周期内）
    func periodChallengeState(dates: [Date]) -> (active: [String], resolved: [String]) {
        guard let firstDay = dates.first, let lastDay = dates.last else { return ([], []) }
        let cal = Calendar.current
        let firstStart = cal.startOfDay(for: firstDay)
        _ = cal.startOfDay(for: lastDay)  // lastDay bound-checked implicitly

        // 本周期第一天继承的困难（上周期最后一天的active）
        let dayBefore = cal.date(byAdding: .day, value: -1, to: firstStart)!
        var accumulated = dailyChallengeActiveRaw(for: dayBefore)

        // 本周期内每天新增的困难
        let periodDays = dates.filter { cal.startOfDay(for: $0) <= cal.startOfDay(for: today) }
        for d in periodDays {
            let kws = review(for: d)?.challengeKeywords ?? []
            for kw in kws where !accumulated.contains(kw) { accumulated.append(kw) }
        }

        // 本周期内解决的（resolvedOnDate 在 firstDay...today 范围内）
        let resolvedInPeriod = Set(dailyChallenges.filter { entry in
            guard let rd = entry.resolvedOnDate else { return false }
            let rds = cal.startOfDay(for: rd)
            return rds >= firstStart && rds <= cal.startOfDay(for: today)
        }.map { $0.keyword })

        return (
            active:   accumulated.filter { !resolvedInPeriod.contains($0) },
            resolved: accumulated.filter {  resolvedInPeriod.contains($0) }
        )
    }

    func weekChallengeState()  -> (active: [String], resolved: [String]) {
        periodChallengeState(dates: weekDates())
    }
    func monthChallengeState() -> (active: [String], resolved: [String]) {
        periodChallengeState(dates: monthDates())
    }
    func yearChallengeState()  -> (active: [String], resolved: [String]) {
        periodChallengeState(dates: yearDates())
    }

    /// 某个周期内解决的 entries（含心得，用于智能总结）
    func resolvedEntriesInPeriod(dates: [Date]) -> [DailyChallengeEntry] {
        guard let firstDay = dates.first else { return [] }
        let cal = Calendar.current
        let firstStart = cal.startOfDay(for: firstDay)
        let nowStart   = cal.startOfDay(for: today)
        return dailyChallenges.filter { entry in
            guard let rd = entry.resolvedOnDate else { return false }
            let rds = cal.startOfDay(for: rd)
            return rds >= firstStart && rds <= nowStart
        }
    }

    // 更新周期总结的已解决困难

    func toggleResolvedChallenge(type: Int, label: String, keyword: String) {
        guard var s = periodSummary(type:type, label:label) else { return }
        if s.resolvedChallenges.contains(keyword) {
            s.resolvedChallenges.remove(keyword)
        } else {
            s.resolvedChallenges.insert(keyword)
        }
        submitPeriodSummary(s)
    }

    // 本周每天摘要（今日反馈 → 我的·本周日志）
    func weeklyDigest() -> [(date:Date, label:String, rate:Double, rating:Int, snippet:String)] {
        let wds = weekDates()
        let labels = language == .chinese
            ? ["一","二","三","四","五","六","日"]
            : ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        return wds.enumerated().map { (i, date) in
            let rate = completionRate(for: date)
            let rev = self.review(for: date)
            let rating = rev?.rating ?? 0
            var snippet = rev?.journalGains ?? ""
            if snippet.isEmpty { snippet = rev?.feedbackNote ?? "" }
            if snippet.count > 18 { snippet = String(snippet.prefix(18)) + "…" }
            return (date: date, label: labels[i], rate: rate, rating: rating, snippet: snippet)
        }
    }

    // ── 统计 ──────────────────────────────────────────────

    func weekDates() -> [Date] {
        let cal=Calendar.current, tod=cal.startOfDay(for:today)
        let wd=cal.component(.weekday,from:tod)
        let mon=cal.date(byAdding:.day,value:-(wd==1 ? 6:wd-2),to:tod)!
        return (0..<7).map { cal.date(byAdding:.day,value:$0,to:mon)! }
    }

    func weekCompletions() -> [(String,Double,Date)] {
        // Returns (label, rate, date) for each day of the current week.
        // label is used in bar charts AND in statsRow "Best/Worst" tiles.
        // Chinese: "周一"…"周日" (full, readable in Best tile)
        // Other locales: short 3-letter labels from locale-specific names
        func wd(_ zh:String,_ en:String,_ ja:String,_ ko:String,_ es:String) -> String {
            switch language {
            case .chinese:  return zh
            case .english:  return en
            case .japanese: return ja
            case .korean:   return ko
            case .spanish:  return es
            }
        }
        let labels = [
            wd("周一","Mon","月","월","Lun"),
            wd("周二","Tue","火","화","Mar"),
            wd("周三","Wed","水","수","Mié"),
            wd("周四","Thu","木","목","Jue"),
            wd("周五","Fri","金","금","Vie"),
            wd("周六","Sat","土","토","Sáb"),
            wd("周日","Sun","日","일","Dom")
        ]
        return weekDates().enumerated().map { (i,d) in (labels[i],completionRate(for:d),d) }
    }

    func monthDates() -> [Date] {
        let cal=Calendar.current
        let first=cal.date(from:cal.dateComponents([.year,.month],from:today))!
        return cal.range(of:.day,in:.month,for:today)!.map { cal.date(byAdding:.day,value:$0-1,to:first)! }
    }

    func monthWeeklyCompletions() -> [(String,Double)] {
        let dates=monthDates(); var weeks:[(String,Double)]=[]; var i=0,wn=1
        while i<dates.count {
            let chunk=Array(dates[i..<min(i+7,dates.count)])
            let avg=chunk.map { completionRate(for:$0) }.reduce(0,+)/Double(chunk.count)
            weeks.append((t("第\(wn)周","W\(wn)"),avg))
            i+=7; wn+=1
        }
        return weeks
    }

    func yearMonthCompletions() -> [(String,Double)] {
        let cal=Calendar.current, year=cal.component(.year,from:today)
        return (1...12).map { month in
            var c=DateComponents(); c.year=year; c.month=month; c.day=1
            guard let first=cal.date(from:c) else { return ("\(month)",0.0) }
            let rates=cal.range(of:.day,in:.month,for:first)!.compactMap { day -> Double? in
                guard let d=cal.date(byAdding:.day,value:day-1,to:first), d<=today else { return nil }
                let r=completionRate(for:d); return r>0 ? r:nil
            }
            return ("\(month)", rates.isEmpty ? 0:rates.reduce(0,+)/Double(rates.count))
        }
    }

    func yearDates() -> [Date] {
        let cal = Calendar.current, year = cal.component(.year, from:today)
        var all: [Date] = []
        for m in 1...12 {
            var c = DateComponents(); c.year = year; c.month = m; c.day = 1
            guard let first = cal.date(from:c) else { continue }
            let days = cal.range(of:.day, in:.month, for:first)!
            all += days.compactMap { day -> Date? in
                guard let d = cal.date(byAdding:.day, value:day-1, to:first), d <= today else { return nil }
                return d
            }
        }
        return all
    }

    func avgCompletion(for dates: [Date]) -> Double {
        let r=dates.map { completionRate(for:$0) }
        return r.isEmpty ? 0:r.reduce(0,+)/Double(r.count)
    }

    // ── 本月各周结构（用于「我的」月卡）────────────────────────
    struct MonthWeekEntry {
        let weekLabel: String      // "第1周"
        let weekOfYear: Int
        let year: Int
        let dates: [Date]
        let periodLabel: String    // 对应 PeriodSummary 的 label
    }

    func monthWeekEntries() -> [MonthWeekEntry] {
        let cal = Calendar.current
        let dates = monthDates()
        var result: [MonthWeekEntry] = []
        var wn = 1
        var i = 0
        while i < dates.count {
            let chunk = Array(dates[i..<min(i+7, dates.count)])
            guard let refDate = chunk.first else { i += 7; continue }
            let woy = cal.component(.weekOfYear, from:refDate)
            let yr  = cal.component(.year, from:refDate)
            let lbl = t("第\(wn)周", "Week \(wn)")
            let pLabel = t("\(yr)年第\(woy)周", "Week \(woy), \(yr)")
            result.append(MonthWeekEntry(weekLabel:lbl, weekOfYear:woy, year:yr, dates:chunk, periodLabel:pLabel))
            i += 7; wn += 1
        }
        return result
    }

    // ── 本年各月结构（用于「我的」年卡）────────────────────────
    struct YearMonthEntry {
        let monthLabel: String    // "1月"
        let month: Int
        let year: Int
        let dates: [Date]
        let periodLabel: String
    }

    func yearMonthEntries() -> [YearMonthEntry] {
        let cal = Calendar.current
        let yr = cal.component(.year, from:today)
        return (1...12).compactMap { month -> YearMonthEntry? in
            var c = DateComponents(); c.year = yr; c.month = month; c.day = 1
            guard let first = cal.date(from:c) else { return nil }
            let days = cal.range(of:.day, in:.month, for:first)!
            let dates = days.compactMap { day -> Date? in
                guard let d = cal.date(byAdding:.day, value:day-1, to:first), d <= today else { return nil }
                return d
            }
            guard !dates.isEmpty else { return nil }
            let lbl = t("\(month)月", "\(month)/\(yr)")
            let pLabel = t("\(yr)年\(month)月", "\(month)/\(yr)")
            return YearMonthEntry(monthLabel:lbl, month:month, year:yr, dates:dates, periodLabel:pLabel)
        }
    }

    // ── 过滤后的困难关键词（已在下层解决的不往上传）────────────
    // 周层：取各日 challengeKeywords，减去已在周总结中 resolved 的
    func unresolvedDayChallenges(weekLabel: String, dates: [Date]) -> [String] {
        let resolved = periodSummary(type:0, label:weekLabel)?.resolvedChallenges ?? []
        let all = dates.compactMap { review(for:$0) }
            .flatMap(\.challengeKeywords)
            .reduce(into:[String]()){ if !$0.contains($1){ $0.append($1) } }
        return all.filter { !resolved.contains($0) }
    }

    // 月层：取各周总结的 challengeKeywords，减去已在月总结中 resolved 的
    func unresolvedWeekChallenges(monthLabel: String, weekEntries: [MonthWeekEntry]) -> [String] {
        let resolved = periodSummary(type:1, label:monthLabel)?.resolvedChallenges ?? []
        let all = weekEntries.compactMap { periodSummary(type:0, label:$0.periodLabel) }
            .flatMap(\.challengeKeywords)
            .reduce(into:[String]()){ if !$0.contains($1){ $0.append($1) } }
        return all.filter { !resolved.contains($0) }
    }

    // 年层：取各月总结的 challengeKeywords，减去已在年总结中 resolved 的
    func unresolvedMonthChallenges(yearLabel: String, monthEntries: [YearMonthEntry]) -> [String] {
        let resolved = periodSummary(type:2, label:yearLabel)?.resolvedChallenges ?? []
        let all = monthEntries.compactMap { periodSummary(type:1, label:$0.periodLabel) }
            .flatMap(\.challengeKeywords)
            .reduce(into:[String]()){ if !$0.contains($1){ $0.append($1) } }
        return all.filter { !resolved.contains($0) }
    }

    // ── 当前周期 label ────────────────────────────────────────
    var currentWeekLabel: String {
        let c = Calendar.current
        let wk = c.component(.weekOfYear, from:today)
        let yr = c.component(.year, from:today)
        switch language {
        case .chinese:  return "\(yr)年第\(wk)周"
        case .japanese: return "\(yr)年第\(wk)週"
        case .korean:   return "\(yr)년 \(wk)주차"
        case .spanish:  return "Semana \(wk), \(yr)"
        case .english:  return "Week \(wk), \(yr)"
        }
    }
    var currentMonthLabel: String {
        let c = Calendar.current
        let mo = c.component(.month, from:today)
        let yr = c.component(.year, from:today)
        switch language {
        case .chinese:  return "\(yr)年\(mo)月"
        case .japanese: return "\(yr)年\(mo)月"
        case .korean:   return "\(yr)년 \(mo)월"
        case .spanish:  return "\(mo)/\(yr)"
        case .english:  return "\(mo)/\(yr)"
        }
    }
    var currentYearLabel: String {
        let yr = Calendar.current.component(.year, from:today)
        switch language {
        case .chinese:  return "\(yr)年"
        case .japanese: return "\(yr)年"
        case .korean:   return "\(yr)년"
        case .spanish, .english: return "\(yr)"
        }
    }

    func checkMilestones() {
        for goal in goals where goal.goalType == .longterm {
            let streak=currentStreak(for:goal)
            for m in [7,30,100,365] where streak==m {
                guard !achievements.contains(where:{$0.goalId==goal.id && $0.streakDays==m}) else { continue }
                let milestoneAch = Achievement(goalId:goal.id,goalTitle:goal.title,goalColor:goal.color,
                    level:.milestone,completionRate:1.0,date:Date(),streakDays:m,
                    description:t("连续坚持 \(m) 天！","Streak: \(m) days!"))
                achievements.append(milestoneAch)
                trackAchievementUnlocked(milestoneAch)
            }
        }
    }

    func currentStreak(for goal: Goal) -> Int {
        let cal=Calendar.current; var streak=0; var date=cal.startOfDay(for:Date())
        while goal.covers(date) {
            if completionRate(for:date)>=0.7 { streak+=1 } else { break }
            guard let prev=cal.date(byAdding:.day,value:-1,to:date) else { break }
            date=prev
        }
        return streak
    }

    func achievements(in range: ClosedRange<Date>) -> [Achievement] { achievements.filter { range.contains($0.date) } }

    // ── AI 总结：读真实记录，提炼关键词，多鼓励 ──────────

    func generateSummary(range: Int) -> String {
        let dates: [Date]
        let cal = Calendar.current
        switch range {
        case 0:  dates = weekDates()
        case 1:  dates = monthDates()
        default:
            let year = cal.component(.year, from:today); var all:[Date]=[]
            for m in 1...12 {
                var c=DateComponents(); c.year=year; c.month=m; c.day=1
                if let f=cal.date(from:c) {
                    all += cal.range(of:.day,in:.month,for:f)!
                        .compactMap{cal.date(byAdding:.day,value:$0-1,to:f)}
                        .filter{$0<=today}
                }
            }
            dates = all
        }

        let avg        = avgCompletion(for:dates)
        let reviews    = dates.compactMap { review(for:$0) }.filter(\.isSubmitted)
        let avgRating  = reviews.isEmpty ? 0.0 : Double(reviews.map(\.rating).reduce(0,+)) / Double(reviews.count)
        let streak     = goals.map { currentStreak(for:$0) }.max() ?? 0
        let activeDays = dates.filter { completionRate(for:$0) > 0 }.count
        let pct        = Int(avg * 100)

        // Keyword sentiment (language-aware)
        let allText = reviews.flatMap { [$0.journalGains, $0.journalChallenges, $0.feedbackNote] }.joined(separator:" ")
        let posWords: [String]
        let chalWords: [String]
        switch language {
        case .chinese:  posWords = ["进步","完成","坚持","突破","专注","高效","充实","开心","满意","成长","收获"]
                        chalWords = ["困难","疲惫","拖延","焦虑","压力","没动力","状态差"]
        case .japanese: posWords = ["進歩","達成","継続","突破","集中","効率","充実","嬉しい","満足","成長","収穫"]
                        chalWords = ["困難","疲れた","遅延","不安","プレッシャー","やる気","調子"]
        case .korean:   posWords = ["진보","완성","지속","돌파","집중","효율","충실","기쁨","만족","성장","수확"]
                        chalWords = ["어려움","피곤","지연","불안","스트레스","의욕","상태"]
        case .spanish:  posWords = ["progreso","completé","constancia","logro","enfoque","eficiencia","satisfecho","crecimiento"]
                        chalWords = ["difícil","cansado","procrastiné","ansiedad","estrés","desmotivado"]
        case .english:  posWords = ["progress","completed","consistent","focused","efficient","happy","satisfied","growth","achieved"]
                        chalWords = ["tired","difficult","delayed","anxious","stress","unmotivated","struggled"]
        }
        let posHits  = posWords.filter { allText.lowercased().contains($0.lowercased()) }
        let chalHits = chalWords.filter { allText.lowercased().contains($0.lowercased()) }
        let activeGoals = goals.filter { g in dates.contains { completionRate(for:$0)>0 && !tasks(for:$0,goal:g).isEmpty }}

        var lines: [String] = []

        // ── Completion line ──
        switch language {
        case .chinese:
            if pct >= 80      { lines.append("🏆 完成率 \(pct)%，做得非常出色！") }
            else if pct >= 60 { lines.append("✨ 完成率 \(pct)%，节奏不错。") }
            else if pct >= 30 { lines.append("💪 完成率 \(pct)%，哪怕一部分也在前进。") }
            else if activeDays > 0 { lines.append("🌱 有 \(activeDays) 天留下了记录。") }
            else              { lines.append("🌙 还没有记录——新的开始随时可以。") }
        case .japanese:
            if pct >= 80      { lines.append("🏆 完了率 \(pct)%、素晴らしい！") }
            else if pct >= 60 { lines.append("✨ 完了率 \(pct)%、安定したペース。") }
            else if pct >= 30 { lines.append("💪 完了率 \(pct)%、一歩ずつ前進中。") }
            else if activeDays > 0 { lines.append("🌱 \(activeDays)日間記録あり。") }
            else              { lines.append("🌙 まだ記録なし——いつでも始められる。") }
        case .korean:
            if pct >= 80      { lines.append("🏆 완료율 \(pct)%, 정말 훌륭해요!") }
            else if pct >= 60 { lines.append("✨ 완료율 \(pct)%, 꾸준한 페이스.") }
            else if pct >= 30 { lines.append("💪 완료율 \(pct)%, 조금씩 앞으로.") }
            else if activeDays > 0 { lines.append("🌱 \(activeDays)일 기록 남김.") }
            else              { lines.append("🌙 기록 없음——언제든 시작 가능.") }
        case .spanish:
            if pct >= 80      { lines.append("🏆 Completado \(pct)%, ¡excelente!") }
            else if pct >= 60 { lines.append("✨ Completado \(pct)%, buen ritmo.") }
            else if pct >= 30 { lines.append("💪 Completado \(pct)%, avanzando.") }
            else if activeDays > 0 { lines.append("🌱 \(activeDays) días con registro.") }
            else              { lines.append("🌙 Sin registros aún — puedes empezar hoy.") }
        case .english:
            if pct >= 80      { lines.append("🏆 \(pct)% completion — excellent!") }
            else if pct >= 60 { lines.append("✨ \(pct)% completion — good rhythm.") }
            else if pct >= 30 { lines.append("💪 \(pct)% completion — making progress.") }
            else if activeDays > 0 { lines.append("🌱 \(activeDays) active days recorded.") }
            else              { lines.append("🌙 No records yet — a fresh start is always ready.") }
        }

        // ── Active goals ──
        if !activeGoals.isEmpty {
            let titles = activeGoals.prefix(3).map(\.title)
            switch language {
            case .chinese:  lines.append("📌 推进中：\(titles.joined(separator:"、"))")
            case .japanese: lines.append("📌 進行中：\(titles.joined(separator:"、"))")
            case .korean:   lines.append("📌 진행 중：\(titles.joined(separator:", "))")
            case .spanish:  lines.append("📌 En marcha：\(titles.joined(separator:", "))")
            case .english:  lines.append("📌 In motion: \(titles.joined(separator:", "))")
            }
        }

        // ── Positive keywords ──
        if !posHits.isEmpty {
            let kws = posHits.prefix(4)
            switch language {
            case .chinese:  lines.append("🔑 你的记录里出现了：\(kws.joined(separator:" · "))")
            case .japanese: lines.append("🔑 記録のキーワード：\(kws.joined(separator:" · "))")
            case .korean:   lines.append("🔑 기록 키워드：\(kws.joined(separator:" · "))")
            case .spanish:  lines.append("🔑 Palabras en tus notas: \(kws.joined(separator:" · "))")
            case .english:  lines.append("🔑 Keywords from notes: \(kws.joined(separator:" · "))")
            }
        }

        // ── Challenge keywords ──
        if !chalHits.isEmpty {
            let kws = chalHits.prefix(3)
            switch language {
            case .chinese:  lines.append("🤝 也有挑战：\(kws.joined(separator:"、"))。承认困难是清醒。")
            case .japanese: lines.append("🤝 課題も：\(kws.joined(separator:"、"))。認めることが第一歩。")
            case .korean:   lines.append("🤝 어려움도：\(kws.joined(separator:", "))。인정이 첫걸음.")
            case .spanish:  lines.append("🤝 Desafíos：\(kws.joined(separator:", ")). Reconocerlos es lo primero.")
            case .english:  lines.append("🤝 Challenges noted: \(kws.joined(separator:", ")). Naming them is step one.")
            }
        }

        // ── Mood ──
        if avgRating >= 4 {
            switch language {
            case .chinese:  lines.append("😊 整体心情积极，状态很好！")
            case .japanese: lines.append("😊 全体的に気分良好！")
            case .korean:   lines.append("😊 전반적으로 기분이 좋아요!")
            case .spanish:  lines.append("😊 ¡Ánimo mayormente positivo!")
            case .english:  lines.append("😊 Mood has been mostly positive — great sign!")
            }
        } else if avgRating >= 3 {
            switch language {
            case .chinese:  lines.append("🙂 心情整体稳定，继续保持。")
            case .japanese: lines.append("🙂 気分は安定、この調子で。")
            case .korean:   lines.append("🙂 기분은 전반적으로 안정적.")
            case .spanish:  lines.append("🙂 Ánimo estable, sigue así.")
            case .english:  lines.append("🙂 Mood steady. Keep that foundation strong.")
            }
        } else if avgRating > 0 {
            switch language {
            case .chinese:  lines.append("🌤 有些低落的时候——照顾好自己。")
            case .japanese: lines.append("🌤 落ち込む日も——自分を大切に。")
            case .korean:   lines.append("🌤 힘든 날도 있었어요——자신을 챙겨요.")
            case .spanish:  lines.append("🌤 Días difíciles también — cuídate.")
            case .english:  lines.append("🌤 Some tough days — rest is part of the process.")
            }
        }

        // ── Streak ──
        if streak >= 14 {
            switch language {
            case .chinese:  lines.append("🔥 连续坚持 \(streak) 天！这种韧性会改变你。")
            case .japanese: lines.append("🔥 \(streak)日連続！その継続力が変化を生む。")
            case .korean:   lines.append("🔥 \(streak)일 연속! 그 꾸준함이 변화를 만들어요.")
            case .spanish:  lines.append("🔥 ¡\(streak) días seguidos! Esa tenacidad te cambia.")
            case .english:  lines.append("🔥 \(streak)-day streak! That consistency transforms habits.")
            }
        } else if streak >= 7 {
            switch language {
            case .chinese:  lines.append("🔥 连续 \(streak) 天，一整周的坚持！")
            case .japanese: lines.append("🔥 \(streak)日連続、まる1週間！")
            case .korean:   lines.append("🔥 \(streak)일 연속, 일주일 달성!")
            case .spanish:  lines.append("🔥 ¡\(streak) días seguidos — toda una semana!")
            case .english:  lines.append("🔥 \(streak) days in a row — a full week!")
            }
        } else if streak >= 3 {
            switch language {
            case .chinese:  lines.append("⚡ 连续 \(streak) 天，势头来了！")
            case .japanese: lines.append("⚡ \(streak)日連続、勢い出てきた！")
            case .korean:   lines.append("⚡ \(streak)일 연속, 탄력 붙었어요!")
            case .spanish:  lines.append("⚡ \(streak) días — ¡el impulso llega!")
            case .english:  lines.append("⚡ \(streak)-day run — momentum is building!")
            }
        }

        return lines.joined(separator:"\n")
    }

    // ── AI 任务建议（贴近目标关键词）──────────────────────

    func taskSuggestions(for goal: Goal, rotationOffset: Int = 0) -> [String] {
        let title = goal.title
        let cat = goal.category
        let existing = Set(goal.tasks.map(\.title))
        let lower = title.lowercased()

        // ── Core word extraction for template fill-in ──────────
        let stopWordsCN = ["学会","学习","完成","坚持","达到","实现","每天","每日","养成","提升","掌握","练习","的","了","和","与","及"]
        let stopWordsEN = ["learn","practice","complete","achieve","improve","master","daily","every","a","the","to","and","or","be","do"]
        let coreWords = (language == .chinese || language == .japanese || language == .korean)
            ? stopWordsCN.reduce(title){ r,w in r.replacingOccurrences(of:w,with:"") }
                .components(separatedBy:CharacterSet.whitespaces).filter{$0.count>=2}
            : stopWordsEN.reduce(lower){ r,w in r.replacingOccurrences(of:" \(w) ",with:" ") }
                .components(separatedBy:" ").filter{$0.count>=3}
        let coreName: String
        if let first = coreWords.first { coreName = first }
        else {
            switch language {
            case .chinese: coreName = "目标"; case .japanese: coreName = "目標"
            case .korean: coreName = "목표"; case .spanish: coreName = "meta"; case .english: coreName = "goal"
            }
        }

        // ── 5-language keyword pools (action-oriented, specific, varied) ──
        struct KPool5 {
            let kw:[String]
            let zh:[String]; let en:[String]; let ja:[String]; let ko:[String]; let es:[String]
        }
        let pools:[KPool5] = [
            // 健身/运动
            KPool5(kw:["健身","跑步","运动","体能","锻炼","力量","有氧","增肌","瑜伽","游泳","骑行","fitness","run","workout","exercise","gym","yoga","swim","cycle","운동","달리기","헬스","요가","健身","运动","トレーニング","筋トレ"],
                   zh:["今日跑量打卡记录","力量训练：3组×12次","热身5分钟+动态拉伸","训练后拉伸放松10分","记录体重与体脂率","补充蛋白质并记录","睡前核心力量10分","HIIT间歇训练20分","达成10000步目标","完成深蹲100个打卡"],
                   en:["Log today's run + distance","Strength: 3 sets × 12 reps","5min warm-up + dynamic stretch","Cool-down stretch 10min","Track weight + body fat","Log protein intake","Core circuit before bed","HIIT session 20min","Hit 10k steps goal","100 squat challenge"],
                   ja:["今日の走行距離を記録","筋トレ：3セット×12回","ウォームアップ5分+動的ストレッチ","クールダウン10分","体重と体脂肪率を記録","プロテイン摂取を記録","就寝前コア10分","HIITトレーニング20分","1万歩達成","スクワット100回チャレンジ"],
                   ko:["오늘 달리기 거리 기록","근력: 3세트 × 12회","워밍업 5분+동적 스트레칭","쿨다운 스트레칭 10분","체중+체지방률 기록","단백질 섭취 기록","자기 전 코어 10분","HIIT 운동 20분","만보 목표 달성","스쿼트 100개 도전"],
                   es:["Registrar distancia de hoy","Fuerza: 3 series × 12 reps","Calentamiento 5min+estiramiento","Vuelta a la calma 10min","Registrar peso y grasa corporal","Registrar ingesta de proteína","Core antes de dormir 10min","Sesión HIIT 20min","Meta de 10k pasos","Desafío 100 sentadillas"]),
            // 阅读/书籍
            KPool5(kw:["读书","阅读","看书","书","文学","小说","传记","read","book","novel","reading","literature","독서","책","読書","本"],
                   zh:["今日阅读25页并记要点","摘录3条金句写出感想","写读后感200字","用思维导图梳理全书","记录书中一个核心方法并试用","带问题读：找到书的核心论点","把书中1个方法用于今天实践","写短评发现这本书的独特价值"],
                   en:["Read 25 pages + note key points","Extract 3 quotes + write reaction","Write 200-word reflection","Mind map the whole book","Note one method + apply today","Read with a question: find core argument","Apply one book idea to today","Write a short review: what's unique"],
                   ja:["25ページ読んで要点メモ","名言3つ抽出+感想記入","200字の読後感を書く","全体をマインドマップで整理","1つのメソッドを今日に適用","問いを持って読む：核心論点を探す","書籍の1アイデアを今日実践","短評：この本の独自性を発見"],
                   ko:["25쪽 읽고 핵심 메모","명언 3개 발췌+반응 기록","독후감 200자 작성","전체 마인드맵으로 정리","핵심 방법 1개 오늘 적용","질문 가지고 읽기: 핵심 논점 찾기","책의 아이디어 오늘 실천","짧은 리뷰: 이 책의 독창성 발견"],
                   es:["Leer 25 páginas + anotar puntos clave","Extraer 3 citas + reacción escrita","Escribir reflexión de 200 palabras","Mapa mental del libro completo","Aplicar un método del libro hoy","Leer con pregunta: hallar argumento central","Aplicar una idea del libro hoy","Reseña corta: qué hace único este libro"]),
            // 语言学习
            KPool5(kw:["语言","英语","日语","西班牙","法语","韩语","德语","意大利","口语","词汇","背单词","language","spanish","english","japanese","french","korean","vocab","words","영어","한국어","언어","英語","言語"],
                   zh:["精听一段播客→记5个新词各造句","Duolingo 1节+跟读3句→复述录音","今日新词10个：看图记忆法","用目标语言写日记100字","语法专项练习一节+做错题分析","看外语视频→用母语概括大意","与AI对话练口语15分钟","复习本周词汇→默写测试"],
                   en:["Intensive listen to podcast → note 5 words + sentences","Duolingo 1 lesson + shadow 3 sentences + record recap","10 new words: visual memory method","Write 100-word journal in target language","Grammar drill + analyze mistakes","Watch video in target language → summarize in native tongue","Speak with AI 15min oral practice","Review this week's vocab → write from memory"],
                   ja:["ポッドキャスト精聴→新語5つ+例文作成","Duolingo1レッスン+シャドーイング3文+録音復唱","今日の新語10個：イメージ記憶法","目標言語で日記100字","文法ドリル+ミス分析","外国語動画視聴→母語で要約","AIと口頭練習15分","今週の語彙を復習→書き取りテスト"],
                   ko:["팟캐스트 정청→단어 5개+문장 작성","Duolingo 1과+섀도잉 3문장+녹음 복기","오늘 새 단어 10개: 이미지 기억법","목표 언어로 일기 100자 쓰기","문법 연습+오답 분석","외국어 영상 시청→모국어로 요약","AI와 회화 연습 15분","이번 주 단어 복습→받아쓰기 테스트"],
                   es:["Escucha intensiva podcast→5 palabras+frases","Duolingo 1 lección+shadowing 3 frases+grabar resumen","10 palabras nuevas: método visual","Escribir diario 100 palabras en idioma objetivo","Ejercicio gramática+analizar errores","Ver video en idioma objetivo→resumir en lengua nativa","Hablar con AI 15min práctica oral","Repasar vocabulario semanal→dictado"]),
            // 写作/创作
            KPool5(kw:["写作","博客","文章","创作","写字","日记","小说","剧本","write","blog","article","journal","writing","essay","story","script","글쓰기","블로그","작문","ライティング","ブログ"],
                   zh:["今日写作500字不删改直出","修改昨日文字→精简30%冗余","收集5条写作素材并标注用途","为下篇文章列详细大纲","解决一个卡住的情节/论点","用5种感官描写一个场景","写开头三段→找到最佳切入点","完成一个完整段落并自我点评"],
                   en:["Write 500 words — no editing, just flow","Edit yesterday's text → cut 30% fluff","Collect 5 writing material + tag purpose","Detailed outline for next article","Solve one stuck plot/argument problem","Describe a scene using all 5 senses","Write 3 opening paragraphs → pick the best","Complete one full section + self-critique"],
                   ja:["今日500字を書く、修正なし","昨日の文章を編集→30%削減","書く素材を5つ集めて目的を記す","次の記事の詳細なアウトライン","行き詰まったプロット/論点を解決","5感を使った場面描写","書き出し3段落→最良を選ぶ","完全な1セクション+自己批評"],
                   ko:["오늘 500자 쓰기 — 수정 없이","어제 글 수정→30% 군더더기 삭제","글감 5개 수집+용도 표시","다음 글 상세 목차 작성","막힌 플롯/논점 해결","5가지 감각으로 장면 묘사","도입 3단락 작성→최선 선택","완전한 단락 1개+자기 비평"],
                   es:["Escribir 500 palabras — sin editar","Editar texto de ayer → recortar 30%","Recolectar 5 materiales + anotar propósito","Esquema detallado del próximo artículo","Resolver un problema de trama/argumento","Describir escena con los 5 sentidos","Escribir 3 párrafos introductorios → elegir el mejor","Completar una sección + autocrítica"]),
            // 编程/开发
            KPool5(kw:["编程","代码","开发","算法","swift","python","java","javascript","code","programming","developer","app","web","개발","코딩","알고리즘","プログラミング","コード"],
                   zh:["完成一个完整功能模块并提交","刷LeetCode中等难度1题并分析复杂度","阅读官方技术文档一章并做笔记","重构一段代码→提升可读性","为昨日功能写单元测试","定位并修复一个具体Bug","学习一个新API/框架并写Demo","代码复盘：找出可改进的3处设计"],
                   en:["Complete one feature module + commit","Solve one LeetCode medium + analyze complexity","Read one chapter of official docs + notes","Refactor a module → improve readability","Write unit tests for yesterday's feature","Locate + fix one specific bug","Learn one new API/framework + write demo","Code review: find 3 design improvements"],
                   ja:["機能モジュール1つ完成+コミット","LeetCode中級1問+計算量分析","公式ドキュメント1章読んでメモ","1モジュールのリファクタリング","昨日の機能のユニットテスト作成","具体的なバグを特定して修正","新しいAPI/フレームワークを学びデモ作成","コードレビュー：設計改善点3つ発見"],
                   ko:["기능 모듈 1개 완성+커밋","LeetCode 중급 1문제+복잡도 분석","공식 문서 1챕터 읽고 노트","모듈 리팩토링→가독성 향상","어제 기능 단위 테스트 작성","특정 버그 찾아서 수정","새 API/프레임워크 학습+데모 작성","코드 리뷰: 설계 개선점 3가지 발견"],
                   es:["Completar un módulo funcional + commit","Resolver LeetCode medio + analizar complejidad","Leer un capítulo de docs + notas","Refactorizar un módulo → legibilidad","Tests unitarios para feature de ayer","Localizar + corregir un bug específico","Aprender nueva API/framework + demo","Code review: encontrar 3 mejoras de diseño"]),
            // 冥想/心理健康
            KPool5(kw:["冥想","正念","减压","心理","情绪","平静","呼吸","meditate","mindful","stress","anxiety","calm","breathe","mental","명상","마음","호흡","瞑想","マインドフル"],
                   zh:["晨间冥想10分+记录当下感受","4-7-8呼吸法3轮→平复当下情绪","写感恩日记3条：具体事件+感受","数字断联30分钟→记录注意力变化","身体扫描练习：从头到脚15分","情绪日记：标注今日触发点","专注当下5分钟：只观察不评判","睡前放松冥想→记录身体感受"],
                   en:["Morning meditation 10min + note current feeling","4-7-8 breathing 3 rounds → calm this moment","3 gratitude notes: specific event + feeling","Digital detox 30min → log attention changes","Body scan practice: head to toe 15min","Emotion journal: tag today's triggers","Present moment 5min: observe without judging","Sleep meditation → note body sensations"],
                   ja:["朝の瞑想10分+今の感覚を記録","4-7-8呼吸法3ラウンド→今を落ち着かせる","感謝日記3つ：具体的出来事+感情","デジタル断捨離30分→注意力変化を記録","ボディスキャン：頭から足まで15分","感情日記：今日のトリガーを記録","今この瞬間5分：判断せず観察","就寝前リラクゼーション瞑想"],
                   ko:["아침 명상 10분+현재 감정 기록","4-7-8 호흡 3라운드→지금 안정","감사 일기 3가지: 구체적 사건+감정","디지털 디톡스 30분→집중력 변화 기록","바디스캔: 머리부터 발끝까지 15분","감정 일기: 오늘의 트리거 기록","현재 5분: 판단 없이 관찰","수면 전 릴렉세이션 명상"],
                   es:["Meditación matutina 10min + anotar sensación","Respiración 4-7-8 × 3 rondas → calmar el momento","3 notas de gratitud: evento específico + sentimiento","Desintoxicación digital 30min → registrar cambios atencionales","Escáner corporal: cabeza a pies 15min","Diario emocional: registrar triggers de hoy","Momento presente 5min: observar sin juzgar","Meditación de relajación antes de dormir"]),
            // 工作/效率
            KPool5(kw:["工作","项目","效率","职场","时间管理","专注","work","project","productivity","career","focus","time management","professional","업무","프로젝트","직장","効率","仕事","プロジェクト"],
                   zh:["列出今日TOP3必完成任务","深度工作块90分钟（关掉一切通知）","清空邮件收件箱并标记行动项","整理项目进度→找到当前卡点","番茄工作法4轮+记录成果","复盘昨日时间分配→找回浪费点","拒绝一次不必要会议/打断","整理桌面与工作区→激活专注模式"],
                   en:["List today's top 3 must-do tasks","Deep work block 90min (all notifications off)","Clear inbox + tag action items","Update project status → find current blocker","4 Pomodoro rounds + log output","Review yesterday's time allocation → find waste","Decline one unnecessary meeting/interrupt","Tidy workspace → activate focus mode"],
                   ja:["今日のTOP3必須タスクをリストアップ","ディープワーク90分（通知オフ）","受信箱を空に+アクション項目にタグ","プロジェクト進捗更新→現在のブロッカーを特定","ポモドーロ4ラウンド+成果を記録","昨日の時間配分を振り返る→無駄を発見","不要な会議/割り込みを1つ断る","デスク整理→集中モード起動"],
                   ko:["오늘 TOP3 필수 작업 목록 작성","딥워크 블록 90분(모든 알림 끄기)","받은 편지함 정리+행동 항목 태그","프로젝트 현황 업데이트→현재 장애물 파악","포모도로 4라운드+성과 기록","어제 시간 배분 복기→낭비 발견","불필요한 회의/방해 1개 거절","책상 정리→집중 모드 활성화"],
                   es:["Listar las 3 tareas esenciales del día","Bloque de trabajo profundo 90min (sin notificaciones)","Vaciar bandeja de entrada + etiquetar acciones","Actualizar estado del proyecto → encontrar bloqueo","4 rondas Pomodoro + registrar resultados","Revisar distribución de tiempo de ayer → encontrar desperdicio","Rechazar una reunión/interrupción innecesaria","Ordenar escritorio → activar modo concentración"]),
            // 健康饮食
            KPool5(kw:["饮食","减肥","减重","体重","健康","热量","营养","diet","weight","lose","nutrition","calories","healthy","meal","식이","다이어트","체중","食事","ダイエット"],
                   zh:["记录三餐食物+估算热量","蔬菜份量：每餐半盘","饮水2升：设8次提醒","晚饭七分饱→停筷15分钟后自评","戒掉今日一种高糖零食","计算今日净热量差","慢嚼细咽：每口30次练习","记录今日最满意的一餐选择"],
                   en:["Log all meals + estimate calories","Veggie target: half plate per meal","Drink 2L water: set 8 reminders","Stop at 70% full → wait 15min before more","Skip one high-sugar snack today","Calculate net calorie balance","Mindful eating: 30 chews per bite","Log today's best food choice"],
                   ja:["全食事を記録+カロリー推定","野菜目標：1食あたり半皿","水2L：8回のリマインダーを設定","腹七分目で止める→15分後に評価","今日の高糖スナックを1つやめる","純カロリー収支を計算","マインドフル食事：1口30回噛む","今日の最良の食事選択を記録"],
                   ko:["세 끼 식사 기록+칼로리 추정","채소 목표: 매 식사 절반 접시","물 2L: 8번 알림 설정","70% 만복감에서 멈추기→15분 후 재평가","오늘 고당분 간식 1개 패스","순 칼로리 균형 계산","마음챙김 식사: 한 입 30번 씹기","오늘 최고의 음식 선택 기록"],
                   es:["Registrar todas las comidas + estimar calorías","Meta verduras: medio plato por comida","Beber 2L agua: establecer 8 recordatorios","Parar al 70% lleno → esperar 15min","Omitir un snack alto en azúcar hoy","Calcular balance calórico neto","Comer conscientemente: 30 masticaciones","Registrar la mejor elección alimentaria de hoy"]),
            // 学习/备考
            KPool5(kw:["学习","考试","备考","复习","课程","知识","study","exam","review","course","learn","knowledge","test","공부","시험","학습","勉強","試験"],
                   zh:["复习一个章节+自测理解度","完成一套练习题+错题分析","更新错题本→找出薄弱知识点","制作本章知识卡片5张","限时模拟测试20分钟","用费曼技巧：把概念讲给自己听","找出最薄弱的1个考点集中攻破","预习明日内容→带问题上课"],
                   en:["Review one chapter + self-test comprehension","Complete one practice set + analyze errors","Update error log → identify weak points","Make 5 knowledge cards for this chapter","Timed mock test 20min","Feynman technique: explain concept to yourself","Find #1 weakest topic + deep dive","Preview tomorrow's content → come with questions"],
                   ja:["1章復習+理解度を自己テスト","練習問題セット完了+ミス分析","ミスノート更新→弱点を特定","本章の知識カード5枚作成","時間制限模擬テスト20分","ファインマン技法：自分に概念を説明","最も弱い1つのテーマを深掘り","明日の内容を予習→質問を持って臨む"],
                   ko:["1챕터 복습+이해도 자기 테스트","연습 문제 세트 완료+오답 분석","오답 노트 업데이트→약점 파악","이번 챕터 지식 카드 5장 제작","시간 제한 모의 테스트 20분","파인만 기법: 개념 스스로에게 설명","가장 약한 주제 1개 집중 공략","내일 내용 예습→질문 가지고 가기"],
                   es:["Revisar un capítulo + autoexamen de comprensión","Completar un set de práctica + analizar errores","Actualizar registro de errores → identificar debilidades","Hacer 5 tarjetas de conocimiento del capítulo","Simulacro cronometrado 20min","Técnica Feynman: explicar el concepto a uno mismo","Identificar el tema más débil + profundizar","Previsualizar contenido de mañana → venir con preguntas"]),
        ]

        // ── Keyword matching across title + category ──────────
        var poolMatches: [String] = []
        for pool in pools {
            if pool.kw.contains(where:{ lower.contains($0) || cat.lowercased().contains($0) || title.contains($0) }) {
                let suggestions: [String]
                switch language {
                case .chinese:  suggestions = pool.zh
                case .english:  suggestions = pool.en
                case .japanese: suggestions = pool.ja
                case .korean:   suggestions = pool.ko
                case .spanish:  suggestions = pool.es
                }
                poolMatches.append(contentsOf: suggestions.filter { !existing.contains($0) })
            }
        }

        // ── Generic templates as fallback (fill coreName) ──────
        let templates: [String]
        switch language {
        case .chinese:
            templates = ["今日\(coreName)专项练习25分钟","记录\(coreName)今日进展","复盘\(coreName)本周收获","制定\(coreName)下一步行动计划","解决\(coreName)中最棘手的难点"].filter{ !existing.contains($0) }
        case .english:
            templates = ["25min focused \(coreName) session","Log \(coreName) progress today","Review this week's \(coreName) gains","Plan next action step for \(coreName)","Tackle the hardest \(coreName) challenge"].filter{ !existing.contains($0) }
        case .japanese:
            templates = ["\(coreName)の25分集中セッション","\(coreName)の今日の進捗を記録","\(coreName)の今週の成果を振り返る","\(coreName)の次のアクションを計画","\(coreName)の最難関に取り組む"].filter{ !existing.contains($0) }
        case .korean:
            templates = ["\(coreName) 25분 집중 세션","\(coreName) 오늘 진행 상황 기록","\(coreName) 이번 주 성과 복기","\(coreName) 다음 행동 계획 수립","\(coreName)의 가장 어려운 과제 도전"].filter{ !existing.contains($0) }
        case .spanish:
            templates = ["Sesión de 25min en \(coreName)","Registrar progreso hoy en \(coreName)","Revisar logros semanales de \(coreName)","Planificar próximo paso en \(coreName)","Abordar el reto más difícil de \(coreName)"].filter{ !existing.contains($0) }
        }

        // ── History tasks (most personalised) ─────────────────
        let overrideTitles = planOverrides
            .filter { $0.goalId == goal.id && $0.overrideTitle != nil }
            .compactMap(\.overrideTitle)
        let allHistory = Array(Set(overrideTitles)).filter { !existing.contains($0) }

        // ── Merge: pool matches first, then templates, then history ──
        var result: [String] = []
        // Use rotationOffset to deterministically rotate through pool items on each refresh
        let poolCount = poolMatches.count
        if poolCount > 0 {
            let startIdx = (rotationOffset * 4) % poolCount   // shift window by 4 each refresh
            var rotated = poolMatches
            // Rotate the array so different items lead each time
            rotated = Array(poolMatches[startIdx...] + poolMatches[..<startIdx])
            result.append(contentsOf: rotated.prefix(5))
        }
        let templatesFiltered = templates.filter { !result.contains($0) }
        // Also rotate templates by a different stride
        let tCount = templatesFiltered.count
        if tCount > 0 {
            let tStart = (rotationOffset * 2) % tCount
            let rotatedT = Array(templatesFiltered[tStart...] + templatesFiltered[..<tStart])
            result.append(contentsOf: rotatedT.prefix(max(0, 5 - result.count)))
        }
        result.append(contentsOf: allHistory.filter { !result.contains($0) }.prefix(2))
        if result.isEmpty {
            result = SuggestionProvider.fallbackTaskSuggestions(language)
                .filter { !existing.contains($0) }
        }
        // Return 4-5 diverse suggestions — offset ensures variety across refreshes
        return Array(result.prefix(5))
    }



    // ── 我的成长层级数据辅助 ──────────────────────────────────
    func allGrowthYears() -> [GrowthYearEntry] {
        let cal = Calendar.current
        var yearSet = Set<Int>()
        for r in dayReviews where r.isSubmitted || !r.gainKeywords.isEmpty {
            yearSet.insert(cal.component(.year, from:r.date))
        }
        for e in dailyChallenges where e.resolvedOnDate != nil {
            yearSet.insert(cal.component(.year, from:e.date))
        }
        // 包含来自 PeriodSummary 的年份
        for ps in periodSummaries where !ps.gainKeywords.isEmpty {
            yearSet.insert(cal.component(.year, from:ps.startDate))
        }
        return yearSet.sorted(by:>).map { year in
            let label: String
            switch language {
            case .chinese, .japanese: label = "\(year)年"
            case .korean:   label = "\(year)년"
            case .english, .spanish: label = "\(year)"
            }
            let dates = allDatesInYear(year)
            return GrowthYearEntry(year:year, label:label, dates:dates)
        }
    }

    func allDatesInYear(_ year: Int) -> [Date] {
        let cal = Calendar.current
        var comps = DateComponents(); comps.year = year; comps.month = 1; comps.day = 1
        guard let start = cal.date(from:comps),
              let end = cal.date(byAdding:.year, value:1, to:start) else { return [] }
        var dates: [Date] = []
        var d = start
        while d < end { dates.append(d); d = cal.date(byAdding:.day,value:1,to:d)! }
        return dates
    }

    func monthsInYear(_ year: Int) -> [GrowthMonthEntry] {
        let cal = Calendar.current
        return (1...12).compactMap { month -> GrowthMonthEntry? in
            var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
            guard let start = cal.date(from:comps),
                  let end = cal.date(byAdding:.month,value:1,to:start) else { return nil }
            var dates: [Date] = []
            var d = start
            while d < end { dates.append(d); d = cal.date(byAdding:.day,value:1,to:d)! }
            let label: String
            switch language {
            case .chinese, .japanese: label = "\(year)年\(month)月"
            case .korean:   label = "\(year)년 \(month)월"
            case .spanish:
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "es")
                fmt.dateFormat = "MMMM"
                label = fmt.string(from:start)
            case .english:
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US")
                fmt.dateFormat = "MMMM"
                label = fmt.string(from:start)
            }
            let key = "\(year)-\(month)"
            return GrowthMonthEntry(label:label, key:key, dates:dates)
        }
    }

    func weeksInMonth(_ dates: [Date]) -> [GrowthWeekEntry] {
        let cal = Calendar.current
        var weekMap: [Int:[Date]] = [:]
        var weekYear: [Int:Int] = [:]
        for d in dates {
            let w = cal.component(.weekOfYear, from:d)
            let y = cal.component(.yearForWeekOfYear, from:d)
            weekMap[w, default:[]].append(d)
            weekYear[w] = y
        }
        return weekMap.keys.sorted(by:>).map { w in
            let y = weekYear[w] ?? cal.component(.year, from:dates.first ?? Date())
            let label: String
            switch language {
            case .chinese:  label = "\(y)年第\(w)周"
            case .japanese: label = "\(y)年第\(w)週"
            case .korean:   label = "\(y)년 \(w)주차"
            case .spanish:  label = "Semana \(w), \(y)"
            case .english:  label = "Week \(w), \(y)"
            }
            let key = "\(y)-W\(w)"
            return GrowthWeekEntry(label:label, key:key, dates:(weekMap[w] ?? []).sorted())
        }
    }

    func daysInDates(_ dates: [Date]) -> [GrowthDayEntry] {
        dates.compactMap { d -> GrowthDayEntry? in
            guard let r = review(for:d) else { return nil }
            return GrowthDayEntry(date:d, review:r)
        }.sorted { $0.date > $1.date }
    }

}

// ============================================================
// MARK: - 工具
// ============================================================

// ── Unified date formatter — locale-aware, never hardcodes en_US ──────────
// Maps AppLanguage to its canonical BCP-47 locale.
// Unicode CLDR date formats (EEEE, MMM, d, etc.) are applied with the
// correct locale, so "March 4" becomes "4 de marzo" in Spanish,
// "3月4日" in Japanese, "3월 4일" in Korean, etc.
func formatDate(_ date: Date, format: String = "M月d日 EEEE", lang: AppLanguage = .chinese) -> String {
    let localeId: String
    switch lang {
    case .chinese:  localeId = "zh_CN"
    case .english:  localeId = "en_US"
    case .japanese: localeId = "ja_JP"
    case .korean:   localeId = "ko_KR"
    case .spanish:  localeId = "es_ES"
    }
    let f = DateFormatter()
    f.dateFormat = format
    f.locale = Locale(identifier: localeId)
    return f.string(from: date)
}

func startOfWeek() -> Date {
    let cal=Calendar.current, today=cal.startOfDay(for:Date())
    let wd=cal.component(.weekday,from:today)
    return cal.date(byAdding:.day,value:-(wd==1 ? 6:wd-2),to:today)!
}
func startOfMonth() -> Date { Calendar.current.date(from:Calendar.current.dateComponents([.year,.month],from:Date()))! }
func startOfYear()  -> Date { Calendar.current.date(from:Calendar.current.dateComponents([.year],from:Date()))! }

// ============================================================
// MARK: - 语录库（95条，东西方经典+现代励志+哲学+运动+艺术）
// ============================================================

struct Quote { let zh, en, author, authorEn: String }

let quoteLibrary: [Quote] = [
    // ── 中国经典 ──
    Quote(zh:"不积跬步，无以至千里；不积小流，无以成江海。",en:"Without accumulating small steps, you cannot travel a thousand miles.",author:"荀子",authorEn:"Xunzi"),
    Quote(zh:"天行健，君子以自强不息。",en:"Heaven moves with vigor; the noble person strives ceaselessly.",author:"周易",authorEn:"I Ching"),
    Quote(zh:"路漫漫其修远兮，吾将上下而求索。",en:"The road is long and winding; I shall seek the way above and below.",author:"屈原",authorEn:"Qu Yuan"),
    Quote(zh:"知之者不如好之者，好之者不如乐之者。",en:"Knowing is less than loving; loving is less than delighting in it.",author:"孔子",authorEn:"Confucius"),
    Quote(zh:"宝剑锋从磨砺出，梅花香自苦寒来。",en:"A sharp sword is forged through grinding; the plum blooms in bitter cold.",author:"古训",authorEn:"Chinese Proverb"),
    Quote(zh:"千磨万击还坚劲，任尔东西南北风。",en:"Through endless trials I remain firm; let the winds blow from all directions.",author:"郑燮",authorEn:"Zheng Xie"),
    Quote(zh:"志之所趋，无远弗届，穷山距海，不能限也。",en:"Where the will points, no distance is too great.",author:"金缨",authorEn:"Jin Ying"),
    Quote(zh:"静而后能安，安而后能虑，虑而后能得。",en:"Stillness leads to calm; calm to thought; thought to attainment.",author:"大学",authorEn:"The Great Learning"),
    Quote(zh:"合抱之木，生于毫末；九层之台，起于累土。",en:"A great tree grows from a tiny seed; a nine-story tower rises from a pile of earth.",author:"老子",authorEn:"Laozi"),
    Quote(zh:"胜人者有力，自胜者强。",en:"One who overcomes others has strength; one who overcomes himself is truly powerful.",author:"老子",authorEn:"Laozi"),
    Quote(zh:"吾日三省吾身。",en:"I examine myself daily on three points.",author:"曾子",authorEn:"Zengzi"),
    Quote(zh:"学而不思则罔，思而不学则殆。",en:"Learning without thinking is wasted; thinking without learning is dangerous.",author:"孔子",authorEn:"Confucius"),
    Quote(zh:"业精于勤，荒于嬉；行成于思，毁于随。",en:"Mastery comes from diligence; ruin from play. Action succeeds with thought; fails with carelessness.",author:"韩愈",authorEn:"Han Yu"),
    Quote(zh:"博学之，审问之，慎思之，明辨之，笃行之。",en:"Study broadly, inquire carefully, think deeply, discern clearly, act faithfully.",author:"中庸",authorEn:"Doctrine of the Mean"),
    Quote(zh:"日日行，不怕千万里；常常做，不怕千万事。",en:"Walk every day, fear not ten thousand miles; act every day, fear not ten thousand tasks.",author:"古训",authorEn:"Chinese Proverb"),
    Quote(zh:"人生在勤，不索何获。",en:"Life rewards effort; without seeking, nothing is gained.",author:"张衡",authorEn:"Zhang Heng"),
    Quote(zh:"欲穷千里目，更上一层楼。",en:"To see a thousand miles further, climb one more floor.",author:"王之涣",authorEn:"Wang Zhihuan"),
    Quote(zh:"长风破浪会有时，直挂云帆济沧海。",en:"The time will come to ride the waves; I'll set full sail across the vast sea.",author:"李白",authorEn:"Li Bai"),
    Quote(zh:"古之立大事者，不惟有超世之才，亦必有坚忍不拔之志。",en:"Those who accomplish great things need not only exceptional talent, but also indomitable will.",author:"苏轼",authorEn:"Su Shi"),
    Quote(zh:"真正的平静，不是远离车马喧嚣，而是在心中修篱种菊。",en:"True peace is not fleeing the noise of the world, but tending a garden within your heart.",author:"古训",authorEn:"Chinese Proverb"),

    // ── 西方哲学与文学 ──
    Quote(zh:"成功不是终点，失败也不是终结，勇气才是永恒。",en:"Success is not final, failure not fatal — courage to continue is what counts.",author:"丘吉尔",authorEn:"Winston Churchill"),
    Quote(zh:"你无法回到过去改变开始，但你可以从现在出发，改变结局。",en:"You can't go back to the start, but you can begin now and change the ending.",author:"C.S.路易斯",authorEn:"C.S. Lewis"),
    Quote(zh:"行动是治愈恐惧的良药，犹豫拖延只会滋养恐惧。",en:"Action is the antidote to despair; hesitation only feeds fear.",author:"琼·贝兹",authorEn:"Joan Baez"),
    Quote(zh:"先相信自己，然后别人才会相信你。",en:"First believe in yourself; then others will too.",author:"罗曼·罗兰",authorEn:"Romain Rolland"),
    Quote(zh:"生活不是等待暴风雨过去，而是学会在雨中起舞。",en:"Life isn't waiting for the storm to pass; it's learning to dance in the rain.",author:"维维安·格林",authorEn:"Vivian Greene"),
    Quote(zh:"我们必须相信，我们天生就有能力去做我们想做的事。",en:"We must believe we are gifted for something and that it must be attained.",author:"居里夫人",authorEn:"Marie Curie"),
    Quote(zh:"人生中最大的荣耀不在于从未跌倒，而在于每次跌倒后都能爬起来。",en:"The greatest glory is not in never falling, but in rising every time we fall.",author:"奥利弗·哥德史密斯",authorEn:"Oliver Goldsmith"),
    Quote(zh:"把每一天都当作新生命的第一天来迎接。",en:"Greet each day as the first day of a new life.",author:"大卫·梭罗",authorEn:"Henry David Thoreau"),
    Quote(zh:"我们所遭遇的每一个障碍，都是通往卓越的台阶。",en:"Every obstacle encountered is a stepping stone toward excellence.",author:"爱默生",authorEn:"Ralph Waldo Emerson"),
    Quote(zh:"你不必看到整段楼梯，只需迈出第一步。",en:"You don't have to see the whole staircase — just take the first step.",author:"马丁·路德·金",authorEn:"Martin Luther King Jr."),
    Quote(zh:"勇气不是没有恐惧，而是判断有比恐惧更重要的事。",en:"Courage is not the absence of fear — it is judging something more important than fear.",author:"安博罗斯·瑞",authorEn:"Ambrose Redmoon"),
    Quote(zh:"伟大的事业不是靠力气、速度或身体的敏捷完成的，而是靠性格、意志和知识的力量。",en:"Great works are performed not by strength but by perseverance.",author:"塞缪尔·约翰逊",authorEn:"Samuel Johnson"),
    Quote(zh:"人生只有一次机会，就是此刻。",en:"You only live once — but if you do it right, once is enough.",author:"梅·韦斯特",authorEn:"Mae West"),
    Quote(zh:"越努力，越幸运。",en:"The harder I work, the luckier I get.",author:"加里·普莱尔",authorEn:"Gary Player"),
    Quote(zh:"一个人能做他所下定决心要做的事。",en:"A person can do anything they make up their mind to do.",author:"卡特总统",authorEn:"Jimmy Carter"),
    Quote(zh:"不要等待机会，而要创造机会。",en:"Don't wait for opportunity; create it.",author:"乔治·萧伯纳",authorEn:"George Bernard Shaw"),
    Quote(zh:"人与人之间的差别，在于业余时间如何度过。",en:"What sets people apart is how they spend their free time.",author:"大卫·里德",authorEn:"David Reed"),
    Quote(zh:"凡是值得做的事，就值得做好。",en:"Anything worth doing is worth doing well.",author:"菲利普·斯坦霍普",authorEn:"Philip Stanhope"),
    Quote(zh:"所有的进步都发生在舒适区之外。",en:"All progress takes place outside the comfort zone.",author:"迈克尔·博博",authorEn:"Michael Bobak"),
    Quote(zh:"我不是失败了一千次，而是成功地发现了一千种行不通的方式。",en:"I have not failed; I've just found 10,000 ways that won't work.",author:"爱迪生",authorEn:"Thomas Edison"),

    // ── 现代励志 ──
    Quote(zh:"你今天的努力，是明天的底气。",en:"Today's effort is tomorrow's confidence.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"专注当下，其余交给时间。",en:"Focus on the present; trust the rest to time.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"小步前行，终抵远山。",en:"Small steps forward will eventually reach distant mountains.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"每一天都是一次全新的机会，去成为更好的自己。",en:"Each day is a fresh chance to become a better version of yourself.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"坚持不是因为有希望，而是坚持本身就是希望。",en:"Perseverance isn't about having hope — it is hope.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"人生最大的失败，是从未尝试。",en:"The greatest failure in life is never having tried.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你种下的每一粒种子，都会在你不注意的时候悄悄发芽。",en:"Every seed you plant quietly sprouts when you're not watching.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"改变需要时间，坚持才是最快的捷径。",en:"Change takes time; consistency is the fastest shortcut.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"不要拿别人的地图，来寻找自己的路。",en:"Don't use someone else's map to find your own way.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"每个你羡慕的结果，背后都有你看不见的坚持。",en:"Every outcome you envy has behind it a persistence you cannot see.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"开始永远不嫌晚，不开始才是真正的晚。",en:"It's never too late to start; not starting is the only real lateness.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"把复杂的事情简单化，把简单的事情坚持做。",en:"Simplify the complex; persist in the simple.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"痛苦是暂时的，放弃才是永远的。",en:"Pain is temporary; quitting is permanent.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"赢不是打败别人，而是超越昨天的自己。",en:"Winning isn't beating others — it's surpassing yesterday's self.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你不需要等到准备好，才能开始。",en:"You don't need to be ready before you begin.",author:"无名",authorEn:"Unknown"),

    // ── 运动与身体 ──
    Quote(zh:"身体是一切的基础，锻炼是最好的投资。",en:"The body is the foundation of everything; exercise is the best investment.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"运动不是惩罚身体，而是奖励身体。",en:"Exercise isn't punishment for the body — it's a reward for the body.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"每次锻炼都是一封写给未来自己的情书。",en:"Every workout is a love letter to your future self.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你的身体能做到的，往往比你的大脑认为的更多。",en:"Your body can do far more than your mind believes.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"坚持锻炼的人，不是没有惰性，而是比惰性更强大。",en:"People who keep exercising aren't free of laziness — they're just stronger than it.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"今天的汗水，是明天的力量。",en:"Today's sweat is tomorrow's strength.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"一英里的起点，是迈出第一步。",en:"A mile begins with a single step.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"没有什么比健康更奢侈，没有什么比懒惰更昂贵。",en:"Nothing is more luxurious than health; nothing more costly than laziness.",author:"无名",authorEn:"Unknown"),

    // ── 学习与成长 ──
    Quote(zh:"学习是一种生活方式，而不是一个阶段。",en:"Learning is a way of life, not a phase of life.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"每天进步1%，一年后你会进步37倍。",en:"Improve by 1% every day; in a year, you'll be 37 times better.",author:"詹姆斯·克利尔",authorEn:"James Clear"),
    Quote(zh:"知识的边界，就是好奇心所到之处。",en:"The boundary of knowledge is wherever curiosity leads.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"阅读是最低成本的成长方式。",en:"Reading is the lowest-cost form of growth.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"真正的学习，发生在你离开书本之后。",en:"Real learning happens after you put the book down.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你读过的每一本书，都是你未来思考的原材料。",en:"Every book you've read is raw material for your future thinking.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"成长的本质，是不断让自己感到陌生。",en:"The essence of growth is constantly making yourself feel like a stranger.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"学习不是填满水桶，而是点燃火焰。",en:"Education is not filling a bucket but lighting a fire.",author:"叶芝",authorEn:"W.B. Yeats"),

    // ── 创造与艺术 ──
    Quote(zh:"创意不是天赋，而是日积月累的产物。",en:"Creativity is not a talent; it is the product of daily accumulation.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"灵感青睐有准备的人。",en:"Inspiration favors the prepared mind.",author:"巴斯德",authorEn:"Louis Pasteur"),
    Quote(zh:"完成永远好过完美，完美是完成的敌人。",en:"Done is better than perfect; perfect is the enemy of done.",author:"谢丽尔·桑德伯格",authorEn:"Sheryl Sandberg"),
    Quote(zh:"每一件艺术品，都是无数个微小决定的集合。",en:"Every work of art is the sum of countless small decisions.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"把你热爱的事情做好，世界自然会为你让路。",en:"Do what you love well enough, and the world will make room for you.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"创作的勇气，是对空白的不妥协。",en:"The courage to create is an unwillingness to surrender to the blank page.",author:"罗洛·梅",authorEn:"Rollo May"),

    // ── 专注与心智 ──
    Quote(zh:"心智清明的人，不会被噪音所困。",en:"A clear mind is never trapped by noise.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"深度工作是这个时代最稀缺的能力。",en:"Deep work is the most rare and valuable ability of our time.",author:"卡尔·纽波特",authorEn:"Cal Newport"),
    Quote(zh:"注意力是你最宝贵的资源，请把它给值得的事。",en:"Attention is your most precious resource; give it only to what deserves it.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你在什么上面花时间，就会成为什么样的人。",en:"You become what you spend your time on.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"一次只做一件事，但要全力以赴。",en:"Do one thing at a time, but do it with everything you have.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"拒绝的勇气，和接受的勇气一样重要。",en:"The courage to say no is as important as the courage to say yes.",author:"无名",authorEn:"Unknown"),

    // ── 时间与习惯 ──
    Quote(zh:"我们是我们反复做的事情，卓越不是行为而是习惯。",en:"We are what we repeatedly do. Excellence is not an act but a habit.",author:"亚里士多德",authorEn:"Aristotle"),
    Quote(zh:"时间不够用的人，是不知道什么对自己最重要的人。",en:"People who never have enough time don't know what matters most to them.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"今日事今日毕，是对未来自己最大的善意。",en:"Finishing today's work today is the greatest kindness to your future self.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"习惯的力量不在于它的大小，而在于它的稳定。",en:"The power of a habit lies not in its size, but in its consistency.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"把时间花在值得的人和事上，其余的自然会消失。",en:"Invest time in what matters; the rest will fall away on its own.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"好的习惯是你给自己的礼物，坏的习惯是你欠自己的债。",en:"Good habits are gifts you give yourself; bad ones are debts you owe yourself.",author:"无名",authorEn:"Unknown"),

    // ── 人生哲思 ──
    Quote(zh:"人生不是在寻找自我，而是在创造自我。",en:"Life is not about finding yourself; it's about creating yourself.",author:"萧伯纳",authorEn:"George Bernard Shaw"),
    Quote(zh:"你现在的选择，正在创造你未来的经历。",en:"Your present choices are creating your future experiences.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"有些事情你不能掌控，但你可以掌控自己的反应。",en:"Some things are beyond your control; your response never is.",author:"爱比克泰德",authorEn:"Epictetus"),
    Quote(zh:"不要因为昨天的失败，轻视今天的可能。",en:"Don't let yesterday's failures diminish today's possibilities.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"真正的自由，是选择自己如何回应这个世界。",en:"True freedom is choosing how you respond to the world.",author:"维克多·弗兰克尔",authorEn:"Viktor Frankl"),
    Quote(zh:"生命中最重要的不是你处于什么位置，而是你面朝哪个方向。",en:"The most important thing isn't where you stand, but which direction you face.",author:"奥利弗·温德尔·霍姆斯",authorEn:"Oliver Wendell Holmes"),
    Quote(zh:"我们能掌控的，只有思想与行动。",en:"The only things we truly control are our thoughts and our actions.",author:"马可·奥勒留",authorEn:"Marcus Aurelius"),
    Quote(zh:"不要和昨天比输赢，要和昨天比成长。",en:"Don't compete with yesterday; grow beyond it.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"把每件小事做好，是通往伟大的唯一路径。",en:"Doing small things well is the only path to greatness.",author:"无名",authorEn:"Unknown"),
    Quote(zh:"你不一定要很厉害才能开始，但你必须开始才能变得很厉害。",en:"You don't have to be great to start, but you have to start to be great.",author:"无名",authorEn:"Unknown"),
]

// ── 每日推送逻辑（日期种子shuffle，排除收藏，每天15条）──
func dailyQuotes(saved: Set<Int>, language: AppLanguage) -> [Int] {
    let cal = Calendar.current
    let today = Date()
    let day = cal.ordinality(of: .day, in: .era, for: today) ?? 1
    // 用日期作为随机种子，同一天顺序固定，换天自动换批
    var rng = SeededRNG(seed: day)
    var indices = Array(0..<quoteLibrary.count)
    // Fisher-Yates shuffle with seeded RNG
    for i in stride(from: indices.count - 1, through: 1, by: -1) {
        let j = Int(rng.next() % UInt64(i + 1))
        indices.swapAt(i, j)
    }
    // 排除已收藏的，优先推未收藏
    let unsaved = indices.filter { !saved.contains($0) }
    let savedOnes = indices.filter { saved.contains($0) }
    let ordered = unsaved + savedOnes
    return Array(ordered.prefix(10))
}

struct SeededRNG {
    var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed &* 2654435761)) | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// ============================================================
// MARK: - 安全索引 & 心情常量
// ============================================================

extension Collection {
    /// Safe subscript — returns nil instead of crashing on out-of-bounds access
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Centralized mood emoji array (avoids scattered hardcoded arrays)
enum MoodEmoji {
    /// Index 0 is empty (rating 0 = unset), 1-5 = mood levels
    static let indexed = ["", "😞", "😶", "🙂", "🤍", "✨"]
    /// 0-indexed (for ForEach 0..<5)
    static let flat = ["😞", "😶", "🙂", "🤍", "✨"]

    /// Safe access: returns emoji for rating 1-5, or "" for invalid
    static func emoji(for rating: Int) -> String {
        indexed[safe: rating] ?? ""
    }
}
