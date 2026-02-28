import SwiftUI
import Combine

// ============================================================
// MARK: - 语言
// ============================================================

enum AppLanguage: String, CaseIterable {
    case chinese = "zh"; case english = "en"
    var displayName: String { self == .chinese ? "中文" : "English" }
}

// ============================================================
// MARK: - Pro 订阅系统
// ============================================================

// ── 我的成长层级数据结构 ────────────────────────────────────
struct GrowthDayEntry   { let date: Date; let review: DayReview }
struct GrowthWeekEntry  { let label: String; let key: String; let dates: [Date] }
struct GrowthMonthEntry { let label: String; let key: String; let dates: [Date] }
struct GrowthYearEntry  { let year: Int; let label: String; let dates: [Date] }

class ProStore: ObservableObject {
    @Published var isPro: Bool = true           // 设为 false 可预览免费版
    @Published var showPaywall: Bool = false

    static let monthlyUSD  = "$1.99"
    static let yearlyUSD   = "$14.99"
    static let monthlyGBP  = "£1.99"
    static let yearlyGBP   = "£14.99"
    static let monthlyCNY  = "¥14"
    static let yearlyCNY   = "¥98"

    // 免费版限制
    static let freeGoalLimit = 3
    static let freeQuoteLimit = 3   // 灵感页每天限看条数

    func requirePro(action: @escaping () -> Void) {
        if isPro { action() } else { showPaywall = true }
    }
}

// ============================================================
// MARK: - 模型
// ============================================================

struct GoalTask: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var estimatedMinutes: Int?
    var progress: Double = 0.0
    var pinnedDate: Date? = nil       // 非nil时只在该天显示（单日任务）
    var isCompleted: Bool { progress >= 1.0 }
}

enum GoalType: String, CaseIterable, Equatable {
    case deadline = "deadline"; case longterm = "longterm"
}

struct Goal: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var category: String
    var color: Color
    var goalType: GoalType
    var startDate: Date
    var endDate: Date?
    var tasks: [GoalTask]
    var showCalendarDot: Bool = true   // 是否在日历中显示光点

    func covers(_ date: Date) -> Bool {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date), s = cal.startOfDay(for: startDate)
        guard d >= s else { return false }
        if goalType == .longterm { return true }
        if let e = endDate { return d <= cal.startOfDay(for: e) }
        return false
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

struct DailyRecord: Identifiable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID; var progress: Double
}

// 跨天移动的任务记录（目标本身不覆盖该天时使用）
struct ExtraTaskEntry: Identifiable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID
}

// 周/月/年总结（结构化：情绪/收获/困难/展望 + 关键词 + 困难跟踪）
struct PeriodSummary: Identifiable {
    var id = UUID()
    var periodType: Int          // 0=周 1=月 2=年
    var periodLabel: String      // "2026年第10周" / "2026年2月" / "2026年"
    var startDate: Date
    var mood: Int = 0            // 1-5 情绪评分
    var gains: String = ""       // 收获详细
    var challenges: String = ""  // 困难详细
    var outlook: String = ""     // 展望/下期计划
    // 关键词（3-5词）
    var gainKeywords: [String] = []
    var challengeKeywords: [String] = []
    var nextKeywords: [String] = []     // 下期计划关键词
    // 困难跟踪：记录下层（日/周）哪些困难关键词已被标为已解决
    var resolvedChallenges: Set<String> = []
    var text: String = ""        // 旧版自由文本（兼容）
    var submittedAt: Date = Date()
    var hasContent: Bool { mood > 0 || !gains.isEmpty || !challenges.isEmpty || !outlook.isEmpty || !gainKeywords.isEmpty }
    var avgCompletion: Double = 0
}

struct PlanTaskOverride: Identifiable {
    var id = UUID()
    var date: Date; var taskId: UUID; var goalId: UUID
    var overrideTitle: String?; var overrideMinutes: Int?
    var isSkipped: Bool
}

// 每日困难追踪条目（独立于日记，可跨天继承）
struct DailyChallengeEntry: Identifiable, Equatable {
    var id = UUID()
    var date: Date                          // 归属日期（首次出现）
    var keyword: String                     // 困难关键词
    var resolvedOnDate: Date? = nil         // 被解决的日期（nil=未解决）
    var resolvedNote: String = ""           // 解决心得（可选）
}

// 每日回顾（提交后才保存）
struct DayReview: Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var rating: Int = 0
    var feedbackNote: String = ""
    var journalGains: String = ""       // 收获详细文本
    var journalChallenges: String = ""  // 困难详细文本
    var journalTomorrow: String = ""    // 明日计划详细文本
    // 关键词（3-5词，用于智能总结 + 上层汇总）
    var gainKeywords: [String] = []
    var challengeKeywords: [String] = []
    var tomorrowKeywords: [String] = []
    var isSubmitted: Bool = false
}

enum AchievementLevel: String, CaseIterable {
    case good = "基本完成"; case great = "优秀完成"
    case perfect = "完美完成"; case milestone = "里程碑"
}

struct Achievement: Identifiable {
    var id = UUID()
    var goalId: UUID; var goalTitle: String; var goalColor: Color
    var level: AchievementLevel; var completionRate: Double
    var date: Date; var streakDays: Int?; var description: String

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
// MARK: - 颜色主题
// ============================================================

struct AppTheme {
    // ═══════════════════════════════════════════════════════════
    // DESIGN SYSTEM v3  —  Monet Luminist Palette
    // Philosophy: Giverny dawn light — misted ivory, pond green,
    //   willow shadow, lotus blush. Quiet depth, never harsh.
    //   Reference: Water Lilies 1906-1926, Impression Sunrise.
    // ═══════════════════════════════════════════════════════════

    // ── 背景：晨雾烟灰，莫奈水面底调 ──
    // bg0: #1A1C1E  深烟炭，接近水面阴影
    static let bg0 = Color(red:0.102, green:0.110, blue:0.118)
    // bg1: #242729  卡片底，芦苇茎灰
    static let bg1 = Color(red:0.141, green:0.153, blue:0.161)
    // bg2: #2E3235  次层，雾中柳影
    static let bg2 = Color(red:0.180, green:0.196, blue:0.208)
    // bg3: #383D41  高亮/hover，池水微涟
    static let bg3 = Color(red:0.220, green:0.239, blue:0.255)

    // ── 边框：烟光极淡 ──
    static let border0 = Color.white.opacity(0.060)
    static let border1 = Color.white.opacity(0.110)
    static let borderGlow = Color(red:0.600, green:0.820, blue:0.740).opacity(0.20)

    // ── 文字：暖象牙系，莫奈油彩感 ──
    static let textPrimary   = Color(red:0.930, green:0.920, blue:0.900)  // 暖象牙白
    static let textSecondary = Color(red:0.640, green:0.640, blue:0.620)  // 雾中灰绿
    static let textTertiary  = Color(red:0.380, green:0.390, blue:0.380)  // 苔藓深灰

    // ── 主调：莫奈荷叶绿 — 饱和但雅，非荧光 ──
    // Inspired by "Water Lilies" reed-green reflections
    static let accent      = Color(red:0.420, green:0.740, blue:0.650)   // #6BBDA5 荷影绿
    static let accentSoft  = Color(red:0.420, green:0.740, blue:0.650).opacity(0.12)
    static let accentGlow  = Color(red:0.420, green:0.740, blue:0.650).opacity(0.06)

    // ── 目标调色板：莫奈色系六色 ──
    // Water Lilies · Impression Sunrise · Rouen Cathedral · Haystacks
    static let palette: [Color] = [
        Color(red:0.420, green:0.740, blue:0.650),   // 荷影绿    Waterlily Green
        Color(red:0.500, green:0.650, blue:0.820),   // 晨雾蓝    Morning Mist Blue
        Color(red:0.750, green:0.580, blue:0.780),   // 紫藤紫    Wisteria Mauve
        Color(red:0.870, green:0.640, blue:0.420),   // 晚霞橙    Sunset Amber
        Color(red:0.840, green:0.520, blue:0.560),   // 莲花粉    Lotus Blush
        Color(red:0.560, green:0.720, blue:0.590),   // 苔草绿    Reed Meadow
    ]

    // ── 语义色：莫奈自然调 ──
    static let gold    = Color(red:0.890, green:0.750, blue:0.440)  // 麦秆金
    static let danger  = Color(red:0.820, green:0.380, blue:0.380)  // 暗玫瑰红
    static let success = Color(red:0.440, green:0.730, blue:0.540)  // 嫩芽绿

    // ── 渐变辅助 ──
    static let gradientTop    = Color(red:0.420, green:0.740, blue:0.650).opacity(0.07)
    static let gradientBottom = Color.clear
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

class AppStore: ObservableObject {

    @Published var goals: [Goal] = [
        Goal(title:"每天健身", category:"健康", color:AppTheme.palette[0],
             goalType:.longterm, startDate:Calendar.current.date(byAdding:.day,value:-15,to:Date())!,
             endDate:nil, tasks:[
                GoalTask(title:"早晨跑步",  estimatedMinutes:30),
                GoalTask(title:"核心训练",  estimatedMinutes:20),
                GoalTask(title:"拉伸放松")]),
        Goal(title:"读完10本书", category:"学习", color:AppTheme.palette[3],
             goalType:.deadline, startDate:Date(),
             endDate:Calendar.current.date(from:DateComponents(year:2026,month:12,day:31)),
             tasks:[GoalTask(title:"阅读",estimatedMinutes:30),GoalTask(title:"读书笔记")]),
        Goal(title:"学会基础西班牙语", category:"技能", color:AppTheme.palette[4],
             goalType:.deadline, startDate:Date(),
             endDate:Calendar.current.date(from:DateComponents(year:2026,month:9,day:30)),
             tasks:[GoalTask(title:"Duolingo",estimatedMinutes:15),GoalTask(title:"听播客",estimatedMinutes:20)])
    ]

    @Published var dailyRecords:  [DailyRecord]      = []
    @Published var planOverrides: [PlanTaskOverride]  = []
    @Published var extraTasks:    [ExtraTaskEntry]    = []
    @Published var achievements:  [Achievement]       = []
    @Published var dayReviews:    [DayReview]         = []
    @Published var periodSummaries: [PeriodSummary]   = []
    @Published var dailyChallenges: [DailyChallengeEntry] = []  // 跨天困难追踪
    @Published var language:      AppLanguage         = .chinese
    @Published var userBirthYear: Int                 = 0
    @Published var simulatedDate: Date?               = nil  // 调试用：nil = 使用真实今日

    /// 当前「今日」—— 调试时可覆盖
    var today: Date { simulatedDate ?? Date() }

    func t(_ zh: String, _ en: String) -> String { language == .chinese ? zh : en }

    /// 按当前语言填充示例目标（首次启动时调用）
    func initDefaultGoals() {
        guard goals.isEmpty else { return }
        let isCN = language == .chinese
        goals = [
            Goal(title: isCN ? "每天健身" : "Daily Workout",
                 category: isCN ? "健康" : "Health",
                 color: AppTheme.palette[0], goalType:.longterm,
                 startDate: Calendar.current.date(byAdding:.day, value:-15, to:Date())!,
                 endDate: nil,
                 tasks:[GoalTask(title: isCN ? "早晨跑步" : "Morning Run", estimatedMinutes:30),
                        GoalTask(title: isCN ? "核心训练" : "Core Training", estimatedMinutes:20),
                        GoalTask(title: isCN ? "拉伸放松" : "Stretch")]),
            Goal(title: isCN ? "读完10本书" : "Read 10 Books",
                 category: isCN ? "学习" : "Learning",
                 color: AppTheme.palette[3], goalType:.deadline,
                 startDate: Date(),
                 endDate: Calendar.current.date(from:DateComponents(year:2026, month:12, day:31)),
                 tasks:[GoalTask(title: isCN ? "阅读" : "Reading", estimatedMinutes:30),
                        GoalTask(title: isCN ? "读书笔记" : "Book Notes")]),
            Goal(title: isCN ? "学会基础西班牙语" : "Learn Basic Spanish",
                 category: isCN ? "技能" : "Skills",
                 color: AppTheme.palette[4], goalType:.deadline,
                 startDate: Date(),
                 endDate: Calendar.current.date(from:DateComponents(year:2026, month:9, day:30)),
                 tasks:[GoalTask(title: "Duolingo", estimatedMinutes:15),
                        GoalTask(title: isCN ? "听播客" : "Podcast", estimatedMinutes:20)])
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
        // 每日关键词记录
        struct DailyEntry: Codable {
            let date: String  // yyyy-MM-dd
            let mood: Int
            let gainKeywords: [String]
            let challengeKeywords: [String]
            let planKeywords: [String]
            let gainDetail: String
            let challengeDetail: String
            let planDetail: String
            let completionRate: Double
        }
        // 周期总结关键词记录
        struct PeriodEntry: Codable {
            let periodType: Int  // 0=周 1=月 2=年
            let periodLabel: String
            let mood: Int
            let gainKeywords: [String]
            let challengeKeywords: [String]
            let planKeywords: [String]
            let gainDetail: String
            let challengeDetail: String
            let planDetail: String
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
                planKeywords: r.tomorrowKeywords,
                gainDetail: r.journalGains,
                challengeDetail: r.journalChallenges,
                planDetail: r.journalTomorrow,
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
                planKeywords: p.nextKeywords,
                gainDetail: p.gains,
                challengeDetail: p.challenges,
                planDetail: p.outlook,
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

    // ── 计划页 ────────────────────────────────────────────

    func skipTask(_ taskId: UUID, goalId: UUID, on date: Date) {
        let cal = Calendar.current
        planOverrides.removeAll { $0.taskId==taskId && $0.goalId==goalId && cal.isDate($0.date,inSameDayAs:date) }
        planOverrides.append(PlanTaskOverride(date:date,taskId:taskId,goalId:goalId,isSkipped:true))
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
    func addPinnedTask(goalId: UUID, title: String, minutes: Int? = nil, on date: Date) {
        if let gi = goals.firstIndex(where:{$0.id==goalId}) {
            let task = GoalTask(title:title, estimatedMinutes:minutes, pinnedDate:date)
            goals[gi].tasks.append(task)
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
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:r.date) }) {
            // 保留原有的 isSubmitted 状态，只更新内容
            var updated = r
            updated.isSubmitted = dayReviews[i].isSubmitted
            dayReviews[i] = updated
        } else {
            // 新的一天，只在有实质内容时才存（避免空记录污染历史）
            if r.rating > 0 || !r.feedbackNote.isEmpty || !r.journalGains.isEmpty
               || !r.gainKeywords.isEmpty || !r.challengeKeywords.isEmpty || !r.tomorrowKeywords.isEmpty {
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
            dayReviews[i].tomorrowKeywords  = r.tomorrowKeywords
        } else {
            dayReviews.append(r)
        }
    }

    // ── 任意日期的收获/计划读写（用于历史编辑）──────────────
    func gainKeywords(for date: Date) -> [String] {
        review(for: date)?.gainKeywords ?? []
    }
    func planKeywords(for date: Date) -> [String] {
        review(for: date)?.tomorrowKeywords ?? []
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
    func setPlanKeyword(_ kw: String, for date: Date, add: Bool) {
        let cal = Calendar.current
        var r: DayReview
        if let existing = review(for: date) { r = existing }
        else { r = DayReview(date: date) }
        if add {
            if !r.tomorrowKeywords.contains(kw) { r.tomorrowKeywords.append(kw) }
        } else {
            r.tomorrowKeywords.removeAll { $0 == kw }
        }
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:date) }) {
            dayReviews[i].tomorrowKeywords = r.tomorrowKeywords
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
    func replacePlanKeywords(_ kws: [String], for date: Date) {
        let cal = Calendar.current
        if let i = dayReviews.firstIndex(where:{ cal.isDate($0.date,inSameDayAs:date) }) {
            dayReviews[i].tomorrowKeywords = kws
        } else {
            var r = DayReview(date: date); r.tomorrowKeywords = kws
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

    // ── 计划聚合：日记 + 周/月/年总结（统一来源）────────────
    func allPlanKeywords(for dates: [Date]) -> [String] {
        let cal = Calendar.current
        var seen = Set<String>(); var result: [String] = []
        func add(_ kw: String) { if seen.insert(kw).inserted { result.append(kw) } }
        // 1. DayReview
        dates.compactMap { review(for:$0) }.flatMap { $0.tomorrowKeywords }.forEach(add)
        // 2. PeriodSummary
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
            if relevant { ps.nextKeywords.forEach(add) }
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
    var datesWithPlans: [Date] {
        var set = Set<Date>()
        dayReviews.filter { !$0.tomorrowKeywords.isEmpty }
                  .forEach { set.insert(Calendar.current.startOfDay(for:$0.date)) }
        periodSummaries.filter { !$0.nextKeywords.isEmpty }
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

    // ── 计划关键词（实时写 store）────────────────────────────
    func addTodayPlanKeyword(_ kw: String) {
        let d = today
        var r = review(for:d) ?? DayReview(date:d)
        guard !r.tomorrowKeywords.contains(kw) else { return }
        r.tomorrowKeywords.append(kw)
        updateReviewKeywords(r)
    }
    func removeTodayPlanKeyword(_ kw: String) {
        guard var r = review(for:today) else { return }
        r.tomorrowKeywords.removeAll { $0 == kw }
        updateReviewKeywords(r)
    }
    func renameTodayPlanKeyword(from old: String, to new: String) {
        guard var r = review(for:today) else { return }
        if let i = r.tomorrowKeywords.firstIndex(of:old) { r.tomorrowKeywords[i] = new }
        updateReviewKeywords(r)
    }

    var journalEntries: [DayReview] {
        // 收录：已提交 + 有实质内容（情绪/关键词/详细文本 任一）
        dayReviews.filter {
            $0.isSubmitted && (
                $0.rating > 0 ||
                !$0.gainKeywords.isEmpty || !$0.challengeKeywords.isEmpty || !$0.tomorrowKeywords.isEmpty ||
                !$0.journalGains.isEmpty || !$0.journalChallenges.isEmpty || !$0.journalTomorrow.isEmpty
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
    func journalText(for dates: [Date]) -> (gains:[String], challenges:[String], tomorrows:[String]) {
        let reviews = dates.compactMap { review(for:$0) }.filter(\.isSubmitted)
        return (
            reviews.map(\.journalGains).filter { !$0.isEmpty },
            reviews.map(\.journalChallenges).filter { !$0.isEmpty },
            reviews.map(\.journalTomorrow).filter { !$0.isEmpty }
        )
    }

    // 某时间段所有收获/困难/明日关键词汇总（按首次出现顺序，去重）
    func aggregateKeywords(for dates: [Date]) -> (gains:[String], challenges:[String], nexts:[String]) {
        let reviews = dates.compactMap { review(for:$0) }
        func ordered(_ arr: [[String]]) -> [String] {
            var seen = Set<String>(); var result: [String] = []
            arr.flatMap{$0}.forEach { if seen.insert($0).inserted { result.append($0) } }
            return result
        }
        return (
            ordered(reviews.map(\.gainKeywords)),
            ordered(reviews.map(\.challengeKeywords)),
            ordered(reviews.map(\.tomorrowKeywords))
        )
    }

    // 某周期总结汇总下层关键词（周取日，月取周，年取月）
    func aggregateKeywordsFromPeriods(type: Int, dates: [Date]) -> (gains:[String], challenges:[String], nexts:[String]) {
        let cal = Calendar.current
        if type == 0 {
            // 周：从日记关键词聚合
            return aggregateKeywords(for: dates)
        } else if type == 1 {
            // 月：从本月各周总结的关键词聚合
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
                top(weekSummaries.map(\.challengeKeywords)),
                top(weekSummaries.map(\.nextKeywords))
            )
        } else {
            // 年：从本年各月总结的关键词聚合
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
                top(monthSummaries.map(\.challengeKeywords)),
                top(monthSummaries.map(\.nextKeywords))
            )
        }
    }

    // 智能总结：优先使用关键词，fallback 到全文摘要
    func smartSummary(type: Int, label: String, dates: [Date]) -> String {
        let isCN = language == .chinese
        let avg = avgCompletion(for:dates)
        let mood = avgMood(for:dates)
        let activeDays = dates.filter { completionRate(for:$0) > 0 }.count
        let moodEmoji = mood >= 4.5 ? "✨" : mood >= 3.5 ? "🤍" : mood >= 2.5 ? "🙂" : mood >= 1.5 ? "😶" : mood > 0 ? "😞" : ""

        // 优先取关键词（已有总结则从总结取，否则从日记聚合）
        let kw: (gains:[String], challenges:[String], nexts:[String])
        // 总是聚合所有层级的关键词（日记 + PeriodSummary）
        let aggGains  = allGainKeywords(for:dates)
        let aggPlans  = allPlanKeywords(for:dates)
        let baseChallenges: [String]
        if let existing = periodSummary(type:type, label:label) {
            baseChallenges = existing.challengeKeywords
        } else {
            baseChallenges = aggregateKeywordsFromPeriods(type:type, dates:dates).challenges
        }
        kw = (aggGains, baseChallenges, aggPlans)

        var parts: [String] = []
        if isCN {
            if avg >= 0.8 { parts.append("完成率 \(Int(avg*100))%，非常出色 🏆") }
            else if avg >= 0.6 { parts.append("完成率 \(Int(avg*100))%，节奏稳定 ✨") }
            else if avg >= 0.3 { parts.append("完成率 \(Int(avg*100))%，有所推进 💪") }
            else if activeDays > 0 { parts.append("🌱 \(activeDays)天有记录，在坚持中") }
            else { parts.append("🌙 尚无记录") }
            if mood > 0 { parts.append("\(moodEmoji) 平均心情 \(String(format:"%.1f",mood))/5") }
            if !kw.gains.isEmpty { parts.append("💡 收获：\(kw.gains.prefix(5).joined(separator:" · "))") }
            if !kw.challenges.isEmpty { parts.append("🔧 困难：\(kw.challenges.prefix(5).joined(separator:" · "))") }
            if !kw.nexts.isEmpty { parts.append("🎯 计划：\(kw.nexts.prefix(5).joined(separator:" · "))") }
        } else {
            if avg >= 0.8 { parts.append("Completion \(Int(avg*100))% — excellent 🏆") }
            else if avg >= 0.6 { parts.append("Completion \(Int(avg*100))% — steady ✨") }
            else if avg >= 0.3 { parts.append("Completion \(Int(avg*100))% — progressing 💪") }
            else if activeDays > 0 { parts.append("🌱 \(activeDays) active days") }
            else { parts.append("🌙 No records yet") }
            if mood > 0 { parts.append("\(moodEmoji) Avg mood \(String(format:"%.1f",mood))/5") }
            if !kw.gains.isEmpty { parts.append("💡 Wins: \(kw.gains.prefix(5).joined(separator:" · "))") }
            if !kw.challenges.isEmpty { parts.append("🔧 Challenges: \(kw.challenges.prefix(5).joined(separator:" · "))") }
            if !kw.nexts.isEmpty { parts.append("🎯 Next: \(kw.nexts.prefix(5).joined(separator:" · "))") }
        }
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
            let prevLabel = language == .chinese ? "\(prevWeekYear)年第\(prevWeekNum)周" : "Week \(prevWeekNum), \(prevWeekYear)"
            let prevResolved = periodSummary(type:0, label:prevLabel)?.resolvedChallenges ?? []
            let prevChallenges = allChallengeKeywords(for: prevWeekDates)
            let prevUnresolved = prevChallenges.filter { !prevResolved.contains($0) }

            // 合并：上周未解决 + 本周新增（去重）
            var result = prevUnresolved
            for kw in weekChallenges where !result.contains(kw) { result.append(kw) }

            // 减去本周已解决的（在周总结里勾掉的）
            let thisWeekYear = cal.component(.year, from: dates.last ?? today)
            let thisWeekNum = cal.component(.weekOfYear, from: dates.last ?? today)
            let thisWeekLabel = language == .chinese ? "\(thisWeekYear)年第\(thisWeekNum)周" : "Week \(thisWeekNum), \(thisWeekYear)"
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
        let labels=[t("一","Mon"),t("二","Tue"),t("三","Wed"),t("四","Thu"),t("五","Fri"),t("六","Sat"),t("日","Sun")]
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
            let refDate = chunk.first!
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
        return t("\(c.component(.year,from:today))年第\(c.component(.weekOfYear,from:today))周",
                 "Week \(c.component(.weekOfYear,from:today)), \(c.component(.year,from:today))")
    }
    var currentMonthLabel: String {
        let c = Calendar.current
        return t("\(c.component(.year,from:today))年\(c.component(.month,from:today))月",
                 "\(c.component(.month,from:today))/\(c.component(.year,from:today))")
    }
    var currentYearLabel: String {
        let c = Calendar.current
        return t("\(c.component(.year,from:today))年", "\(c.component(.year,from:today))")
    }

    func checkMilestones() {
        for goal in goals where goal.goalType == .longterm {
            let streak=currentStreak(for:goal)
            for m in [7,30,100,365] where streak==m {
                guard !achievements.contains(where:{$0.goalId==goal.id && $0.streakDays==m}) else { continue }
                achievements.append(Achievement(goalId:goal.id,goalTitle:goal.title,goalColor:goal.color,
                    level:.milestone,completionRate:1.0,date:Date(),streakDays:m,
                    description:t("连续坚持 \(m) 天！","Streak: \(m) days!")))
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
        let periodName: String
        let cal = Calendar.current
        switch range {
        case 0:
            dates = weekDates(); periodName = t("本周","This Week")
        case 1:
            dates = monthDates(); periodName = t("本月","This Month")
        default:
            let year = cal.component(.year, from:today); var all:[Date]=[]
            for m in 1...12 {
                var c=DateComponents(); c.year=year; c.month=m; c.day=1
                if let f=cal.date(from:c) {
                    all += cal.range(of:.day,in:.month,for:f)!.compactMap{cal.date(byAdding:.day,value:$0-1,to:f)}.filter{$0<=today}
                }
            }
            dates = all; periodName = t("今年","This Year")
        }
        let avg = avgCompletion(for:dates)
        let reviews = dates.compactMap { review(for:$0) }.filter(\.isSubmitted)
        let avgRating = reviews.isEmpty ? 0.0 : Double(reviews.map(\.rating).reduce(0,+)) / Double(reviews.count)
        let streak = goals.map { currentStreak(for:$0) }.max() ?? 0
        let activeDays = dates.filter { completionRate(for:$0) > 0 }.count
        let allText = reviews.flatMap { [$0.journalGains, $0.journalChallenges, $0.feedbackNote] }.joined(separator:" ")
        let posWords_zh = ["进步","完成","坚持","突破","专注","高效","充实","开心","满意","成长","收获"]
        let posWords_en = ["progress","completed","consistent","focused","efficient","happy","satisfied","growth","achieved"]
        let chalWords_zh = ["困难","疲惫","拖延","焦虑","压力","没动力","状态差"]
        let chalWords_en = ["tired","difficult","delayed","anxious","stress","unmotivated","struggled"]
        let posHits = language == .chinese ? posWords_zh.filter{allText.contains($0)} : posWords_en.filter{allText.lowercased().contains($0)}
        let chalHits = language == .chinese ? chalWords_zh.filter{allText.contains($0)} : chalWords_en.filter{allText.lowercased().contains($0)}
        let activeGoals = goals.filter { g in dates.contains { completionRate(for:$0)>0 && !tasks(for:$0,goal:g).isEmpty }}

        var lines:[String]=[]
        if language == .chinese {
            if avg >= 0.8 { lines.append("🏆 \(periodName)完成率 \(Int(avg*100))%，做得非常出色！每一个打卡的任务都是对自己的承诺。") }
            else if avg >= 0.6 { lines.append("✨ \(periodName)完成率 \(Int(avg*100))%，节奏不错。坚持本身就是一种能力，你正在培养它。") }
            else if avg >= 0.3 { lines.append("💪 \(periodName)完成率 \(Int(avg*100))%。哪怕只完成一部分，也比什么都不做强——你已经在路上了。") }
            else if activeDays > 0 { lines.append("🌱 \(periodName)有 \(activeDays) 天留下了记录。每次打开这个应用都是对自己的关注，这很重要。") }
            else { lines.append("🌙 \(periodName)还没有记录，没关系——新的开始随时可以。") }
            if !activeGoals.isEmpty { lines.append("📌 推进中：\(activeGoals.prefix(3).map(\.title).joined(separator:"、"))") }
            if !posHits.isEmpty { lines.append("🔑 你的记录里出现了：\(posHits.prefix(4).joined(separator:" · "))") }
            if !chalHits.isEmpty { lines.append("🤝 也有挑战：\(chalHits.prefix(3).joined(separator:"、"))。承认困难是清醒的表现。") }
            if avgRating >= 4 { lines.append("😊 整体心情积极，状态很好！") }
            else if avgRating >= 3 { lines.append("🙂 心情整体稳定，继续保持。") }
            else if avgRating > 0 { lines.append("🌤 有些低落的时候——照顾好自己，状态是一切的基础。") }
            if streak >= 14 { lines.append("🔥 连续坚持 \(streak) 天！这种韧性会慢慢改变你。") }
            else if streak >= 7 { lines.append("🔥 连续 \(streak) 天！一周的坚持已经不简单了。") }
            else if streak >= 3 { lines.append("⚡ 连续 \(streak) 天，势头来了！") }
        } else {
            if avg >= 0.8 { lines.append("🏆 \(Int(avg*100))% completion \(periodName)! Every checked task is a promise kept to yourself.") }
            else if avg >= 0.6 { lines.append("✨ \(Int(avg*100))% \(periodName). Good rhythm — consistency is a skill you're building.") }
            else if avg >= 0.3 { lines.append("💪 \(Int(avg*100))% \(periodName). Partial progress still counts — you're on the move.") }
            else if activeDays > 0 { lines.append("🌱 \(activeDays) active days \(periodName). Every check-in is an act of self-awareness.") }
            else { lines.append("🌙 No records yet \(periodName) — a fresh start is always one task away.") }
            if !activeGoals.isEmpty { lines.append("📌 In motion: \(activeGoals.prefix(3).map(\.title).joined(separator:", "))") }
            if !posHits.isEmpty { lines.append("🔑 Keywords from your notes: \(posHits.prefix(4).joined(separator:" · "))") }
            if !chalHits.isEmpty { lines.append("🤝 Challenges noted: \(chalHits.prefix(3).joined(separator:", ")). Naming them is the first step.") }
            if avgRating >= 4 { lines.append("😊 Mood has been mostly positive — great sign!") }
            else if avgRating >= 3 { lines.append("🙂 Mood steady. Keep that foundation strong.") }
            else if avgRating > 0 { lines.append("🌤 Some tough days — rest is part of the process.") }
            if streak >= 14 { lines.append("🔥 \(streak)-day streak! That consistency transforms habits.") }
            else if streak >= 7 { lines.append("🔥 \(streak) days in a row — a full week of showing up!") }
            else if streak >= 3 { lines.append("⚡ \(streak)-day run — momentum is building!") }
        }
        return lines.joined(separator:"\n")
    }

    // ── AI 任务建议（贴近目标关键词）──────────────────────

    func taskSuggestions(for goal: Goal) -> [String] {
        let title = goal.title
        let cat = goal.category
        let existing = Set(goal.tasks.map(\.title))
        let lower = title.lowercased()
        let isCN = language == .chinese

        // ══════════════════════════════════════════════════════
        // B：用户历史任务（最个性化，优先展示）
        // 读取该目标下用户曾经有过的任务名，过滤掉当前已有的
        // ══════════════════════════════════════════════════════
        let historyTasks = goal.tasks.map(\.title)   // 当前任务（已有）
        // 从 planOverrides / extraTasks 里提取曾经出现过的任务标题
        let overrideTitles = planOverrides
            .filter { $0.goalId == goal.id && $0.overrideTitle != nil }
            .compactMap(\.overrideTitle)
        // 历史：extraTask里出现的任务ID对应的标题
        let extraTitles = extraTasks
            .filter { $0.goalId == goal.id }
            .compactMap { e in goal.tasks.first(where:{$0.id==e.taskId})?.title }
        let allHistory = Array(Set(historyTasks + overrideTitles + extraTitles))
            .filter { !existing.contains($0) }

        // ══════════════════════════════════════════════════════
        // C：模板填空（从目标 title 提取核心名词）
        // ══════════════════════════════════════════════════════
        // 提取核心词：去掉常见助词/动词，保留实质名词
        let stopWordsCN = ["学会","学习","完成","坚持","达到","实现","每天","每日","养成","提升","掌握","练习","的","了","和","与","及"]
        let stopWordsEN = ["learn","practice","complete","achieve","improve","master","daily","every","a","the","to","and","or","be","do"]
        let coreWords = isCN
            ? stopWordsCN.reduce(title){ r,w in r.replacingOccurrences(of:w,with:"") }
                .components(separatedBy:CharacterSet.whitespaces).filter{$0.count>=2}
            : stopWordsEN.reduce(lower){ r,w in r.replacingOccurrences(of:" \(w) ",with:" ") }
                .components(separatedBy:" ").filter{$0.count>=3}
        let coreName = coreWords.first ?? (isCN ? "目标" : "goal")

        let templatesCN = [
            "今日\(coreName)打卡",
            "\(coreName)专注25分钟",
            "记录\(coreName)进展",
            "回顾\(coreName)动力",
            "\(coreName)重点突破",
        ]
        let templatesEN = [
            "Daily \(coreName) check-in",
            "Focus 25min on \(coreName)",
            "Log \(coreName) progress",
            "Review \(coreName) motivation",
            "\(coreName) deep work",
        ]
        let templates = (isCN ? templatesCN : templatesEN).filter { !existing.contains($0) }

        // ══════════════════════════════════════════════════════
        // A：关键词词库（40个池，覆盖更多目标类型）
        // ══════════════════════════════════════════════════════
        struct KPool { let kw:[String]; let zh:[String]; let en:[String] }
        let pools:[KPool] = [
            // 健身/运动
            KPool(kw:["健身","跑步","运动","体能","锻炼","力量","有氧","增肌","瑜伽","游泳","骑行","fitness","run","workout","exercise","gym","yoga","swim","cycle"],
                  zh:["今日跑量打卡","力量训练组数","热身5分钟","拉伸放松10分","记录体重","补充蛋白质","睡前核心训练","HIIT间歇训练","步行10000步","深蹲100个"],
                  en:["Log today's run","Track strength sets","5min warm-up","Cool-down stretch","Log weight","Protein intake","Core before bed","HIIT session","10k steps","100 squats"]),
            // 阅读/书籍
            KPool(kw:["读书","阅读","看书","书","文学","小说","传记","read","book","novel","reading","literature"],
                  zh:["今日阅读页数","摘录金句3条","写读后感","画思维导图","书评一段","带着问题读","找到书中核心观点","把书中方法用于今天"],
                  en:["Pages read today","Note 3 key quotes","Write a reflection","Mind map","Short book review","Read with questions","Find core argument","Apply one idea today"]),
            // 语言学习
            KPool(kw:["语言","英语","日语","西班牙","法语","韩语","德语","意大利","口语","词汇","背单词","language","spanish","english","japanese","french","korean","vocab","words"],
                  zh:["今日新词汇10个","口语跟读15分","听力精听一段","用新词造句5个","复习昨日词汇","看一段外语视频","语法练习一节","用目标语记日记"],
                  en:["Learn 10 new words","Oral shadowing 15min","Intensive listening","Write 5 sentences","Review yesterday's words","Watch a video in target language","Grammar practice","Journal in target language"]),
            // 写作/创作
            KPool(kw:["写作","博客","文章","创作","写字","日记","小说","剧本","write","blog","article","journal","writing","essay","story","script"],
                  zh:["今日写作字数","修改一段文字","收集写作素材","列写作大纲","解决一个情节难题","描写一个场景","写开头三句","完成一个段落"],
                  en:["Daily word count","Edit one paragraph","Gather material","Draft an outline","Solve a plot problem","Describe a scene","Write 3 opening lines","Complete one section"]),
            // 编程/开发
            KPool(kw:["编程","代码","开发","算法","swift","python","java","javascript","code","programming","developer","app","web"],
                  zh:["完成一个函数","刷一道算法题","阅读技术文档","重构一段代码","写单元测试","解决一个bug","学习一个新API","代码复盘10分钟"],
                  en:["Complete one function","Solve one algorithm","Read tech docs","Refactor old code","Write unit tests","Fix one bug","Learn one new API","Code review 10min"]),
            // 冥想/心理
            KPool(kw:["冥想","正念","减压","心理","情绪","平静","呼吸","meditate","mindful","stress","anxiety","calm","breathe","mental"],
                  zh:["晨间冥想10分","4-7-8呼吸法","写感恩日记3条","数字断联30分","身体扫描练习","记录情绪变化","专注当下5分钟","睡前放松冥想"],
                  en:["Morning meditation 10min","4-7-8 breathing","3 gratitude notes","Digital detox 30min","Body scan practice","Track mood changes","Present moment 5min","Sleep meditation"]),
            // 饮食/减重
            KPool(kw:["饮食","减肥","减重","体重","健康","热量","营养","diet","weight","lose","nutrition","calories","healthy eating","meal"],
                  zh:["记录今日饮食","蔬菜份量打卡","饮水2升记录","晚饭七分饱","戒掉一种零食","无糖饮料一天","计算今日热量","慢嚼细咽练习"],
                  en:["Log meals today","Veggie serving check","Drink 2L water","Stop at 70% full","Skip one snack","No sugar drinks today","Count calories","Eat slowly today"]),
            // 理财/投资
            KPool(kw:["理财","投资","存款","记账","资产","股票","基金","finance","invest","savings","budget","money","stock","fund"],
                  zh:["记录今日支出","复盘本周花费","学一个理财知识","分析一只股票","更新资产表","设本月储蓄目标","读财报一页","控制冲动消费"],
                  en:["Log daily expenses","Review this week's spending","Learn one finance concept","Analyze one stock","Update asset sheet","Set monthly saving goal","Read one page of financials","Avoid impulse buy"]),
            // 工作/效率
            KPool(kw:["工作","项目","效率","职场","时间管理","专注","work","project","productivity","career","focus","time management","professional"],
                  zh:["列出今日TOP3任务","深度工作90分钟","清空邮件收件箱","整理项目进度","番茄工作法4轮","15分钟站立会议","整理桌面工作区","拒绝一次不必要会议"],
                  en:["Pick top 3 tasks","Deep work 90min","Clear email inbox","Update project status","4 Pomodoro rounds","15min standup","Tidy workspace","Decline one unnecessary meeting"]),
            // 绘画/艺术
            KPool(kw:["绘画","画画","素描","水彩","设计","艺术","draw","paint","sketch","design","art","illustration","creative"],
                  zh:["速写一个物体","色彩练习15分","临摹一幅作品","记录创作灵感","研究一位艺术家","完成一个细节","画人物头像练习","整理画材"],
                  en:["Quick sketch one object","Color practice 15min","Copy one artwork","Note creative ideas","Study one artist","Finish one detail","Portrait practice","Organize art supplies"]),
            // 音乐/乐器
            KPool(kw:["音乐","钢琴","吉他","唱歌","乐器","music","piano","guitar","sing","instrument","practice","melody"],
                  zh:["练习基本音阶","曲目练习20分","节奏训练一段","录制练习片段","学习乐理一节","听分析一首曲子","和弦转换练习","演奏给自己听"],
                  en:["Practice scales","Play piece 20min","Rhythm drill","Record a practice clip","Learn one music theory concept","Analyze one song","Chord transition drill","Perform for yourself"]),
            // 社交/人际
            KPool(kw:["社交","人际","朋友","关系","沟通","表达","social","relationship","friend","communicate","networking","people"],
                  zh:["主动联系一位朋友","参加一个活动","给家人发消息","学一个沟通技巧","记录今日互动","改进一次表达方式","表达感谢一次","建立一个新联系"],
                  en:["Reach out to one friend","Attend one event","Message a family member","Learn one communication skill","Log a key interaction","Improve one expression","Express gratitude","Make one new connection"]),
            // 学习/考试
            KPool(kw:["学习","考试","备考","复习","课程","知识","study","exam","review","course","learn","knowledge","test"],
                  zh:["复习一个章节","做一套练习题","整理错题本","制作知识卡片","限时模拟练习","把知识讲给自己听","找到薄弱点","预习明日内容"],
                  en:["Review one chapter","Complete one practice set","Update error log","Make flashcards","Timed mock test","Explain concept to yourself","Find weak points","Preview tomorrow's content"]),
        ]

        // 关键词匹配——同时检查 title 和 category，支持多池合并
        var poolMatches: [String] = []
        for pool in pools {
            if pool.kw.contains(where:{ lower.contains($0) || cat.contains($0) }) {
                let suggestions = isCN ? pool.zh : pool.en
                poolMatches.append(contentsOf: suggestions.filter { !existing.contains($0) })
            }
        }

        // ══════════════════════════════════════════════════════
        // 合并 B + C + A，去重，shuffle 保证每次不同顺序
        // ══════════════════════════════════════════════════════
        var result: [String] = []
        // B 历史任务优先（最多2条）
        result.append(contentsOf: allHistory.prefix(2))
        // A 关键词匹配（最多6条）
        let poolFiltered = poolMatches.filter { !result.contains($0) }
        result.append(contentsOf: poolFiltered.prefix(6))
        // C 模板填空（补充到最多8条）
        let templatesFiltered = templates.filter { !result.contains($0) }
        result.append(contentsOf: templatesFiltered.prefix(max(0, 8 - result.count)))
        // 如果全部都空，用通用兜底
        if result.isEmpty {
            let fallback = isCN
                ? ["记录今日进展","明确今日优先级","专注25分钟","回顾目标动力","与昨日对比进步","写下今天的收获"]
                : ["Log today's progress","Set today's priority","Focus 25 minutes","Review your motivation","Compare vs yesterday","Write today's takeaway"]
            result = fallback.filter { !existing.contains($0) }
        }
        // 每次调用 shuffle，让「刷新」有新鲜感
        return Array(result.shuffled().prefix(8))
    }



    // ── 我的成长层级数据辅助 ──────────────────────────────────
    func allGrowthYears() -> [GrowthYearEntry] {
        let cal = Calendar.current
        let isCN = language == .chinese
        var yearSet = Set<Int>()
        for r in dayReviews where r.isSubmitted || !r.gainKeywords.isEmpty || !r.tomorrowKeywords.isEmpty {
            yearSet.insert(cal.component(.year, from:r.date))
        }
        for e in dailyChallenges where e.resolvedOnDate != nil {
            yearSet.insert(cal.component(.year, from:e.date))
        }
        // 包含来自 PeriodSummary 的年份
        for ps in periodSummaries where !ps.gainKeywords.isEmpty || !ps.nextKeywords.isEmpty {
            yearSet.insert(cal.component(.year, from:ps.startDate))
        }
        return yearSet.sorted(by:>).map { year in
            let label = isCN ? "\(year)年" : "\(year)"
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
        let isCN = language == .chinese
        return (1...12).compactMap { month -> GrowthMonthEntry? in
            var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
            guard let start = cal.date(from:comps),
                  let end = cal.date(byAdding:.month,value:1,to:start) else { return nil }
            var dates: [Date] = []
            var d = start
            while d < end { dates.append(d); d = cal.date(byAdding:.day,value:1,to:d)! }
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: isCN ? "zh_CN":"en_US")
            fmt.dateFormat = isCN ? "M月" : "MMMM"
            let label = isCN ? "\(year)年\(month)月" : fmt.string(from:start)
            let key = "\(year)-\(month)"
            return GrowthMonthEntry(label:label, key:key, dates:dates)
        }
    }

    func weeksInMonth(_ dates: [Date]) -> [GrowthWeekEntry] {
        let cal = Calendar.current
        let isCN = language == .chinese
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
            let label = isCN ? "\(y)年第\(w)周" : "Week \(w), \(y)"
            let key = "\(y)-W\(w)"
            return GrowthWeekEntry(label:label, key:key, dates:weekMap[w]!.sorted())
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

func formatDate(_ date: Date, format: String = "M月d日 EEEE", lang: AppLanguage = .chinese) -> String {
    let f=DateFormatter(); f.dateFormat=format
    f.locale=Locale(identifier:lang == .chinese ? "zh_CN":"en_US")
    return f.string(from:date)
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
