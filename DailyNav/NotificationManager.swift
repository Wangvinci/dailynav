import Foundation
import Combine
import UserNotifications

// ============================================================
// MARK: - 通知管理器（每日提醒）
// ============================================================

class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var morningEnabled: Bool = false {
        didSet { save(); reschedule() }
    }
    @Published var eveningEnabled: Bool = false {
        didSet { save(); reschedule() }
    }
    @Published var morningHour: Int = 8 {
        didSet { save(); reschedule() }
    }
    @Published var morningMinute: Int = 0 {
        didSet { save(); reschedule() }
    }
    @Published var eveningHour: Int = 21 {
        didSet { save(); reschedule() }
    }
    @Published var eveningMinute: Int = 0 {
        didSet { save(); reschedule() }
    }

    private let center = UNUserNotificationCenter.current()
    private let ud = UserDefaults.standard

    private init() {
        morningEnabled = ud.bool(forKey: "dn_notify_morning")
        eveningEnabled = ud.bool(forKey: "dn_notify_evening")
        morningHour   = ud.object(forKey: "dn_notify_mH") as? Int ?? 8
        morningMinute = ud.object(forKey: "dn_notify_mM") as? Int ?? 0
        eveningHour   = ud.object(forKey: "dn_notify_eH") as? Int ?? 21
        eveningMinute = ud.object(forKey: "dn_notify_eM") as? Int ?? 0
        Task { @MainActor in
            let settings = await center.notificationSettings()
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // ── 检查权限状态 ──────────────────────────────────────────
    @MainActor
    func checkAuthorization() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // ── 请求通知权限 ──────────────────────────────────────────
    @MainActor
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                morningEnabled = true
                eveningEnabled = true
            }
            return granted
        } catch {
            #if DEBUG
            print("[Notification] Permission error: \(error)")
            #endif
            return false
        }
    }

    // ── 重新调度所有通知 ──────────────────────────────────────
    func reschedule() {
        center.removeAllPendingNotificationRequests()

        if morningEnabled {
            scheduleDailyNotification(
                id: "dn_morning",
                hour: morningHour,
                minute: morningMinute,
                title: "DailyNav",
                body: morningBodyForLocale()
            )
        }

        if eveningEnabled {
            scheduleDailyNotification(
                id: "dn_evening",
                hour: eveningHour,
                minute: eveningMinute,
                title: "DailyNav",
                body: eveningBodyForLocale()
            )
        }
    }

    // ── 调度单个每日通知 ──────────────────────────────────────
    private func scheduleDailyNotification(id: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = nil

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            #if DEBUG
            if let error { print("[Notification] Schedule error: \(error)") }
            #endif
        }
    }

    // ── 保存设置 ──────────────────────────────────────────────
    private func save() {
        ud.set(morningEnabled, forKey: "dn_notify_morning")
        ud.set(eveningEnabled, forKey: "dn_notify_evening")
        ud.set(morningHour,   forKey: "dn_notify_mH")
        ud.set(morningMinute, forKey: "dn_notify_mM")
        ud.set(eveningHour,   forKey: "dn_notify_eH")
        ud.set(eveningMinute, forKey: "dn_notify_eM")
    }

    // ── 本地化通知文案 ────────────────────────────────────────
    private func morningBodyForLocale() -> String {
        let lang = Locale.preferredLanguages.first ?? ""
        if lang.hasPrefix("zh") { return "新的一天开始了，来看看今天的目标吧！" }
        if lang.hasPrefix("ja") { return "新しい一日の始まりです。今日の目標を確認しましょう！" }
        if lang.hasPrefix("ko") { return "새로운 하루가 시작됐어요. 오늘의 목표를 확인하세요!" }
        if lang.hasPrefix("es") { return "¡Un nuevo día comienza! Revisa tus metas de hoy." }
        return "A new day begins! Check your goals for today."
    }

    private func eveningBodyForLocale() -> String {
        let lang = Locale.preferredLanguages.first ?? ""
        if lang.hasPrefix("zh") { return "别忘了记录今天的心得，回顾你的进步。" }
        if lang.hasPrefix("ja") { return "今日の振り返りを忘れずに。あなたの進歩を確認しましょう。" }
        if lang.hasPrefix("ko") { return "오늘의 소감을 기록하고 진전을 확인하세요." }
        if lang.hasPrefix("es") { return "No olvides registrar tus reflexiones de hoy." }
        return "Don't forget to log today's reflections and review your progress."
    }
}
