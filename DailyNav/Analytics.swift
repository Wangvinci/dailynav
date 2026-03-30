//
//  Analytics.swift
//  DailyNav
//
//  Created by Shengtao Wang on 04/03/2026.
//
import Foundation
import Combine

// ============================================================
// MARK: - DailyNav Analytics & AI Data Pipeline
// ============================================================
//
// Architecture:
//   AppStore  ──track()──►  Analytics.shared  ──►  AnalyticsStore (local)
//                                              ──►  [future: AIDataBridge / CloudSync]
//
// Design principles:
//   1. Zero coupling  — AppStore calls Analytics.track() one-way only
//   2. Pluggable backend — swap AnalyticsBackend protocol impl without
//      touching a single call site
//   3. AI-ready schema — every event carries enough context for an LLM
//      to reconstruct "what did this user do, why, and with what result"
//   4. Privacy-first — no PII, no network calls by default; all local
//   5. Aggregation layer — raw events + daily/weekly digests for AI prompts
//
// To add a new event:
//   1. Add case to AnalyticsEvent enum
//   2. Call Analytics.track(.yourEvent(...)) at the action site
//   That's it — no other changes required.
//
// To plug in an AI backend later:
//   1. Implement AnalyticsBackend protocol
//   2. Analytics.shared.backend = YourAIBackend()
// ============================================================

// ─────────────────────────────────────────────────────────────
// MARK: Screen enum
// ─────────────────────────────────────────────────────────────
enum AppScreen: String, Codable, CaseIterable {
    case plan    = "plan"
    case today   = "today"
    case goals   = "goals"
    case stats   = "stats"
    case inspire = "inspire"
    case growth  = "growth"
    case unknown = "unknown"
}

// ─────────────────────────────────────────────────────────────
// MARK: Time block (maps to Plan page time slots)
// ─────────────────────────────────────────────────────────────
enum TimeBlock: String, Codable {
    case morning   = "morning"    // slot 0
    case afternoon = "afternoon"  // slot 1
    case evening   = "evening"    // slot 2
    case unset     = "unset"      // nil slot

    static func from(slot: Int?) -> TimeBlock {
        switch slot {
        case 0:  return .morning
        case 1:  return .afternoon
        case 2:  return .evening
        default: return .unset
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Mood level (maps to DayReview.rating)
// ─────────────────────────────────────────────────────────────
enum MoodLevel: Int, Codable {
    case unrated = 0
    case awful   = 1
    case bad     = 2
    case okay    = 3
    case good    = 4
    case great   = 5
}

// ─────────────────────────────────────────────────────────────
// MARK: Analytics Event Catalog
//
// Every event is an enum case carrying only what that event
// genuinely needs. Associated values → JSON payload at encode time.
//
// Naming convention: {screen}_{object}_{verb}
// e.g.  plan_task_add, today_task_complete, goal_created
// ─────────────────────────────────────────────────────────────
enum AnalyticsEvent {

    // ── Plan page ─────────────────────────────────────────────

    /// User added a task to a specific day (pinned task)
    case plan_task_add(goalId: UUID, goalTitle: String, taskId: UUID, taskTitle: String,
                       date: Date, timeBlock: TimeBlock)

    /// User deleted a task from a specific day
    case plan_task_delete(goalId: UUID, goalTitle: String, taskId: UUID, taskTitle: String,
                          date: Date, wasPinned: Bool)

    /// User edited a task title/time on a specific day
    case plan_task_edit(goalId: UUID, taskId: UUID, date: Date,
                        oldTitle: String, newTitle: String)

    /// User dragged a task from one day to another
    case plan_task_drag(goalId: UUID, taskId: UUID, fromDate: Date, toDate: Date,
                        toTimeBlock: TimeBlock)

    /// User expanded a day card
    case plan_day_expand(date: Date, taskCount: Int, doneCount: Int)

    /// User collapsed a day card
    case plan_day_collapse(date: Date, taskCount: Int, doneCount: Int, completionRate: Double)

    /// User toggled goal filter in Plan page header
    case plan_goal_filter_toggle(goalId: UUID, goalTitle: String, isSelected: Bool)

    /// User requested AI task suggestions
    case plan_ai_suggest(selectedGoalIds: [UUID], suggestionsCount: Int)

    /// User accepted an AI suggested task (dragged into a day)
    case plan_ai_accept(goalId: UUID, taskTitle: String, targetDate: Date, timeBlock: TimeBlock)

    // ── Today page ────────────────────────────────────────────

    /// User marked a task as done (progress = 1.0)
    case today_task_complete(goalId: UUID, goalTitle: String, taskId: UUID, taskTitle: String,
                             date: Date, timeToCompleteMinutes: Int?)

    /// User un-marked a task (progress < 1.0)
    case today_task_uncomplete(goalId: UUID, taskId: UUID, date: Date)

    /// User set partial progress on a task
    case today_task_progress(goalId: UUID, taskId: UUID, date: Date,
                             oldProgress: Double, newProgress: Double)

    /// Day fully completed (all tasks done)
    case today_day_complete(date: Date, taskCount: Int, completionRate: Double,
                            durationMinutes: Int?)

    // ── Goals page ────────────────────────────────────────────

    /// User created a new goal
    case goal_created(goalId: UUID, goalTitle: String, goalType: String,
                      category: String, taskCount: Int)

    /// User edited a goal
    case goal_edited(goalId: UUID, goalTitle: String, fieldChanged: String)

    /// User deleted a goal
    case goal_deleted(goalId: UUID, goalTitle: String, taskCount: Int,
                      completionRate: Double)

    /// User added a task template to a goal (global, not date-pinned)
    case goal_task_template_add(goalId: UUID, taskTitle: String)

    // ── Growth / Review page ──────────────────────────────────

    /// User submitted a day review
    case review_submitted(date: Date, rating: Int, gainKeywords: [String],
                          challengeKeywords: [String],
                          hasGainNote: Bool, hasChallengeNote: Bool)

    /// User marked a challenge as resolved
    case challenge_resolved(keyword: String, originDate: Date, resolvedDate: Date,
                            daysOpen: Int, hasNote: Bool)

    /// User wrote a plan journal / task insight
    case insight_written(goalId: UUID, taskId: UUID?, date: Date, noteLength: Int)

    // ── Stats / Achievements ──────────────────────────────────

    /// User unlocked an achievement badge
    case achievement_unlocked(goalId: UUID, goalTitle: String,
                               level: String, completionRate: Double, date: Date)

    /// Period summary submitted (week/month/year)
    case period_summary_submitted(periodType: Int, periodLabel: String,
                                   mood: Int, gainKeywords: [String],
                                   challengeKeywords: [String], avgCompletion: Double)

    // ── Navigation ────────────────────────────────────────────

    /// Screen viewed
    case screen_view(screen: AppScreen, previousScreen: AppScreen?)
}

// ─────────────────────────────────────────────────────────────
// MARK: AnalyticsPayload — the actual stored/serialized shape
// ─────────────────────────────────────────────────────────────
struct AnalyticsPayload: Identifiable, Codable {
    var id: UUID = UUID()
    var eventName: String
    var timestamp: Date
    var screen: AppScreen
    // Core identifiers (all optional — only set when relevant)
    var goalId: String?
    var goalTitle: String?
    var taskId: String?
    var taskTitle: String?
    var date: String?            // ISO8601 date string for the day the event concerns
    // Numeric values
    var completionRate: Double?
    var taskCount: Int?
    var doneCount: Int?
    var progressValue: Double?
    var durationMinutes: Int?
    var noteLength: Int?
    var rating: Int?
    // Categorical values
    var timeBlock: String?
    var fieldChanged: String?
    var periodType: Int?
    var periodLabel: String?
    var boolValue: Bool?
    // Arrays (stored as JSON string to stay Codable without generics)
    var keywords: String?        // JSON array of strings
    var goalIds: String?         // JSON array of UUID strings
    // Misc
    var extraJson: String?       // future-proof overflow bucket
}

// ─────────────────────────────────────────────────────────────
// MARK: Daily Aggregate — AI-ready daily summary
//
// This is what you feed to the LLM prompt. One object per day,
// rich enough for the AI to understand:
//   "On March 5 the user planned 8 tasks across 3 goals,
//    completed 6, rating 4/5, wrote about challenges with focus,
//    plans to work on coding in the morning tomorrow"
// ─────────────────────────────────────────────────────────────
struct DailyAnalyticsAggregate: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date

    // Task completion
    var plannedTaskCount: Int = 0
    var completedTaskCount: Int = 0
    var completionRate: Double { plannedTaskCount == 0 ? 0 : Double(completedTaskCount) / Double(plannedTaskCount) }

    // Time block distribution
    var morningTaskCount: Int = 0
    var afternoonTaskCount: Int = 0
    var eveningTaskCount: Int = 0
    var unsetTaskCount: Int = 0

    // Goals involved
    var activeGoalIds: [String] = []        // goals that had tasks this day
    var activeGoalTitles: [String] = []

    // Review / mood
    var moodRating: Int = 0                 // 0 = not reviewed, 1-5
    var gainKeywords: [String] = []
    var challengeKeywords: [String] = []
    var hasDetailedReview: Bool = false

    // Challenges & insights
    var newChallengeCount: Int = 0
    var resolvedChallengeCount: Int = 0
    var insightCount: Int = 0               // plan journal entries written

    // Achievements this day
    var achievementsUnlocked: [String] = []  // level strings

    // Time active
    var firstEventTime: Date?
    var lastEventTime: Date?
    var activeMinutes: Int? {               // rough estimate
        guard let first = firstEventTime, let last = lastEventTime else { return nil }
        return Int(last.timeIntervalSince(first) / 60)
    }

    // Computed for AI prompt
    var aiSummaryDict: [String: Any] {
        var d: [String: Any] = [
            "date": ISO8601DateFormatter().string(from: date),
            "planned": plannedTaskCount,
            "completed": completedTaskCount,
            "completion_pct": Int(completionRate * 100),
            "mood": moodRating,
            "morning_tasks": morningTaskCount,
            "afternoon_tasks": afternoonTaskCount,
            "evening_tasks": eveningTaskCount,
            "goals": activeGoalTitles,
        ]
        if !gainKeywords.isEmpty     { d["gains"]      = gainKeywords }
        if !challengeKeywords.isEmpty { d["challenges"] = challengeKeywords }
        if !achievementsUnlocked.isEmpty { d["achievements"] = achievementsUnlocked }
        if let mins = activeMinutes  { d["active_minutes"] = mins }
        return d
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Analytics Backend Protocol
//
// Default: LocalAnalyticsBackend (UserDefaults + JSON)
// Future:  CloudAnalyticsBackend, AIAnalyticsBackend, etc.
// ─────────────────────────────────────────────────────────────
protocol AnalyticsBackend: AnyObject {
    func record(payload: AnalyticsPayload)
    func fetchPayloads(from: Date?, to: Date?, limit: Int?) -> [AnalyticsPayload]
    func fetchAggregate(for date: Date) -> DailyAnalyticsAggregate?
    func fetchAggregates(from: Date, to: Date) -> [DailyAnalyticsAggregate]
    func pruneOldEvents(keepDays: Int)
}

// ─────────────────────────────────────────────────────────────
// MARK: Local Backend — UserDefaults + JSON files
//
// Storage strategy:
//   • Raw events:   UserDefaults key "dn_analytics_events" (last 90 days)
//   • Aggregates:   UserDefaults key "dn_analytics_agg_{dateKey}"
//   • Pruned automatically on app launch (>90 days old removed)
// ─────────────────────────────────────────────────────────────
final class LocalAnalyticsBackend: AnalyticsBackend {

    private let ud = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    // In-memory buffer — flushed to UserDefaults in batches
    private var buffer: [AnalyticsPayload] = []
    private var flushTimer: Timer?
    private let bufferFlushInterval: TimeInterval = 10  // flush every 10s
    private let maxBufferSize = 50                       // flush when buffer hits 50

    private static let eventsKey    = "dn_analytics_events_v2"
    private static let aggKeyPrefix = "dn_analytics_agg_"

    init() {
        scheduleFlush()
    }

    deinit {
        flushTimer?.invalidate()
        flushNow()
    }

    func record(payload: AnalyticsPayload) {
        buffer.append(payload)
        updateAggregate(for: payload)
        if buffer.count >= maxBufferSize { flushNow() }
    }

    func fetchPayloads(from: Date? = nil, to: Date? = nil, limit: Int? = nil) -> [AnalyticsPayload] {
        let all = loadAllPayloads()
        var filtered = all
        if let from = from { filtered = filtered.filter { $0.timestamp >= from } }
        if let to   = to   { filtered = filtered.filter { $0.timestamp <= to   } }
        filtered.sort { $0.timestamp > $1.timestamp }
        if let limit = limit { return Array(filtered.prefix(limit)) }
        return filtered
    }

    func fetchAggregate(for date: Date) -> DailyAnalyticsAggregate? {
        let key = Self.aggKeyPrefix + dateKey(date)
        guard let data = ud.data(forKey: key) else { return nil }
        return try? decoder.decode(DailyAnalyticsAggregate.self, from: data)
    }

    func fetchAggregates(from: Date, to: Date) -> [DailyAnalyticsAggregate] {
        var result: [DailyAnalyticsAggregate] = []
        var current = Calendar.current.startOfDay(for: from)
        let end = Calendar.current.startOfDay(for: to)
        while current <= end {
            if let agg = fetchAggregate(for: current) { result.append(agg) }
            current = Calendar.current.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return result
    }

    func pruneOldEvents(keepDays: Int = 90) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        var all = loadAllPayloads()
        let before = all.count
        all = all.filter { $0.timestamp > cutoff }
        if all.count != before { saveAllPayloads(all) }
    }

    // ── Private helpers ───────────────────────────────────────

    private func scheduleFlush() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: bufferFlushInterval,
                                          repeats: true) { [weak self] _ in
            self?.flushNow()
        }
    }

    private func flushNow() {
        guard !buffer.isEmpty else { return }
        var all = loadAllPayloads()
        all.append(contentsOf: buffer)
        saveAllPayloads(all)
        buffer.removeAll()
    }

    private func loadAllPayloads() -> [AnalyticsPayload] {
        guard let data = ud.data(forKey: Self.eventsKey) else { return [] }
        return (try? decoder.decode([AnalyticsPayload].self, from: data)) ?? []
    }

    private func saveAllPayloads(_ payloads: [AnalyticsPayload]) {
        if let data = try? encoder.encode(payloads) {
            ud.set(data, forKey: Self.eventsKey)
        }
    }

    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    private func updateAggregate(for payload: AnalyticsPayload) {
        let eventDate: Date = {
            if let ds = payload.date,
               let d = ISO8601DateFormatter().date(from: ds) {
                return Calendar.current.startOfDay(for: d)
            }
            return Calendar.current.startOfDay(for: payload.timestamp)
        }()
        let key = Self.aggKeyPrefix + dateKey(eventDate)
        var agg = fetchAggregate(for: eventDate) ?? DailyAnalyticsAggregate(date: eventDate)

        // Update first/last event time
        if agg.firstEventTime == nil { agg.firstEventTime = payload.timestamp }
        agg.lastEventTime = payload.timestamp

        // Route to aggregate update logic
        switch payload.eventName {
        case "plan_task_add":
            agg.plannedTaskCount += 1
            switch payload.timeBlock {
            case TimeBlock.morning.rawValue:   agg.morningTaskCount += 1
            case TimeBlock.afternoon.rawValue: agg.afternoonTaskCount += 1
            case TimeBlock.evening.rawValue:   agg.eveningTaskCount += 1
            default:                           agg.unsetTaskCount += 1
            }
            if let gid = payload.goalId, !agg.activeGoalIds.contains(gid) {
                agg.activeGoalIds.append(gid)
                if let gt = payload.goalTitle { agg.activeGoalTitles.append(gt) }
            }
        case "today_task_complete":
            agg.completedTaskCount += 1
        case "today_task_uncomplete":
            agg.completedTaskCount = max(0, agg.completedTaskCount - 1)
        case "review_submitted":
            agg.moodRating       = payload.rating ?? 0
            agg.hasDetailedReview = true
            if let kw = payload.keywords, let arr = try? JSONDecoder().decode([String].self, from: Data(kw.utf8)) {
                // keywords field stores gain keywords for review events
                agg.gainKeywords = arr
            }
        case "challenge_resolved":
            agg.resolvedChallengeCount += 1
        case "insight_written":
            agg.insightCount += 1
        case "achievement_unlocked":
            if let level = payload.fieldChanged { agg.achievementsUnlocked.append(level) }
        default:
            break
        }

        // Persist aggregate
        if let data = try? encoder.encode(agg) {
            ud.set(data, forKey: key)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: Analytics Singleton
// ─────────────────────────────────────────────────────────────
final class Analytics {

    static let shared = Analytics()
    private init() {
        backend = LocalAnalyticsBackend()
        // Prune on init (runs once per app launch)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
            self.backend.pruneOldEvents(keepDays: 90)
        }
    }

    /// Swap this to plug in cloud / AI backend
    var backend: AnalyticsBackend

    /// Current screen — set by the app's tab/navigation layer
    var currentScreen: AppScreen = .unknown

    // ── Core tracking entry point ─────────────────────────────
    func track(_ event: AnalyticsEvent) {
        let payload = encode(event)
        backend.record(payload: payload)
        #if DEBUG
        print("📊 [Analytics] \(payload.eventName) — \(payload.timestamp)")
        #endif
    }

    // ── Convenience: build AI context snapshot for any date range ──────
    /// Returns a structured JSON string suitable for inclusion in an AI prompt.
    /// Pass this directly to your LLM: "Here is the user's recent activity: {json}"
    func aiContextSnapshot(days: Int = 7) -> String {
        let to   = Date()
        let from = Calendar.current.date(byAdding: .day, value: -days, to: to) ?? to
        let aggs = backend.fetchAggregates(from: from, to: to)
        let dicts = aggs.map { $0.aiSummaryDict }
        if let data = try? JSONSerialization.data(withJSONObject: dicts, options: .prettyPrinted),
           let str  = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    /// Full user profile snapshot for AI: goals + recent activity + patterns
    func aiUserProfile(store: AppStore, days: Int = 30) -> [String: Any] {
        let to   = Date()
        let from = Calendar.current.date(byAdding: .day, value: -days, to: to) ?? to
        let aggs = backend.fetchAggregates(from: from, to: to)

        let totalPlanned   = aggs.reduce(0) { $0 + $1.plannedTaskCount }
        let totalCompleted = aggs.reduce(0) { $0 + $1.completedTaskCount }
        let avgMood        = aggs.filter { $0.moodRating > 0 }.map { Double($0.moodRating) }
        let avgMoodVal     = avgMood.isEmpty ? 0.0 : avgMood.reduce(0, +) / Double(avgMood.count)

        // Best time block
        let morningTotal   = aggs.reduce(0) { $0 + $1.morningTaskCount }
        let afternoonTotal = aggs.reduce(0) { $0 + $1.afternoonTaskCount }
        let eveningTotal   = aggs.reduce(0) { $0 + $1.eveningTaskCount }
        let bestBlock      = [("morning", morningTotal), ("afternoon", afternoonTotal), ("evening", eveningTotal)]
                              .max(by: { $0.1 < $1.1 })?.0 ?? "unset"

        // Recent gain/challenge keywords (frequency ranked)
        let allGains      = aggs.flatMap { $0.gainKeywords }
        let allChallenges = aggs.flatMap { $0.challengeKeywords }

        func topKeywords(_ arr: [String], n: Int) -> [String] {
            var freq: [String: Int] = [:]
            arr.forEach { freq[$0, default: 0] += 1 }
            return freq.sorted { $0.value > $1.value }.prefix(n).map { $0.key }
        }

        // Goals summary
        let goalsSummary = store.goals.map { g -> [String: Any] in
            let tasks = g.tasks.count
            return [
                "id":       g.id.uuidString,
                "title":    g.title,
                "category": g.category,
                "type":     g.goalType.rawValue,
                "tasks":    tasks,
            ]
        }

        // Recent reviews
        let recentReviews = store.dayReviews
            .filter { $0.date >= from && $0.isSubmitted }
            .sorted { $0.date > $1.date }
            .prefix(7)
            .map { r -> [String: Any] in
                var d: [String: Any] = [
                    "date":   ISO8601DateFormatter().string(from: r.date),
                    "rating": r.rating,
                ]
                if !r.gainKeywords.isEmpty      { d["gains"]      = r.gainKeywords      }
                if !r.challengeKeywords.isEmpty  { d["challenges"] = r.challengeKeywords }
                return d
            }

        // Resolved challenges (recent)
        let resolvedChallenges = store.dailyChallenges
            .filter { $0.resolvedOnDate != nil }
            .prefix(10)
            .map { c -> [String: Any] in
                var d: [String: Any] = ["keyword": c.keyword]
                if !c.resolvedNote.isEmpty { d["note"] = c.resolvedNote }
                return d
            }

        // Achievements
        let recentAchievements = store.achievements
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { a -> [String: Any] in [
                "goal":  a.goalTitle,
                "level": a.level.rawValue,
                "date":  ISO8601DateFormatter().string(from: a.date),
                "rate":  Int(a.completionRate * 100),
            ]}

        return [
            "profile_window_days":  days,
            "total_planned":        totalPlanned,
            "total_completed":      totalCompleted,
            "overall_completion_pct": totalPlanned == 0 ? 0 : Int(Double(totalCompleted)/Double(totalPlanned)*100),
            "avg_mood":             String(format: "%.1f", avgMoodVal),
            "best_time_block":      bestBlock,
            "top_gain_keywords":    topKeywords(allGains, n: 10),
            "top_challenge_keywords": topKeywords(allChallenges, n: 10),
            "goals":                goalsSummary,
            "recent_reviews":       Array(recentReviews),
            "resolved_challenges":  Array(resolvedChallenges),
            "recent_achievements":  Array(recentAchievements),
        ]
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Event encoder — AnalyticsEvent → AnalyticsPayload
    // ─────────────────────────────────────────────────────────
    private func encode(_ event: AnalyticsEvent) -> AnalyticsPayload {
        let iso = ISO8601DateFormatter()
        var p = AnalyticsPayload(
            eventName: eventName(event),
            timestamp: Date(),
            screen:    currentScreen
        )
        func setDate(_ d: Date) { p.date = iso.string(from: d) }

        switch event {

        case .plan_task_add(let goalId, let goalTitle, let taskId, let taskTitle, let date, let block):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.taskId = taskId.uuidString; p.taskTitle = taskTitle
            p.timeBlock = block.rawValue; setDate(date)

        case .plan_task_delete(let goalId, let goalTitle, let taskId, let taskTitle, let date, let wasPinned):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.taskId = taskId.uuidString; p.taskTitle = taskTitle
            p.boolValue = wasPinned; setDate(date)

        case .plan_task_edit(let goalId, let taskId, let date, let old, let new):
            p.goalId = goalId.uuidString; p.taskId = taskId.uuidString
            p.fieldChanged = "title"; p.extraJson = jsonString(["old": old, "new": new])
            setDate(date)

        case .plan_task_drag(let goalId, let taskId, let from, let to, let block):
            p.goalId = goalId.uuidString; p.taskId = taskId.uuidString
            p.timeBlock = block.rawValue
            p.extraJson = jsonString(["from": iso.string(from: from), "to": iso.string(from: to)])
            setDate(to)

        case .plan_day_expand(let date, let taskCount, let doneCount):
            p.taskCount = taskCount; p.doneCount = doneCount; setDate(date)

        case .plan_day_collapse(let date, let taskCount, let doneCount, let rate):
            p.taskCount = taskCount; p.doneCount = doneCount
            p.completionRate = rate; setDate(date)

        case .plan_goal_filter_toggle(let goalId, let goalTitle, let isSelected):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle; p.boolValue = isSelected

        case .plan_ai_suggest(let ids, let count):
            p.goalIds = ids.map { $0.uuidString }.joined(separator: ",")
            p.taskCount = count

        case .plan_ai_accept(let goalId, let title, let targetDate, let block):
            p.goalId = goalId.uuidString; p.taskTitle = title
            p.timeBlock = block.rawValue; setDate(targetDate)

        case .today_task_complete(let goalId, let goalTitle, let taskId, let taskTitle, let date, let mins):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.taskId = taskId.uuidString; p.taskTitle = taskTitle
            p.durationMinutes = mins; setDate(date)

        case .today_task_uncomplete(let goalId, let taskId, let date):
            p.goalId = goalId.uuidString; p.taskId = taskId.uuidString; setDate(date)

        case .today_task_progress(let goalId, let taskId, let date, let old, let new):
            p.goalId = goalId.uuidString; p.taskId = taskId.uuidString
            p.progressValue = new
            p.extraJson = jsonString(["old": old, "new": new]); setDate(date)

        case .today_day_complete(let date, let count, let rate, let mins):
            p.taskCount = count; p.completionRate = rate
            p.durationMinutes = mins; setDate(date)

        case .goal_created(let goalId, let goalTitle, let type, let cat, let count):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.taskCount = count; p.extraJson = jsonString(["type": type, "category": cat])

        case .goal_edited(let goalId, let goalTitle, let field):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle; p.fieldChanged = field

        case .goal_deleted(let goalId, let goalTitle, let count, let rate):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.taskCount = count; p.completionRate = rate

        case .goal_task_template_add(let goalId, let title):
            p.goalId = goalId.uuidString; p.taskTitle = title

        case .review_submitted(let date, let rating, let gains, let challenges,
                                let hasGain, let hasChallenge):
            p.rating = rating
            p.keywords = jsonString(gains)
            p.boolValue = hasGain || hasChallenge
            p.extraJson = jsonString(["challenges": challenges,
                                       "has_gain": hasGain, "has_challenge": hasChallenge])
            setDate(date)

        case .challenge_resolved(let keyword, let origin, let resolved, let daysOpen, let hasNote):
            p.taskTitle = keyword; p.durationMinutes = daysOpen; p.boolValue = hasNote
            p.extraJson = jsonString(["origin": iso.string(from: origin),
                                       "resolved": iso.string(from: resolved)])

        case .insight_written(let goalId, let taskId, let date, let length):
            p.goalId = goalId.uuidString
            p.taskId = taskId?.uuidString
            p.noteLength = length; setDate(date)

        case .achievement_unlocked(let goalId, let goalTitle, let level, let rate, let date):
            p.goalId = goalId.uuidString; p.goalTitle = goalTitle
            p.fieldChanged = level; p.completionRate = rate; setDate(date)

        case .period_summary_submitted(let type, let label, let mood, let gains, let challenges, let avg):
            p.periodType = type; p.periodLabel = label; p.rating = mood
            p.completionRate = avg
            p.keywords = jsonString(gains)
            p.extraJson = jsonString(["challenges": challenges])

        case .screen_view(let screen, let prev):
            p.fieldChanged = screen.rawValue
            p.extraJson = prev.map { "{\"prev\":\"\($0.rawValue)\"}" }
        }

        return p
    }

    private func eventName(_ event: AnalyticsEvent) -> String {
        switch event {
        case .plan_task_add:               return "plan_task_add"
        case .plan_task_delete:            return "plan_task_delete"
        case .plan_task_edit:              return "plan_task_edit"
        case .plan_task_drag:              return "plan_task_drag"
        case .plan_day_expand:             return "plan_day_expand"
        case .plan_day_collapse:           return "plan_day_collapse"
        case .plan_goal_filter_toggle:     return "plan_goal_filter_toggle"
        case .plan_ai_suggest:             return "plan_ai_suggest"
        case .plan_ai_accept:              return "plan_ai_accept"
        case .today_task_complete:         return "today_task_complete"
        case .today_task_uncomplete:       return "today_task_uncomplete"
        case .today_task_progress:         return "today_task_progress"
        case .today_day_complete:          return "today_day_complete"
        case .goal_created:                return "goal_created"
        case .goal_edited:                 return "goal_edited"
        case .goal_deleted:                return "goal_deleted"
        case .goal_task_template_add:      return "goal_task_template_add"
        case .review_submitted:            return "review_submitted"
        case .challenge_resolved:          return "challenge_resolved"
        case .insight_written:             return "insight_written"
        case .achievement_unlocked:        return "achievement_unlocked"
        case .period_summary_submitted:    return "period_summary_submitted"
        case .screen_view:                 return "screen_view"
        }
    }

    private func jsonString(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    private func jsonString(_ strings: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(strings) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: AppStore + Analytics integration points
//
// These extensions add track() calls to the key AppStore mutations.
// No changes needed to the existing AppStore implementation.
// ─────────────────────────────────────────────────────────────
extension AppStore {

    // Call from: plan page "add task" after addPinnedTask()
    func trackAddTask(goalId: UUID, goalTitle: String, taskId: UUID, taskTitle: String,
                      date: Date, timeBlock: TimeBlock = .unset) {
        Analytics.shared.track(.plan_task_add(
            goalId: goalId, goalTitle: goalTitle,
            taskId: taskId, taskTitle: taskTitle,
            date: date, timeBlock: timeBlock
        ))
    }

    // Call from: chip delete (context menu / edit sheet)
    func trackDeleteTask(goalId: UUID, goalTitle: String, taskId: UUID, taskTitle: String,
                         date: Date, wasPinned: Bool) {
        Analytics.shared.track(.plan_task_delete(
            goalId: goalId, goalTitle: goalTitle,
            taskId: taskId, taskTitle: taskTitle,
            date: date, wasPinned: wasPinned
        ))
    }

    // Call from: chip edit sheet save
    func trackEditTask(goalId: UUID, taskId: UUID, date: Date,
                       oldTitle: String, newTitle: String) {
        guard oldTitle != newTitle else { return }
        Analytics.shared.track(.plan_task_edit(
            goalId: goalId, taskId: taskId, date: date,
            oldTitle: oldTitle, newTitle: newTitle
        ))
    }

    // Call from: drag-drop handleDrop()
    func trackDragTask(goalId: UUID, taskId: UUID, fromDate: Date, toDate: Date,
                       toTimeBlock: TimeBlock = .unset) {
        Analytics.shared.track(.plan_task_drag(
            goalId: goalId, taskId: taskId,
            fromDate: fromDate, toDate: toDate,
            toTimeBlock: toTimeBlock
        ))
    }

    // Call from: setProgress() when progress reaches 1.0
    func trackTaskComplete(goalId: UUID, taskId: UUID, date: Date) {
        guard let g = goals.first(where: { $0.id == goalId }),
              let t = g.tasks.first(where: { $0.id == taskId }) else { return }
        Analytics.shared.track(.today_task_complete(
            goalId: goalId, goalTitle: g.title,
            taskId: taskId, taskTitle: t.title,
            date: date, timeToCompleteMinutes: nil
        ))
    }

    // Call from: setProgress() when progress drops from 1.0
    func trackTaskUncomplete(goalId: UUID, taskId: UUID, date: Date) {
        Analytics.shared.track(.today_task_uncomplete(goalId: goalId, taskId: taskId, date: date))
    }

    // Call from: day review submission
    func trackReviewSubmitted(_ review: DayReview) {
        guard review.isSubmitted else { return }
        Analytics.shared.track(.review_submitted(
            date: review.date, rating: review.rating,
            gainKeywords: review.gainKeywords,
            challengeKeywords: review.challengeKeywords,
            hasGainNote:      !review.journalGains.isEmpty,
            hasChallengeNote: !review.journalChallenges.isEmpty
        ))
    }

    // Call from: challenge resolved action
    func trackChallengeResolved(_ entry: DailyChallengeEntry) {
        guard let resolved = entry.resolvedOnDate else { return }
        let days = Calendar.current.dateComponents([.day], from: entry.date, to: resolved).day ?? 0
        Analytics.shared.track(.challenge_resolved(
            keyword: entry.keyword, originDate: entry.date,
            resolvedDate: resolved, daysOpen: days,
            hasNote: !entry.resolvedNote.isEmpty
        ))
    }

    // Call from: achievement unlock
    func trackAchievementUnlocked(_ achievement: Achievement) {
        Analytics.shared.track(.achievement_unlocked(
            goalId: achievement.goalId, goalTitle: achievement.goalTitle,
            level: achievement.level.rawValue, completionRate: achievement.completionRate,
            date: achievement.date
        ))
    }

    // Call from: plan journal written
    func trackInsightWritten(_ entry: PlanJournalEntry) {
        Analytics.shared.track(.insight_written(
            goalId: entry.goalId, taskId: entry.taskId,
            date: entry.date, noteLength: entry.note.count
        ))
    }
}
