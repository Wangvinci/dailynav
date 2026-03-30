import UIKit

// ============================================================
// MARK: - 触感反馈管理器
// ============================================================

enum HapticManager {

    // ── 冲击反馈（按钮点击、任务完成）────────────────────────
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // ── 通知反馈（成功/失败/警告）──────────────────────────
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    // ── 选择反馈（滑动选择器、切换开关）────────────────────
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // ── 语义化快捷方法 ──────────────────────────────────────

    /// 任务完成打卡
    static func taskComplete() {
        notification(.success)
    }

    /// 目标创建
    static func goalCreated() {
        impact(.medium)
    }

    /// 目标删除
    static func goalDeleted() {
        notification(.warning)
    }

    /// 心情选择
    static func moodSelected() {
        impact(.light)
    }

    /// 成就解锁
    static func achievementUnlocked() {
        notification(.success)
    }

    /// 奖励获得（连续打卡等）
    static func rewardEarned() {
        impact(.heavy)
    }

    /// 错误操作
    static func error() {
        notification(.error)
    }

    /// Tab 切换
    static func tabChanged() {
        selection()
    }
}
