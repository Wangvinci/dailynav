import SwiftUI
import Combine
import UIKit

// ============================================================
// MARK: - App 入口
// ============================================================


struct ContentView: View {
    @StateObject var store = AppStore()
    @StateObject var pro   = ProStore()
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            GoalsView()
                .tabItem {
                    // Use consistent fill/outline pattern across all tabs.
                    // UITabBarAppearance handles selected colour — SwiftUI tint
                    // drives the fill visual weight automatically.
                    Label(store.t(key: L10n.goals),
                          systemImage: selectedTab == 0 ? "target" : "target")
                }.tag(0)
            TodayView()
                .tabItem {
                    Label(store.t(key: L10n.today),
                          systemImage: selectedTab == 1 ? "checkmark.circle.fill" : "checkmark.circle")
                }.tag(1)
            PlanView()
                .tabItem {
                    Label(store.t(key: L10n.plan),
                          systemImage: selectedTab == 2 ? "calendar.badge.checkmark" : "calendar")
                }.tag(2)
            StatsView()
                .tabItem {
                    Label(store.t(key: L10n.myPage),
                          systemImage: selectedTab == 3 ? "chart.bar.fill" : "chart.bar")
                }.tag(3)
            InspireView()
                .tabItem {
                    Label(store.t(key: L10n.inspire),
                          systemImage: selectedTab == 4 ? "sparkles" : "sparkles")
                }.tag(4)
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
        .environmentObject(store)
        .environmentObject(pro)
        .sheet(isPresented: $pro.showPaywall) {
            ProPaywallSheet()
                .environmentObject(store)
                .environmentObject(pro)
        }
        .onAppear {
            applyGlobalAppearance()
        }
    }

    private func applyGlobalAppearance() {

        // ══════════════════════════════════════════════════════
        // TAB BAR — 深黑磨砂玻璃，所有 tab 完全等高等基线
        //
        // Root cause of "今日 lower than others":
        //   Different tabs use different layout modes
        //   (stacked vs inline) or mismatched icon frame sizes.
        //   Fix: force stackedLayout for ALL tabs, lock icon
        //   size via UITabBarItemAppearance, zero out any
        //   title/icon offset that could shift baselines.
        // ══════════════════════════════════════════════════════
        let a = UITabBarAppearance()
        a.configureWithTransparentBackground()
        a.backgroundColor = UIColor(
            red: 0.051, green: 0.059, blue: 0.078, alpha: 0.97
        )
        // Top hairline — accent micro-glow
        a.shadowColor = UIColor(
            red: 0.278, green: 0.824, blue: 0.796, alpha: 0.14
        )

        // ── Shared colour palette ────────────────────────────
        let normalIconColor  = UIColor(red:0.30, green:0.36, blue:0.46, alpha:1.0)
        let selectedIconColor = UIColor(red:0.38, green:0.82, blue:0.70, alpha:1.0)

        // ── Shared text attributes — SAME font for ALL tabs ──
        // Using SF Rounded at 10pt keeps tab labels consistent.
        // tabBar system font is ~10pt; set explicitly to lock it.
        let tabFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let normalTitleAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalIconColor,
            .font: tabFont
        ]
        let selectedTitleAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedIconColor,
            .font: tabFont
        ]

        // ── Build one canonical item appearance ──────────────
        // Apply to BOTH stacked (icon+label) and inline (iPad).
        // titlePositionAdjustment = 0 prevents any vertical shift.
        func configure(_ item: UITabBarItemAppearance) {
            item.normal.iconColor         = normalIconColor
            item.selected.iconColor       = selectedIconColor
            item.normal.titleTextAttributes   = normalTitleAttr
            item.selected.titleTextAttributes = selectedTitleAttr
            // Zero out any position adjustments — this is the key fix
            item.normal.titlePositionAdjustment   = UIOffset(horizontal: 0, vertical: 0)
            item.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 0)
            item.normal.badgePositionAdjustment   = UIOffset(horizontal: 6, vertical: -4)
            item.selected.badgePositionAdjustment = UIOffset(horizontal: 6, vertical: -4)
        }

        configure(a.stackedLayoutAppearance)
        configure(a.inlineLayoutAppearance)
        configure(a.compactInlineLayoutAppearance)

        UITabBar.appearance().standardAppearance   = a
        UITabBar.appearance().scrollEdgeAppearance = a

        // ══════════════════════════════════════════════════════
        // NAVIGATION BAR — 全透明，标题完全隐藏（用 PageHeaderView）
        // ══════════════════════════════════════════════════════
        let nb = UINavigationBarAppearance()
        nb.configureWithTransparentBackground()
        nb.backgroundColor = .clear
        nb.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red:0.95, green:0.96, blue:0.98, alpha:0.0),
            .font: UIFont.systemFont(ofSize: 32, weight: .ultraLight)
        ]
        nb.titleTextAttributes = [
            .foregroundColor: UIColor(red:0.60, green:0.65, blue:0.74, alpha:0.0),
            .font: UIFont.systemFont(ofSize: 16, weight: .light)
        ]
        UINavigationBar.appearance().standardAppearance   = nb
        UINavigationBar.appearance().scrollEdgeAppearance = nb
        UINavigationBar.appearance().compactAppearance    = nb
    }
}

// ============================================================
// MARK: - 共用
// ============================================================

struct SectionLabel: View {
    let text:String;let icon:String
    init(_ t:String,icon:String){text=t;self.icon=icon}
    var body: some View {
        Label(text,systemImage:icon)
            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
            .foregroundColor(AppTheme.textTertiary.opacity(0.65))
            .kerning(1.2)
    }
}

// ============================================================
// MARK: - 目标页
// ============================================================

/// PreferenceKey for fold-mode card frame tracking
struct FoldCardFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// Tracks scroll offset of the goals list to drive calendar pinch
struct GoalsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct GoalsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @State private var currentMonth = Date()
    @State private var selectedDate: Date? = nil  // 初始化在 onAppear 用 store.today
    @State private var selectedGoalId: UUID? = nil
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal? = nil
    @State private var sharingGoal: Goal? = nil
    // 拖拽截止日
    @State private var draggingGoalId: UUID? = nil
    @State private var isDragging = false
    @State private var goalDragPos: CGPoint = .zero
    @State private var monthFlipTimer: Timer? = nil
    @State private var calendarFrame: CGRect = .zero

    var dayGoals: [Goal] { guard let d=selectedDate else{return[]}; return store.goals(for:d) }

    // Edge flip progress (0→1) shown as subtle arrow indicator
    @State private var edgeFlipProgress: CGFloat = 0
    @State private var edgeFlipDirection: Int = 0  // -1=left, 1=right, 0=none
    @State private var edgeFlipAccumTimer: Timer? = nil

    func checkEdgeFlip(pos: CGPoint) {
        guard isDragging, !calendarFrame.isEmpty else { return }
        let edge: CGFloat = 80                          // 56→80: wider trigger band
        let yTop    = calendarFrame.minY - 60           // extend 60pt above (includes header row)
        let yBottom = calendarFrame.maxY + 10           // slight bottom tolerance
        let inLeft  = pos.x < calendarFrame.minX + edge && pos.y > yTop && pos.y < yBottom
        let inRight = pos.x > calendarFrame.maxX - edge && pos.y > yTop && pos.y < yBottom

        if inLeft || inRight {
            let dir = inLeft ? -1 : 1
            if edgeFlipDirection != dir {
                // Direction changed — reset
                edgeFlipAccumTimer?.invalidate(); edgeFlipAccumTimer = nil
                withAnimation(.easeOut(duration:0.15)) { edgeFlipProgress = 0 }
                edgeFlipDirection = dir
            }
            guard monthFlipTimer == nil && edgeFlipAccumTimer == nil else { return }
            // Smoothly fill progress bar over 0.7s, then flip with crossfade
            let totalDuration: Double = 0.50          // 0.70→0.50: faster flip trigger
            let tickInterval: Double = 1.0/30.0
            let ticks = Int(totalDuration / tickInterval)
            var tick = 0
            edgeFlipAccumTimer = Timer.scheduledTimer(withTimeInterval:tickInterval, repeats:true) { t in
                tick += 1
                let progress = min(1.0, CGFloat(tick) / CGFloat(ticks))
                withAnimation(.linear(duration:tickInterval)) { edgeFlipProgress = progress }
                if tick >= ticks {
                    t.invalidate(); edgeFlipAccumTimer = nil
                    let cal = Calendar.current
                    withAnimation(.easeInOut(duration:0.32)) {
                        if dir < 0 {
                            if let p = cal.date(byAdding:.month,value:-1,to:currentMonth) { currentMonth=p }
                        } else {
                            if let n = cal.date(byAdding:.month,value:1,to:currentMonth) { currentMonth=n }
                        }
                    }
                    withAnimation(.easeOut(duration:0.2)) { edgeFlipProgress = 0 }
                    edgeFlipDirection = 0
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.35){ calendarFrame=calendarFrame }
                }
            }
        } else {
            // Left zone
            if edgeFlipDirection != 0 {
                edgeFlipAccumTimer?.invalidate(); edgeFlipAccumTimer = nil
                monthFlipTimer?.invalidate(); monthFlipTimer = nil
                withAnimation(.easeOut(duration:0.2)) { edgeFlipProgress = 0 }
                edgeFlipDirection = 0
            }
        }
    }

    /// How long the drag has been active — drives the card→pill morph animation
    @State private var dragMorphProgress: CGFloat = 0
    @State private var dragMorphTimer: Timer? = nil

    func startDragMorph() {
        dragMorphProgress = 0
        dragMorphTimer?.invalidate()
        // Animate from 0→1 over 0.38s (card morphs to pill)
        let start = Date()
        let duration: Double = 0.38
        dragMorphTimer = Timer.scheduledTimer(withTimeInterval:1/60.0, repeats:true) { t in
            let elapsed = Date().timeIntervalSince(start)
            let p = min(1, elapsed / duration)
            dragMorphProgress = CGFloat(p)
            if p >= 1 { t.invalidate(); dragMorphTimer = nil }
        }
    }
    func stopDragMorph() {
        dragMorphTimer?.invalidate(); dragMorphTimer = nil
        dragMorphProgress = 0
    }

    @ViewBuilder var floatingGoalCard: some View {
        if let gid=draggingGoalId, let goal=store.goals.first(where:{$0.id==gid}), goalDragPos != .zero {
            GeometryReader { geo in
                dragPill(goal:goal, pos:goalDragPos, containerFrame:geo.frame(in:.global))
            }
            .allowsHitTesting(false)
            .zIndex(999)
        }
    }

    /// Extracted to help Swift type-check; avoids opacity-chain ambiguity entirely
    @ViewBuilder func dragPill(goal:Goal, pos:CGPoint, containerFrame:CGRect) -> some View {
        let t: CGFloat = dragMorphProgress
        let hPad:      CGFloat = 12 - t * 2          // 12→10
        let vPad:      CGFloat = 9  - t * 4          // 9→5
        let corner:    CGFloat = 12 + t * 8          // 12→20
        let titleSize: CGFloat = 13 - t              // 13→12
        let shadowR:   CGFloat = 16 - t * 6          // 16→10
        let shadowY:   CGFloat = 6  + t * 2          // 6→8
        // Opacity baked into the Color itself — no chained .opacity() on shapes
        let bgAlpha: CGFloat   = 0.92 - t * 0.22
        let strokeAlpha: CGFloat = 0.35 + t * 0.05

        HStack(spacing:5) {
            Circle().fill(goal.color).frame(width:7, height:7)
            Text(goal.title)
                .font(.system(size:titleSize, weight:.semibold))
                .foregroundColor(AppTheme.textPrimary.opacity(0.82))
                .lineLimit(1)
            if t < 0.6 {
                Image(systemName:"calendar.badge.clock")
                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(Double(1 - t/0.6)))
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(
            ZStack {
                // Glass base
                RoundedRectangle(cornerRadius:corner).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius:corner).fill(AppTheme.bg0.opacity(Double(bgAlpha) * 0.88))
                // Specular sheen
                RoundedRectangle(cornerRadius:corner)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading, endPoint: .center
                    ))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius:corner))
        .overlay(
            RoundedRectangle(cornerRadius:corner)
                .strokeBorder(goal.color.opacity(Double(strokeAlpha) * 1.1), lineWidth:1.0)
        )
        // Double neon glow: inner tight + outer diffuse
        .shadow(color:goal.color.opacity(0.45), radius:4, x:0, y:0)
        .shadow(color:goal.color.opacity(0.22), radius:shadowR, x:0, y:shadowY)
        .fixedSize()
        .position(
            x: pos.x - containerFrame.minX,
            y: pos.y - containerFrame.minY - 32
        )
    }

    @State private var goalsScrollProxy: ScrollViewProxy? = nil
    @State private var autoScrollTimer: Timer? = nil
    @State private var goalsScreenHeight: CGFloat = 0
    @State private var goalDisplayOrder: [UUID] = []  // 目标排列顺序（可拖拽调整）
    @State private var isReordering = false  // 排序/折叠模式开关
    @State private var cardFrames: [UUID: CGRect] = [:]  // 折叠模式各卡片 frame（全局坐标）
    @State private var draggingFoldId: UUID? = nil       // 正在拖的卡片 ID
    @State private var draggingOffset: CGFloat = 0       // 被拖卡片的视觉 Y 偏移
    @State private var draggingAbsPos: CGPoint = .zero   // 被拖卡片浮动副本的绝对位置
    @State private var foldListOrigin: CGPoint = .zero   // 折叠列表容器的全局原点
    @State private var frozenOrder: [UUID] = []          // 拖拽开始时冻结的顺序（不在拖拽中变化）
    @State private var dragTargetIdx: Int = -1           // 当前目标插入位置（-1=无）
    @State private var draggingGoalSnapshot: Goal? = nil // 被拖卡片的数据快照（用于浮动渲染）

    func checkVerticalAutoScroll(pos: CGPoint) {
        guard isDragging else { return }
        // Use dynamic calendarCurrentH + a little buffer
        let topEdge: CGFloat = calendarCurrentH + 40
        if pos.y < topEdge {
            guard autoScrollTimer == nil else { return }
            autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
                withAnimation(.linear(duration: 0.04)) {
                    self.goalsScrollProxy?.scrollTo("goals_top", anchor: .top)
                }
            }
        } else {
            autoScrollTimer?.invalidate(); autoScrollTimer = nil
        }
    }

    // ── Calendar fold state: month ↔ week strip ──────────────
    // calendarProgress: 0.0 = full month view,  1.0 = week strip only
    // Driven continuously by ScrollView offset — silk-smooth
    @State private var calendarProgress: CGFloat = 0
    @State private var showMonthPicker = false   // lifted here so picker escapes .clipped()
    // Height geometry (all in pts):
    //   Nav bar: 44 fixed
    //   Month body: weekday-header(18) + 6×row(28) + 6×spacing(2) + bottom(4) = 190
    //   Week body: single row (28) + top(3) + bottom(3) = 34
    let calNavH:       CGFloat = 44
    // Month body = weekdayHeader(20) + 6rows×28 + 5gaps×2 + bottom padding(4) = 202
    let calMonthBodyH: CGFloat = 202
    // Week body = 1 row(28) + bottom padding(4) = 32
    let calWeekBodyH:  CGFloat = 32
    // Interpolated body height (month body → week body)
    var calBodyH: CGFloat { calMonthBodyH + (calWeekBodyH - calMonthBodyH) * calendarProgress }
    var calendarCurrentH: CGFloat { calNavH + calBodyH }
    var contentTopPad: CGFloat { calendarCurrentH }

    @ViewBuilder var goalsMainContent: some View {
        GeometryReader { rootGeo in
            ZStack(alignment: .top) {

                // ── LAYER A: Scrollable content (goals sit inside) ──
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        // Offset anchor — at the very top of the scroll content
                        GeometryReader { anchorGeo in
                            Color.clear.preference(
                                key: GoalsScrollOffsetKey.self,
                                value: anchorGeo.frame(in: .named("goalsPage")).minY
                            )
                        }
                        .frame(height: 0)

                        // Dynamic spacer matching current calendar height
                        VStack(spacing: 0) {
                            Color.clear.frame(height: contentTopPad + 8)
                            goalsListSection
                        }
                    }
                }
                .coordinateSpace(name: "goalsPage")
                .onPreferenceChange(GoalsScrollOffsetKey.self) { rawOffset in
                    // rawOffset = 0 at top, goes negative as user scrolls DOWN
                    // Guard: never collapse while dragging goal or reordering
                    guard !isDragging, !isReordering else { return }
                    let scrolled = max(0, -rawOffset)
                    // Month→week fold: starts at 44pt scroll, completes at 160pt
                    let trigger: CGFloat = 44
                    let range:   CGFloat = 140
                    let progress = max(0, min(1, (scrolled - trigger) / range))
                    // Smooth spring only when change is non-trivial (avoids jitter)
                    if abs(progress - calendarProgress) > 0.008 {
                        withAnimation(.interactiveSpring(response: 0.30, dampingFraction: 0.92)) {
                            calendarProgress = progress
                        }
                    }
                }

                // ── LAYER B: Calendar sticky header (always on top) ──
                calendarHeaderView
                    .frame(height: calendarCurrentH, alignment: .top)
                    .clipped()
                    .background(
                        ZStack {
                            // Deep silicon base
                            Rectangle().fill(AppTheme.bg0)
                            // Frosted glass film — intensifies as calendar folds
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .opacity(AppTheme.glassBase + calendarProgress * 0.35)
                            // Top-left specular micro-sheen
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [Color.white.opacity(0.038), Color.clear],
                                    startPoint: .topLeading, endPoint: .center
                                ))
                            // Neon top edge — accent+cyberBlue dual-tone glow
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        AppTheme.accent.opacity(0.50 - calendarProgress * 0.20),
                                        AppTheme.cyberBlue.opacity(0.18 - calendarProgress * 0.08),
                                        Color.clear
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .frame(height: 0.8)
                                Spacer()
                            }
                            // Scan-line depth texture
                            ScanlineOverlay(cornerRadius: 0)
                                .opacity(AppTheme.scanlineOpacity * (1.0 - calendarProgress * 0.6))
                        }
                    )
                    // Bottom shadow — deeper when week-strip (more separation from content)
                    .shadow(color: AppTheme.accent.opacity(0.04 + calendarProgress * 0.06), radius: 8, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.28 + calendarProgress * 0.14), radius: 14, x: 0, y: 5)
                    .zIndex(100)

                // ── LAYER C: Floating goal drag pill ──
                floatingGoalCard.zIndex(999)

                // ── LAYER D: Month/Year picker floats ABOVE .clipped() calendar ──
                if showMonthPicker {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response:0.26)) { showMonthPicker = false } }
                        .zIndex(490)
                    VStack(spacing:0) {
                        Spacer().frame(height: calNavH + 6)
                        YearMonthWheelPicker(
                            currentMonth: $currentMonth,
                            onDismiss: { withAnimation(.spring(response:0.26)) { showMonthPicker = false } }
                        )
                        .environmentObject(store)
                        .padding(.horizontal, 16)
                        Spacer()
                    }
                    .zIndex(500)
                    .transition(.opacity.combined(with:.move(edge:.top)))
                }
            }
            .animation(.spring(response:0.28), value: showMonthPicker)
            .onAppear { goalsScreenHeight = rootGeo.size.height }
            .onDisappear {
                // Cleanup all timers to prevent memory leaks
                monthFlipTimer?.invalidate(); monthFlipTimer = nil
                edgeFlipAccumTimer?.invalidate(); edgeFlipAccumTimer = nil
                dragMorphTimer?.invalidate(); dragMorphTimer = nil
                autoScrollTimer?.invalidate(); autoScrollTimer = nil
            }
        }
    }

    // ── Calendar header: month ↔ week fold (silk-smooth) ────
    // Architecture:
    //   - Nav bar (44pt): always visible, never clips
    //   - Calendar body: clips from bottom as calendarProgress → 1.0
    //     Progress=0: full 6-row month,  Progress=1: 1-row week strip
    //   - Week strip: selectedDate's row floats into view
    //   - Swipe ‹/›: progress<0.5 = month flip; progress≥0.5 = week advance
    @ViewBuilder var calendarHeaderView: some View {
        let isWeekMode = calendarProgress > 0.65

        VStack(spacing: 0) {
            // ───────────────────────────────────────────────
            // NAV BAR  (44pt, always on top)
            // [‹]  [MONTH YEAR ˅]  [›]  [●]
            // ───────────────────────────────────────────────
            // ZStack: title absolutely centered, nav/pill overlaid on sides
            ZStack(alignment: .center) {
                // ── Centered title — absolutely centered by ZStack ──
                VStack(spacing: 1) {
                    MonthYearPicker(currentMonth: $currentMonth, showingPicker: $showMonthPicker)
                    if isWeekMode, let d = selectedDate {
                        let wk = Calendar.current.component(.weekOfMonth, from: d)
                        Text("\(store.t(key: L10n.weekLabel)) \(wk)")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.accent.opacity(0.55))
                            .opacity((calendarProgress - 0.65) / 0.35)
                    }
                }
                .frame(maxWidth: 220)  // constrain so side buttons don't push it
                .allowsHitTesting(true)

                // ── Left / right controls ──
                HStack(spacing: 0) {
                    // ‹ Prev
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            if isWeekMode {
                                if let d = selectedDate,
                                   let prev = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: d) {
                                    selectedDate = prev
                                    let m = Calendar.current.dateComponents([.year, .month], from: prev)
                                    if let nm = Calendar.current.date(from: m) { currentMonth = nm }
                                }
                            } else {
                                if let p = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) { currentMonth = p }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.65))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Spacer()

                    // › Next
                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            if isWeekMode {
                                if let d = selectedDate,
                                   let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: d) {
                                    selectedDate = next
                                    let m = Calendar.current.dateComponents([.year, .month], from: next)
                                    if let nm = Calendar.current.date(from: m) { currentMonth = nm }
                                }
                            } else {
                                if let n = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) { currentMonth = n }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.65))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    // Expand/collapse pill — right of › button
                    Button {
                        withAnimation(.spring(response: 0.40, dampingFraction: 0.80)) {
                            calendarProgress = isWeekMode ? 0 : 1
                        }
                    } label: {
                        ZStack {
                            Capsule()
                                .fill(isWeekMode ? AppTheme.accent.opacity(0.18) : Color.white.opacity(0.04))
                                .frame(width: 26, height: 19)
                                .overlay(Capsule().stroke(
                                    isWeekMode ? AppTheme.accent.opacity(0.45) : Color.white.opacity(0.08),
                                    lineWidth: 0.6))
                            Image(systemName: isWeekMode ? "chevron.down" : "chevron.up")
                                .font(.system(size: 7.5, weight: .medium))
                                .foregroundColor(isWeekMode ? AppTheme.accent : AppTheme.textTertiary.opacity(0.55))
                                .shadow(color: isWeekMode ? AppTheme.accent.opacity(0.30) : .clear, radius: 3)
                        }
                    }
                    .padding(.trailing, 13)
                }
            }
            .frame(height: 44)

            // Neon hairline divider
            LinearGradient(
                colors: [Color.clear,
                         AppTheme.accent.opacity(0.14 + calendarProgress * 0.08),
                         AppTheme.cyberBlue.opacity(0.10 + calendarProgress * 0.05),
                         Color.clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 0.6)

            // ───────────────────────────────────────────────
            // CALENDAR BODY  (clips smoothly as progress → 1)
            // CalendarGrid renders full month; we clip from below
            // ───────────────────────────────────────────────
            ZStack(alignment: .top) {
                CalendarFoldGrid(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    selectedGoalId: selectedGoalId,
                    store: store,
                    draggingGoalId: draggingGoalId,
                    onDropGoal: { id, date in
                        let todayStart = Calendar.current.startOfDay(for: store.today)
                        let target     = Calendar.current.startOfDay(for: date)
                        if target >= todayStart { store.setGoalDeadline(id, to: date) }
                        monthFlipTimer?.invalidate(); monthFlipTimer = nil
                        autoScrollTimer?.invalidate(); autoScrollTimer = nil
                        stopDragMorph()
                        draggingGoalId = nil; isDragging = false; goalDragPos = .zero
                    },
                    dragScreenPos: goalDragPos,
                    foldProgress: calendarProgress
                )
                .background(
                    GeometryReader { cGeo in
                        Color.clear
                            .onAppear  { calendarFrame = cGeo.frame(in: .global) }
                            .onChange(of: cGeo.frame(in: .global)) { _, f in calendarFrame = f }
                    }
                )
                .frame(height: calBodyH)
                .clipped()

                // Drag-to-date floating hint
                if isDragging {
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            if edgeFlipProgress > 0 && edgeFlipDirection < 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "chevron.left").font(.system(size: 7, weight: .bold))
                                    Capsule().fill(AppTheme.accent).frame(width: 16 * edgeFlipProgress, height: 1.5)
                                }
                                .foregroundColor(AppTheme.accent.opacity(0.55 + edgeFlipProgress * 0.45))
                            }
                            Image(systemName: "calendar.badge.checkmark").font(.system(size: 9))
                            Text(store.t(key: L10n.dragToDate))
                                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                            if edgeFlipProgress > 0 && edgeFlipDirection > 0 {
                                HStack(spacing: 2) {
                                    Capsule().fill(AppTheme.accent).frame(width: 16 * edgeFlipProgress, height: 1.5)
                                    Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold))
                                }
                                .foregroundColor(AppTheme.accent.opacity(0.55 + edgeFlipProgress * 0.45))
                            }
                        }
                        .foregroundColor(AppTheme.accent.opacity(0.80))
                        .padding(.bottom, 5)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 3)
            .padding(.bottom, 4)
        }
        // Swipe left/right: month flip or week advance depending on mode
        .gesture(
            DragGesture(minimumDistance: 36, coordinateSpace: .local)
                .onEnded { v in
                    guard !isDragging else { return }
                    guard abs(v.translation.width) > abs(v.translation.height) * 1.4 else { return }
                    let goForward = v.translation.width < 0
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        if isWeekMode {
                            let delta = goForward ? 1 : -1
                            if let d = selectedDate,
                               let next = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: d) {
                                selectedDate = next
                                let m = Calendar.current.dateComponents([.year,.month], from: next)
                                if let nm = Calendar.current.date(from: m) { currentMonth = nm }
                            }
                        } else {
                            let delta = goForward ? 1 : -1
                            if let nm = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) { currentMonth = nm }
                        }
                    }
                }
        )
    }

    @ViewBuilder var goalsListSection: some View {
        let atLimit = !pro.isPro && store.goals.count >= ProStore.freeGoalLimit
        Button(action: {
            if atLimit { pro.showPaywall = true } else { showingAddGoal = true }
        }) {
            HStack(spacing: 6) {
                Image(systemName: atLimit ? "lock.fill" : "plus")
                    .font(.system(size: 10, weight: .medium))
                Text(atLimit
                    ? store.t(key: L10n.upgradeLimit)
                    : store.t(key: L10n.addGoalLabel))
                    .font(.system(size: 11.5, weight: .regular, design: .rounded))
                    .tracking(0.8)
            }
            .foregroundColor(atLimit ? AppTheme.gold.opacity(0.80) : AppTheme.accent.opacity(0.60))
            .shadow(color: atLimit ? AppTheme.gold.opacity(0.20) : AppTheme.accent.opacity(0.25), radius: 4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(AppTheme.bg1)
                    RoundedRectangle(cornerRadius: 11)
                        .fill(.ultraThinMaterial).opacity(0.12)
                    RoundedRectangle(cornerRadius: 11)
                        .fill(atLimit ? AppTheme.gold.opacity(0.05) : AppTheme.accent.opacity(0.04))
                    // Dashed neon border drawn via stroke (no separate overlay needed)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(
                        atLimit ? AppTheme.gold.opacity(0.25) : AppTheme.accent.opacity(0.22),
                        style: StrokeStyle(lineWidth: 0.7, dash: [4, 3])
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        if let date=selectedDate { goalDaySection(date:date) }
    }

    // 根据 goalDisplayOrder 排列 dayGoals
    func orderedDayGoals(date: Date) -> [Goal] {
        let goals = store.goals(for: date)
        if goalDisplayOrder.isEmpty { return goals }
        let sorted = goalDisplayOrder.compactMap { id in goals.first(where:{ $0.id == id }) }
        let unsorted = goals.filter { g in !goalDisplayOrder.contains(g.id) }
        return sorted + unsorted
    }

    @ViewBuilder func goalDaySection(date: Date) -> some View {
        let ordered = orderedDayGoals(date: date)
        VStack(alignment:.leading,spacing:0) {
            HStack {
                Text(formatDate(date, format: {
                        switch store.language {
                        case .chinese:  return "M月d日 EEEE"
                        case .japanese: return "M月d日 EEEE"
                        case .korean:   return "M월 d일 EEEE"
                        case .english:  return "EEE, MMM d"
                        case .spanish:  return "EEE, d MMM"
                        }
                    }(), lang: store.language))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.70))
                    .tracking(0.3)
                Spacer()
                // 排序按钮（紧靠目标区块）
                Button(action:{
                    withAnimation(.spring(response:0.45, dampingFraction:0.82)){
                        isReordering.toggle()
                        // Initialize display order from current visible goals when entering sort mode
                        if isReordering && goalDisplayOrder.isEmpty {
                            goalDisplayOrder = ordered.map { $0.id }
                        }
                    }
                }) {
                    HStack(spacing:3) {
                        Image(systemName: isReordering ? "checkmark.circle.fill" : "arrow.up.arrow.down")
                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        Text(isReordering ? store.t(key: L10n.done) : store.t(key: L10n.sort))
                            .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                    }
                    .foregroundColor(isReordering ? AppTheme.accent : AppTheme.textTertiary)
                    .padding(.horizontal,8).padding(.vertical,4)
                    .background(isReordering ? AppTheme.accent.opacity(0.1) : AppTheme.bg2)
                    .cornerRadius(7)
                    .animation(.spring(response:0.28), value:isReordering)
                }
                Text(L10n.goalsCount(ordered.count, store.language))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
            }.padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 5)
            if ordered.isEmpty {
                Text(store.t(key: L10n.noGoalsDay))
                    .font(.subheadline).foregroundColor(AppTheme.textTertiary)
                    .frame(maxWidth:.infinity).padding(.vertical,28)
            } else if isReordering {
                // ── 折叠模式：named coord space + 浮动副本 overlay ──
                // stableOrder: use goalDisplayOrder if it contains at least the current goals
                let stableOrder: [UUID] = {
                    let orderedIds = ordered.map { $0.id }
                    if goalDisplayOrder.isEmpty { return orderedIds }
                    // Merge: keep custom order for known IDs, append any new goals at end
                    let known = goalDisplayOrder.filter { id in orderedIds.contains(id) }
                    let new = orderedIds.filter { id in !goalDisplayOrder.contains(id) }
                    return known + new
                }()
                let stableGoals = stableOrder.compactMap { id in ordered.first(where:{ $0.id == id }) }

                ZStack(alignment:.topLeading) {
                    // ── 列表层 ──
                    VStack(spacing:8) {
                        Color.clear.frame(height:8)
                        ForEach(stableGoals) { goal in
                            let isDraggingThis = draggingFoldId == goal.id
                            // Drop target indicator — thin accent line above this card
                            let showDropIndicator: Bool = {
                                guard draggingFoldId != nil, let fromIdx = frozenOrder.firstIndex(of: draggingFoldId!),
                                      let thisIdx = frozenOrder.firstIndex(of: goal.id) else { return false }
                                return dragTargetIdx == thisIdx && thisIdx != fromIdx && thisIdx != fromIdx + 1
                            }()
                            VStack(spacing:0) {
                                if showDropIndicator {
                                    Capsule()
                                        .fill(AppTheme.accent.opacity(0.55))
                                        .frame(height:2)
                                        .padding(.horizontal,16)
                                        .transition(.opacity)
                                }
                                foldCardRow(goal:goal, pct:store.goalProgress(for:goal,on:date), isDragging:false)
                            }
                            // 被拖时原位占位透明
                            .opacity(isDraggingThis ? 0.15 : 1.0)
                                // 在折叠列表坐标系里记录每张卡片的 frame
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key:FoldCardFrameKey.self,
                                        value:[goal.id: geo.frame(in:.named("foldList"))])
                                })
                                .gesture(DragGesture(minimumDistance:6, coordinateSpace:.named("foldList"))
                                    .onChanged { val in
                                        if draggingFoldId != goal.id {
                                            frozenOrder = stableOrder
                                            draggingFoldId = goal.id
                                            draggingGoalSnapshot = goal
                                        }
                                        draggingOffset = val.translation.height
                                        // 找最近的插入位置
                                        let dragY = val.location.y
                                        var best = frozenOrder.count
                                        var bestDist = CGFloat.infinity
                                        for (i, id) in frozenOrder.enumerated() where id != goal.id {
                                            if let f = cardFrames[id] {
                                                let d = abs(dragY - f.midY)
                                                if d < bestDist { bestDist = d; best = i }
                                            }
                                        }
                                        // 拖过最后一张下方→放最后
                                        if let lastId = frozenOrder.last(where:{ $0 != goal.id }),
                                           let lastF = cardFrames[lastId], dragY > lastF.maxY {
                                            best = frozenOrder.count
                                        }
                                        dragTargetIdx = best
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response:0.3, dampingFraction:0.82)) {
                                            if draggingFoldId != nil {
                                                var order = frozenOrder
                                                guard let fromIdx = order.firstIndex(of: goal.id) else {
                                                    draggingFoldId = nil; draggingGoalSnapshot = nil
                                                    draggingOffset = 0; dragTargetIdx = -1; frozenOrder = []
                                                    return
                                                }
                                                // Proper splice: remove first, then insert at adjusted idx
                                                let targetIdx = max(0, min(dragTargetIdx, order.count - 1))
                                                order.remove(at: fromIdx)
                                                let insertAt = max(0, min(targetIdx, order.count))
                                                order.insert(goal.id, at: insertAt)
                                                goalDisplayOrder = order
                                            }
                                        }
                                        // Haptic
                                        let gen = UIImpactFeedbackGenerator(style: .light)
                                        gen.impactOccurred()
                                        draggingFoldId = nil
                                        draggingGoalSnapshot = nil
                                        draggingOffset = 0
                                        dragTargetIdx = -1
                                        frozenOrder = []
                                    }
                                )
                        }
                        Color.clear.frame(height:8)
                    }
                    .padding(.horizontal)
                    .coordinateSpace(name:"foldList")
                    .onPreferenceChange(FoldCardFrameKey.self) { frames in
                        // 只在非拖拽时更新 cardFrames，避免位移
                        if draggingFoldId == nil {
                            for (id, f) in frames { cardFrames[id] = f }
                        }
                    }

                    // ── 浮动副本（在 ZStack 最上层，不受列表遮挡）──
                    if let floatGoal = draggingGoalSnapshot,
                       let originFrame = cardFrames[floatGoal.id] {
                        foldCardRow(goal:floatGoal, pct:store.goalProgress(for:floatGoal,on:date), isDragging:true)
                            .padding(.horizontal)
                            .shadow(color:floatGoal.color.opacity(0.28), radius:12, x:0, y:6)
                            .scaleEffect(1.03)
                            // 浮动位置 = 原始位置 + 拖拽偏移
                            .offset(y: originFrame.minY + draggingOffset)
                            .allowsHitTesting(false)
                            .animation(nil, value:draggingOffset)
                    }
                }
            } else {
                ForEach(ordered) { goal in
                    DayGoalCard(goal:goal, date:date,
                        isHighlighted: selectedGoalId==goal.id,
                        isDragging: draggingGoalId==goal.id,
                        onSingleTap:{
                            withAnimation(.spring(response:0.3)){
                                selectedGoalId = selectedGoalId==goal.id ? nil : goal.id
                            }
                            // 不强制 scrollTo，避免锁死 ScrollView 手势
                        },
                        onDoubleTap:{ editingGoal=goal },
                        // 左侧竖条拖拽 → 改截止日（日历翻页联动）
                        onDragChanged:{ pos in
                            if draggingGoalId==nil { withAnimation(.spring(response:0.2)){ draggingGoalId=goal.id; isDragging=true }; startDragMorph() }
                            goalDragPos=pos
                            checkEdgeFlip(pos:pos)
                            checkVerticalAutoScroll(pos:pos)
                        },
                        onDragEnded:{
                            monthFlipTimer?.invalidate(); monthFlipTimer=nil
                            autoScrollTimer?.invalidate(); autoScrollTimer=nil
                            DispatchQueue.main.asyncAfter(deadline:.now()+0.1){
                                if draggingGoalId != nil { stopDragMorph(); withAnimation(.spring(response:0.25)){ draggingGoalId=nil; isDragging=false; goalDragPos = .zero } }
                            }
                        },
                        onShare:{ pro.requirePlus{ sharingGoal=goal } },
                        onDelete:{ store.deleteGoal(goal) }
                        // 普通模式无长按排序，避免手势冲突影响滑动
                    )
                    .id(goal.id)
                    .padding(.horizontal, 12).padding(.bottom, 5)
                    .scaleEffect(selectedGoalId != nil && selectedGoalId != goal.id ? 0.97 : 1.0)
                    .animation(.spring(response:0.3), value:selectedGoalId)
                    .transition(.asymmetric(
                        insertion:.scale(scale:0.96).combined(with:.opacity),
                        removal:.scale(scale:0.96).combined(with:.opacity)
                    ))
                }
            }
        }.padding(.bottom,30)
    }

    // 折叠模式排序现在完全在 gesture 内处理（frozenOrder + offset），这些函数不再需要
    func reorderGoalIfNeeded(dragId: UUID, pos: CGPoint, ordered: [Goal]) {}

    /// 折叠模式卡片行（列表占位 + 浮动副本共用同一外观）
    @ViewBuilder func foldCardRow(goal: Goal, pct: Double, isDragging: Bool) -> some View {
        HStack(spacing:12) {
            // Goal color accent bar (Monet style — slim, elegant)
            RoundedRectangle(cornerRadius:2)
                .fill(goal.color.opacity(isDragging ? 0.9 : 0.55))
                .frame(width:3, height:32)

            // Radial progress ring — compact
            ZStack {
                Circle()
                    .stroke(AppTheme.bg3, lineWidth: 1.5)
                    .frame(width:22, height:22)
                Circle()
                    .trim(from:0, to: CGFloat(pct))
                    .stroke(goal.color, style:StrokeStyle(lineWidth:2, lineCap:.round))
                    .frame(width:22, height:22)
                    .rotationEffect(.degrees(-90))
            }
            .scaleEffect(isDragging ? 1.08 : 1.0)

            VStack(alignment:.leading, spacing:2) {
                Text(goal.title)
                    .font(.system(size:DSTSize.label, weight:.medium, design:.rounded))
                    .foregroundColor(isDragging ? AppTheme.textPrimary : AppTheme.textPrimary.opacity(0.88))
                    .lineLimit(1)
                HStack(spacing:4) {
                    Text("\(Int(pct*100))%")
                        .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                        .foregroundColor(goal.color.opacity(0.8))
                        .monospacedDigit()
                    Text("·").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    Text(goal.category)
                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            Spacer()

            // Drag handle — three dots (more Apple-like than lines)
            VStack(spacing:3) {
                ForEach(0..<3, id:\.self) { _ in
                    Circle()
                        .fill(isDragging ? goal.color.opacity(0.7) : AppTheme.textTertiary.opacity(0.35))
                        .frame(width:3, height:3)
                }
            }
            .padding(.trailing,2)
        }
        .padding(.horizontal,12).padding(.vertical,9)
        .background(
            RoundedRectangle(cornerRadius:13)
                .fill(AppTheme.bg1)
                .shadow(color: isDragging ? goal.color.opacity(0.20) : .clear,
                        radius: 10, x:0, y:5)
        )
        .overlay(
            RoundedRectangle(cornerRadius:13)
                .stroke(
                    isDragging ? goal.color.opacity(0.45) : AppTheme.border0,
                    lineWidth: isDragging ? 1.2 : 0.8
                )
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.spring(response:0.25, dampingFraction:0.75), value:isDragging)
    }

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                goalsMainContent
                    .onAppear { goalsScreenHeight = geo.size.height }
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.principal) {
                    GlassImprintTitle(text: store.t(key: L10n.goals), fontSize: 20)
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(action:{
                        withAnimation(.spring(response:0.35)){
                            currentMonth=store.today; selectedDate=store.today
                        }
                    }) {
                        HStack(spacing:4){
                            Image(systemName:"calendar.circle")
                            Text(store.t(key: L10n.today)).font(.subheadline)
                        }.foregroundColor(AppTheme.accent)
                    }
                }
            }
            .sheet(isPresented:$showingAddGoal){ GoalEditSheet(goal:nil, defaultDate:store.today){store.addGoal($0)}.environmentObject(store).environmentObject(pro) }
            .sheet(item:$editingGoal){ g in GoalEditSheet(goal:g){store.updateGoal($0)}.environmentObject(store).environmentObject(pro) }
            .sheet(item:$sharingGoal){ g in ShareSheet(goal:g).environmentObject(store).environmentObject(pro) }
            .onAppear{
                currentMonth = store.today
                selectedDate = store.today
            }
            .onChange(of: store.simulatedDate) { _, _ in
                currentMonth = store.today
                selectedDate = store.today
            }
            // 新增目标后刷新选中日的目标列表
            .onChange(of: store.goals.count) { _, _ in
                if selectedDate == nil { selectedDate = store.today }
            }
        }
        .animation(.easeInOut(duration:0.2),value:isDragging)
    }
}

// ── 月份选择 ──────────────────────────────────────────────

struct MonthYearPicker: View {
    @Binding var currentMonth: Date
    @Binding var showingPicker: Bool   // Lifted to GoalsView — escapes .clipped() calendar header
    @EnvironmentObject var store: AppStore

    var displayString: String {
        let f = DateFormatter()
        switch store.language {
        case .chinese, .japanese, .korean: f.dateFormat = "yyyy年 M月"
        case .english, .spanish:           f.dateFormat = "MMMM yyyy"
        }
        f.locale = Locale(identifier: store.language.localeIdentifier)
        return f.string(from: currentMonth)
    }

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.26)) { showingPicker.toggle() } }) {
            HStack(spacing: 5) {
                Text(displayString)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                    .tracking(0.2)
                    .shadow(color: AppTheme.accent.opacity(0.18), radius: 4, x: 0, y: 0)
                Image(systemName: showingPicker ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AppTheme.accent.opacity(0.50))
                    .shadow(color: AppTheme.accent.opacity(0.25), radius: 2, x: 0, y: 0)
            }
        }
    }
    func shift(_ d: Int) {
        if let n = Calendar.current.date(byAdding: .month, value: d, to: currentMonth) { currentMonth = n }
    }
}

struct YearMonthWheelPicker: View {
    @Binding var currentMonth:Date
    @EnvironmentObject var store:AppStore
    let onDismiss:()->Void
    @State private var sy:Int;@State private var sm:Int
    init(currentMonth:Binding<Date>,onDismiss:@escaping()->Void){
        _currentMonth=currentMonth;self.onDismiss=onDismiss
        let c=Calendar.current
        _sy=State(initialValue:c.component(.year,from:currentMonth.wrappedValue))
        _sm=State(initialValue:c.component(.month,from:currentMonth.wrappedValue))
    }
    var body: some View {
        VStack(spacing:10){
            // Header with explicit cancel button
            HStack {
                Text(store.t(zh:"选择月份", en:"Select Month", ja:"月を選択", ko:"월 선택", es:"Seleccionar mes"))
                    .font(.system(size:DSTSize.caption, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName:"xmark.circle.fill")
                        .font(.system(size:DSTSize.titleCard, weight:.light, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.6))
                }
            }
            HStack(spacing:0){
                Picker("",selection:$sy){ ForEach(2024...2035,id:\.self){ Text(store.language == .chinese || store.language == .japanese || store.language == .korean ? "\($0)年":"\($0)").tag($0) } }.pickerStyle(.wheel).frame(maxWidth:.infinity).clipped()
                Picker("",selection:$sm){ ForEach(1...12,id:\.self){ m in Text(store.language == .chinese || store.language == .japanese || store.language == .korean ? "\(m)月":Calendar.current.monthSymbols[m-1]).tag(m) } }.pickerStyle(.wheel).frame(maxWidth:.infinity).clipped()
            }.frame(height:130)
            // Cancel + Confirm row
            HStack(spacing:8) {
                Button(store.t(zh:"取消", en:"Cancel", ja:"キャンセル", ko:"취소", es:"Cancelar")) { onDismiss() }
                    .frame(maxWidth:.infinity).padding(.vertical,11)
                    .background(AppTheme.bg3).foregroundColor(AppTheme.textSecondary)
                    .cornerRadius(10).overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border1,lineWidth:1))
                Button(store.t(key: L10n.confirm)){
                    var c=DateComponents();c.year=sy;c.month=sm;c.day=1
                    if let d=Calendar.current.date(from:c){currentMonth=d}
                    onDismiss()
                }.frame(maxWidth:.infinity).padding(.vertical,11).background(AppTheme.accent).cornerRadius(10).foregroundColor(AppTheme.bg0).fontWeight(.semibold)
            }
        }
        .padding(16).background(AppTheme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16).stroke(AppTheme.border1,lineWidth:1))
        .shadow(color:.black.opacity(0.4), radius:24, x:0, y:8)
        // Swipe down = cancel
        .gesture(DragGesture(minimumDistance:24).onEnded{ v in if v.translation.height > 24 { onDismiss() } })
    }
}

// ── 日历 ──────────────────────────────────────────────────

/// CalendarFoldGrid: renders the full month but animates rows to collapse
/// into a single-row "week strip" as foldProgress goes 0→1.
///
/// Architecture:
///   foldProgress=0: normal CalendarGrid  (all rows full-opacity, normal position)
///   foldProgress=1: only selectedDate row visible, rows above/below slide away
///
/// This is achieved by:
///   1. Computing which "week row" (0-5) contains selectedDate
///   2. Rows above that row: translate up by (rowIndex / totalRows) * foldProgress * totalOffsetNeeded
///   3. Rows below that row: translate down similarly
///   4. All other rows fade to opacity 0 at foldProgress=1
///   5. The entire VStack clips to calBodyH (set by parent)

struct CalendarFoldGrid: View {
    let currentMonth: Date
    @Binding var selectedDate: Date?
    let selectedGoalId: UUID?
    let store: AppStore
    let draggingGoalId: UUID?
    let onDropGoal: (UUID, Date) -> Void
    var dragScreenPos: CGPoint = .zero
    var foldProgress: CGFloat = 0

    @EnvironmentObject var storeEnv: AppStore
    let cols = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var weekdays: [String] { L10n.weekdayShort(storeEnv.language) }

    /// All date cells for the month, grouped by week row
    var weekRows: [[Date?]] {
        let cal = Calendar.current
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: currentMonth)) else { return [] }
        let offset = cal.component(.weekday, from: first) - 1
        let range = cal.range(of: .day, in: .month, for: currentMonth)!
        var flat: [Date?] = Array(repeating: nil, count: offset)
        for d in range { flat.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        // Pad to multiple of 7
        while flat.count % 7 != 0 { flat.append(nil) }
        // Split into rows
        return stride(from: 0, to: flat.count, by: 7).map { Array(flat[$0..<min($0+7, flat.count)]) }
    }

    /// Which row index (0-5) contains the selectedDate (or today as fallback)
    var activeRowIdx: Int {
        let anchor = selectedDate ?? Date()
        let cal = Calendar.current
        for (i, row) in weekRows.enumerated() {
            if row.contains(where: { d in d.map { cal.isDate($0, inSameDayAs: anchor) } ?? false }) {
                return i
            }
        }
        return 0
    }

    func dotColor(for date: Date) -> Color? {
        if let gid = selectedGoalId, let goal = store.goals.first(where: { $0.id == gid }) {
            return goal.covers(date) ? goal.color : nil
        }
        let covering = store.goals.filter { $0.covers(date) }
        guard !covering.isEmpty else { return nil }
        return covering[0].color.opacity(0.85)
    }

    var body: some View {
        let rows = weekRows
        let activeRow = activeRowIdx
        let rowH: CGFloat = 28
        let rowSpacing: CGFloat = 2
        let headerH: CGFloat = 20  // weekday header height including bottom pad

        // How far the VStack must shift up so that the active row sits at y=0 of the clip frame.
        // activeRow's top is at: headerH + activeRow * (rowH + rowSpacing)
        let activeRowTop = headerH + CGFloat(activeRow) * (rowH + rowSpacing)
        // Apply proportionally: at foldProgress=0 no shift, at 1.0 full shift
        let vStackShift = -activeRowTop * foldProgress

        VStack(spacing: 0) {
            // Weekday header — fades as we fold to week strip
            HStack(spacing: 0) {
                ForEach(Array(zip(weekdays.indices, weekdays)), id: \.0) { idx, day in
                    let isTodayCol: Bool = Calendar.current.component(.weekday, from: Date()) - 1 == idx
                    Text(day)
                        .font(.system(size: 10, weight: isTodayCol ? .medium : .regular, design: .rounded))
                        .foregroundColor(isTodayCol ? AppTheme.accent.opacity(0.75) : AppTheme.textTertiary.opacity(0.55))
                        .shadow(color: isTodayCol ? AppTheme.accent.opacity(0.28) : .clear, radius: 3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: headerH)
            .opacity(1.0 - foldProgress * 1.4)  // fade out as fold happens

            // All week rows in natural VStack flow — no translateY on individual rows
            ForEach(rows.indices, id: \.self) { rowIdx in
                let row = rows[rowIdx]

                // Rows that aren't the active row fade out
                let rowOpacity: Double = rowIdx == activeRow
                    ? 1.0
                    : max(0.0, 1.0 - Double(foldProgress) * 2.2)

                HStack(spacing: 1) {
                    ForEach(row.indices, id: \.self) { colIdx in
                        if let date = row[colIdx] {
                            let hasSelectedGoal: Bool = {
                                if let gid = selectedGoalId, let goal = store.goals.first(where: { $0.id == gid }) {
                                    return goal.covers(date)
                                }
                                return true
                            }()
                            GeometryReader { cellGeo in
                                let cellCenter = CGPoint(
                                    x: cellGeo.frame(in: .global).midX,
                                    y: cellGeo.frame(in: .global).midY
                                )
                                let dragDist: CGFloat = draggingGoalId != nil && dragScreenPos != .zero
                                    ? hypot(dragScreenPos.x - cellCenter.x, dragScreenPos.y - cellCenter.y)
                                    : .infinity
                                let proximity: CGFloat = draggingGoalId != nil
                                    ? max(0, 1 - dragDist / 130)
                                    : 0
                                CalendarDayCell(
                                    date: date,
                                    isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                    isToday: Calendar.current.isDate(date, inSameDayAs: store.today),
                                    dotColor: dotColor(for: date),
                                    isDragging: draggingGoalId != nil,
                                    isDimmed: selectedGoalId != nil && !hasSelectedGoal,
                                    dragProximity: proximity,
                                    onTap: {
                                        if let gid = draggingGoalId { onDropGoal(gid, date) }
                                        else { selectedDate = date }
                                    }
                                )
                                .scaleEffect(1.0 + proximity * 0.22)
                                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: proximity)
                            }
                            .frame(height: rowH)
                        } else {
                            Color.clear.frame(height: rowH)
                        }
                    }
                }
                .frame(height: rowH)
                .opacity(rowOpacity)
                // Row spacing
                if rowIdx < rows.count - 1 {
                    Spacer().frame(height: rowSpacing)
                }
            }
        }
        .offset(y: vStackShift)  // slide the whole VStack so active row rises to top
    }
}

struct CalendarGrid: View {
    let currentMonth:Date;@Binding var selectedDate:Date?
    let selectedGoalId:UUID?;let store:AppStore
    let draggingGoalId:UUID?;let onDropGoal:(UUID,Date)->Void
    /// Screen-space position of the drag label (for proximity animation)
    var dragScreenPos: CGPoint = .zero
    @EnvironmentObject var storeEnv:AppStore
    let cols=Array(repeating:GridItem(.flexible(),spacing:1),count:7)
    var weekdays:[String]{ L10n.weekdayShort(storeEnv.language) }
    var days:[Date?]{
        let cal=Calendar.current
        let first=cal.date(from:cal.dateComponents([.year,.month],from:currentMonth))!
        let off=cal.component(.weekday,from:first)-1
        let range=cal.range(of:.day,in:.month,for:currentMonth)!
        var r:[Date?]=Array(repeating:nil,count:off)
        for d in range { r.append(cal.date(byAdding:.day,value:d-1,to:first)) }
        return r
    }
    func dotColor(for date:Date)->Color?{
        // If a goal is selected: show that goal's color dot
        if let gid=selectedGoalId,
           let goal=store.goals.first(where:{$0.id==gid}) {
            return goal.covers(date) ? goal.color : nil
        }
        // No goal selected: show first matching goal's color (blended if multiple)
        let covering = store.goals.filter { $0.covers(date) }
        guard !covering.isEmpty else { return nil }
        return covering[0].color.opacity(0.85)
    }
    var body: some View {
        VStack(spacing:2){
            HStack(spacing:0) {
                ForEach(Array(zip(weekdays.indices, weekdays)), id:\.0) { idx, day in
                    let isTodayCol: Bool = {
                        let cal = Calendar.current
                        let todayWeekday = cal.component(.weekday, from: Date()) - 1
                        return idx == todayWeekday
                    }()
                    Text(day)
                        .font(.system(size: 10, weight: isTodayCol ? .medium : .regular, design: .rounded))
                        .foregroundColor(
                            isTodayCol
                                ? AppTheme.accent.opacity(0.75)
                                : AppTheme.textTertiary.opacity(0.55)
                        )
                        .shadow(
                            color: isTodayCol ? AppTheme.accent.opacity(0.30) : .clear,
                            radius: 3, x: 0, y: 0
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)
            LazyVGrid(columns:cols,spacing:2){
                ForEach(days.indices,id:\.self){ i in
                    if let date=days[i]{
                        let hasSelectedGoal: Bool = {
                            if let gid=selectedGoalId, let goal=store.goals.first(where:{$0.id==gid}) {
                                return goal.covers(date)
                            }
                            return true
                        }()
                        GeometryReader { cellGeo in
                            let cellCenter = CGPoint(
                                x: cellGeo.frame(in:.global).midX,
                                y: cellGeo.frame(in:.global).midY
                            )
                            let dragDist: CGFloat = draggingGoalId != nil && dragScreenPos != .zero
                                ? hypot(dragScreenPos.x - cellCenter.x, dragScreenPos.y - cellCenter.y)
                                : .infinity
                            // proximity: max +22% at 0px, fades beyond 130px — strong magnetic feel
                            let proximity: CGFloat = draggingGoalId != nil
                                ? max(0, 1 - dragDist/130)
                                : 0
                            let scaleBoost: CGFloat = 1.0 + proximity * 0.22
                            CalendarDayCell(date:date,
                                isSelected:selectedDate.map{Calendar.current.isDate($0,inSameDayAs:date)} ?? false,
                                isToday:Calendar.current.isDate(date, inSameDayAs:store.today),
                                dotColor:dotColor(for:date),
                                isDragging: draggingGoalId != nil,
                                isDimmed: selectedGoalId != nil && !hasSelectedGoal,
                                dragProximity: proximity,
                                onTap:{
                                    if let gid=draggingGoalId { onDropGoal(gid,date) }
                                    else { selectedDate=date }
                                })
                            .scaleEffect(scaleBoost)
                            .animation(.spring(response:0.28, dampingFraction:0.62), value:scaleBoost)
                        }
                        .frame(height:28)
                    } else { Color.clear.frame(height:28) }
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date:Date;let isSelected:Bool;let isToday:Bool;let dotColor:Color?
    /// true when a goal is being dragged (replaces isDropTarget)
    var isDragging:Bool = false
    var isDimmed:Bool = false
    /// 0–1: how close the drag is to this cell (1 = right on top)
    var dragProximity: CGFloat = 0
    let onTap:()->Void
    var day:Int { Calendar.current.component(.day,from:date) }
    var isPast:Bool { Calendar.current.startOfDay(for:date) < Calendar.current.startOfDay(for:Date()) }
    var isDroppable:Bool { isDragging && !isPast }  // today or future

    var body: some View {
        Button(action: {
            if isDroppable || !isDragging { onTap() }
        }) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(
                        size: isToday ? 12 : 11,
                        weight: isToday ? .semibold : .regular,
                        design: .rounded
                    ))
                    .foregroundColor(
                        (isSelected && isToday) ? AppTheme.bg0 :
                        isSelected              ? AppTheme.accent :
                        isToday                 ? AppTheme.accent :
                        (isDragging && isPast)  ? AppTheme.textTertiary.opacity(0.22) :
                        isDragging ? AppTheme.textPrimary.opacity(0.38 + dragProximity * 0.62) :
                        AppTheme.textPrimary.opacity(0.82)
                    )
                    .fontWeight(isDragging && dragProximity > 0.45 && !isSelected ? .medium : nil)
                    .frame(width: 26, height: 26)
                    .background(
                        ZStack {
                            // Selected fill — neon solid for today, glassy tint otherwise
                            if isToday && isSelected {
                                Circle()
                                    .fill(AppTheme.accent)
                                    .shadow(color: AppTheme.accent.opacity(0.55), radius: 5, x: 0, y: 0)
                            } else if isSelected {
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.20))
                                    .overlay(Circle().stroke(AppTheme.accent.opacity(0.55), lineWidth: 0.8))
                            }
                            // Drag proximity magnetic glow
                            if isDroppable && !isSelected && dragProximity > 0.40 {
                                Circle()
                                    .fill(AppTheme.accent.opacity(dragProximity * 0.18))
                                    .shadow(color: AppTheme.accent.opacity(dragProximity * 0.35), radius: 4)
                            }
                        }
                    )
                    .overlay(
                        ZStack {
                            if isToday && !isSelected {
                                // Cyber: thin neon ring for today
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [AppTheme.accent.opacity(0.75), AppTheme.accent.opacity(0.30)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.0
                                    )
                            }
                            if isDroppable && !isSelected && !isToday && dragProximity > 0.65 {
                                // Drop target: animated glow ring
                                Circle()
                                    .stroke(AppTheme.accent.opacity(dragProximity * 0.55), lineWidth: 1.0)
                            }
                        }
                    )

                // Dot — color-coded by goal, glows on drag proximity
                Circle()
                    .fill(
                        dotColor != nil && !isDimmed && !isDragging
                            ? dotColor!
                            : (isDragging && dragProximity > 0.4 && isDroppable
                                ? AppTheme.accent.opacity(dragProximity * 0.6)
                                : Color.clear)
                    )
                    .frame(width: 3, height: 3)
            }
            .opacity(
                (isDragging && isPast) ? 0.22 :
                isDimmed               ? 0.18 : 1.0
            )
            .animation(.easeInOut(duration: 0.15), value: isDimmed)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
        }
        .frame(maxWidth: .infinity)
        .disabled(isDragging && isPast)
    }
}

// ── 目标卡片 ──────────────────────────────────────────────

struct DayGoalCard: View {
    let goal:Goal;let date:Date;let isHighlighted:Bool;let isDragging:Bool
    let onSingleTap:()->Void;let onDoubleTap:()->Void
    let onDragChanged:(CGPoint)->Void;let onDragEnded:()->Void
    let onShare:()->Void;let onDelete:()->Void
    var onReorder:((CGPoint)->Void)? = nil
    var onReorderEnd:(()->Void)? = nil
    @EnvironmentObject var store:AppStore
    @State private var tapCount=0;@State private var tapTimer:Timer?=nil
    @State private var showDeleteConfirm=false
    @State private var showJournal=false
    @State private var cardExpanded = false  // default collapsed: show 2 tasks + "+N"

    var daysColor:Color{
        guard goal.goalType == .deadline else{return AppTheme.accent}
        return goal.daysLeft>90 ? AppTheme.accent:goal.daysLeft>30 ? AppTheme.gold:AppTheme.danger
    }

    // Use store.tasks(for:date,goal:) so Plan-page pinned tasks & skips are respected
    var effectiveTasks: [GoalTask] { store.tasks(for: date, goal: goal) }

    var body: some View {
        let pct = store.goalProgress(for: goal, on: date)
        let visibleCount = cardExpanded ? effectiveTasks.count : min(2, effectiveTasks.count)
        let hiddenCount  = effectiveTasks.count - visibleCount

        VStack(alignment: .leading, spacing: 0) {
            // ── Header row ──────────────────────────────────
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(goal.category.uppercased())
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundColor(goal.color.opacity(0.65))
                            .kerning(1.6)
                            .shadow(color: goal.color.opacity(0.22), radius: 3, x: 0, y: 0)
                        if goal.goalType == .longterm {
                            Text("∞").font(.system(size: 9, weight: .regular))
                                .foregroundColor(goal.color.opacity(0.50))
                        }
                    }
                    Text(goal.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.90))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Progress + stat
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 24, weight: .thin, design: .rounded))
                        .foregroundColor(pct >= 1.0 ? goal.color : AppTheme.textPrimary.opacity(0.80))
                        .monospacedDigit()
                        .shadow(color: pct >= 1.0 ? goal.color.opacity(0.35) : .clear, radius: 5, x: 0, y: 0)
                    if goal.goalType == .longterm {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").font(.system(size: 8))
                            Text("\(goal.daysSinceStart)d").font(.system(size: 9, design: .monospaced))
                        }.foregroundColor(goal.color.opacity(0.55))
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "hourglass").font(.system(size: 8))
                            Text("\(goal.daysLeft)d").font(.system(size: 9, design: .monospaced))
                        }.foregroundColor(daysColor.opacity(0.65))
                    }
                }

                // ── Expand/collapse chevron ──
                Button(action: { withAnimation(.spring(response: 0.22)) { cardExpanded.toggle() } }) {
                    Image(systemName: cardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .padding(.leading, 8)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            // ── Progress bar ─────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06)).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [goal.color.opacity(0.55), goal.color, goal.color.opacity(0.80)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * CGFloat(pct)), height: 3)
                        .shadow(color: goal.color.opacity(0.75), radius: 4, x: 0, y: 0)
                        .shadow(color: goal.color.opacity(0.35), radius: 8, x: 0, y: 0)
                }
            }.frame(height: 3)

            // ── Tasks: horizontal chip row ────────────────────
            if !effectiveTasks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(effectiveTasks.prefix(visibleCount)) { task in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(task.isCompleted ? goal.color : Color.white.opacity(0.15))
                                    .frame(width: 4, height: 4)
                                Text(task.title)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(task.isCompleted ? goal.color.opacity(0.55) : AppTheme.textSecondary.opacity(0.70))
                                    .lineLimit(1)
                                if let m = task.estimatedMinutes {
                                    Text("·\(m)m").font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(AppTheme.textTertiary.opacity(0.82))
                                }
                            }
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Capsule()
                                .fill(task.isCompleted ? goal.color.opacity(0.12) : Color.white.opacity(0.045))
                                .overlay(Capsule().stroke(task.isCompleted ? goal.color.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 0.5)))
                        }
                        // "+N more" chip — tap to expand
                        if hiddenCount > 0 {
                            Button(action: { withAnimation(.spring(response:0.22)) { cardExpanded = true } }) {
                                Text("+\(hiddenCount)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(goal.color.opacity(0.70))
                                    .padding(.horizontal, 7).padding(.vertical, 4)
                                    .background(Capsule().fill(goal.color.opacity(0.10))
                                        .overlay(Capsule().stroke(goal.color.opacity(0.25), lineWidth: 0.5)))
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(.top, 6).padding(.bottom, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.spring(response:0.22), value: cardExpanded)
            }

            // ── Action row (always visible when highlighted, or write-insight shortcut) ──
            if isHighlighted {
                HStack(spacing: 0) {
                    Text(store.t(key: L10n.editHint))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(goal.color.opacity(0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        // 写心得 button
                        Button(action: { showJournal = true }) {
                            HStack(spacing: 2) {
                                Image(systemName: "lightbulb.fill").font(.system(size: 8))
                                Text(store.t(zh:"心得", en:"Note", ja:"気づき", ko:"메모", es:"Nota"))
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.12))
                            .foregroundColor(AppTheme.accent.opacity(0.80))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppTheme.accent.opacity(0.22), lineWidth: 0.5))
                        }
                        Button(action: onShare) {
                            HStack(spacing: 2) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 8))
                                Text(store.t(zh:"分享", en:"Share", ja:"共有", ko:"공유", es:"Enviar"))
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(goal.color.opacity(0.12))
                            .foregroundColor(goal.color.opacity(0.80))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(goal.color.opacity(0.20), lineWidth: 0.5))
                        }
                        Button(action: { showDeleteConfirm = true }) {
                            HStack(spacing: 2) {
                                Image(systemName: "trash").font(.system(size: 8))
                                Text(store.t(zh:"删除", en:"Del", ja:"削除", ko:"삭제", es:"Del"))
                                    .font(.system(size: 9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Color.red.opacity(0.10))
                            .foregroundColor(Color.red.opacity(0.70))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.18), lineWidth: 0.5))
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.top, 8).padding(.bottom, 2)
                .transition(.opacity)
            }
        }
        .padding(.bottom, 11)
        .padding(.leading, 22)
        .padding(.trailing, 13)
        .cyberGlass(color: goal.color, cornerRadius: 16, isActive: isHighlighted, isGlowing: isDragging)
        // ── Left drag strip ──────────────────────────────────
        .overlay(alignment: .leading) {
            ZStack {
                // Color wash background
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [goal.color.opacity(isDragging ? 0.30 : 0.14), Color.clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 24)
                    .clipShape(.rect(topLeadingRadius: 16, bottomLeadingRadius: 16))
                // Neon leading edge line — glows on drag
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                goal.color.opacity(isDragging ? 1.0 : 0.60),
                                goal.color.opacity(isDragging ? 0.55 : 0.12)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: isDragging ? 2.0 : 1.5)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 10)
                    .frame(width: 24, alignment: .leading)
                    .shadow(color: goal.color.opacity(isDragging ? 0.7 : 0), radius: 4, x: 2, y: 0)
                // Drag dots (vertically centred)
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(isDragging ? goal.color : Color.white.opacity(0.28))
                            .frame(width: 2, height: 4)
                    }
                }
                .frame(width: 24)
                .scaleEffect(isDragging ? 1.30 : 1.0)
                .shadow(color: goal.color.opacity(isDragging ? 0.45 : 0), radius: 3)
                .animation(.spring(response: 0.18), value: isDragging)
            }
            .frame(width: 24)
            // Wider invisible hit area extends 8pt into card for easier grab
            .contentShape(Rectangle().inset(by: -2))
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { v in onDragChanged(v.location) }
                    .onEnded   { _ in onDragEnded() }
            )
        }
        .scaleEffect(isDragging ? 0.975 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            tapCount += 1
            if tapCount == 1 {
                tapTimer = Timer.scheduledTimer(withTimeInterval: 0.30, repeats: false) { _ in
                    if self.tapCount == 1 { self.onSingleTap() }
                    self.tapCount = 0
                }
            } else if tapCount >= 2 {
                tapTimer?.invalidate(); tapCount = 0; onDoubleTap()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isHighlighted)
        .animation(.spring(response: 0.22), value: isDragging)
        .sheet(isPresented: $showJournal) {
            PlanJournalSheet(date: date, goalId: goal.id, goalTitle: goal.title, goalColor: goal.color)
                .environmentObject(store)
        }
        .alert(store.t(key: L10n.deleteGoalTitle), isPresented: $showDeleteConfirm) {
            Button(store.t(key: L10n.delete), role: .destructive) { onDelete() }
            Button(store.t(key: L10n.cancel), role: .cancel) {}
        } message: {
            Text(store.t(key: L10n.cannotUndo))
        }
    }
}

// ============================================================
// MARK: - 共用：心得Sheet + 奖励徽记
// ============================================================

/// 奖励徽记 — 日✦ 周❋ 月◈ 年✺（强度递增体系）
struct RewardBadge: View {
    let level: RewardLevel
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            // Outer glow halo
            Image(systemName: level.symbol)
                .font(.system(size: size * 0.92, weight: .bold))
                .foregroundColor(level.color)
                .blur(radius: size * 0.55)
                .opacity(0.60)
            // Crisp icon
            Image(systemName: level.symbol)
                .font(.system(size: size * 0.75, weight: .semibold))
                .foregroundColor(level.color)
                .shadow(color: level.color.opacity(0.70), radius: 3, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

/// 计划心得快写 Sheet（目标/今日/计划页通用）
struct PlanJournalSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    let date: Date
    let goalId: UUID; let goalTitle: String; let goalColor: Color
    var taskId: UUID? = nil; var taskTitle: String? = nil
    var editing: PlanJournalEntry? = nil
    @State private var note: String = ""
    @FocusState private var focused: Bool

    init(date: Date, goalId: UUID, goalTitle: String, goalColor: Color,
         taskId: UUID? = nil, taskTitle: String? = nil, editing: PlanJournalEntry? = nil) {
        self.date = date; self.goalId = goalId; self.goalTitle = goalTitle
        self.goalColor = goalColor; self.taskId = taskId; self.taskTitle = taskTitle
        self.editing = editing; _note = State(initialValue: editing?.note ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                // Context header
                HStack(spacing: 8) {
                    Circle().fill(goalColor).frame(width: 8, height: 8)
                    Text(goalTitle)
                        .font(.system(size: 13, weight: .medium)).foregroundColor(AppTheme.textPrimary)
                    if let t = taskTitle {
                        Text("›").font(.caption).foregroundColor(AppTheme.textTertiary)
                        Text(t).font(.caption).foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text({ let f=DateFormatter(); f.dateFormat="M/d"; return f.string(from:date) }())
                        .font(.caption).foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
                Rectangle().fill(AppTheme.border0).frame(height:0.5)

                ZStack(alignment: .topLeading) {
                    if note.isEmpty {
                        Text(store.t(zh:"写下今天的心得…",en:"Write your insight…",ja:"今日の気づきを…",ko:"오늘의 인사이트…",es:"Escribe tu reflexión…"))
                            .font(.system(size:DSTSize.body, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            .padding(.top,18).padding(.leading,20)
                    }
                    TextEditor(text: $note)
                        .font(.system(size: 15)).foregroundColor(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden).background(Color.clear)
                        .padding(.horizontal, 16).padding(.vertical, 12).focused($focused)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(AppTheme.bg1).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius:12)
                    .stroke(focused ? AppTheme.accent.opacity(0.5) : AppTheme.border0,
                            lineWidth: focused ? 1.5 : 1))
                .padding(.horizontal, 20).padding(.top, 16)
                Spacer()
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(zh:"写心得",en:"Add Insight",ja:"気づきを書く",ko:"인사이트 작성",es:"Añadir reflexión"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.t(zh:"取消",en:"Cancel",ja:"キャンセル",ko:"취소",es:"Cancelar")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t(zh:"保存",en:"Save",ja:"保存",ko:"저장",es:"Guardar")) {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { dismiss(); return }
                        if var e = editing {
                            e.note = trimmed; e.updatedAt = Date(); store.updatePlanJournal(e)
                        } else {
                            store.addPlanJournal(PlanJournalEntry(
                                date: date, goalId: goalId, goalTitle: goalTitle,
                                taskId: taskId, taskTitle: taskTitle, note: trimmed))
                        }
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent).fontWeight(.medium)
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true } }
    }
}

// ── 目标编辑 ──────────────────────────────────────────────

struct GoalEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store:AppStore
    let goal:Goal?;let onSave:(Goal)->Void
    @State private var title:String;@State private var category:String
    @State private var selectedColor:Color;@State private var goalType:GoalType
    @State private var startDate:Date;@State private var endDate:Date
    @State private var tasks:[GoalTask]
    @State private var showingAddTask=false
    @State private var showDeleteConfirm=false
    @FocusState private var titleFocused: Bool

    // Category list sourced from SuggestionProvider for current language — always localised
    // Colors from AppTheme.palette (10 colors, accessed directly)

    @State private var showCalendarDot: Bool = true

    init(goal:Goal?, defaultDate: Date = Date(), onSave:@escaping(Goal)->Void){
        self.goal=goal;self.onSave=onSave
        _title=State(initialValue:goal?.title ?? "")
        _category=State(initialValue:goal?.category ?? SuggestionProvider.categoryOptions(.chinese).first ?? "健康")
        _selectedColor=State(initialValue:goal?.color ?? AppTheme.accent)
        _goalType=State(initialValue:goal?.goalType ?? .deadline)
        _startDate=State(initialValue:goal?.startDate ?? Calendar.current.startOfDay(for:defaultDate))
        _endDate=State(initialValue:goal?.endDate ?? Calendar.current.date(byAdding:.month,value:3,to:defaultDate)!)
        _tasks=State(initialValue:goal?.tasks ?? [])
        _showCalendarDot=State(initialValue:goal?.showCalendarDot ?? true)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment:.leading,spacing:20){
                    // 名称
                    VStack(alignment:.leading,spacing:7){
                        SectionLabel(store.t(key: L10n.goalTitle),icon:"flag")
                        TextField(store.t(key: L10n.goalTitlePlaceholderLocal),text:$title)
                            .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12).foregroundColor(AppTheme.textPrimary)
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(titleFocused ? AppTheme.accent.opacity(0.5) : AppTheme.border1,lineWidth:1))
                            .focused($titleFocused)
                            .submitLabel(.done)
                    }
                    // 分类
                    VStack(alignment:.leading,spacing:7){
                        SectionLabel(store.t(key: L10n.category),icon:"tag")
                        ScrollView(.horizontal,showsIndicators:false){
                            HStack(spacing:7){
                                ForEach(SuggestionProvider.categoryOptions(store.language), id: \.self) { cat in
                                    let sel = store.localizeCategory(category) == cat
                                    Button(action: {
                                        // Store the localised category directly
                                        category = cat
                                    }) {
                                        Text(cat).font(.subheadline).padding(.horizontal, 13).padding(.vertical, 7)
                                            .background(sel ? selectedColor.opacity(0.2) : AppTheme.bg2)
                                            .foregroundColor(sel ? selectedColor : AppTheme.textSecondary).cornerRadius(20)
                                            .overlay(RoundedRectangle(cornerRadius:20).stroke(sel ? selectedColor.opacity(0.4) : AppTheme.border0, lineWidth:1))
                                    }
                                }
                            }
                        }
                    }
                    // 颜色
                    VStack(alignment:.leading,spacing:10){
                        SectionLabel(store.t(key: L10n.colorLabel),icon:"paintpalette")
                        // 10-color grid: 2 rows × 5 cols
                        VStack(spacing: 10) {
                            // Row 0: colors 0–4
                            HStack(spacing: 0) {
                                ForEach(0..<5, id: \.self) { i in
                                    let c = AppTheme.palette[i]
                                    let isSel = (selectedColor == c)
                                    Button(action: { withAnimation(.spring(response:0.20, dampingFraction:0.70)) { selectedColor = c } }) {
                                        ZStack {
                                            Circle().fill(c).frame(width:30, height:30)
                                                .shadow(color:c.opacity(isSel ? 0.60 : 0.22), radius:isSel ? 6 : 3)
                                            if isSel {
                                                Circle().stroke(Color.white.opacity(0.90), lineWidth:2.0).frame(width:30, height:30)
                                                Circle().fill(Color.white).frame(width:6, height:6)
                                            } else {
                                                Circle().stroke(c.opacity(0.35), lineWidth:0.7).frame(width:30, height:30)
                                            }
                                        }
                                        .scaleEffect(isSel ? 1.15 : 1.0)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            // Row 1: colors 5–9
                            HStack(spacing: 0) {
                                ForEach(0..<5, id: \.self) { j in
                                    let i = j + 5
                                    let c = AppTheme.palette[i]
                                    let isSel = (selectedColor == c)
                                    Button(action: { withAnimation(.spring(response:0.20, dampingFraction:0.70)) { selectedColor = c } }) {
                                        ZStack {
                                            Circle().fill(c).frame(width:30, height:30)
                                                .shadow(color:c.opacity(isSel ? 0.60 : 0.22), radius:isSel ? 6 : 3)
                                            if isSel {
                                                Circle().stroke(Color.white.opacity(0.90), lineWidth:2.0).frame(width:30, height:30)
                                                Circle().fill(Color.white).frame(width:6, height:6)
                                            } else {
                                                Circle().stroke(c.opacity(0.35), lineWidth:0.7).frame(width:30, height:30)
                                            }
                                        }
                                        .scaleEffect(isSel ? 1.15 : 1.0)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    // 类型
                    VStack(alignment:.leading,spacing:10){
                        SectionLabel(store.t(key: L10n.goalTypeLabel),icon:"repeat")
                        HStack(spacing:10){
                            ForEach(GoalType.allCases,id:\.self){ type in
                                let sel=goalType==type
                                Button(action:{goalType=type}){
                                    VStack(spacing:4){Image(systemName:type == .deadline ? "calendar":"infinity").font(.title3);Text(type == .deadline ? store.t(key:L10n.goalTypeDeadline) : store.t(key:L10n.goalTypeOngoing)).font(.caption)}
                                        .frame(maxWidth:.infinity).padding(.vertical,13)
                                        .background(sel ? selectedColor.opacity(0.15):AppTheme.bg2)
                                        .foregroundColor(sel ? selectedColor:AppTheme.textSecondary).cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius:12).stroke(sel ? selectedColor.opacity(0.4):AppTheme.border0,lineWidth:1))
                                }
                            }
                        }
                    }
                    // 开始日期（新建时可选，编辑时锁定）
                    VStack(alignment:.leading,spacing:7){
                        SectionLabel(store.t(key: L10n.startDateLabel),icon:"play.circle")
                        if goal == nil {
                            // 新建：可以选开始日期（支持回填历史目标）
                            DatePicker("",selection:$startDate,displayedComponents:.date)
                                .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                                .padding(13).background(AppTheme.bg2).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
                            Text(store.t(key: L10n.longtermGoalHint))
                                .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                        } else {
                            // 编辑：仅显示（不允许修改开始日期，否则历史数据混乱）
                            HStack {
                                Text(formatDate(startDate, format:"yyyy年M月d日", lang:store.language))
                                    .font(.subheadline).foregroundColor(AppTheme.textTertiary)
                                Spacer()
                                Text(store.t(key: L10n.cannotChangeAfter))
                                    .font(.caption2).foregroundColor(AppTheme.textTertiary.opacity(0.6))
                            }
                            .padding(13).background(AppTheme.bg2.opacity(0.5)).cornerRadius(12)
                        }
                    }.transition(.opacity.combined(with:.move(edge:.top)))
                    // 截止日期
                    if goalType == .deadline {
                        VStack(alignment:.leading,spacing:7){
                            SectionLabel(store.t(key: L10n.endDateLabel),icon:"calendar.badge.exclamationmark")
                            DatePicker("",selection:$endDate,in:startDate...,displayedComponents:.date)
                                .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark)
                                .frame(maxWidth:.infinity).clipped().frame(height:120)
                                .background(AppTheme.bg2).cornerRadius(12)
                        }.transition(.opacity.combined(with:.move(edge:.top)))
                    }
                    // 任务
                    VStack(alignment:.leading,spacing:8){
                        HStack{
                            SectionLabel(store.t(key: L10n.tasks),icon:"checklist");Spacer()
                            Button(action:{showingAddTask=true}){
                                HStack(spacing:4){Image(systemName:"plus");Text(store.t(key: L10n.addLabel))}.font(.caption).padding(.horizontal,11).padding(.vertical,5).background(AppTheme.bg3).cornerRadius(8).foregroundColor(AppTheme.textSecondary).overlay(RoundedRectangle(cornerRadius:8).stroke(AppTheme.border1,lineWidth:1))
                            }
                        }
                        if tasks.isEmpty{Text(store.t(key: L10n.noTasksYet)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).frame(maxWidth:.infinity).padding(.vertical,12)}
                        else{ ForEach(tasks.indices,id:\.self){ i in TaskEditRow(task:$tasks[i],color:selectedColor,onDelete:{tasks.remove(at:i)},store:store) } }
                    }
                    // 日历光点开关
                    HStack(spacing:12) {
                        VStack(alignment:.leading, spacing:3) {
                            Text(store.t(key: L10n.calendarDotLabel))
                                .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                            Text(store.t(key: L10n.calendarDotHint))
                                .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                        }
                        Spacer()
                        Toggle("", isOn:$showCalendarDot).tint(selectedColor).labelsHidden()
                    }
                    .padding(14).background(AppTheme.bg2).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
                    // 删除目标按钮（仅编辑已有目标时显示）
                    if goal != nil {
                        Button(action:{showDeleteConfirm=true}){
                            HStack(spacing:6){
                                Image(systemName:"trash").font(.subheadline)
                                Text(store.t(key: L10n.deleteThisGoal))
                            }
                            .font(.subheadline).frame(maxWidth:.infinity).padding(.vertical,13)
                            .background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(Color.red.opacity(0.25),lineWidth:1))
                        }
                    }
                    Spacer(minLength:20)
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(key: goal==nil ? L10n.addGoalLabel : L10n.editGoalLabel)).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){Button(store.t(key: L10n.cancel)){dismiss()}.foregroundColor(AppTheme.textSecondary)}
                ToolbarItem(placement:.navigationBarTrailing){
                    Button(store.t(key: L10n.save)){
                        guard !title.isEmpty else { return }
                        let finalStart = goal?.startDate ?? Calendar.current.startOfDay(for:startDate)
                        let newGoal = Goal(
                            id: goal?.id ?? UUID(),
                            title: title, category: category, color: selectedColor,
                            goalType: goalType,
                            startDate: finalStart,
                            endDate: goalType == .deadline ? Calendar.current.startOfDay(for:endDate) : nil,
                            tasks: tasks,
                            showCalendarDot: showCalendarDot
                        )
                        onSave(newGoal)
                        dismiss()
                    }.foregroundColor(AppTheme.accent).fontWeight(.medium).disabled(title.isEmpty)
                }
            }
            .sheet(isPresented:$showingAddTask){TaskAddSheet(color:selectedColor){tasks.append($0)}}
            .animation(.spring(response:0.3),value:goalType)
            .alert(store.t(key: L10n.deleteGoalTitle),isPresented:$showDeleteConfirm){
                Button(store.t(key: L10n.delete),role:.destructive){
                    if let g=goal { store.deleteGoal(g) }
                    dismiss()
                }
                Button(store.t(key: L10n.cancel),role:.cancel){}
            } message:{
                Text(store.t(key: L10n.cannotUndo))
            }
        }
        .onAppear {
            // Auto-focus title field when adding a new goal
            if goal == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    titleFocused = true
                }
            }
        }
    }
}

struct TaskEditRow: View {
    @Binding var task:GoalTask;let color:Color;let onDelete:()->Void;let store:AppStore
    var body: some View {
        HStack(spacing:11){
            Circle().fill(color.opacity(0.6)).frame(width:7,height:7)
            VStack(alignment:.leading,spacing:2){
                Text(task.title).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                if let m=task.estimatedMinutes{Text(L10n.minuteWithNumber(m, store.language)).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)}
            }
            Spacer()
            Button(action:onDelete){Image(systemName:"xmark.circle.fill").foregroundColor(AppTheme.textTertiary.opacity(0.7)).font(.body)}
        }.padding(11).background(AppTheme.bg2).cornerRadius(10).overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border0,lineWidth:1))
    }
}

struct TaskAddSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store:AppStore
    let color:Color;let onAdd:(GoalTask)->Void
    @State private var title="";@State private var useTime=false;@State private var mins=30;@State private var maxMins=120;@State private var maxInput="120"
    @FocusState private var titleFocused: Bool
    var options:[Int]{stride(from:5,through:max(maxMins,5),by:5).map{$0}}
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment:.leading,spacing:20){
                    VStack(alignment:.leading,spacing:7){
                        SectionLabel(store.t(key: L10n.taskNameLabel),icon:"pencil")
                        TextField(store.t(key: L10n.taskNamePlaceholderLocal),text:$title)
                            .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12)
                            .foregroundColor(AppTheme.textPrimary)
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(titleFocused ? color.opacity(0.5) : AppTheme.border1,lineWidth:1))
                            .focused($titleFocused)
                            .submitLabel(.done)
                    }
                    HStack{Text(store.t(key: L10n.estimatedTimeLabel)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary);Spacer();Toggle("",isOn:$useTime).tint(color).labelsHidden()}
                    if useTime {
                        VStack(spacing:10){
                            HStack{Text(store.t(key: L10n.maxLabel)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary);TextField("120",text:$maxInput).keyboardType(.numberPad).textFieldStyle(.plain).frame(width:55).padding(8).background(AppTheme.bg3).cornerRadius(8).foregroundColor(AppTheme.textPrimary).multilineTextAlignment(.center).onChange(of:maxInput){if let n=Int(maxInput),n>0{maxMins=n}};Text(store.t(key: L10n.minuteLabel)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)}
                            Picker("",selection:$mins){ForEach(options,id:\.self){Text(L10n.minuteWithNumber($0, store.language)).tag($0)}}.pickerStyle(.wheel).frame(height:120).clipped().background(AppTheme.bg2).cornerRadius(12)
                        }.padding(13).background(AppTheme.bg2).cornerRadius(12).overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1)).transition(.move(edge:.top).combined(with:.opacity))
                    }
                    Spacer(minLength:20)
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(response:0.3),value:useTime)
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(key: L10n.addTask)).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){Button(store.t(key: L10n.cancel)){dismiss()}.foregroundColor(AppTheme.textSecondary)}
                ToolbarItem(placement:.navigationBarTrailing){Button(store.t(key: L10n.addLabel)){guard !title.isEmpty else{return};onAdd(GoalTask(title:title,estimatedMinutes:useTime ? mins:nil));dismiss()}.foregroundColor(color).fontWeight(.medium).disabled(title.isEmpty)}
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                titleFocused = true
            }
        }
    }
}

// ============================================================
// MARK: - 今日页面
// ============================================================

struct TodayView: View {
    @EnvironmentObject var store:AppStore
    @EnvironmentObject var pro:ProStore
    @State private var draft=DayReview(date:Date())
    @State private var journalSubmitted=false

    // 使用 store.today 使模拟日期生效
    var today: Date { store.today }

    var todayGoals:[Goal]{store.goals(for:today)}
    // Use store.tasks(for:today,goal:) so Plan page pinned tasks & skips are respected
    var allPairs:[(Goal,GoalTask)]{todayGoals.flatMap{g in store.tasks(for:today,goal:g).map{(g,$0)}}}
    var totalRate:Double{guard !allPairs.isEmpty else{return 0};return allPairs.map{store.progress(for:today,taskId:$0.1.id)}.reduce(0,+)/Double(allPairs.count)}
    var completedCount:Int{allPairs.filter{store.progress(for:today,taskId:$0.1.id)>=1.0}.count}

    // 加载或刷新今日数据
    func loadToday() {
        if let r = store.review(for:today) {
            draft = r
            journalSubmitted = r.isSubmitted && (r.rating > 0 || !r.journalGains.isEmpty
                || !r.journalChallenges.isEmpty || !r.journalTomorrow.isEmpty
                || !r.gainKeywords.isEmpty || !r.challengeKeywords.isEmpty || !r.tomorrowKeywords.isEmpty)
        } else {
            draft = DayReview(date:today)
            journalSubmitted = false
        }
    }

    // 实时自动保存 draft（先同步 store 中实时写入的 keywords，避免覆盖）
    func autoSaveDraft() {
        var toSave = draft
        if let live = store.review(for: store.today) {
            toSave.challengeKeywords = live.challengeKeywords
            toSave.gainKeywords      = live.gainKeywords
            toSave.tomorrowKeywords  = live.tomorrowKeywords
        }
        store.autoSaveReview(toSave)
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing:14){
                    // ── Today page header — same PageHeaderView as Plan/Me ──
                    PageHeaderView(
                        title: store.t(key: L10n.todayNav),
                        subtitle: formatDate(today,
                                             format: store.language == .chinese ? "M月d日 EEEE" : "EEEE, MMMM d",
                                             lang: store.language),
                        accentColor: AppTheme.accent
                    )

                    // ── 每日总结（完成情况 + 困难追踪）──
                    TodayDailySummaryCard(
                        completed:completedCount, total:allPairs.count,
                        rate:totalRate, date:today
                    ).padding(.horizontal)

                    ForEach(todayGoals){ goal in TodayGoalSection(goal:goal,store:store,date:today).padding(.horizontal) }

                    if todayGoals.isEmpty {
                        VStack(spacing:8){
                            Image(systemName:"target").font(.largeTitle).foregroundColor(AppTheme.textTertiary)
                            Text(store.t(key: L10n.noTasksToday)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary)
                        }.frame(maxWidth:.infinity).padding(.vertical,36)
                    }

                    // ── 今日心得（合并版：心情 + 收获 + 困难 + 明日）──
                    TodayJournalCard(
                        draft:$draft, isSubmitted:$journalSubmitted, store:store,
                        onExpand:{ withAnimation(.spring(response:0.5)){
                            proxy.scrollTo("journalCard", anchor:.center)
                        }}
                    )
                    .id("journalCard")
                    .padding(.horizontal)

                    // ── 今日智能总结（Pro 订阅专属）─────────
                    if pro.isProSubscriber {
                        MergedSummaryCard(range: -1, singleDate: today)
                            .padding(.horizontal)
                    }

                    Spacer(minLength:20)
                }.padding(.top, 0)
            }
            .scrollDismissesKeyboard(.interactively)
            } // ScrollViewReader
            .background(
                ZStack {
                    AppTheme.bg0.ignoresSafeArea()
                    // Monet pond light glow at top
                    LinearGradient(
                        colors:[AppTheme.accent.opacity(0.055), Color.clear],
                        startPoint:.top, endPoint:.init(x:0.5, y:0.4)
                    ).ignoresSafeArea()
                }
            )
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .onAppear{ loadToday() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                loadToday()
            }
            // 监听 simulatedDate 变化，重新加载
            .onChange(of: store.simulatedDate) { _, _ in loadToday() }
            // 监听 goals 变化（新增目标后刷新）
            .onChange(of: store.goals.count) { _, _ in loadToday() }
            .onChange(of: draft.rating)            { _, _ in autoSaveDraft() }
            .onChange(of: draft.journalGains)      { _, _ in autoSaveDraft() }
            .onChange(of: draft.journalChallenges) { _, _ in autoSaveDraft() }
            .onChange(of: draft.journalTomorrow)   { _, _ in autoSaveDraft() }
            .onChange(of: draft.gainKeywords)      { _, _ in autoSaveDraft() }
            .onChange(of: draft.challengeKeywords) { _, _ in autoSaveDraft() }
            .onChange(of: draft.tomorrowKeywords)  { _, _ in autoSaveDraft() }
        }
    }
}

// ── 每日困难追踪卡 ──────────────────────────────────────────
struct DailyChallengeTracker: View {
    @EnvironmentObject var store: AppStore
    let date: Date
    @State private var expanded = true

    var state: (active: [String], resolved: [String]) {
        store.dailyChallengeState(for: date)
    }
    var hasAny: Bool { !state.active.isEmpty || !state.resolved.isEmpty }

    var body: some View {
        if hasAny {
            VStack(alignment: .leading, spacing: 0) {
                // 标题行
                Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundColor(AppTheme.gold)
                        Text(store.t(key: L10n.pendingItems))
                            .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).kerning(1.5)
                        Spacer()
                        let totalActive = state.active.count
                        let totalResolved = state.resolved.count
                        if totalActive + totalResolved > 0 {
                            Text("\(totalResolved)/\(totalActive + totalResolved)")
                                .font(.system(size: 10)).foregroundColor(AppTheme.gold)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(AppTheme.gold.opacity(0.1)).cornerRadius(5)
                        }
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                    }.padding(14)
                }

                if expanded {
                    Rectangle().fill(AppTheme.border0).frame(height:0.5).padding(.horizontal, 14)
                    VStack(alignment: .leading, spacing: 6) {
                        let allKW = state.active + state.resolved

                        if allKW.isEmpty {
                            Text(store.t(key: L10n.noChallengesLabel))
                                .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(allKW, id: \.self) { kw in
                                let solved = state.resolved.contains(kw)
                                Button(action: {
                                    store.toggleDailyChallenge(keyword: kw, on: date)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: solved ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 13))
                                            .foregroundColor(solved ? AppTheme.accent : AppTheme.gold.opacity(0.7))
                                        Text(kw)
                                            .font(.subheadline)
                                            .foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textPrimary)
                                            .strikethrough(solved, color: AppTheme.textTertiary)
                                        Spacer()
                                        if solved {
                                            Text(store.t(key: L10n.resolvedLabel))
                                                .font(.system(size: 10))
                                                .foregroundColor(AppTheme.accent)
                                        } else {
                                            Text(store.t(key: L10n.todoLabel))
                                                .font(.system(size: 10))
                                                .foregroundColor(AppTheme.gold)
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(solved ? AppTheme.accent.opacity(0.05) : AppTheme.gold.opacity(0.06))
                                    .cornerRadius(8)
                                    .animation(.spring(response: 0.2), value: solved)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(AppTheme.bg1)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.gold.opacity(0.2), lineWidth: 1))
        }
    }
}

// ── 今日心得：心情 + 关键词 + 详细文本 ──────────────────────
struct TodayJournalCard: View {
    @Binding var draft: DayReview
    @Binding var isSubmitted: Bool
    let store: AppStore
    var onExpand: (() -> Void)? = nil
    @EnvironmentObject var pro: ProStore
    @State private var expanded = false
    @State private var showGainDetail = false
    @State private var showTomorrowDetail = false
    @State private var showSmartSummary = false

    let emojis = ["😞","😶","🙂","🤍","✨"]
    let moodLabels_zh = ["不太好","一般","还行","不错","很棒"]
    let moodLabels_en = ["Rough","Okay","Alright","Good","Great"]

    var moodLabel: String {
        guard draft.rating > 0 else { return store.t(key: L10n.howAreYouFeeling) }
        let moodLabels_ja = ["つらい","普通","まあまあ","良い","最高"]
        let moodLabels_ko = ["힘들어","보통","괜찮아","좋아","최고"]
        let moodLabels_es = ["Mal","Regular","Bien","Muy bien","Genial"]
        let labels: [String]
        switch store.language {
        case .chinese:  labels = moodLabels_zh
        case .japanese: labels = moodLabels_ja
        case .korean:   labels = moodLabels_ko
        case .spanish:  labels = moodLabels_es
        case .english:  labels = moodLabels_en
        }
        return labels[min(draft.rating-1, 4)]
    }
    var hasContent: Bool {
        let liveChallengeKW = store.review(for:store.today)?.challengeKeywords ?? []
        return draft.rating > 0 || !draft.gainKeywords.isEmpty
            || !draft.challengeKeywords.isEmpty || !liveChallengeKW.isEmpty
            || !draft.tomorrowKeywords.isEmpty
    }

    var body: some View {
        VStack(alignment:.leading, spacing:0) {
            // 标题行
            Button(action:{
                withAnimation(.spring(response:0.45, dampingFraction:0.85)){ expanded.toggle() }
                if !expanded { DispatchQueue.main.asyncAfter(deadline:.now()+0.15){ onExpand?() } }
            }) {
                HStack(spacing:8) {
                    Image(systemName:"book.pages")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent.opacity(0.60))
                    Text(store.t(key: L10n.todayJournal))
                        .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                        .kerning(0.3)
                    Spacer()
                    if draft.rating > 0 { Text(emojis[draft.rating-1]).font(.body) }
                    // 关键词计数徽标
                    let kwCount = draft.gainKeywords.count + draft.challengeKeywords.count + draft.tomorrowKeywords.count
                    if kwCount > 0 {
                        Text("\(kwCount)\(store.language == .english ? " words" : store.language == .japanese ? "語" : store.language == .korean ? "개" : store.language == .spanish ? " palabras" : "词")")
                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                            .padding(.horizontal,5).padding(.vertical,2)
                            .background(AppTheme.accent.opacity(0.12)).cornerRadius(4)
                            .foregroundColor(AppTheme.accent.opacity(0.80))
                    }
                    if isSubmitted {
                        Image(systemName:"checkmark.circle.fill")
                            .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                            .foregroundColor(AppTheme.accent)
                    }
                    Image(systemName: expanded ? "chevron.up":"chevron.down")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                }.padding(.horizontal,14).padding(.top,14).padding(.bottom,10)
            }

            if expanded {
                Rectangle().fill(AppTheme.border0).frame(height:0.5).padding(.horizontal,14)
                VStack(alignment:.leading, spacing:18) {

                    // ── 1. 心情 ─────────────────────────────
                    VStack(alignment:.leading, spacing:8) {
                        Text(moodLabel).font(.caption).foregroundColor(draft.rating > 0 ? AppTheme.accent : AppTheme.textTertiary)
                        HStack(spacing:8) {
                            ForEach(1...5, id:\.self) { i in
                                Button(action:{ draft.rating = i }) {
                                    Text(emojis[i-1]).font(.title2).frame(maxWidth:.infinity).padding(.vertical,8)
                                        .background(draft.rating==i ? AppTheme.accent.opacity(0.15) : AppTheme.bg2).cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius:10).stroke(draft.rating==i ? AppTheme.accent.opacity(0.5) : AppTheme.border0, lineWidth:1))
                                }
                                .accessibilityLabel(moodLabels_en[i-1])
                                .accessibilityAddTraits(.isButton)
                                .animation(.spring(response:0.2), value:draft.rating)
                            }
                        }
                    }

                    // ── 2. 今日待决标签（实时读写 store，全视图同步）──
                    ChallengeKeywordSection()

                    // ── 3. 今日收获（实时写 store，四视图同步）────
                    LiveKeywordSection(
                        kwType:.gain, icon:"star.fill", color:AppTheme.accent,
                        title:store.t(key: L10n.winsToday),
                        hint:store.t(key: L10n.winsHint)
                    )

                    // ── 4. 今日计划（实时写 store，四视图同步）────
                    LiveKeywordSection(
                        kwType:.plan, icon:"arrow.right.circle.fill",
                        color:Color(red:0.780,green:0.500,blue:0.700),
                        title:store.t(key: L10n.tomorrowPlan),
                        hint:store.t(key: L10n.tomorrowHint)
                    )

                    // ── 提交 ────────────────────────────────
                    Button(action:{
                        // 所有关键词均已实时写入 store
                        var toSubmit = draft
                        if let live = store.review(for:store.today) {
                            toSubmit.challengeKeywords = live.challengeKeywords
                            toSubmit.gainKeywords      = live.gainKeywords
                            toSubmit.tomorrowKeywords  = live.tomorrowKeywords
                        }
                        store.submitReview(toSubmit)
                        draft = toSubmit
                        isSubmitted = true
                        withAnimation(.spring(response:0.35)){ expanded = false }
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.4){
                            showSmartSummary = true
                        }
                    }) {
                        HStack(spacing:6) {
                            Image(systemName: isSubmitted ? "arrow.clockwise.circle.fill" : "sparkles")
                            Text(isSubmitted ? store.t(key: L10n.updateJournal) : store.t(key: L10n.submitJournal))
                        }
                        .font(.subheadline).fontWeight(.medium)
                        .frame(maxWidth:.infinity).padding(.vertical,13)
                        .background(isSubmitted ? AppTheme.bg2 : AppTheme.accent.opacity(0.15)).cornerRadius(12)
                        .foregroundColor(isSubmitted ? AppTheme.textTertiary : AppTheme.accent)
                        .overlay(RoundedRectangle(cornerRadius:12).stroke(isSubmitted ? AppTheme.border0 : AppTheme.accent.opacity(0.4), lineWidth:1))
                    }
                    .disabled(!hasContent).opacity(hasContent ? 1 : 0.45)
                }
                .padding(14)
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .background(AppTheme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16).stroke(isSubmitted ? AppTheme.accent.opacity(0.25) : AppTheme.border0, lineWidth:1))
        .onAppear { expanded = true }
        .sheet(isPresented:$showSmartSummary) {
            SmartSummarySheet(ctx: SummaryContext.forDay(store.today, store:store))
                .environmentObject(store)
                .environmentObject(pro)
        }
    }
}

// ── 关键词输入区（带可选详细文本展开）────────────────────────
struct KeywordInputSection: View {
    let icon: String; let color: Color; let title: String; let hint: String
    @Binding var keywords: [String]
    @Binding var detailText: String
    @Binding var showDetail: Bool
    let store: AppStore
    @State private var inputText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            // 标题行
            HStack(spacing:5) {
                Image(systemName:icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(color)
                Spacer()
                // 展开详细文本按钮
                Button(action:{ withAnimation(.spring(response:0.3)){ showDetail.toggle() }}) {
                    HStack(spacing:3) {
                        Image(systemName:"text.alignleft").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        Text(store.t(key: L10n.detailLabel)).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                    }.foregroundColor(showDetail ? color : AppTheme.textTertiary)
                    .padding(.horizontal,7).padding(.vertical,3)
                    .background(showDetail ? color.opacity(0.12) : AppTheme.bg2).cornerRadius(6)
                }
            }

            // 提示文字
            if keywords.isEmpty {
                Text(hint).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary).lineSpacing(2)
            }

            // 已添加的关键词 chips
            if !keywords.isEmpty {
                FlowLayout(spacing:6) {
                    ForEach(keywords, id:\.self) { kw in
                        HStack(spacing:4) {
                            Text(kw).font(.caption).foregroundColor(color)
                            Button(action:{
                                keywords.removeAll { $0 == kw }
                            }) {
                                Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(color.opacity(0.6))
                            }
                        }
                        .padding(.horizontal,9).padding(.vertical,5)
                        .background(color.opacity(0.1)).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(0.3),lineWidth:1))
                    }
                }
            }

            // 输入框
            HStack(spacing:8) {
                TextField(store.t(key: L10n.typeKeyword), text:$inputText)
                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                    .focused($focused)
                    .onSubmit { addKeyword() }
                    .padding(.horizontal,11).padding(.vertical,9)
                    .background(AppTheme.bg2).cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius:9).stroke(focused ? color.opacity(0.4) : AppTheme.border1, lineWidth:1))

                if !inputText.isEmpty {
                    Button(action:addKeyword) {
                        Image(systemName:"return").font(.caption).foregroundColor(color)
                            .frame(width:34,height:34).background(color.opacity(0.12)).cornerRadius(9)
                    }
                }
            }

            // 关键词数量提示
            if keywords.count >= 5 {
                Text(store.t(key: L10n.keywordLimit)).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
            }

            // 详细文本（可选展开）
            if showDetail {
                ZStack(alignment:.topLeading) {
                    if detailText.isEmpty {
                        Text(store.t(key: L10n.addDetails))
                            .foregroundColor(AppTheme.textTertiary).font(.subheadline)
                            .padding(.horizontal,10).padding(.vertical,9)
                    }
                    TextEditor(text:$detailText)
                        .frame(minHeight:56).padding(6).scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.textPrimary).font(.subheadline)
                }
                .background(AppTheme.bg2).cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius:9).stroke(AppTheme.border1, lineWidth:1))
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .padding(12).background(AppTheme.bg0.opacity(0.6)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.15), lineWidth:1))
    }

    func addKeyword() {
        let kw = inputText.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !kw.isEmpty, !keywords.contains(kw), keywords.count < 8 else { inputText = ""; return }
        withAnimation(.spring(response:0.25)) { keywords.append(kw) }
        inputText = ""
    }
}

struct JournalInputField: View {
    let icon: String; let iconColor: Color; let label: String; let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment:.leading, spacing:6) {
            HStack(spacing:5) {
                Image(systemName:icon).font(.caption2).foregroundColor(iconColor)
                Text(label).font(.caption2).foregroundColor(iconColor).kerning(0.5)
            }
            ZStack(alignment:.topLeading) {
                if text.isEmpty {
                    Text(placeholder).foregroundColor(AppTheme.textTertiary).font(.subheadline)
                        .padding(.horizontal,10).padding(.vertical,9)
                }
                TextEditor(text:$text)
                    .frame(minHeight:52).padding(6)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(AppTheme.textPrimary).font(.subheadline)
            }
            .background(AppTheme.bg2).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border1, lineWidth:1))
        }
    }
}

struct GoalJournalEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    let date: Date; let goal: Goal; var existing: PlanJournalEntry?
    @State private var note: String = ""
    @FocusState private var focused: Bool

    init(date: Date, goal: Goal, existing: PlanJournalEntry?) {
        self.date = date; self.goal = goal; self.existing = existing
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(alignment:.leading, spacing:0) {
                // Context header
                HStack(spacing:8) {
                    Circle().fill(goal.color).frame(width:8, height:8)
                    Text(goal.title)
                        .font(.system(size:DSTSize.label, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text({ let f=DateFormatter(); f.dateFormat="M/d"; return f.string(from:date) }())
                        .font(.caption).foregroundColor(AppTheme.textTertiary)
                }
                .padding(.horizontal,20).padding(.top,16).padding(.bottom,12)
                Rectangle().fill(AppTheme.border0).frame(height:0.5)

                ZStack(alignment:.topLeading) {
                    if note.isEmpty {
                        Text(store.t(zh:"写下今天的心得…",en:"Write your insight…",ja:"今日の気づきを…",ko:"오늘의 인사이트…",es:"Escribe tu reflexión…"))
                            .font(.system(size:DSTSize.body, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            .padding(.top,18).padding(.leading,20)
                    }
                    TextEditor(text:$note)
                        .font(.system(size:DSTSize.body, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                        .scrollContentBackground(.hidden).background(Color.clear)
                        .padding(.horizontal,16).padding(.vertical,12).focused($focused)
                }
                .frame(maxWidth:.infinity, minHeight:160)
                .background(AppTheme.bg1).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius:12)
                    .stroke(focused ? AppTheme.accent.opacity(0.5) : AppTheme.border0,
                            lineWidth: focused ? 1.5 : 1))
                .padding(.horizontal,20).padding(.top,16)
                Spacer()
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(existing == nil
                ? store.t(zh:"写心得",en:"Add Insight",ja:"気づきを書く",ko:"인사이트 작성",es:"Añadir")
                : store.t(zh:"编辑心得",en:"Edit Insight",ja:"気づきを編集",ko:"편집",es:"Editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button(store.t(zh:"取消",en:"Cancel",ja:"キャンセル",ko:"취소",es:"Cancelar")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(store.t(zh:"保存",en:"Save",ja:"保存",ko:"저장",es:"Guardar")) {
                        let trimmed = note.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { dismiss(); return }
                        if var e = existing {
                            // Update existing entry
                            e.note = trimmed; e.updatedAt = Date(); store.updatePlanJournal(e)
                        } else {
                            // Create new entry for today
                            store.addPlanJournal(PlanJournalEntry(
                                date:date, goalId:goal.id, goalTitle:goal.title,
                                taskId:nil, taskTitle:nil, note:trimmed))
                        }
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accent).fontWeight(.medium)
                    .disabled(note.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline:.now()+0.35) { focused = true } }
    }
}

struct TodayGoalSection: View {
    let goal: Goal; let store: AppStore; let date: Date
    @EnvironmentObject var storeEnv: AppStore
    @State private var collapsed = true           // default collapsed
    @State private var showJournal = false

    // Use store.tasks(for:date,goal:) to respect pinnedDate, skips, overrides
    var allTasks: [GoalTask] { storeEnv.tasks(for: date, goal: goal) }
    // Compute pct from allTasks directly (consistent with task list shown)
    var pct: Double {
        guard !allTasks.isEmpty else { return 0 }
        let total = allTasks.map { storeEnv.progress(for:date, taskId:$0.id) }.reduce(0,+)
        return total / Double(allTasks.count)
    }
    var doneCount: Int { allTasks.filter { storeEnv.progress(for:date, taskId:$0.id) >= 1.0 }.count }

    // Single persistent journal per goal per day (upsert pattern)
    var todayJournal: PlanJournalEntry? {
        let cal = Calendar.current
        return storeEnv.planJournals
            .filter { $0.goalId == goal.id && cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    var hasJournal: Bool { todayJournal != nil }

    var body: some View {
        VStack(spacing:0) {
            // ═══════════════════════════════════════════════
            // HEADER — always visible
            // ═══════════════════════════════════════════════
            Button(action:{
                withAnimation(.spring(response:0.38, dampingFraction:0.82)) { collapsed.toggle() }
            }) {
                HStack(spacing:12) {
                    // ── Progress ring (Apple Fitness style) ─
                    ZStack {
                        Circle()
                            .stroke(goal.color.opacity(0.15), lineWidth:3)
                            .frame(width:38, height:38)
                        Circle()
                            .trim(from:0, to:CGFloat(pct))
                            .stroke(
                                AngularGradient(
                                    colors:[goal.color.opacity(0.7), goal.color],
                                    center:.center,
                                    startAngle:.degrees(-90),
                                    endAngle:.degrees(-90 + 360 * pct)
                                ),
                                style: StrokeStyle(lineWidth:3, lineCap:.round)
                            )
                            .frame(width:38, height:38)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response:0.5, dampingFraction:0.75), value:pct)
                        if pct >= 1.0 {
                            Image(systemName:"checkmark")
                                .font(.system(size:DSTSize.micro, weight:.bold, design:.rounded))
                                .foregroundColor(goal.color)
                        } else {
                            Text("\(Int(pct*100))")
                                .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
                                .foregroundColor(goal.color.opacity(0.9))
                        }
                    }  // ZStack close

                    // ── Title + metadata ──────────────────────
                    VStack(alignment:.leading, spacing:3) {
                        Text(goal.title)
                            .font(.system(size:DSTSize.label, weight:.semibold, design:.rounded))
                            .foregroundColor(AppTheme.textPrimary.opacity(0.90))
                            .lineLimit(1)
                        HStack(spacing:6) {
                            if goal.goalType == .longterm {
                                HStack(spacing:3) {
                                    Image(systemName:"flame.fill")
                                        .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                                        .foregroundColor(goal.color.opacity(0.65))
                                    Text(L10n.daysSinceStartFmt(goal.daysSinceStart, storeEnv.language))
                                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                        .foregroundColor(goal.color.opacity(0.65))
                                }
                            }
                            Text("\(doneCount)/\(allTasks.count)")
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                                .monospacedDigit()
                            if pct >= 1.0 {
                                Text("·")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                    .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                                Text(storeEnv.t(zh:"全部完成", en:"All done", ja:"完了", ko:"완료", es:"Completo"))
                                    .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                                    .foregroundColor(goal.color)
                            }
                        }
                    }

                    Spacer()

                    // ── Journal pill + chevron ─────────────────
                    HStack(spacing:8) {
                        Button(action:{ showJournal = true }) {
                            HStack(spacing:4) {
                                Image(systemName: hasJournal ? "lightbulb.fill" : "lightbulb")
                                    .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                                    .foregroundColor(hasJournal ? AppTheme.gold : AppTheme.textTertiary.opacity(0.45))
                                Text(storeEnv.t(zh:"心得", en:"Note", ja:"記録", ko:"노트", es:"Nota"))
                                    .font(.system(size:DSTSize.micro, weight: hasJournal ? .medium : .regular, design:.rounded))
                                    .foregroundColor(hasJournal ? AppTheme.gold.opacity(0.88) : AppTheme.textTertiary.opacity(0.45))
                            }
                            .padding(.horizontal,9).padding(.vertical,5)
                            .background(Capsule().fill(hasJournal ? AppTheme.gold.opacity(0.10) : AppTheme.bg2))
                            .overlay(Capsule().stroke(
                                hasJournal ? AppTheme.gold.opacity(0.22) : AppTheme.border0,
                                lineWidth: hasJournal ? 0.7 : 0.5))
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture())

                        Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size:DSTSize.nano, weight:.medium, design:.rounded))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.50))
                            .frame(width:16)
                    }
                }
                .padding(.horizontal,14).padding(.vertical,12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ═══════════════════════════════════════════════
            // EXPANDED TASK LIST
            // ═══════════════════════════════════════════════
            if !collapsed {
                VStack(spacing:0) {
                    Rectangle()
                        .fill(goal.color.opacity(0.12))
                        .frame(height:0.8)
                        .padding(.horizontal,12)

                    VStack(spacing:0) {
                        ForEach(Array(allTasks.enumerated()), id:\.element.id) { idx, task in
                            TodaySliderRow(task:task, goal:goal, store:store, date:date)
                                .padding(.horizontal,14)
                                .padding(.top, idx == 0 ? 10 : 6)
                                .padding(.bottom, idx == allTasks.count-1 ? 14 : 0)
                        }
                    }

                    // Journal preview
                    if let j = todayJournal, !j.note.isEmpty {
                        Rectangle()
                            .fill(goal.color.opacity(0.10))
                            .frame(height:0.8)
                            .padding(.horizontal,12)
                        HStack(alignment:.top, spacing:8) {
                            Image(systemName:"lightbulb.fill")
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold.opacity(0.8))
                                .padding(.top,2)
                            Text(j.note)
                                .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(3)
                                .frame(maxWidth:.infinity, alignment:.leading)
                            Button(action:{ showJournal = true }) {
                                Text(storeEnv.t(zh:"编辑", en:"Edit", ja:"編集", ko:"편집", es:"Editar"))
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold.opacity(0.7))
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal,14).padding(.vertical,10)
                    }
                }
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        // cyberGlass style matching Goals page
        .background(
            ZStack {
                RoundedRectangle(cornerRadius:16).fill(AppTheme.bg1)
                // Frosted glass film
                RoundedRectangle(cornerRadius:16)
                    .fill(.ultraThinMaterial).opacity(0.18)
                // Diagonal specular sheen
                RoundedRectangle(cornerRadius:16)
                    .fill(LinearGradient(
                        colors:[Color.white.opacity(0.055), Color.clear],
                        startPoint:.topLeading, endPoint:.center))
                // Goal color ambient bloom
                RoundedRectangle(cornerRadius:16)
                    .fill(RadialGradient(
                        colors:[goal.color.opacity(pct >= 1.0 ? 0.22 : 0.08), Color.clear],
                        center:.topLeading, startRadius:0, endRadius:130))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius:16))
        .overlay(
            RoundedRectangle(cornerRadius:16)
                .stroke(
                    LinearGradient(
                        colors: pct >= 1.0
                            ? [goal.color.opacity(0.50), goal.color.opacity(0.18)]
                            : [goal.color.opacity(0.22), goal.color.opacity(0.07)],
                        startPoint:.topLeading, endPoint:.bottomTrailing),
                    lineWidth: pct >= 1.0 ? 1.2 : 0.8)
        )
        // Left color accent strip
        .overlay(alignment:.leading) {
            RoundedRectangle(cornerRadius:2)
                .fill(LinearGradient(
                    colors:[goal.color, goal.color.opacity(0.3)],
                    startPoint:.top, endPoint:.bottom))
                .frame(width:3).padding(.vertical,12)
        }
        .shadow(color: pct >= 1.0 ? goal.color.opacity(0.20) : goal.color.opacity(0.07),
                radius: pct >= 1.0 ? 14 : 8, x:0, y:3)
        .shadow(color:.black.opacity(0.10), radius:6, x:0, y:2)
        .sheet(isPresented:$showJournal) {
            GoalJournalEditSheet(
                date:date, goal:goal, existing:todayJournal
            ).environmentObject(storeEnv)
        }
    }
}

struct TodaySliderRow: View {
    let task:GoalTask;let goal:Goal;let store:AppStore;let date:Date
    @EnvironmentObject var storeEnv:AppStore
    // localProgress: set on drag, stays set until next render cycle after store confirms
    // This prevents the jump-to-old-value flicker on commit
    @State private var localProgress:Double = -1
    @State private var pressing = false

    // Always use localProgress when set; fall back to store
    var storedProgress: Double { store.progress(for:date,taskId:task.id) }
    var cur: Double { localProgress >= 0 ? localProgress : storedProgress }
    var done:Bool  { cur >= 1.0 }
    var hasMinutes: Bool { task.estimatedMinutes != nil }

    var progressLabel: String {
        if hasMinutes {
            let total = task.estimatedMinutes!
            return "\(Int(cur*Double(total)))/\(total)min"
        }
        return done ? storeEnv.t(key: L10n.doneLabel) : storeEnv.t(key: L10n.pendingLabel)
    }

    func commitProgress(_ p: Double) {
        // Keep localProgress in sync until SwiftUI re-renders with updated store value
        localProgress = p
        store.setProgress(for:date, taskId:task.id, goalId:goal.id, progress:p)
        // Clear localProgress after store has had time to update (next render cycle)
        DispatchQueue.main.async { localProgress = -1 }
    }

    var body: some View {
        VStack(alignment:.leading, spacing:0) {
            // ── Title row ──────────────────────────────────────
            HStack(alignment:.center, spacing:10) {
                // Tap-to-toggle done circle — large tap target
                Button(action:{
                    let newVal = done ? 0.0 : 1.0
                    let gen = UIImpactFeedbackGenerator(style: .light)
                    gen.impactOccurred()
                    commitProgress(newVal)
                }) {
                    ZStack {
                        // Outer ring — goal color when done, faint when not
                        Circle()
                            .stroke(done ? goal.color : goal.color.opacity(0.30), lineWidth: done ? 2.0 : 1.5)
                            .frame(width:22, height:22)
                        // Fill — solid goal color background when done
                        if done {
                            Circle()
                                .fill(goal.color)
                                .frame(width:22, height:22)
                            // Checkmark on solid color background — always white/dark for contrast
                            Image(systemName:"checkmark")
                                .font(.system(size:9, weight:.bold, design:.rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width:36, height:36)  // large tap target
                    .contentShape(Circle().size(CGSize(width:36, height:36)))
                }
                .buttonStyle(.plain)
                .animation(.spring(response:0.2, dampingFraction:0.7), value:done)

                Text(task.title)
                    .font(.system(size:DSTSize.label, weight:.medium, design:.rounded))
                    .foregroundColor(done ? AppTheme.textTertiary.opacity(0.55) : AppTheme.textPrimary.opacity(0.92))
                    .strikethrough(done && !hasMinutes, color:AppTheme.textTertiary.opacity(0.35))
                    .animation(.easeInOut(duration:0.18), value:done)

                Spacer(minLength:4)

                Text(progressLabel)
                    .font(.system(size:DSTSize.micro, weight:.medium, design: hasMinutes ? .monospaced : .default))
                    .foregroundColor(done ? goal.color.opacity(0.65) : AppTheme.textTertiary.opacity(0.6))
                    .animation(.easeInOut(duration:0.12), value:cur)
                    .monospacedDigit()
            }
            .padding(.leading, -8)  // offset to align circle edge with left margin

            // ── Progress track (only for timed tasks, or show completion) ──
            if hasMinutes || true {
                GeometryReader { geo in
                    ZStack(alignment:.leading) {
                        // Track
                        RoundedRectangle(cornerRadius:3)
                            .fill(goal.color.opacity(0.10))
                            .frame(height:5)

                        // Fill — no animation during drag (prevents jitter), smooth on release
                        let fillW = max(8, geo.size.width * CGFloat(cur))
                        RoundedRectangle(cornerRadius:3)
                            .fill(LinearGradient(
                                colors: done
                                    ? [goal.color.opacity(0.8), goal.color]
                                    : [goal.color.opacity(0.55), goal.color.opacity(0.85)],
                                startPoint:.leading, endPoint:.trailing))
                            .frame(width: cur > 0 ? fillW : 0, height:5)
                            .shadow(color: goal.color.opacity(done ? 0.5 : 0.25),
                                    radius: done ? 5 : 3, x:0, y:0)
                            // Only animate on press/release transitions, not during drag
                            .animation(pressing ? nil : .spring(response:0.25, dampingFraction:0.85), value:cur)

                        // Interactive thumb
                        let thumbX = cur > 0 ? max(0, geo.size.width * CGFloat(cur) - 7) : 0
                        Circle()
                            .fill(pressing ? goal.color : (cur > 0 ? goal.color.opacity(0.9) : goal.color.opacity(0.3)))
                            .frame(width: pressing ? 14 : 10, height: pressing ? 14 : 10)
                            .shadow(color: goal.color.opacity(pressing ? 0.7 : 0.3), radius: pressing ? 6 : 3)
                            .offset(x: thumbX)
                            .animation(pressing ? nil : .spring(response:0.18, dampingFraction:0.7), value:thumbX)
                            .animation(.spring(response:0.15, dampingFraction:0.7), value:pressing)
                    }
                    .frame(maxWidth:.infinity)
                    .frame(height:14)  // tall visible zone
                    .padding(.vertical, 8)  // extend hit area to 30pt total
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance:0, coordinateSpace:.local)
                            .onChanged { v in
                                let w = geo.size.width
                                guard w > 0 else { return }
                                pressing = true
                                let ratio = min(max(v.location.x / w, 0), 1)
                                localProgress = hasMinutes ? ratio : (ratio > 0.5 ? 1.0 : 0.0)
                            }
                            .onEnded { v in
                                pressing = false
                                let w = geo.size.width
                                guard w > 0 else { return }
                                let ratio = min(max(v.location.x / w, 0), 1)
                                let p = hasMinutes ? ratio : (ratio > 0.5 ? 1.0 : 0.0)
                                commitProgress(p)
                            }
                    )
                }
                .frame(height:30)
                .padding(.leading, 28)  // align under title text
            }
        }
        .animation(.easeInOut(duration:0.18), value:done)
    }
}

// ── 今日每日总结：完成情况 + 困难追踪（合并卡）──────────────
// ── 今日每日总结：完成情况 + 困难追踪（含解决心得）──────────
struct TodayDailySummaryCard: View {
    let completed: Int; let total: Int; let rate: Double; let date: Date
    @EnvironmentObject var store: AppStore
    @State private var trackerExpanded = true
    @State private var noteKW: String? = nil  // 当前展开心得输入的 kw

    var state: (active: [String], resolved: [String]) { store.dailyChallengeState(for: date) }
    var hasAny: Bool { !state.active.isEmpty || !state.resolved.isEmpty }
    var allKW: [String] { state.active + state.resolved }

    // 昨日新增（继承自昨天，不是今日新增）
    var inheritedKW: Set<String> {
        let cal = Calendar.current
        let y = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date))!
        return Set(store.dailyChallengeActiveRaw(for: y))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 完成统计行 ──
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(AppTheme.bg3, lineWidth: 3.5).frame(width: 56, height: 56)
                    Circle()
                        .stroke(AppTheme.accent.opacity(0.08), lineWidth: 8)
                        .frame(width: 56, height: 56)
                    Circle().trim(from: 0, to: rate)
                        .stroke(
                            AngularGradient(colors:[AppTheme.accent.opacity(0.7), AppTheme.accent, AppTheme.accent.opacity(0.85)],
                                           center:.center, startAngle:.degrees(-90), endAngle:.degrees(270)),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: 56, height: 56).rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.7), value: rate)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 4, x:0, y:0)
                    Text("\(Int(rate*100))%").font(.system(size: 10, weight: .semibold)).foregroundColor(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(completed)").font(.system(size: 30, weight: .ultraLight)).foregroundColor(AppTheme.textPrimary)
                        Text("/ \(total)").font(.system(size: 13)).foregroundColor(AppTheme.textTertiary)
                        Text(store.t(key: L10n.doneLabel)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                    }
                    Text(rate >= 1.0 ? store.t(key: L10n.allDoneToday) :
                         rate >= 0.5 ? store.t(key: L10n.moreThanHalfway) :
                         total == 0  ? store.t(key: L10n.noTasksYetShort) :
                                       store.t(key: L10n.todayStillYours))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                }
                Spacer()
                if hasAny {
                    let unresolvedCount = state.active.count
                    let pendingColor: Color = unresolvedCount > 0 ? AppTheme.gold : AppTheme.accent
                    // Badge: shows unresolved count OR resolved toggle
                    if !state.resolved.isEmpty {
                        Button(action: { withAnimation(.spring(response: 0.3)) { trackerExpanded.toggle() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: trackerExpanded ? "chevron.up" : "checkmark.circle.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppTheme.accent.opacity(0.65))
                                Text(trackerExpanded
                                     ? store.t(zh:"收起", en:"Hide", ja:"閉じる", ko:"접기", es:"Ocultar")
                                     : "\(state.resolved.count)✓")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppTheme.accent.opacity(0.65))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(AppTheme.accent.opacity(0.07)).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.accent.opacity(0.15), lineWidth: 1))
                        }
                    } else if unresolvedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(pendingColor)
                            Text("\(unresolvedCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(pendingColor)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(pendingColor.opacity(0.08)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(pendingColor.opacity(0.20), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            // ── 待决事项：active 始终显示，resolved 按 trackerExpanded 折叠 ──
            if hasAny {
                Rectangle().fill(AppTheme.border0).frame(height:0.5).padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundColor(AppTheme.gold)
                        Text(store.t(key: L10n.pendingItems)).font(.system(size: 10)).foregroundColor(AppTheme.textTertiary).kerning(1)
                        Spacer()
                        Text(store.t(key: L10n.tapToResolve)).font(.system(size: 9)).foregroundColor(AppTheme.textTertiary.opacity(0.5))
                    }.padding(.bottom, 8)

                    // ── Active items — ALWAYS visible ────────────────────
                    if state.active.isEmpty {
                        Text(store.t(zh:"全部已解决 ✓", en:"All resolved ✓", ja:"すべて解決済み ✓", ko:"모두 해결됨 ✓", es:"Todo resuelto ✓"))
                            .font(.system(size: DSTSize.micro, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.accent.opacity(0.55))
                            .padding(.bottom, 4)
                    } else {
                        ForEach(state.active, id: \.self) { kw in
                            ChallengeTrackRow(
                                kw: kw,
                                solved: false,
                                isInherited: inheritedKW.contains(kw),
                                resolvedDate: nil,
                                note: "",
                                noteExpanded: noteKW == kw,
                                onToggle: { store.toggleDailyChallenge(keyword: kw, on: date) },
                                onNoteToggle: { withAnimation(.spring(response: 0.25)) { noteKW = noteKW == kw ? nil : kw } },
                                onNoteSave: { note in store.updateResolvedNote(keyword: kw, on: date, note: note) },
                                onRenameKW: Calendar.current.isDate(date, inSameDayAs: store.today) ? { newKW in
                                    store.renameTodayChallengeKeyword(from: kw, to: newKW)
                                } : nil
                            )
                            .padding(.bottom, 4)
                        }
                    }

                    // ── Resolved items — toggled by trackerExpanded ───────
                    if !state.resolved.isEmpty {
                        Rectangle()
                            .fill(AppTheme.border0.opacity(0.40))
                            .frame(height: 0.4)
                            .padding(.top, 4).padding(.bottom, 6)
                        // Resolved header — always visible, acts as tap hint
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9)).foregroundColor(AppTheme.accent.opacity(0.65))
                            Text(store.t(zh: "已解决 (\(state.resolved.count))",
                                        en: "Resolved (\(state.resolved.count))",
                                        ja: "解決済み (\(state.resolved.count))",
                                        ko: "해결됨 (\(state.resolved.count))",
                                        es: "Resueltos (\(state.resolved.count))"))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.accent.opacity(0.65))
                            Spacer()
                            // Chevron on the resolved header itself
                            Image(systemName: trackerExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                        }
                        .padding(.bottom, trackerExpanded ? 6 : 0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) { trackerExpanded.toggle() }
                        }

                        // Resolved rows — only when expanded
                        if trackerExpanded {
                            ForEach(state.resolved, id: \.self) { kw in
                                let resolvedEntry = store.dailyChallenges.first(where: {
                                    $0.keyword == kw && $0.resolvedOnDate != nil
                                })
                                ChallengeTrackRow(
                                    kw: kw,
                                    solved: true,
                                    isInherited: inheritedKW.contains(kw),
                                    resolvedDate: resolvedEntry?.resolvedOnDate,
                                    note: resolvedEntry?.resolvedNote ?? "",
                                    noteExpanded: noteKW == kw,
                                    onToggle: { store.toggleDailyChallenge(keyword: kw, on: date) },
                                    onNoteToggle: { withAnimation(.spring(response: 0.25)) { noteKW = noteKW == kw ? nil : kw } },
                                    onNoteSave: { note in store.updateResolvedNote(keyword: kw, on: date, note: note) },
                                    onRenameKW: nil
                                )
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .animation(.spring(response: 0.30, dampingFraction: 0.80), value: trackerExpanded)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                RoundedRectangle(cornerRadius:20)
                    .fill(LinearGradient(colors:[Color.white.opacity(0.03), Color.clear],
                                        startPoint:.topLeading, endPoint:.bottomTrailing))
            }
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border0, lineWidth: 1))
        .shadow(color:.black.opacity(0.3), radius:10, x:0, y:4)
    }
}

// ── 通用实时关键词标签（收获/计划，直接写store）────────────────────
struct LiveKeywordSection: View {
    enum KWType { case gain, plan }
    @EnvironmentObject var store: AppStore
    let kwType: KWType
    let icon: String; let color: Color; let title: String; let hint: String

    @State private var inputText = ""
    @State private var editingKW: String? = nil
    @State private var editDraft = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var editFocused: Bool

    var liveKW: [String] {
        let r = store.review(for: store.today)
        switch kwType {
        case .gain: return r?.gainKeywords ?? []
        case .plan: return r?.tomorrowKeywords ?? []
        }
    }

    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            HStack(spacing:5) {
                Image(systemName:icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(color)
                Spacer()
                if !liveKW.isEmpty {
                    Text("\(liveKW.count)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color.opacity(0.6))
                }
            }
            if liveKW.isEmpty {
                Text(hint).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary).lineSpacing(2)
            } else {
                FlowLayout(spacing:6) {
                    ForEach(liveKW, id:\.self) { kw in chipView(kw:kw) }
                }
            }
            HStack(spacing:8) {
                TextField(store.t(key: L10n.typeKeywordPlan), text:$inputText)
                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                    .focused($inputFocused).onSubmit { addKW() }
                    .padding(.horizontal,11).padding(.vertical,9)
                    .background(AppTheme.bg2).cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius:9).stroke(inputFocused ? color.opacity(0.4) : AppTheme.border1, lineWidth:1))
                if !inputText.isEmpty {
                    Button(action:addKW) {
                        Image(systemName:"return").font(.caption).foregroundColor(color)
                            .frame(width:34,height:34).background(color.opacity(0.12)).cornerRadius(9)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.bg0.opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.15), lineWidth:1))
    }

    @ViewBuilder func chipView(kw: String) -> some View {
        if editingKW == kw {
            HStack(spacing:4) {
                TextField("", text:$editDraft).font(.caption).foregroundColor(color)
                    .focused($editFocused).onSubmit { commitEdit(from:kw) }.frame(minWidth:50,maxWidth:110)
                Button(action:{ commitEdit(from:kw) }) {
                    Image(systemName:"checkmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(AppTheme.accent)
                }
                Button(action:{ deleteKW(kw) }) {
                    Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal,9).padding(.vertical,5)
            .background(color.opacity(0.15)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(0.5),lineWidth:1))
        } else {
            HStack(spacing:4) {
                Text(kw).font(.caption).foregroundColor(color)
                Button(action:{ deleteKW(kw) }) {
                    Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(color.opacity(0.6))
                }
            }
            .padding(.horizontal,9).padding(.vertical,5)
            .background(color.opacity(0.1)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(0.3),lineWidth:1))
            .onLongPressGesture(minimumDuration:0.35) {
                editingKW = kw; editDraft = kw
                DispatchQueue.main.asyncAfter(deadline:.now()+0.05){ editFocused = true }
            }
        }
    }

    func addKW() {
        let kw = inputText.trimmingCharacters(in:.whitespaces)
        guard !kw.isEmpty, !liveKW.contains(kw) else { inputText = ""; return }
        switch kwType {
        case .gain: store.addTodayGainKeyword(kw)
        case .plan: store.addTodayPlanKeyword(kw)
        }
        inputText = ""
    }
    func deleteKW(_ kw: String) {
        editingKW = nil
        switch kwType {
        case .gain: store.removeTodayGainKeyword(kw)
        case .plan: store.removeTodayPlanKeyword(kw)
        }
    }
    func commitEdit(from old: String) {
        let kw = editDraft.trimmingCharacters(in:.whitespaces)
        if kw.isEmpty { deleteKW(old) }
        else if kw != old {
            switch kwType {
            case .gain: store.renameTodayGainKeyword(from:old, to:kw)
            case .plan: store.renameTodayPlanKeyword(from:old, to:kw)
            }
        }
        editingKW = nil
    }
}

// ── 单条困难追踪行（日/周/月/年共用）───────────────────────────
struct ChallengeTrackRow: View {
    let kw: String
    let solved: Bool
    var isInherited: Bool = false
    var resolvedDate: Date? = nil        // nil = 未解决，非nil = 解决日期
    let note: String
    let noteExpanded: Bool
    let onToggle: () -> Void             // 切换解决状态
    let onNoteToggle: () -> Void
    let onNoteSave: (String) -> Void
    var onRenameKW: ((String) -> Void)? = nil  // 长按重命名（仅今日可编辑）

    @EnvironmentObject var store: AppStore
    @State private var noteDraft: String = ""
    @State private var editingName = false   // 长按编辑关键词
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool

    // 是否可以撤销：今天（store.today）划掉的才可以点击撤销
    var canToggle: Bool {
        if !solved { return true }
        guard let rd = resolvedDate else { return true }
        // 用 store.today 而非系统今日，兼容日期模拟器
        return Calendar.current.isDate(rd, inSameDayAs: store.today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行
            HStack(spacing: 8) {
                // 勾选圆圈
                Button(action: { if canToggle { onToggle() } }) {
                    Image(systemName: solved ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundColor(
                            solved ? (canToggle ? AppTheme.accent : AppTheme.textTertiary)
                                   : AppTheme.gold.opacity(0.65)
                        )
                }
                .disabled(!canToggle && solved)  // 过往已解决的 = 灰化不可点

                // 关键词（正常显示 or 长按后的编辑 TextField）
                if editingName {
                    TextField("", text: $nameDraft)
                        .font(.subheadline).foregroundColor(AppTheme.gold)
                        .focused($nameFocused)
                        .onSubmit { commitRename() }
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(AppTheme.gold.opacity(0.1)).cornerRadius(5)
                    Button(action: commitRename) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }
                    Button(action: { editingName = false }) {
                        Image(systemName: "xmark").font(.system(size: 10))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(kw)
                            .font(.subheadline)
                            .foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textPrimary)
                            .strikethrough(solved, pattern: .solid, color: AppTheme.textTertiary)
                            .overlay(
                                solved ? GeometryReader { g in
                                    Rectangle()
                                        .fill(AppTheme.textTertiary.opacity(0.7))
                                        .frame(height: 1)
                                        .frame(width: g.size.width)
                                        .offset(y: g.size.height / 2)
                                } : nil
                            )
                        if solved, !note.isEmpty {
                            Text(note).font(.system(size: 10)).foregroundColor(AppTheme.textTertiary).lineLimit(1)
                        }
                    }
                    // 长按 → 编辑关键词（仅当 onRenameKW 存在时）
                    .onLongPressGesture(minimumDuration: 0.4) {
                        if onRenameKW != nil && !solved {
                            nameDraft = kw
                            editingName = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { nameFocused = true }
                        }
                    }
                }

                Spacer()

                if editingName {
                    EmptyView()
                } else if solved {
                    Button(action: onNoteToggle) {
                        HStack(spacing: 3) {
                            Image(systemName: note.isEmpty ? "pencil" : "text.bubble.fill").font(.system(size: 9))
                            Text(note.isEmpty ? store.t(key: L10n.noteLabel) : store.t(key: L10n.noteDoneLabel)).font(.system(size: 9))
                        }
                        .foregroundColor(note.isEmpty ? AppTheme.textTertiary : AppTheme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(note.isEmpty ? AppTheme.bg3 : AppTheme.accent.opacity(0.1)).cornerRadius(5)
                    }
                } else {
                    Text(store.t(key: L10n.todoShort)).font(.system(size: 9)).foregroundColor(AppTheme.gold)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(solved ? AppTheme.accent.opacity(0.06) : AppTheme.gold.opacity(0.07))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius:10).stroke(solved ? AppTheme.accent.opacity(0.12) : AppTheme.gold.opacity(0.12),lineWidth:0.5))

            // 心得输入区
            if solved && noteExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $noteDraft)
                        .font(.system(size: 13)).foregroundColor(AppTheme.textPrimary)
                        .frame(minHeight: 60, maxHeight: 100)
                        .padding(8).background(AppTheme.bg2).cornerRadius(8)
                    HStack {
                        Spacer()
                        Button(store.t(key: L10n.saveNote)) { onNoteSave(noteDraft); onNoteToggle() }
                            .font(.caption).foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(AppTheme.accent.opacity(0.1)).cornerRadius(7)
                    }
                }
                .padding(.horizontal, 10).padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear { noteDraft = note }
            }
        }
    }

    func commitRename() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && trimmed != kw { onRenameKW?(trimmed) }
        editingName = false
    }
}

struct DailySummaryCard: View {

    let completed:Int;let total:Int;let rate:Double
    @EnvironmentObject var store:AppStore
    var body: some View {
        HStack(spacing:20){
            // Progress ring
            ZStack{
                Circle().stroke(AppTheme.bg3,lineWidth:2.5).frame(width:58,height:58)
                Circle().trim(from:0,to:rate)
                    .stroke(AppTheme.accent,style:StrokeStyle(lineWidth:2.5,lineCap:.round))
                    .frame(width:58,height:58).rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration:0.6),value:rate)
                Text("\(Int(rate*100))%")
                    .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.accent)
                    .monospacedDigit()
            }
            VStack(alignment:.leading,spacing:6){
                // displayLarge token for the hero count
                HStack(alignment:.lastTextBaseline,spacing:4){
                    Text("\(completed)")
                        .font(.system(size:DSTSize.displayLarge, weight:.ultraLight, design:.rounded))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                        .monospacedDigit()
                    Text("/ \(total)")
                        .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                    Text(store.t(key: L10n.doneLabel))
                        .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                        .misty(.tertiary)
                }
                Text(rate >= 1.0 ? store.t(key: L10n.allDoneToday) :
                     rate >= 0.5 ? store.t(key: L10n.moreThanHalfway) :
                     total == 0  ? store.t(key: L10n.noTasksYetShort) :
                                   store.t(key: L10n.todayStillYours))
                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                    .misty(.tertiary)
            }
            Spacer()
        }.padding(18).background(ZStack { RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1); RoundedRectangle(cornerRadius:20).fill(LinearGradient(colors:[Color.white.opacity(0.03),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing)) }).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0,lineWidth:1))
        .shadow(color:.black.opacity(0.25),radius:8,x:0,y:3)
    }
}

// ============================================================
// MARK: - 计划页（标签块 + AI建议 + 拖拽）
// ============================================================

// 任务来源：正常任务 or 从AI建议区拖来的
enum TaskChipSource { case normal(GoalTask, Goal, Date); case aiSuggestion(String, Goal) }

struct PlanChipDrag: Equatable {
    var taskId: UUID?          // 正常任务
    var aiText: String?        // AI建议文字
    var goalId: UUID
    var fromDate: Date?        // nil = 来自AI建议区
    var position: CGPoint = .zero
    var originPosition: CGPoint = .zero   // starting position for bounce-back animation
}

struct AddTaskToPlanItem: Identifiable { let id=UUID(); let date:Date; let goal:Goal }

// GoalsScrollOffsetKey already declared at top of file

struct DayFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct PlanView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @State private var selectedGoalIds: Set<UUID> = []
    @State private var aiChips: [PlanChipItem] = []            // AI建议标签
    @State private var aiRefreshSeed: Int = 0                   // 刷新计数，确保每次得到不同建议
    @State private var chipDrag: PlanChipDrag? = nil           // 当前拖拽中的chip
    @State private var dayFrames: [String: CGRect] = [:]       // 每天row的全局frame
    @State private var addingTask: AddTaskToPlanItem? = nil
    @State private var editingItem: PlanEditItem? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil     // 自动滚动
    @State private var screenHeight: CGFloat = 812             // 屏幕高度（GeometryReader更新）
    @State private var aiSectionFrame: CGRect = .zero          // AI建议区全局frame（判断拖回）
    @State private var chipBouncing = false                    // 弹回动画状态

    var weekDates: [Date] { store.weekDates() }
    let labels_zh = ["周一","周二","周三","周四","周五","周六","周日"]
    let labels_en = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    var selectedGoals: [Goal] { store.goals.filter { selectedGoalIds.contains($0.id) } }

    // 悬浮跟随卡 — 使用全局坐标叠加在最顶层
    @ViewBuilder var floatingChip: some View {
        if let d = chipDrag, d.position != .zero {
            let title: String = {
                if let t = d.aiText { return t }
                return store.goals.first(where:{$0.id==d.goalId})?.tasks.first(where:{$0.id==d.taskId})?.title ?? ""
            }()
            let color = store.goals.first(where:{$0.id==d.goalId})?.color ?? AppTheme.accent
            // 用 GeometryReader 把 global 坐标转换为 overlay 本地坐标
            GeometryReader { geo in
                Text(title)
                    .font(.system(size:DSTSize.caption,weight:.semibold, design:.rounded))
                    .foregroundColor(color)
                    .padding(.horizontal,12).padding(.vertical,7)
                    .background(
                        RoundedRectangle(cornerRadius:8)
                            .fill(AppTheme.bg1)
                            .shadow(color:color.opacity(0.35),radius:14,y:6)
                    )
                    .overlay(RoundedRectangle(cornerRadius:8).stroke(color.opacity(0.5),lineWidth:1.2))
                    .fixedSize()
                    .position(
                        x: d.position.x - geo.frame(in:.global).minX,
                        y: d.position.y - geo.frame(in:.global).minY - 26
                    )
                    .scaleEffect(1.08)
                    .animation(.spring(response:0.2), value:d.position)
            }
            .allowsHitTesting(false)
            .zIndex(1000)
        }
    }

    // 查找落点对应的日期 — 用最近距离匹配，不只是严格contains（解决边缘miss问题）
    func targetDate(for pos: CGPoint) -> Date? {
        var bestDate: Date? = nil
        var bestDist: CGFloat = .infinity
        for (key, frame) in dayFrames {
            guard let ts = Double(key) else { continue }
            // 水平方向严格在frame内，垂直方向用中心距离找最近
            let expandedFrame = frame.insetBy(dx:-20, dy:0)
            if expandedFrame.contains(CGPoint(x:pos.x, y:frame.midY)) {
                let dist = abs(pos.y - frame.midY)
                if dist < bestDist {
                    bestDist = dist
                    bestDate = Date(timeIntervalSince1970: ts)
                }
            }
        }
        // 如果没有水平匹配，用垂直最近的
        if bestDate == nil {
            for (key, frame) in dayFrames {
                guard let ts = Double(key) else { continue }
                let dist = abs(pos.y - frame.midY)
                if dist < bestDist && dist < frame.height * 2 {
                    bestDist = dist
                    bestDate = Date(timeIntervalSince1970: ts)
                }
            }
        }
        return bestDate
    }

    // ── Drop 事务（Transaction Drop）──────────────────────────
    // 规则：先做全部校验，只有全部通过才写入；失败则 rollback（标签回到原位置）
    //
    // 校验顺序：
    // 1. 目标日期有效且不是过去（isPast 检查）
    // 2. 目标日期在本周范围内
    // 3. 不同天（schedule chip），或来源是 AI
    // 4. 无重复任务名（dedup 检查）
    // 5. 写入数据层成功
    func handleDrop(at pos: CGPoint) {
        guard let d = chipDrag else { return }
        guard let target = targetDate(for: pos) else {
            dropFailFeedback(); return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: store.today)
        let targetDay = cal.startOfDay(for: target)
        let isPastDay = targetDay < today

        if let tid = d.taskId, let fromDate = d.fromDate {
            // ── Schedule chip drop ──
            // Validation 1: Must be in weekDates
            guard weekDates.contains(where:{ cal.isDate($0,inSameDayAs:target) }) else {
                dropFailFeedback(); return
            }
            // Validation 2: Can't drop on past days (today is allowed)
            if isPastDay {
                dropFailFeedback(); return
            }
            // Validation 3: Same day = silently return to origin
            if cal.isDate(fromDate, inSameDayAs:target) {
                withAnimation(.spring(response:0.25)) { chipDrag = nil }; return
            }
            // Validation 4: Duplicate check - if target already has same-named task
            let dragTitle = store.goals.first(where:{$0.id==d.goalId})?.tasks.first(where:{$0.id==tid})?.title ?? ""
            if let g = store.goals.first(where:{$0.id==d.goalId}) {
                let targetTasks = store.tasks(for:target, goal:g)
                if !dragTitle.isEmpty && targetTasks.contains(where:{ $0.title == dragTitle && $0.id != tid }) {
                    dropFailFeedback(); return
                }
            }
            // All validation passed → write
            store.moveTask(tid, goalId:d.goalId, from:fromDate, to:target)
            store.trackDragTask(goalId: d.goalId, taskId: tid, fromDate: fromDate, toDate: target)
            withAnimation(.spring(response:0.25)) { chipDrag = nil }
        } else if let text = d.aiText {
            // ── AI chip drop ──
            // Validation 1: Can't drop on past days
            if isPastDay {
                dropFailFeedback(); return
            }
            // Validation 2: Must be in weekDates
            guard weekDates.contains(where:{ cal.isDate($0,inSameDayAs:target) }) else {
                dropFailFeedback(); return
            }
            // Validation 3: Duplicate check
            if let g = store.goals.first(where:{$0.id==d.goalId}) {
                let targetTasks = store.tasks(for:target, goal:g)
                if targetTasks.contains(where:{ $0.title == text }) {
                    dropFailFeedback(); return
                }
            }
            // All validation passed → write THEN remove from AI chips
            store.addPinnedTask(goalId:d.goalId, title:text, on:target)
            Analytics.shared.track(.plan_ai_accept(
                goalId: d.goalId, taskTitle: text, targetDate: target, timeBlock: .unset))
            withAnimation(.spring(response:0.3)) {
                aiChips.removeAll { $0.text == text && $0.goal.id == d.goalId }
            }
            withAnimation(.spring(response:0.25)) { chipDrag = nil }
        } else {
            withAnimation(.spring(response:0.25)) { chipDrag = nil }
        }
    }

    // Drop 失败时：震动 + 弹回动画
    func dropFailFeedback() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        // Animate chip back to origin, then clear
        guard let origin = chipDrag?.originPosition else {
            withAnimation(.spring(response:0.25)) { chipDrag = nil }
            return
        }
        withAnimation(.spring(response:0.35, dampingFraction:0.65)) {
            chipDrag?.position = origin
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.easeOut(duration:0.18)) { chipDrag = nil }
        }
    }

    // AI chip 拖拽结束时：
    // - 落在某一天 → 添加任务，从 AI 列表移除
    // - 其他位置（包括拖回 AI 区） → 保留在 AI 列表，仅清除拖拽状态
    func handleChipDragEnd(at pos: CGPoint) {
        guard chipDrag != nil else { return }
        // 落在某天行内 → 拖入并移除
        if dayFrames.values.contains(where:{ $0.contains(pos) || abs($0.midY - pos.y) < $0.height * 0.5 }) {
            handleDrop(at: pos)
        } else {
            // 未落在有效天（含拖回 AI 区、拖到空白处）→ 保留 chip，弹回
            withAnimation(.spring(response:0.35, dampingFraction:0.7)) { chipDrag = nil }
        }
    }

    // 目标选择区
    @ViewBuilder var goalSelectorSection: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text(store.t(key: L10n.selectGoalsLabel))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).kerning(1.5)
                Spacer()
                if !selectedGoalIds.isEmpty {
                    aiTipsButton
                }
            }
            goalChipsRow
        }
        .padding(.horizontal).padding(.top,10).padding(.bottom,14)
    }

    @ViewBuilder var aiTipsButton: some View {
        Button(action: generateAIChips) {
            HStack(spacing:4) {
                Image(systemName: aiChips.isEmpty ? "sparkles" : "arrow.clockwise")
                    .font(.system(size: DSTSize.nano, weight: .medium, design: .rounded))
                Text(aiChips.isEmpty ? store.t(key: L10n.aiTips) : L10n.refreshTips(store.language))
                    .font(.system(size: DSTSize.micro, weight: .regular, design: .rounded))
            }
            .padding(.horizontal,10).padding(.vertical,5)
            .background(AppTheme.bg3)
            .foregroundColor(AppTheme.accent.opacity(0.85))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius:8).stroke(AppTheme.accent.opacity(0.22), lineWidth:0.7))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder var goalChipsRow: some View {
        ScrollViewReader { hProxy in
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:8) {
                    ForEach(store.goals) { goal in
                        GoalSelectorChip(goal:goal,
                            isSelected:selectedGoalIds.contains(goal.id),
                            onTap:{
                                withAnimation(.spring(response:0.2)){
                                    let wasSelected = selectedGoalIds.contains(goal.id)
                                    if wasSelected { selectedGoalIds.remove(goal.id) }
                                    else {
                                        selectedGoalIds.insert(goal.id)
                                        DispatchQueue.main.asyncAfter(deadline:.now()+0.1) {
                                            withAnimation(.easeInOut(duration:0.35)) {
                                                hProxy.scrollTo(goal.id, anchor:.center)
                                            }
                                        }
                                    }
                                    aiChips = []
                                    Analytics.shared.track(.plan_goal_filter_toggle(
                                        goalId: goal.id, goalTitle: goal.title, isSelected: !wasSelected))
                                }
                            })
                        .id(goal.id)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    func generateAIChips() {
        let isRefresh = !aiChips.isEmpty
        // On refresh: bump seed so taskSuggestions rotates to different items
        if isRefresh { aiRefreshSeed += 1 }

        let sugs = selectedGoals.flatMap { g in
            store.taskSuggestions(for: g, rotationOffset: aiRefreshSeed).prefix(4).map { s in
                PlanChipItem(id: UUID(), text: s, goal: g, date: nil)
            }
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if isRefresh {
                // Full replacement on refresh — always show new content
                aiChips = sugs
            } else {
                // First load: smooth merge (avoid full flash)
                let oldTexts = Set(aiChips.map { "\($0.goal.id)|\($0.text)" })
                let newItems = sugs.filter { s in !oldTexts.contains("\(s.goal.id)|\(s.text)") }
                let keepTexts = Set(sugs.map { "\($0.goal.id)|\($0.text)" })
                aiChips = aiChips.filter { keepTexts.contains("\($0.goal.id)|\($0.text)") } + newItems
            }
        }
        Analytics.shared.track(.plan_ai_suggest(
            selectedGoalIds: Array(selectedGoalIds), suggestionsCount: sugs.count))
    }

    // AI建议区
    @ViewBuilder var aiSuggestSection: some View {
        if !aiChips.isEmpty {
            VStack(alignment:.leading,spacing:8) {
                HStack(spacing:4) {
                    Image(systemName:"sparkles").font(.caption2).foregroundColor(AppTheme.accent)
                    Text(store.t(key: L10n.aiTips)).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                }
                PlanChipFlow(chips:aiChips, chipDrag:$chipDrag, onDoubleTap:{ _ in },
                             isAIArea:true,
                             onDeleteAI:{ chip in withAnimation{ aiChips.removeAll{$0.id==chip.id} } },
                             onDrop:{ pos in handleChipDragEnd(at:pos) })
                    .environmentObject(store)
                Text(store.t(key: L10n.doubleTapEdit))
                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.6))
            }
            .padding(.horizontal).padding(.vertical,12)
            .background(AppTheme.bg1)
            .overlay(Rectangle().fill(AppTheme.border0).frame(height:1),alignment:.bottom)
        }
    }

    // ── 每天行 — 万家灯火：分离卡片，密而不乱 ─────────────────
    @ViewBuilder var weekSection: some View {
        VStack(spacing: 6) {  // 6pt gap = windows in the night city
            ForEach(weekDates.indices, id:\.self) { i in
                let date = weekDates[i]
                let lbl: String = {
                    let cal = Calendar.current
                    let wd = cal.component(.weekday, from: date)
                    let idx = wd - 1
                    return L10n.weekdayFull(store.language)[safe: idx] ?? labels_zh[safe: i] ?? "?"
                }()
                let key = "\(Calendar.current.startOfDay(for:date).timeIntervalSince1970)"
                let isPast = Calendar.current.startOfDay(for:date) < Calendar.current.startOfDay(for:store.today)

                PlanDayRow2(
                    date:date, label:lbl,
                    isToday:Calendar.current.isDate(date, inSameDayAs:store.today),
                    isPast:isPast,
                    chipDrag:$chipDrag,
                    onReportFrame:{ frame in dayFrames[key] = frame },
                    onEdit:{ task,goal in editingItem=PlanEditItem(task:task,goal:goal,date:date) },
                    onAddTask:{ goal in addingTask=AddTaskToPlanItem(date:date,goal:goal) },
                    onDrop:{ handleDrop(at:$0) }
                )
                .environmentObject(store)
                // Each day card: rounded glass card, subtle border, micro shadow
                // Past cards get a subtle dark overlay — legible but clearly behind us
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isPast
                            ? AppTheme.bg1.opacity(0.70)   // dimmer for past
                            : Calendar.current.isDate(date, inSameDayAs: store.today)
                                ? AppTheme.bg2.opacity(1.0)   // today: brightest
                                : AppTheme.bg1.opacity(1.0))  // future: bright
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            Calendar.current.isDate(date, inSameDayAs:store.today)
                                ? AppTheme.accent.opacity(0.55)
                                : isPast
                                ? AppTheme.border0.opacity(0.35)
                                : AppTheme.border0.opacity(0.85),
                            lineWidth: Calendar.current.isDate(date, inSameDayAs:store.today) ? 1.5 : 0.5
                        )
                )
                .shadow(
                    color: Calendar.current.isDate(date, inSameDayAs:store.today)
                        ? AppTheme.accent.opacity(0.10)
                        : isPast
                        ? Color.black.opacity(0.06)
                        : Color.black.opacity(0.14),
                    radius: Calendar.current.isDate(date, inSameDayAs:store.today) ? 8 : 3,
                    x: 0, y: 2
                )
                // Frame tracking for drag-drop
                .background(GeometryReader{ geo in
                    Color.clear
                        .preference(key:DayFramePreferenceKey.self,
                                    value:[key: geo.frame(in:.global)])
                })
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onPreferenceChange(DayFramePreferenceKey.self){ frames in
            for (k,v) in frames { dayFrames[k] = v }
        }
    }

    // aiSuggestSection 的高度（动态由 stickyHeaderHeight 统一管理）

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack(alignment:.top) {
                    VStack(spacing:0) {
                        // ── Glass imprint page title ────────────────────
                        PageHeaderView(title: store.t(key: L10n.plan), accentColor: AppTheme.accent)
                            .background(AppTheme.bg0)

                        // ── 目标选择 + AI建议：固定不滚动 ──────
                        VStack(spacing:0) {
                            goalSelectorSection
                                .background(AppTheme.bg0)
                            if !aiChips.isEmpty {
                                aiSuggestSection
                                    .background(
                                        GeometryReader { g in
                                            Color.clear
                                                .onAppear { aiSectionFrame = g.frame(in:.global) }
                                                .onChange(of: g.size) { _, _ in aiSectionFrame = g.frame(in:.global) }
                                        }
                                    )
                                    .transition(.opacity.combined(with:.move(edge:.top)))
                            }
                            Rectangle().fill(AppTheme.border0).frame(height:0.5)
                        }
                        .animation(.spring(response:0.3), value:aiChips.count)

                        // ── 周几内容：独立可滚动 ────────────────
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing:0) {
                                    Color.clear.frame(height:1).id("plan_top")
                                    weekSection.padding(.top, 8)
                                    Spacer(minLength:80).id("plan_bottom")
                                }
                            }
                            .onAppear { scrollProxy = proxy }
                        }
                    }
                    // floatingChip 叠在最顶层
                    floatingChip
                }
                .onAppear { screenHeight = geo.size.height }
            }
            .coordinateSpace(name:"planView")
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .sheet(item:$editingItem){ item in
                PlanTaskEditSheet(task:item.task,goal:item.goal,date:item.date,store:store).environmentObject(store).environmentObject(pro)
            }
            .sheet(item:$addingTask){ item in
                PlanAddTaskSheet(goal:item.goal,date:item.date).environmentObject(store).environmentObject(pro)
            }
        }
        .animation(.spring(response:0.3),value:aiChips.count)
        .onAppear { Analytics.shared.currentScreen = .plan }
        // 拖拽到底部/顶部时自动滚动
        .onChange(of: chipDrag?.position.y) { _, y in
            guard let y = y, chipDrag != nil else { return }
            // 顶部安全区高度（导航栏+目标选择器+AI建议栏）
            let safeTop: CGFloat = aiChips.isEmpty ? 140 : 200
            // 向下滚动：接近底部 100pt 触发
            if y > screenHeight - 100 {
                withAnimation(.easeInOut(duration:0.3)) {
                    scrollProxy?.scrollTo("plan_bottom", anchor:.bottom)
                }
            }
            // 向上滚动：进入顶部区域即触发（更灵敏）
            else if y < safeTop + 20 {
                withAnimation(.easeInOut(duration:0.3)) {
                    scrollProxy?.scrollTo("plan_top", anchor:.top)
                }
            }
        }
    }
}

// 目标选择chip（独立组件避免body过长）
struct GoalSelectorChip: View {
    let goal: Goal; let isSelected: Bool; let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(goal.color).frame(width: 6, height: 6)
            Text(goal.title)
                .font(.system(size: DSTSize.caption, weight: isSelected ? .medium : .regular, design: .rounded))
                .lineLimit(1)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: DSTSize.nano, weight: .bold, design: .rounded))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isSelected ? goal.color.opacity(0.16) : AppTheme.bg2)
                // press feedback: local highlight only, never dims parent
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(pressed ? 0.07 : 0))
                )
        )
        .foregroundColor(isSelected ? goal.color : AppTheme.textSecondary.opacity(0.80))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? goal.color.opacity(0.45) : AppTheme.border0.opacity(0.8),
                        lineWidth: isSelected ? 1.0 : 0.6)
        )
        .scaleEffect(pressed ? 0.96 : (isSelected ? 1.02 : 1.0))
        .animation(.spring(response: 0.18, dampingFraction: 0.75), value: pressed)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed { pressed = true }
                }
                .onEnded { _ in
                    pressed = false
                    onTap()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        )
    }
}

// Flow布局辅助
struct FlowLayout: Layout {
    var spacing: CGFloat = 7
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 300
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at:CGPoint(x:x,y:y),proposal:ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}

// chip数据模型
struct PlanChipItem: Identifiable {
    let id: UUID; let text: String; let goal: Goal; let date: Date?
}

// Flow形式的chip区域（AI区 & 周几区 共用）
struct PlanChipFlow: View {
    let chips: [PlanChipItem]
    @Binding var chipDrag: PlanChipDrag?
    let onDoubleTap: (PlanChipItem) -> Void
    var isAIArea: Bool = false
    var onDeleteAI: ((PlanChipItem)->Void)? = nil
    var onDrop: ((CGPoint)->Void)? = nil
    @EnvironmentObject var store: AppStore

    var body: some View {
        FlowLayout(spacing:6) {
            ForEach(chips) { chip in
                PlanChipView(chip:chip, chipDrag:$chipDrag,
                             onDoubleTap:{ onDoubleTap(chip) },
                             isAIArea:isAIArea,
                             onDeleteAI:onDeleteAI != nil ? { onDeleteAI?(chip) } : nil,
                             onDrop:onDrop)
                    .environmentObject(store)
            }
        }
    }
}

struct PlanChipView: View {
    let chip: PlanChipItem
    @Binding var chipDrag: PlanChipDrag?
    let onDoubleTap: () -> Void
    var isAIArea: Bool = false
    var onDeleteAI: (()->Void)? = nil
    var onDrop: ((CGPoint)->Void)? = nil
    @EnvironmentObject var store: AppStore
    @State private var showEdit    = false
    @State private var showJournal = false
    @State private var lastGlobalPos: CGPoint = .zero

    var isDraggingThis: Bool {
        guard let d = chipDrag else { return false }
        if let tid = d.taskId { return tid == chip.id }
        if let t = d.aiText { return t == chip.text && d.goalId == chip.goal.id }
        return false
    }

    var isDone: Bool {
        guard let date = chip.date else { return false }
        return store.progress(for: date, taskId: chip.id) >= 1.0
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(chip.text)
                .font(.system(size: DSTSize.caption,
                              weight: isDone ? .regular : .medium,
                              design: .rounded))
                .foregroundColor(
                    isDraggingThis        ? chip.goal.color.opacity(0.28)
                    : isDone && !isAIArea ? chip.goal.color.opacity(0.32)
                    :                       chip.goal.color.opacity(1.0)
                )
                .strikethrough(isDone && !isAIArea, color: chip.goal.color.opacity(0.20))
                .lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
            isDone && !isAIArea
                ? chip.goal.color.opacity(isDraggingThis ? 0.03 : 0.045)   // done: very faint bg
                : chip.goal.color.opacity(isDraggingThis ? 0.06 : 0.16)    // incomplete: richer bg
        )
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(chip.goal.color.opacity(
                    isDraggingThis        ? 0.12
                    : isDone && !isAIArea ? 0.10          // done: barely visible border
                    :                       0.38           // incomplete: strong border
                ), lineWidth: isDone && !isAIArea ? 0.5 : 0.9)
        )
        .shadow(color: chip.goal.color.opacity(
            isDraggingThis ? 0
            : isDone       ? 0
            : isAIArea     ? 0.06
            :                0.16                          // incomplete: subtle glow
        ), radius: 3, x: 0, y: 1)
        .scaleEffect(isDraggingThis ? 0.88 : 1.0)
        .animation(.spring(response: 0.2), value: isDraggingThis)
        .animation(.easeInOut(duration: 0.25), value: isDone)
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .sequenced(before: DragGesture(minimumDistance:0, coordinateSpace:.global))
                    .onChanged { val in
                        switch val {
                        case .second(true, let drag):
                            guard let drag = drag else { return }
                            lastGlobalPos = drag.location
                            if chipDrag == nil {
                                withAnimation(.spring(response:0.18)) {
                                    if isAIArea {
                                        chipDrag = PlanChipDrag(taskId:nil, aiText:chip.text, goalId:chip.goal.id, fromDate:nil, position:drag.location, originPosition:drag.startLocation)
                                    } else {
                                        chipDrag = PlanChipDrag(taskId:chip.id, aiText:nil, goalId:chip.goal.id, fromDate:chip.date, position:drag.location, originPosition:drag.startLocation)
                                    }
                                }
                            }
                            chipDrag?.position = drag.location
                        default: break
                        }
                    }
                    .onEnded { val in
                        switch val {
                        case .second(true, _): onDrop?(lastGlobalPos)
                        default: withAnimation(.spring(response:0.25)) { chipDrag = nil }
                        }
                    }
            )
            // Context menu — long-press reveals actions
            .contextMenu {
                // Edit
                Button { showEdit = true } label: {
                    Label(store.t(zh:"编辑",en:"Edit",ja:"編集",ko:"편집",es:"Editar"), systemImage:"pencil")
                }
                // Insight journal (real tasks only)
                if !isAIArea {
                    Button { showJournal = true } label: {
                        Label(store.t(zh:"写心得",en:"Add Insight",ja:"気づきを書く",ko:"인사이트 추가",es:"Reflexión"), systemImage:"lightbulb.fill")
                    }
                }
                Divider()
                // Delete — works for both AI chips and regular chips
                Button(role: .destructive) {
                    if isAIArea {
                        onDeleteAI?()
                    } else if let date = chip.date {
                        store.trackDeleteTask(
                            goalId: chip.goal.id, goalTitle: chip.goal.title,
                            taskId: chip.id, taskTitle: chip.text,
                            date: date,
                            wasPinned: store.goals.first(where:{$0.id==chip.goal.id})?
                                .tasks.first(where:{$0.id==chip.id})?.pinnedDate != nil
                        )
                        store.deleteTaskOnDate(chip.id, goalId: chip.goal.id, on: date)
                    }
                } label: {
                    Label(
                        store.t(zh:"从本日删除",en:"Remove from Day",ja:"この日から削除",ko:"이 날에서 삭제",es:"Eliminar del día"),
                        systemImage:"trash"
                    )
                }
            }
            // Double-tap → edit sheet (which contains a reliable delete button)
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { showEdit = true }
            )
            .sheet(isPresented:$showEdit) {
                PlanChipEditSheet(chip:chip, isAIArea:isAIArea, onDeleteAI:onDeleteAI)
                    .environmentObject(store)
            }
            .sheet(isPresented:$showJournal) {
                PlanJournalSheet(
                    date: chip.date ?? store.today,
                    goalId: chip.goal.id, goalTitle: chip.goal.title, goalColor: chip.goal.color,
                    taskId: chip.id, taskTitle: chip.text
                ).environmentObject(store)
            }
    }
}

struct PlanChipEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    let chip: PlanChipItem
    var isAIArea: Bool = false
    var onDeleteAI: (()->Void)? = nil
    @State private var title: String
    @State private var selectedGoalId: UUID
    @State private var showDeleteConfirm = false

    init(chip: PlanChipItem, isAIArea: Bool = false, onDeleteAI:(()->Void)?=nil) {
        self.chip = chip; self.isAIArea = isAIArea; self.onDeleteAI = onDeleteAI
        _title = State(initialValue: chip.text)
        _selectedGoalId = State(initialValue: chip.goal.id)
    }

    var selectedGoal: Goal? { store.goals.first(where:{$0.id==selectedGoalId}) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    // 任务名
                    VStack(alignment:.leading,spacing:7){
                        SectionLabel(store.t(key: L10n.taskNameShort),icon:"pencil")
                        TextField(store.t(key: L10n.taskNamePH),text:$title)
                            .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12).foregroundColor(AppTheme.textPrimary)
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
                    }
                    // 切换目标
                    VStack(alignment:.leading,spacing:8){
                        SectionLabel(store.t(key: L10n.goalBelongsTo),icon:"target")
                        ScrollView(.horizontal,showsIndicators:false){
                            HStack(spacing:8){
                                ForEach(store.goals){ goal in
                                    let sel = goal.id == selectedGoalId
                                    Button(action:{selectedGoalId=goal.id}){
                                        HStack(spacing:5){
                                            Circle().fill(goal.color).frame(width:6,height:6)
                                            Text(goal.title).font(.caption).lineLimit(1)
                                            if sel { Image(systemName:"checkmark").font(.system(size:DSTSize.micro,weight:.bold, design:.rounded)) }
                                        }
                                        .padding(.horizontal,10).padding(.vertical,7)
                                        .background(sel ? goal.color.opacity(0.18):AppTheme.bg2)
                                        .foregroundColor(sel ? goal.color:AppTheme.textSecondary)
                                        .cornerRadius(20)
                                        .overlay(RoundedRectangle(cornerRadius:20).stroke(sel ? goal.color.opacity(0.5):AppTheme.border0,lineWidth:sel ? 1.5:1))
                                    }
                                }
                            }
                        }
                    }
                    // 删除
                    if !isAIArea {
                        Button(action:{showDeleteConfirm=true}){
                            HStack(spacing:6){ Image(systemName:"trash"); Text(store.t(key: L10n.deleteTaskLabel)) }
                                .font(.subheadline).frame(maxWidth:.infinity).padding(.vertical,12)
                                .background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(12)
                        }
                    }
                    Spacer(minLength:20)
                }.padding(20)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(key: L10n.editTask)).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){ Button(store.t(key: L10n.cancel)){dismiss()}.foregroundColor(AppTheme.textSecondary) }
                ToolbarItem(placement:.navigationBarTrailing){
                    Button(store.t(key: L10n.save)){
                        guard !title.isEmpty else { return }
                        let newGoalId = selectedGoalId
                        let oldGoalId = chip.goal.id
                        if let date = chip.date {
                            if newGoalId != oldGoalId {
                                // Cross-goal move: delete from old goal on this date, pin to new goal on this date
                                store.deleteTaskOnDate(chip.id, goalId:oldGoalId, on:date)
                                store.addPinnedTask(goalId:newGoalId, title:title, on:date)
                            } else {
                                store.updateTaskOverride(chip.id, goalId:oldGoalId, on:date, title:title, minutes:nil)
                            }
                        }
                        dismiss()
                    }.foregroundColor(selectedGoal?.color ?? AppTheme.accent).fontWeight(.medium).disabled(title.isEmpty)
                }
            }
            .alert(store.t(key: L10n.deleteTask),isPresented:$showDeleteConfirm){
                Button(store.t(key: L10n.delete),role:.destructive){
                    if isAIArea { onDeleteAI?() }
                    else if let date = chip.date { store.deleteTaskOnDate(chip.id, goalId:chip.goal.id, on:date) }
                    dismiss()
                }
                Button(store.t(key: L10n.cancel),role:.cancel){}
            }
        }
    }
}

struct PlanEditItem:Identifiable{let id=UUID();let task:GoalTask;let goal:Goal;let date:Date}

struct PlanDayRow2: View {
    let date: Date; let label: String; let isToday: Bool; var isPast: Bool = false
    @Binding var chipDrag: PlanChipDrag?
    let onReportFrame: (CGRect) -> Void
    let onEdit: (GoalTask, Goal) -> Void
    let onAddTask: (Goal) -> Void
    let onDrop: (CGPoint) -> Void
    @EnvironmentObject var store: AppStore
    @State private var showGoalPicker = false
    @State private var collapsed: Bool = true

    // ── Data ──────────────────────────────────────────────────────────
    var allPairs: [(Goal,GoalTask)] {
        store.goals(for:date).flatMap { g in store.tasks(for:date,goal:g).map{(g,$0)} }
    }
    var completionRate: Double { store.completionRate(for:date) }
    var doneCount: Int  { allPairs.filter { store.progress(for:date,taskId:$0.1.id) >= 1.0 }.count }
    var totalCount: Int { allPairs.count }
    var dateNum: String { "\(Calendar.current.component(.day,from:date))" }
    var isDragOver: Bool { chipDrag != nil }
    var isDone: Bool { totalCount > 0 && doneCount == totalCount }
    var pctInt:  Int { totalCount > 0 ? Int(Double(doneCount)/Double(totalCount)*100) : 0 }
    var chips: [PlanChipItem] {
        // Sort: incomplete tasks first (brighter, more urgent), done tasks last (dimmed)
        allPairs
            .map { PlanChipItem(id:$0.1.id, text:$0.1.title, goal:$0.0, date:date) }
            .sorted { a, b in
                let aDone = store.progress(for:date, taskId:a.id) >= 1.0
                let bDone = store.progress(for:date, taskId:b.id) >= 1.0
                if aDone == bDone { return false }  // preserve original order within each group
                return !aDone  // incomplete (false) sorts before done (true)
            }
    }
    var showPastOverlay: Bool { chipDrag != nil && isPast }

    // ── Design tokens (local, single source) ─────────────────────────
    // Row height: generous enough to breathe, tight enough to scan
    private let ROW_H:    CGFloat = 56
    // Date column width: fits 2-digit date at 24pt with margin
    private let DATE_W:   CGFloat = 54

    // Semantic colours derived from state
    private var accentCol: Color {
        isDone ? AppTheme.gold : isToday ? AppTheme.accent : AppTheme.textSecondary.opacity(0.9)
    }
    private var chipsBg: Color { isDragOver ? AppTheme.accent.opacity(0.04) : Color.clear }

    // ════════════════════════════════════════════════════════════════════
    // MARK: Date Column
    // Three-tier contrast:
    //   Today  — accent glow, bold date, glass pill
    //   Future — clearly readable, not competing
    //   Past   — visibly dimmed but still legible
    // ════════════════════════════════════════════════════════════════════
    @ViewBuilder private var dateColumn: some View {
        ZStack {
            if isToday {
                // Layer 1: deep accent fill
                RoundedRectangle(cornerRadius:11, style:.continuous)
                    .fill(AppTheme.accent.opacity(0.10))
                // Layer 2: specular top-edge highlight
                RoundedRectangle(cornerRadius:11, style:.continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.09), Color.clear],
                        startPoint:.top, endPoint:.center
                    ))
                // Layer 3: accent border hairline
                RoundedRectangle(cornerRadius:11, style:.continuous)
                    .stroke(AppTheme.accent.opacity(0.30), lineWidth:0.8)
            }
            VStack(spacing:2) {
                // Weekday label
                Text(label)
                    .font(.system(size:DSTSize.micro, weight: isToday ? .semibold : isPast ? .regular : .medium, design:.rounded))
                    .kerning(0.4)
                    .foregroundColor(
                        isToday  ? AppTheme.accent.opacity(0.92)
                        : isPast ? AppTheme.textTertiary.opacity(0.55)
                        :          AppTheme.textSecondary.opacity(0.85)
                    )
                    .shadow(color: isToday ? AppTheme.accent.opacity(0.35) : .clear, radius:3)

                // Date number
                Text(dateNum)
                    .font(.system(
                        size:   isToday ? 24 : DSTSize.displaySmall,
                        weight: isToday ? .bold : isPast ? .light : .regular,
                        design: .rounded))
                    .foregroundColor(
                        isToday  ? AppTheme.accent.opacity(0.95)
                        : isPast ? AppTheme.textTertiary.opacity(0.58)
                        :          AppTheme.textPrimary.opacity(0.88)
                    )
                    .monospacedDigit()
                    .shadow(color: isToday ? AppTheme.accent.opacity(0.45) : .clear, radius:5)
                    .shadow(color: isToday ? AppTheme.accent.opacity(0.15) : .clear, radius:10)
            }
        }
        .frame(width:DATE_W)
        .shadow(color: isToday ? AppTheme.accent.opacity(0.18) : .clear, radius:12, x:0, y:0)
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: Collapsed Summary
    //
    // Layout (left → right, vertically centered in ROW_H):
    //
    //   [leading pad] [✦ sparkle (if done, accent green) + % bold] [track flex] [✓ (if done)] [chevron]
    //
    //   • sparkle + % are LEFT of the track — they anchor the visual weight
    //   • sparkle uses accent green glow (isDone only), strictly clipped inside card
    //   • track fills remaining space
    //   • checkmark appears only when isDone (strict badge rule: done == total > 0)
    // ════════════════════════════════════════════════════════════════════
    @ViewBuilder private var collapsedSummary: some View {
        HStack(alignment:.center, spacing:0) {
            if chips.isEmpty {
                Text(store.t(key:L10n.noTasks))
                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                    .italic()
                    .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                    .frame(maxWidth:.infinity, alignment:.leading)
                    .frame(height:ROW_H)
                    .padding(.leading,14)
            } else {
                // ── LEFT: sparkle + % group ─────────────────────────────
                HStack(alignment:.center, spacing: isDone ? 4 : 0) {
                    // Sparkle — ONLY when all done, accent green
                    if isDone {
                        ZStack {
                            Image(systemName:"sparkle")
                                .font(.system(size:DSTSize.caption, weight:.bold, design:.rounded))
                                .foregroundColor(AppTheme.accent)
                                .blur(radius:3.5)
                                .opacity(0.70)
                            Image(systemName:"sparkle")
                                .font(.system(size:DSTSize.caption, weight:.bold, design:.rounded))
                                .foregroundColor(AppTheme.accent.opacity(0.95))
                                .shadow(color:AppTheme.accent.opacity(0.65), radius:4)
                        }
                        .transition(.scale(scale:0.5).combined(with:.opacity))
                    }

                    // Percentage — gold at 100%, accent otherwise
                    Text("\(pctInt)%")
                        .font(.system(size:DSTSize.body, weight:.bold, design:.rounded))
                        .foregroundColor(
                            isDone    ? AppTheme.gold.opacity(0.92)
                            : isToday ? AppTheme.accent.opacity(0.78)
                            :           AppTheme.textSecondary.opacity(0.60))
                        .monospacedDigit()
                        .shadow(color: isDone ? AppTheme.gold.opacity(0.35) : .clear, radius:4)
                }
                .padding(.leading, 14)
                .animation(.spring(response:0.30, dampingFraction:0.78), value:isDone)
                .clipped()

                // ── MIDDLE: Progress track — gold when done ─────────────
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:2)
                        .fill(AppTheme.bg3.opacity(0.50))
                        .frame(height:3)
                    if completionRate > 0 {
                        GeometryReader { g in
                            RoundedRectangle(cornerRadius:2)
                                .fill(LinearGradient(
                                    colors: isDone
                                        ? [AppTheme.gold.opacity(0.60), AppTheme.gold]   // gold at 100%
                                        : isToday
                                        ? [AppTheme.accent.opacity(0.45), AppTheme.accent.opacity(0.75)]
                                        : [AppTheme.textSecondary.opacity(0.30),
                                           AppTheme.textTertiary.opacity(0.10)],
                                    startPoint:.leading, endPoint:.trailing
                                ))
                                .frame(width:max(4, g.size.width * CGFloat(completionRate)), height:3)
                                .shadow(color: isDone    ? AppTheme.gold.opacity(0.40)
                                             : isToday  ? AppTheme.accent.opacity(0.18) : .clear,
                                        radius:2)
                        }
                        .frame(height:3)
                        .animation(.spring(response:0.50, dampingFraction:0.78), value:completionRate)
                    }
                }
                .frame(maxWidth:.infinity)
                .padding(.leading, 10)
                .padding(.trailing, isDone ? 6 : 4)

                // ── RIGHT: Checkmark — ONLY when all done ───────────────
                if isDone {
                    ZStack {
                        Image(systemName:"checkmark")
                            .font(.system(size:DSTSize.micro, weight:.bold, design:.rounded))
                            .foregroundColor(AppTheme.gold)
                            .blur(radius:2.5)
                            .opacity(0.55)
                        Image(systemName:"checkmark")
                            .font(.system(size:DSTSize.micro, weight:.bold, design:.rounded))
                            .foregroundColor(AppTheme.gold.opacity(0.90))
                            .shadow(color:AppTheme.gold.opacity(0.65), radius:3)
                    }
                    .transition(.scale(scale:0.5).combined(with:.opacity))
                    .padding(.trailing, 4)
                }
            }

            // ── Chevron — always rightmost ──────────────────────────────
            Image(systemName:"chevron.right")
                .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
                .foregroundColor(AppTheme.textTertiary.opacity(0.28))
                .rotationEffect(.degrees(collapsed ? 0 : 90))
                .frame(width:26, height:ROW_H)
                .padding(.trailing,4)
                .animation(.spring(response:0.30, dampingFraction:0.78), value:collapsed)
        }
        .frame(maxWidth:.infinity)
        .frame(height:ROW_H)
        .animation(.spring(response:0.32, dampingFraction:0.78), value:isDone)
    }

    @ViewBuilder var headerRow: some View {
        HStack(alignment: collapsed ? .center : .top, spacing:0) {
            dateColumn
                .frame(minHeight: ROW_H)
                .padding(.vertical, collapsed ? 0 : 10)

            // Hairline divider — same opacity as AppTheme.border0
            Rectangle()
                .fill(AppTheme.border0)
                .frame(width:0.5)

            if collapsed {
                collapsedSummary
            } else {
                // Expanded header strip: task count + chevron
                HStack(alignment:.center, spacing:0) {
                    Text(totalCount > 0
                         ? store.t(zh:"\(totalCount) 个任务",
                                   en:"\(totalCount) task\(totalCount == 1 ? "" : "s")",
                                   ja:"\(totalCount) タスク",
                                   ko:"\(totalCount) 태스크",
                                   es:"\(totalCount) tarea\(totalCount == 1 ? "" : "s")")
                         : store.t(key:L10n.noTasks))
                        .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                        .padding(.leading,14)
                    Spacer()
                    Image(systemName:"chevron.right")
                        .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
                        .foregroundColor(AppTheme.accent.opacity(0.45))
                        .rotationEffect(.degrees(90))
                        .frame(width:26, height:ROW_H)
                        .padding(.trailing,6)
                }
                .frame(maxWidth:.infinity)
                .frame(height:ROW_H)
            }
        }
        .frame(minHeight: ROW_H)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style:.light).impactOccurred()
            withAnimation(.spring(response:0.34, dampingFraction:0.80)) {
                collapsed.toggle()
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: Chip area (expanded)
    // Chips start FLUSH from the date column divider.
    // Background uses same accent-tinted glass as drag-over state.
    // ════════════════════════════════════════════════════════════════════
    @ViewBuilder var chipArea: some View {
        VStack(alignment:.leading, spacing:0) {
            if chips.isEmpty {
                Text(store.t(key:L10n.noTasks))
                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                    .italic()
                    .foregroundColor(isDragOver ? AppTheme.accent
                                                : AppTheme.textTertiary.opacity(0.40))
                    .frame(maxWidth:.infinity, alignment:.leading)
                    .padding(.horizontal,12).padding(.vertical,12)
            } else {
                PlanChipFlow(chips:chips, chipDrag:$chipDrag,
                    onDoubleTap:{ chip in
                        if let g = store.goals.first(where:{$0.id==chip.goal.id}),
                           let t = store.tasks(for:date,goal:g).first(where:{$0.id==chip.id}) {
                            onEdit(t,g)
                        }
                    },
                    onDrop:{ pos in onDrop(pos) }
                ).environmentObject(store)
                .padding(.leading,12).padding(.trailing,12)
                .padding(.top,10).padding(.bottom,6)
            }
            if !isPast {
                HStack {
                    Spacer()
                    addButton
                }.padding(.trailing,12).padding(.bottom,10)
            }
        }
        .frame(maxWidth:.infinity)
        .background(chipsBg)
        .overlay(
            // Subtle top separator inside chip area
            Rectangle()
                .fill(AppTheme.border0.opacity(0.60))
                .frame(height:0.4),
            alignment:.top
        )
        .transition(.asymmetric(
            insertion:.opacity.combined(with:.move(edge:.top))
                .animation(.spring(response:0.28, dampingFraction:0.80)),
            removal:.opacity.animation(.easeOut(duration:0.14))
        ))
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: Past drag overlay
    // ════════════════════════════════════════════════════════════════════
    @ViewBuilder var pastOverlay: some View {
        if showPastOverlay {
            Color.gray.opacity(0.18)
                .overlay(
                    Text(store.t(key:L10n.pastLabel))
                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal,6).padding(.vertical,2)
                        .background(AppTheme.bg2.opacity(0.9)).cornerRadius(4),
                    alignment:.trailing
                ).padding(.trailing,8)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: Body
    // ════════════════════════════════════════════════════════════════════
    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            // ── LEFT: Date column ─────────────────────────────────────────
            ZStack {
                if isToday {
                    RoundedRectangle(cornerRadius:0, style:.continuous)
                        .fill(AppTheme.accent.opacity(0.08))
                    RoundedRectangle(cornerRadius:0, style:.continuous)
                        .fill(LinearGradient(
                            colors:[Color.white.opacity(0.06), Color.clear],
                            startPoint:.top, endPoint:.center))
                }
                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size:DSTSize.micro,
                                     weight: isToday ? .semibold : isPast ? .regular : .medium,
                                     design:.rounded))
                        .kerning(0.4)
                        .foregroundColor(
                            isToday  ? AppTheme.accent.opacity(0.92)
                            : isPast ? AppTheme.textTertiary.opacity(0.55)
                            :          AppTheme.textSecondary.opacity(0.85))
                        .shadow(color: isToday ? AppTheme.accent.opacity(0.35) : .clear, radius:3)
                    Text(dateNum)
                        .font(.system(
                            size:   isToday ? 24 : DSTSize.displaySmall,
                            weight: isToday ? .bold : isPast ? .light : .regular,
                            design: .rounded))
                        .foregroundColor(
                            isToday  ? AppTheme.accent.opacity(0.95)
                            : isPast ? AppTheme.textTertiary.opacity(0.58)
                            :          AppTheme.textPrimary.opacity(0.88))
                        .monospacedDigit()
                        .shadow(color: isToday ? AppTheme.accent.opacity(0.45) : .clear, radius:5)
                }
            }
            .frame(width: DATE_W)
            .frame(maxHeight: .infinity)
            .shadow(color: isToday ? AppTheme.accent.opacity(0.18) : .clear, radius:12)

            // ── Hairline divider ──────────────────────────────────────────
            Rectangle()
                .fill(isToday ? AppTheme.accent.opacity(0.20) : AppTheme.border0)
                .frame(width: 0.5)
                .frame(maxHeight: .infinity)

            // ── RIGHT: Content ────────────────────────────────────────────
            if collapsed {
                // Collapsed: single-line summary row, full height, tappable
                collapsedSummary
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: ROW_H)
            } else {
                // Expanded: chips + bottom-anchored add button
                VStack(alignment: .leading, spacing: 0) {
                    // Top bar: task count + collapse chevron
                    HStack(spacing: 0) {
                        Text(totalCount > 0
                             ? store.t(zh:"\(doneCount)/\(totalCount)",
                                       en:"\(doneCount)/\(totalCount)",
                                       ja:"\(doneCount)/\(totalCount)",
                                       ko:"\(doneCount)/\(totalCount)",
                                       es:"\(doneCount)/\(totalCount)")
                             : store.t(key:L10n.noTasks))
                            .font(.system(size:DSTSize.caption,
                                         weight: isDone ? .semibold : .regular,
                                         design:.rounded))
                            .foregroundColor(
                                isDone    ? AppTheme.gold.opacity(0.92)
                                : doneCount > 0 ? AppTheme.accent.opacity(0.75)
                                :                 AppTheme.textTertiary.opacity(0.38))
                            .shadow(color: isDone ? AppTheme.gold.opacity(0.35) : .clear, radius: 3)
                            .padding(.leading, 12)
                        Spacer()
                        // Collapse chevron — right-aligned in bar
                        Image(systemName:"chevron.up")
                            .font(.system(size:DSTSize.nano, weight:.semibold, design:.rounded))
                            .foregroundColor(AppTheme.accent.opacity(0.38))
                            .frame(width: 36, height: ROW_H)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: ROW_H)
                    .contentShape(Rectangle())

                    // Chips area
                    if chips.isEmpty {
                        Text(store.t(key:L10n.noTasks))
                            .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                            .italic()
                            .foregroundColor(isDragOver ? AppTheme.accent : AppTheme.textTertiary.opacity(0.38))
                            .frame(maxWidth:.infinity, alignment:.leading)
                            .padding(.horizontal,12).padding(.vertical, 6)
                    } else {
                        PlanChipFlow(chips:chips, chipDrag:$chipDrag,
                            onDoubleTap:{ chip in
                                if let g = store.goals.first(where:{$0.id==chip.goal.id}),
                                   let t = store.tasks(for:date,goal:g).first(where:{$0.id==chip.id}) {
                                    onEdit(t,g)
                                }
                            },
                            onDrop:{ pos in onDrop(pos) }
                        ).environmentObject(store)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    }

                    // Add button — bottom-right, inside card bounds
                    if !isPast {
                        HStack {
                            Spacer()
                            addButton
                        }
                        .padding(.trailing, 10)
                        .padding(.bottom, 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(chipsBg)
                .overlay(
                    Rectangle()
                        .fill(AppTheme.border0.opacity(0.50))
                        .frame(height: 0.4),
                    alignment: .top
                )
                .transition(.asymmetric(
                    insertion:.opacity.combined(with:.move(edge:.top))
                        .animation(.spring(response:0.28, dampingFraction:0.80)),
                    removal:.opacity.animation(.easeOut(duration:0.14))
                ))
            }
        }
        .frame(minHeight: ROW_H)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style:.light).impactOccurred()
            withAnimation(.spring(response:0.34, dampingFraction:0.80)) {
                collapsed.toggle()
            }
        }
        .overlay(
            isDragOver
                ? AnyView(RoundedRectangle(cornerRadius:0).stroke(AppTheme.accent.opacity(0.22), lineWidth:1))
                : AnyView(EmptyView())
        )
        .overlay(pastOverlay)
        .onAppear { collapsed = !isToday }
        .confirmationDialog(
            store.t(key:L10n.chooseGoalTitle),
            isPresented:$showGoalPicker,
            titleVisibility:.visible
        ) {
            ForEach(store.goals) { goal in Button(goal.title){ onAddTask(goal) } }
            Button(store.t(key:L10n.cancel), role:.cancel){}
        }
    }

    // ── Add button ────────────────────────────────────────────────────────
    var addButton: some View {
        Button(action:{ showGoalPicker = true }) {
            HStack(spacing: 4) {
                Image(systemName:"plus")
                    .font(.system(size: DSTSize.nano, weight:.bold, design:.rounded))
                Text(store.t(key:L10n.addLabel))
                    .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
            }
            .foregroundColor(AppTheme.accent)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius:9, style:.continuous)
                        .fill(AppTheme.accent.opacity(0.12))
                    RoundedRectangle(cornerRadius:9, style:.continuous)
                        .fill(LinearGradient(
                            colors:[Color.white.opacity(0.06), Color.clear],
                            startPoint:.top, endPoint:.bottom))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius:9, style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:9, style:.continuous)
                .stroke(AppTheme.accent.opacity(0.30), lineWidth:0.8))
            .shadow(color:AppTheme.accent.opacity(0.14), radius:4, x:0, y:2)
        }
        .buttonStyle(.plain)
    }
}


struct PlanAddTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store:AppStore
    let goal:Goal;let date:Date
    @State private var title="";@State private var useTime=false;@State private var minutes=30

    var body: some View {
        NavigationView {
            VStack(alignment:.leading,spacing:18){
                HStack(spacing:6){Circle().fill(goal.color).frame(width:6,height:6);Text(goal.title).font(.caption).foregroundColor(AppTheme.textSecondary)}.padding(.top,4)
                VStack(alignment:.leading,spacing:7){
                    SectionLabel(store.t(key: L10n.taskNameShort),icon:"pencil")
                    TextField(store.t(key: L10n.taskNamePlaceholderLocal),text:$title)
                        .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12).foregroundColor(AppTheme.textPrimary)
                        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
                }
                HStack{
                    Text(store.t(key: L10n.estimatedTimeShort)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                    Spacer()
                    Toggle("",isOn:$useTime).tint(goal.color).labelsHidden()
                }
                if useTime {
                    Picker("",selection:$minutes){
                        ForEach(stride(from:5,through:120,by:5).map{$0},id:\.self){
                            Text(L10n.minuteWithNumber($0, store.language)).tag($0)
                        }
                    }.pickerStyle(.wheel).frame(height:110).clipped().background(AppTheme.bg2).cornerRadius(12)
                }
                Spacer()
            }.padding(20)
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(key: L10n.addTask)).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){
                    Button(store.t(key: L10n.cancel)){dismiss()}.foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement:.navigationBarTrailing){
                    Button(store.t(key: L10n.addLabel)){
                        guard !title.isEmpty else{return}
                        // addPinnedTask: task scoped to this specific date only
                        store.addPinnedTask(goalId:goal.id, title:title,
                                            minutes:useTime ? minutes:nil,
                                            on:date)
                        // Track after add so we can retrieve the new taskId
                        if let newTask = store.goals.first(where:{$0.id==goal.id})?
                                             .tasks.last(where:{$0.title==title}) {
                            store.trackAddTask(
                                goalId: goal.id, goalTitle: goal.title,
                                taskId: newTask.id, taskTitle: title,
                                date: date
                            )
                        }
                        dismiss()
                    }.foregroundColor(goal.color).fontWeight(.medium).disabled(title.isEmpty)
                }
            }
        }
    }
}

struct PlanTaskEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeEnv:AppStore
    let task:GoalTask;let goal:Goal;let date:Date;let store:AppStore
    @State private var title:String;@State private var useTime:Bool;@State private var minutes:Int
    init(task:GoalTask,goal:Goal,date:Date,store:AppStore){
        self.task=task;self.goal=goal;self.date=date;self.store=store
        _title=State(initialValue:task.title);_useTime=State(initialValue:task.estimatedMinutes != nil);_minutes=State(initialValue:task.estimatedMinutes ?? 30)
    }
    var body: some View {
        NavigationView{
            VStack(alignment:.leading,spacing:18){
                VStack(alignment:.leading,spacing:7){
                    SectionLabel(storeEnv.t(key: L10n.taskNameThisDay),icon:"pencil")
                    TextField(storeEnv.t(key: L10n.taskNamePlain),text:$title).textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12).foregroundColor(AppTheme.textPrimary).overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
                }
                HStack{Text(storeEnv.t(key: L10n.estimatedTimeLabel2)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary);Spacer();Toggle("",isOn:$useTime).tint(goal.color).labelsHidden()}
                if useTime{
                    Picker("",selection:$minutes){ForEach(stride(from:5,through:120,by:5).map{$0},id:\.self){Text(L10n.minutesFmt($0, storeEnv.language)).tag($0)}}.pickerStyle(.wheel).frame(height:110).clipped().background(AppTheme.bg2).cornerRadius(12)
                }
                Spacer()
            }.padding(20)
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(storeEnv.t(key: L10n.editTask)).navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement:.navigationBarLeading){Button(storeEnv.t(key: L10n.cancelLabel)){dismiss()}.foregroundColor(AppTheme.textSecondary)}
                ToolbarItem(placement:.navigationBarTrailing){Button(storeEnv.t(key: L10n.save)){store.updateTaskOverride(task.id,goalId:goal.id,on:date,title:title != task.title ? title:nil,minutes:useTime ? minutes:nil);dismiss()}.foregroundColor(goal.color).fontWeight(.medium)}
            }
        }
    }
}

// ============================================================
// MARK: - 统计页
// ============================================================

struct StatsView: View {
    @EnvironmentObject var store:AppStore
    @EnvironmentObject var pro:ProStore
    @State private var selectedRange=0
    @State private var showSettings=false
    @State private var showJournal=false
    @State private var monthOffset=0   // 0=本月, -1=上月, -2=上上月...（最多-11）
    @State private var yearOffset=0    // 0=今年, -1=去年...（最多-2）

    var weekData:[(String,Double,Date)]{store.weekCompletions()}
    var monthData:[(String,Double)]{store.monthWeeklyCompletions()}
    var yearData:[(String,Double)]{store.yearMonthCompletions()}

    var currentAvg:Double{
        switch selectedRange{
        case 0:let v=weekData.map(\.1);return v.isEmpty ? 0:v.reduce(0,+)/Double(v.count)
        case 1:let v=monthData.map(\.1).filter{$0>0};return v.isEmpty ? 0:v.reduce(0,+)/Double(v.count)
        default:let v=yearData.map(\.1).filter{$0>0};return v.isEmpty ? 0:v.reduce(0,+)/Double(v.count)
        }
    }

    // 偏移后的周期日期（用于历史月/年查看）
    func offsetMonthDates(_ offset: Int) -> [Date] {
        let cal = Calendar.current
        guard let shifted = cal.date(byAdding:.month, value:offset, to:store.today) else { return store.monthDates() }
        let comps = cal.dateComponents([.year,.month], from:shifted)
        guard let first = cal.date(from:comps),
              let lastDay = cal.date(byAdding:.month, value:1, to:first).flatMap({ cal.date(byAdding:.day, value:-1, to:$0) })
        else { return store.monthDates() }
        var dates:[Date] = []
        var d = first
        while d <= lastDay { dates.append(d); d = cal.date(byAdding:.day, value:1, to:d)! }
        return dates
    }
    func offsetYearDates(_ offset: Int) -> [Date] {
        let cal = Calendar.current
        guard let shifted = cal.date(byAdding:.year, value:offset, to:store.today) else { return store.yearDates() }
        let year = cal.component(.year, from:shifted)
        guard let first = cal.date(from:DateComponents(year:year,month:1,day:1)),
              let last  = cal.date(from:DateComponents(year:year,month:12,day:31))
        else { return store.yearDates() }
        var dates:[Date] = []
        var d = first
        while d <= last { dates.append(d); d = cal.date(byAdding:.day, value:1, to:d)! }
        return dates
    }
    var activePeriodDates: [Date] {
        switch selectedRange {
        case 0: return store.weekDates()
        case 1: return offsetMonthDates(monthOffset)
        default: return offsetYearDates(yearOffset)
        }
    }
    var activePeriodLabel: String {
        let cal = Calendar.current
        if selectedRange == 1 {
            guard let shifted = cal.date(byAdding:.month, value:monthOffset, to:store.today) else { return store.currentMonthLabel }
            return store.language == .chinese
                ? "\(cal.component(.year,from:shifted))年\(cal.component(.month,from:shifted))月"
                : "\(cal.component(.month,from:shifted))/\(cal.component(.year,from:shifted))"
        } else if selectedRange == 2 {
            guard let shifted = cal.date(byAdding:.year, value:yearOffset, to:store.today) else { return store.currentYearLabel }
            let y = cal.component(.year, from:shifted)
            return store.language == .chinese ? "\(y)年" : "\(y)"
        }
        return store.currentWeekLabel
    }



    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing:0) {
                    // ── Glass imprint page title ─────────────────────────────
                    PageHeaderView(title: store.t(key: L10n.myPage), accentColor: AppTheme.accent)

                    // ── Period Selector + Nav ────────────────────────────────
                    VStack(spacing:0) {
                        // Tab row — label token for selected, caption for others
                        HStack(spacing:0) {
                            ForEach([(0,store.t(key: L10n.weekLabel2)),(1,store.t(key: L10n.monthLabel2)),(2,store.t(key: L10n.yearLabel2))],id:\.0){ (i,lbl) in
                                Button(action:{withAnimation(.spring(response:0.3)){selectedRange=i; monthOffset=0; yearOffset=0}}){
                                    VStack(spacing:0){
                                        Text(lbl)
                                            .font(.system(size:DSTSize.caption,
                                                          weight:selectedRange==i ? .semibold : .regular,
                                                          design:.rounded))
                                            .frame(maxWidth:.infinity).padding(.vertical,11)
                                            .foregroundColor(selectedRange==i
                                                ? AppTheme.textPrimary.opacity(0.90)
                                                : AppTheme.textTertiary.opacity(0.55))
                                        Rectangle().fill(selectedRange==i ? AppTheme.accent : Color.clear)
                                            .frame(height:1.5).cornerRadius(1)
                                    }
                                }
                            }
                        }
                        // Month / year nav
                        if selectedRange == 1 || selectedRange == 2 {
                            HStack(spacing:0) {
                                Button(action:{withAnimation(.spring(response:0.25)){
                                    if selectedRange==1 { monthOffset = max(monthOffset-1,-11) }
                                    else { yearOffset = max(yearOffset-1,-4) }
                                }}) {
                                    Image(systemName:"chevron.left")
                                        .font(.system(size:DSTSize.caption, weight:.medium, design:.rounded))
                                        .foregroundColor(AppTheme.textTertiary.opacity(0.65))
                                        .frame(width:44,height:32)
                                }
                                Spacer()
                                Text(activePeriodLabel)
                                    .font(.system(size:DSTSize.caption, weight:.medium, design:.rounded))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.80))
                                Spacer()
                                Button(action:{withAnimation(.spring(response:0.25)){
                                    if selectedRange==1 { monthOffset = min(monthOffset+1,0) }
                                    else { yearOffset = min(yearOffset+1,0) }
                                }}) {
                                    Image(systemName:"chevron.right")
                                        .font(.system(size:DSTSize.caption, weight:.medium, design:.rounded))
                                        .foregroundColor(
                                            (selectedRange==1 && monthOffset<0)||(selectedRange==2 && yearOffset<0)
                                            ? AppTheme.textTertiary.opacity(0.65) : AppTheme.textTertiary.opacity(0.20))
                                        .frame(width:44,height:32)
                                }
                                .disabled((selectedRange==1 && monthOffset==0)||(selectedRange==2 && yearOffset==0))
                            }
                            .background(AppTheme.bg0)
                        }
                        Rectangle().fill(AppTheme.border0).frame(height:0.5)
                    }
                    .background(AppTheme.bg0)

                    // ── Hero stat — displayHero token ────────────────────────
                    VStack(spacing:4){
                        Text("\(Int(currentAvg*100))%")
                            .font(.system(size:DSTSize.displayHero, weight:.ultraLight, design:.rounded))
                            .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                            .monospacedDigit()
                            .kerning(-3)
                        Text(store.t(key: L10n.avgCompletion))
                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.50))
                            .kerning(2.5)
                            .textCase(.uppercase)
                    }.padding(.top,28).padding(.bottom,20)

                    // ── Chart ───────────────────────────────────────────────
                    InteractiveBarChartCard(selectedRange: selectedRange).padding(.horizontal,16)

                    // ── Goal Progress ───────────────────────────────────────
                    GoalProgressCard().padding(.horizontal,16).padding(.top,6)

                    // ── Period Review Card (prominent) ──────────────────────
                    PeriodSummaryCard(range:selectedRange, periodDatesOverride:activePeriodDates, periodLabelOverride:activePeriodLabel)
                        .padding(.horizontal,16).padding(.top,6)

                    // ── Smart Summary (Pro 订阅专属) ──────────────────────────
                    if pro.isProSubscriber {
                        MergedSummaryCard(range:selectedRange, periodDates:activePeriodDates).padding(.horizontal,16).padding(.top,6)
                    } else {
                        ProLockedOverlay(message:store.t(key: L10n.proFeatureSmartSummary), requiredTier: .pro).padding(.horizontal,16).padding(.top,6)
                    }



                    // ── Journal History ─────────────────────────────────────
                    if pro.isPro {
                        Button(action:{showJournal=true}){
                            HStack{
                                Image(systemName:"book.fill")
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .frame(width: 20)
                                Text(store.t(key: L10n.myGrowth))
                                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary)
                                Spacer()
                                Text("\(store.journalEntries.count)").font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                                Image(systemName:"chevron.right").font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                            }
                            .padding(14).background(AppTheme.bg1).cornerRadius(13)
                            .overlay(RoundedRectangle(cornerRadius:13).stroke(AppTheme.border0,lineWidth:1))
                        }.padding(.horizontal,16).padding(.top,6)
                    }

                    // ── Settings ─────────────────────────────────────────────
                    VStack(spacing:0) {
                        AgePickerRow().padding(.horizontal,14).padding(.vertical,12)
                        Rectangle().fill(AppTheme.border0).frame(height:0.5).padding(.horizontal,14)
                        Button(action:{showSettings=true}){
                            HStack{
                                Image(systemName:"gearshape.fill")
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .frame(width: 20)
                                Text(store.t(key: L10n.settingsLabel)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary)
                                Spacer()
                                Image(systemName:"chevron.right").font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                            }.padding(.horizontal,14).padding(.vertical,12)
                        }
                    }
                    .background(AppTheme.bg1).cornerRadius(13)
                    .overlay(RoundedRectangle(cornerRadius:13).stroke(AppTheme.border0,lineWidth:1))
                    .padding(.horizontal,16).padding(.top,6)

                    Spacer(minLength:32)
                }
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented:$showSettings){SettingsSheet().environmentObject(store).environmentObject(pro)}
            .sheet(isPresented:$showJournal){JournalListView().environmentObject(store).environmentObject(pro)}
        }
    }
}

struct FilterChip: View {
    let label:String;let isSelected:Bool;let color:Color;let onTap:()->Void
    var body: some View {
        Button(action:onTap){
            Text(label)
                .font(.system(size:DSTSize.caption, weight: isSelected ? .medium : .regular, design:.rounded))
                .padding(.horizontal,10).padding(.vertical,5)
                .background(isSelected ? color.opacity(0.18) : AppTheme.bg2)
                .foregroundColor(isSelected ? color : AppTheme.textTertiary.opacity(0.60))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius:20)
                    .stroke(isSelected ? color.opacity(0.35) : AppTheme.border0, lineWidth:0.7))
        }
    }
}

// ── 年龄选择行（轻量，不突兀，嵌入设置区）────────────────────
struct AgePickerRow: View {
    @EnvironmentObject var store: AppStore
    @State private var showPicker = false

    var thisYear: Int { Calendar.current.component(.year, from:Date()) }

    var displayText: String {
        guard store.userBirthYear > 0 else { return store.t(key: L10n.notSet) }
        let age = thisYear - store.userBirthYear
        return L10n.ageFmt(age, store.language)
    }

    var birthYears: [Int] { Array((1940...(thisYear-5)).reversed()) }

    var pickerBinding: Binding<Int> {
        Binding(
            get:{ store.userBirthYear > 0 ? store.userBirthYear : thisYear - 28 },
            set:{ store.userBirthYear = $0 }
        )
    }

    var body: some View {
        VStack(alignment:.leading, spacing:0) {
            // 主行
            HStack {
                Image(systemName:"person.fill")
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded))
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(width: 20)
                Text(store.t(key: L10n.ageLabel)).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary)
                Spacer()
                Button(action:{ withAnimation(.spring(response:0.3)){ showPicker.toggle() }}) {
                    HStack(spacing:4) {
                        Text(displayText).font(.subheadline).foregroundColor(AppTheme.textTertiary)
                        Image(systemName:showPicker ? "chevron.up":"chevron.down")
                            .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                    }
                }
            }

            // 展开的选择面板
            if showPicker {
                AgePickerPanel(
                    thisYear: thisYear,
                    birthYears: birthYears,
                    pickerBinding: pickerBinding,
                    onSelect: { withAnimation { showPicker = false } }
                )
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
    }
}

// 拆出的选择面板（避免编译器类型推断超时）
private struct AgePickerPanel: View {
    @EnvironmentObject var store: AppStore
    let thisYear: Int
    let birthYears: [Int]
    @Binding var pickerBinding: Int
    let onSelect: () -> Void

    var quickYears: [Int] {
        [25,30,35,40,45,50].map { thisYear - $0 }.filter { $0 > 1940 }
    }

    var body: some View {
        VStack(spacing:0) {
            Rectangle().fill(AppTheme.border0).frame(height:0.5)

            // 快速选（横向滚动）
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing:8) {
                    // 不设置
                    ageChip(label: store.t(key: L10n.skipLabel), isSelected: store.userBirthYear == 0) {
                        store.userBirthYear = 0; onSelect()
                    }
                    // 常用年龄
                    ForEach(quickYears, id:\.self) { yr in
                        let age = thisYear - yr
                        ageChip(label: L10n.ageFmt(age, store.language), isSelected: store.userBirthYear == yr) {
                            store.userBirthYear = yr; onSelect()
                        }
                    }
                }
                .padding(.horizontal,2).padding(.vertical,8)
            }

            // 精确 Wheel Picker
            Picker("", selection: $pickerBinding) {
                ForEach(birthYears, id:\.self) { yr in
                    Text(L10n.birthYearFmt(yr, thisYear-yr, store.language)).tag(yr)
                }
            }
            .pickerStyle(.wheel).frame(height:120).clipped()
        }
    }

    @ViewBuilder
    func ageChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.caption)
                .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textTertiary)
                .padding(.horizontal,10).padding(.vertical,6)
                .background(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.bg2)
                .cornerRadius(8)
        }
    }
}

// ============================================================
// MARK: - 可交互图表卡（点柱展开该段详情）
// ============================================================
struct InteractiveBarChartCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let selectedRange: Int   // 0=周, 1=月, 2=年
    @State private var selectedIdx: Int? = nil

    var weekData:  [(String,Double,Date)]      { store.weekCompletions() }
    var monthData: [AppStore.MonthWeekEntry]   { store.monthWeekEntries() }
    var yearData:  [AppStore.YearMonthEntry]   { store.yearMonthEntries() }

    var body: some View {
        Group {
            switch selectedRange {
            case 0: WeekChartPanel(selectedIdx: $selectedIdx)
            case 1: MonthChartPanel(selectedIdx: $selectedIdx)
            default: YearChartPanel(selectedIdx: $selectedIdx)
            }
        }
    }
}

// ══════════════════════════════════════════════════════════
// MARK: 📅 本周面板
// ══════════════════════════════════════════════════════════
struct WeekChartPanel: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedIdx: Int?
    var data: [(label:String, rate:Double, date:Date)] {
        store.weekCompletions().map { (label:$0.0, rate:$0.1, date:$0.2) }
    }
    var bestIdx: Int? {
        let nonZero = data.enumerated().filter { $0.element.rate > 0 }
        return nonZero.max(by:{ $0.element.rate < $1.element.rate })?.offset
    }
    var worstIdx: Int? {
        let nonZero = data.enumerated().filter { $0.element.rate > 0 }
        guard nonZero.count > 1 else { return nil }
        return nonZero.min(by:{ $0.element.rate < $1.element.rate })?.offset
    }
    var avgRate: Double {
        let r = data.map{$0.rate}.filter{$0>0}
        return r.isEmpty ? 0 : r.reduce(0,+)/Double(r.count)
    }
    var moodDist: [Int:Int] { store.moodDistribution(for:data.map{$0.date}) }

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader(sfIcon:"calendar", title:store.t(key: L10n.weekCompletionRate))
            // Day badges: ✦ sparkle for each day where completionRate = 100%
            let dayBadges: [Int: RewardLevel] = Dictionary(
                uniqueKeysWithValues: data.indices.compactMap { i in
                    guard let d = data[safe:i]?.date else { return nil }
                    let rate = store.completionRate(for:d)
                    let hasTasks = !store.goals(for:d).flatMap { store.tasks(for:d, goal:$0) }.isEmpty
                    let isPast = Calendar.current.startOfDay(for:d) <= Calendar.current.startOfDay(for:store.today)
                    guard hasTasks && isPast && rate >= 1.0 else { return nil }
                    return (i, RewardLevel.day)
                }
            )
            unifiedBarChart(data:data.map{($0.label,$0.rate)}, bestIdx:bestIdx, worstIdx:worstIdx, selectedIdx:$selectedIdx, isToday: { i in
                Calendar.current.isDate(data[safe:i]?.date ?? .distantPast, inSameDayAs:store.today)
            }, isFuture: { i in
                guard let d = data[safe:i]?.date else { return false }
                return Calendar.current.startOfDay(for:d) > Calendar.current.startOfDay(for:store.today)
            }, language: store.language, rewardBadges: dayBadges)
            statsRow(avg:avgRate, best:bestIdx.flatMap{data[safe:$0]}.map{$0.label}, moodDist:moodDist, store:store)
            if let idx = selectedIdx {
                Spacer().frame(height: 12)
                dayDetail(idx:idx).transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .cardStyle()
        .animation(.spring(response:0.28), value:selectedIdx)
    }

    @ViewBuilder func dayDetail(idx: Int) -> some View {
        if let entry = data[safe:idx] {
            let rev = store.review(for:entry.date)
            let isFuture = Calendar.current.startOfDay(for:entry.date) > Calendar.current.startOfDay(for:store.today)
            VStack(alignment:.leading, spacing:8) {
                if isFuture {
                    Text(store.t(key: L10n.futureDateLabel)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                } else if let r = rev, r.isSubmitted {
                    if r.rating > 0 {
                        let moodLbls: [String] = {
                            switch store.language {
                            case .chinese:  return ["","不太好","一般","还行","不错","很棒"]
                            case .english:  return ["","Rough","Okay","Alright","Good","Great"]
                            case .japanese: return ["","つらい","普通","まあまあ","良い","最高"]
                            case .korean:   return ["","힘들어","보통","괜찮아","좋아","최고"]
                            case .spanish:  return ["","Mal","Regular","Bien","Muy bien","Genial"]
                            }
                        }()

                        HStack(spacing: 6) {
                            Text(["","😞","😶","🙂","🤍","✨"][r.rating]).font(.body)
                            Text(moodLbls[r.rating])
                                .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded))
                                .misty(.tertiary)
                        }
                    }
                    // 该日所有收获（日记 + 覆盖这天的周总结）
                    let allGains = store.allGainKeywords(for:[entry.date])
                    let allPlans = store.allPlanKeywords(for:[entry.date])
                    if !allGains.isEmpty { kwRow(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.wins),kws:allGains) }
                    if !allPlans.isEmpty { kwRow(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.plan),kws:allPlans) }
                    if !r.challengeKeywords.isEmpty { kwRow(icon:"exclamationmark.triangle.fill",color:AppTheme.gold,label:store.t(key: L10n.pending),kws:r.challengeKeywords) }
                    if allGains.isEmpty && allPlans.isEmpty && r.challengeKeywords.isEmpty {
                        Text(store.t(key: L10n.checkedInNoKW)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                    }
                } else {
                    Text(store.t(key: L10n.noDataYet)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════
// MARK: 📆 本月面板
// ══════════════════════════════════════════════════════════
struct MonthChartPanel: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @Binding var selectedIdx: Int?
    var monthData: [AppStore.MonthWeekEntry] { store.monthWeekEntries() }
    var allDates: [Date] { store.monthDates() }

    var bestIdx: Int? {
        let nonZero = monthData.enumerated().filter { store.avgCompletion(for:$0.element.dates) > 0 }
        return nonZero.max(by:{ store.avgCompletion(for:$0.element.dates) < store.avgCompletion(for:$1.element.dates) })?.offset
    }
    var worstIdx: Int? {
        let nonZero = monthData.enumerated().filter { store.avgCompletion(for:$0.element.dates) > 0 }
        guard nonZero.count > 1 else { return nil }
        return nonZero.min(by:{ store.avgCompletion(for:$0.element.dates) < store.avgCompletion(for:$1.element.dates) })?.offset
    }
    var avgRate: Double { store.avgCompletion(for:allDates.filter{$0<=store.today}) }
    var moodDist: [Int:Int] { store.moodDistribution(for:allDates.filter{$0<=store.today}) }

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader(sfIcon:"calendar.badge.clock", title:store.t(key: L10n.monthCompletionRate))
            if !pro.isPro {
                ProLockedOverlay(message:store.t(key: L10n.monthlyDataPro))
            } else {
                let barData = monthData.map { ($0.weekLabel, store.avgCompletion(for:$0.dates)) }
                // Week badges: ❋ crown for weeks where every past day = 100%
                let weekBadges: [Int: RewardLevel] = Dictionary(
                    uniqueKeysWithValues: monthData.indices.compactMap { i in
                        guard store.isWeekBadgeEarned(weekDates: monthData[i].dates) else { return nil }
                        return (i, RewardLevel.week)
                    }
                )
                unifiedBarChart(data:barData, bestIdx:bestIdx, worstIdx:worstIdx, selectedIdx:$selectedIdx, isToday:{_ in false}, isFuture:{_ in false}, language:store.language, rewardBadges:weekBadges)
                statsRow(avg:avgRate, best:bestIdx.flatMap{monthData[safe:$0]}.map{$0.weekLabel}, moodDist:moodDist, store:store)
                if let idx = selectedIdx {
                    Spacer().frame(height: 12)
                    weekDetail(idx:idx).transition(.opacity.combined(with:.move(edge:.top)))
                }
            }
        }
        .cardStyle()
        .animation(.spring(response:0.28), value:selectedIdx)
    }

    @ViewBuilder func weekDetail(idx: Int) -> some View {
        if let we = monthData[safe:idx] {
            let ws = store.periodSummary(type:0, label:we.periodLabel)
            let rate = store.avgCompletion(for:we.dates)
            // 聚合这周所有收获（日记 + 周总结）
            let allGains = store.allGainKeywords(for:we.dates)
            let allPlans = store.allPlanKeywords(for:we.dates)
            VStack(alignment:.leading, spacing:8) {
                HStack {
                    Text(we.weekLabel).font(.caption.weight(.medium)).foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    if rate > 0 { Text("\(Int(rate*100))%").font(.caption).foregroundColor(AppTheme.accent) }
                    if let m = ws?.mood, m > 0 { Text(["","😞","😶","🙂","🤍","✨"][m]).font(.caption) }
                }
                if !allGains.isEmpty { kwRow(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.wins),kws:allGains) }
                if !allPlans.isEmpty { kwRow(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.plan),kws:allPlans) }
                if let ws = ws, !ws.challengeKeywords.isEmpty {
                    kwRow(icon:"exclamationmark.triangle.fill",color:AppTheme.gold,label:store.t(key: L10n.pending),kws:ws.challengeKeywords)
                }
                if allGains.isEmpty && allPlans.isEmpty {
                    Text(store.t(key: L10n.noWeeklySummary)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════
// MARK: 📊 本年面板
// ══════════════════════════════════════════════════════════
struct YearChartPanel: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @Binding var selectedIdx: Int?
    var yearData: [AppStore.YearMonthEntry] { store.yearMonthEntries() }

    var bestIdx: Int? {
        let nonZero = yearData.enumerated().filter { store.avgCompletion(for:$0.element.dates) > 0 }
        return nonZero.max(by:{ store.avgCompletion(for:$0.element.dates) < store.avgCompletion(for:$1.element.dates) })?.offset
    }
    var worstIdx: Int? {
        let nonZero = yearData.enumerated().filter { store.avgCompletion(for:$0.element.dates) > 0 }
        guard nonZero.count > 1 else { return nil }
        return nonZero.min(by:{ store.avgCompletion(for:$0.element.dates) < store.avgCompletion(for:$1.element.dates) })?.offset
    }
    var totalDays: Int { yearData.flatMap{$0.dates}.filter{store.completionRate(for:$0)>0}.count }
    var avgRate: Double { store.avgCompletion(for:yearData.flatMap{$0.dates}) }
    var moodDist: [Int:Int] { store.moodDistribution(for:yearData.flatMap{$0.dates}.filter{$0<=store.today}) }

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            sectionHeader(sfIcon:"chart.bar.fill", title:store.t(key: L10n.yearCompletionRate))
            if !pro.isPro {
                ProLockedOverlay(message:store.t(key: L10n.yearlyDataPro))
            } else {
                let barData = yearData.map { ($0.monthLabel, store.avgCompletion(for:$0.dates)) }
                // Month badges: ◈ seal for months where all complete weeks are perfect
                let monthBadges: [Int: RewardLevel] = Dictionary(
                    uniqueKeysWithValues: yearData.indices.compactMap { i in
                        guard store.isMonthBadgeEarned(monthDates: yearData[i].dates) else { return nil }
                        return (i, RewardLevel.month)
                    }
                )
                unifiedBarChart(data:barData, bestIdx:bestIdx, worstIdx:worstIdx, selectedIdx:$selectedIdx, isToday:{_ in false}, isFuture:{_ in false}, language:store.language, rewardBadges:monthBadges)
                statsRow(avg:avgRate, best:bestIdx.flatMap{yearData[safe:$0]}.map{$0.monthLabel}, moodDist:moodDist, store:store)
                if let idx = selectedIdx {
                    Spacer().frame(height: 12)
                    monthDetail(idx:idx).transition(.opacity.combined(with:.move(edge:.top)))
                }
            }
        }
        .cardStyle()
        .animation(.spring(response:0.28), value:selectedIdx)
    }

    @ViewBuilder func monthDetail(idx: Int) -> some View {
        if let me = yearData[safe:idx] {
            let rate = store.avgCompletion(for:me.dates)
            let allGains = store.allGainKeywords(for:me.dates)
            let allPlans = store.allPlanKeywords(for:me.dates)
            let moodDist = store.moodDistribution(for:me.dates)
            VStack(alignment:.leading, spacing:8) {
                HStack {
                    Text(me.monthLabel).font(.caption.weight(.medium)).foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    if rate > 0 { Text("\(Int(rate*100))%").font(.caption).foregroundColor(AppTheme.accent) }
                    HStack(spacing:3) {
                        ForEach([1,2,3,4,5], id:\.self) { v in
                            if let c = moodDist[v], c > 0 { Text(["","😞","😶","🙂","🤍","✨"][v]).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)) }
                        }
                    }
                }
                if !allGains.isEmpty { kwRow(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.wins),kws:allGains) }
                if !allPlans.isEmpty { kwRow(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.plan),kws:allPlans) }
                if allGains.isEmpty && allPlans.isEmpty {
                    Text(store.t(key: L10n.noMonthlySummary)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                }
            }
        }
    }
}

// ══════════════════════════════════════════════════════════
// MARK: 共用图表组件
// ══════════════════════════════════════════════════════════

/// 统一柱状图：极值双色高亮（最高=accent实色，最低=danger虚色）
@ViewBuilder func unifiedBarChart(
    data: [(String,Double)],
    bestIdx: Int?,
    worstIdx: Int?,
    selectedIdx: Binding<Int?>,
    isToday: @escaping (Int)->Bool,
    isFuture: @escaping (Int)->Bool,
    language: AppLanguage = .chinese,
    rewardBadges: [Int: RewardLevel] = [:]   // index → badge level to show above bar
) -> some View {
    let isYearView = data.count > 8
    let barW: CGFloat     = isYearView ? 24 : 40
    let barSpacing: CGFloat = isYearView ? 6 : 8
    let maxH: CGFloat     = 160

    VStack(spacing: 6) {
        if isYearView {
            ScrollView(.horizontal, showsIndicators: false) {
                chartBarRow(data:data, bestIdx:bestIdx, worstIdx:worstIdx, selectedIdx:selectedIdx,
                            isToday:isToday, isFuture:isFuture, barW:barW, barSpacing:barSpacing, maxH:maxH,
                            rewardBadges:rewardBadges)
                    .padding(.horizontal, 2)
            }
        } else {
            chartBarRow(data:data, bestIdx:bestIdx, worstIdx:worstIdx, selectedIdx:selectedIdx,
                        isToday:isToday, isFuture:isFuture, barW:barW, barSpacing:barSpacing, maxH:maxH,
                        rewardBadges:rewardBadges)
        }
        // 图例
        HStack(spacing:12) {
            Spacer()
            HStack(spacing:4) {
                Capsule().fill(AppTheme.accent).frame(width:14, height:3)
                Text(language == .japanese ? "最高" : language == .korean ? "최고" : language == .spanish ? "Mejor" : language == .english ? "Best" : "最高").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
            HStack(spacing:4) {
                Capsule().fill(AppTheme.danger.opacity(0.55)).frame(width:14, height:3)
                Text(language == .japanese ? "最低" : language == .korean ? "최저" : language == .spanish ? "Peor" : language == .english ? "Worst" : "最低").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
        }
    }
}

/// Shared bar row used by unifiedBarChart (avoids @ViewBuilder nesting limits)
@ViewBuilder func chartBarRow(
    data: [(String,Double)],
    bestIdx: Int?,
    worstIdx: Int?,
    selectedIdx: Binding<Int?>,
    isToday: @escaping (Int)->Bool,
    isFuture: @escaping (Int)->Bool,
    barW: CGFloat,
    barSpacing: CGFloat,
    maxH: CGFloat,
    rewardBadges: [Int: RewardLevel] = [:]
) -> some View {
    HStack(alignment:.bottom, spacing:barSpacing) {
        ForEach(data.indices, id:\.self) { i in
            let (lbl, val) = data[i]
            let isSel    = selectedIdx.wrappedValue == i
            let isBest   = bestIdx == i
            let isWorst  = worstIdx == i && val > 0
            let today    = isToday(i)
            let future   = isFuture(i)
            let badge    = rewardBadges[i]

            Button(action:{ withAnimation(.spring(response:0.25)){
                selectedIdx.wrappedValue = selectedIdx.wrappedValue == i ? nil : i
            }}) {
                VStack(spacing:2) {
                    // ── Reward badge floating above bar ──
                    if let lvl = badge {
                        ZStack {
                            // Outer glow
                            Image(systemName: lvl.symbol)
                                .font(.system(size: barW > 30 ? 14 : 11, weight: .bold))
                                .foregroundColor(lvl.color)
                                .blur(radius: 5).opacity(0.65)
                            // Crisp icon
                            Image(systemName: lvl.symbol)
                                .font(.system(size: barW > 30 ? 12 : 9, weight: .semibold))
                                .foregroundColor(lvl.color)
                                .shadow(color: lvl.color.opacity(0.8), radius: 3)
                        }
                        .frame(width: barW, height: barW > 30 ? 18 : 14)
                    } else if (isBest || isWorst || isSel) && val > 0 {
                        // Percentage label — only shown when no badge
                        Text("\(Int(val*100))%")
                            .font(.system(size:DSTSize.nano, weight: isBest ? .semibold : .regular, design:.rounded))
                            .foregroundColor(isBest ? AppTheme.accent : isWorst ? AppTheme.danger.opacity(0.8) : AppTheme.accent)
                    } else {
                        Text("").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                    }

                    let barH: CGFloat = val == 0 ? 6 :
                        future ? 6 :
                        max(20, val * maxH)

                    ZStack(alignment: .bottom) {
                        // Bar body — NO strokeBorder (eliminates the visible top line)
                        RoundedRectangle(cornerRadius:5)
                            .fill(future  ? AppTheme.bg2 :
                                  isSel   ? AppTheme.accent.opacity(0.85) :
                                  isBest  ? AppTheme.accent :
                                  isWorst ? AppTheme.danger.opacity(0.45) :
                                  val > 0 ? AppTheme.accent.opacity(0.30) : AppTheme.bg2)
                            .frame(width:barW, height:barH)
                            .shadow(color: (isBest && !isSel) ? AppTheme.accent.opacity(0.20) : .clear,
                                    radius:4, x:0, y:2)

                        // Selected indicator: glowing bottom pill (not top line)
                        if isSel {
                            Capsule()
                                .fill(Color.white.opacity(0.60))
                                .frame(width: barW * 0.5, height: 2.5)
                                .shadow(color: AppTheme.accent, radius: 4)
                                .offset(y: -4)
                        }
                    }
                    .frame(width:barW)

                    // X-axis label
                    Text(lbl)
                        .font(.system(size: today ? 10 : 9,
                                     weight: today ? .semibold : isBest ? .medium : .regular,
                                     design: .rounded))
                        .foregroundColor(today ? AppTheme.accent :
                                        isSel   ? AppTheme.accent.opacity(0.90) :
                                        isBest  ? AppTheme.accent.opacity(0.80) :
                                        AppTheme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width:barW)
                }
            }.buttonStyle(.plain)
        }
    }
    .frame(height: maxH + 52)  // extra space for badge above bar
}

/// 统一摘要行：均值 + 极值标签 + 心情分布
@ViewBuilder func statsRow(avg:Double, best:String?, moodDist:[Int:Int], store: AppStore? = nil) -> some View {
    HStack(spacing:8) {
        // 均值磁贴
        VStack(alignment:.leading, spacing:2) {
            Text(avg > 0 ? "\(Int(avg*100))%" : "—")
                .font(.system(size:DSTSize.titleCard,weight:.light,design:.rounded))
                .foregroundColor(AppTheme.accent)
            Text(store?.language == .english ? "Avg" : store?.language == .japanese ? "平均" : store?.language == .korean ? "평균" : store?.language == .spanish ? "Prom" : "均值")
                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth:.infinity, alignment:.leading)
        .padding(8).background(AppTheme.bg2.opacity(0.6)).cornerRadius(10)

        // 最佳磁贴
        if let b = best {
            VStack(alignment:.leading, spacing:2) {
                Text(b).font(.system(size:DSTSize.label,weight:.medium, design:.rounded)).foregroundColor(AppTheme.accent)
                Text(store?.language == .english ? "Best" : store?.language == .japanese ? "最高" : store?.language == .korean ? "최고" : store?.language == .spanish ? "Mejor" : "最佳").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
            .frame(maxWidth:.infinity, alignment:.leading)
            .padding(8).background(AppTheme.bg2.opacity(0.6)).cornerRadius(10)
        }

        // 心情分布
        if !moodDist.isEmpty {
            VStack(alignment:.leading, spacing:2) {
                HStack(spacing:2) {
                    ForEach([1,2,3,4,5], id:\.self) { v in
                        if let c = moodDist[v], c > 0 {
                            VStack(spacing:0) {
                                Text(["","😞","😶","🙂","🤍","✨"][v]).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                Text("\(c)").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                Text(store?.language == .english ? "Mood" : store?.language == .japanese ? "気分" : store?.language == .korean ? "기분" : store?.language == .spanish ? "Ánimo" : "心情")
                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
            .frame(maxWidth:.infinity, alignment:.leading)
            .padding(8).background(AppTheme.bg2.opacity(0.6)).cornerRadius(10)
        }
    }
}


// ── 共用工具视图 ─────────────────────────────────────────
@ViewBuilder func emptyPlaceholder(icon:String, msg:String) -> some View {
    VStack(spacing:14) {
        Image(systemName:icon)
            .font(.system(size:DSTSize.displayLarge,weight:.ultraLight, design:.rounded))
            .foregroundColor(AppTheme.textTertiary.opacity(0.62))
        Text(msg)
            .font(.subheadline)
            .foregroundColor(AppTheme.textTertiary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth:.infinity)
    .padding(.vertical,20)
}

extension View {
    func cardStyle() -> some View {
        self.padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                    // Monet luminism: subtle top-light wash
                    RoundedRectangle(cornerRadius:20)
                        .fill(LinearGradient(
                            colors:[Color.white.opacity(0.028), Color.clear],
                            startPoint:.topLeading, endPoint:.center))
                }
            )
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0, lineWidth:0.8))
            .shadow(color:.black.opacity(0.18), radius:10, x:0, y:4)
    }
}

@ViewBuilder func sectionHeader(icon:String, title:String) -> some View {
    HStack(spacing:6) {
        Text(icon)
            .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
            .foregroundColor(AppTheme.accent.opacity(0.60))
        Text(title)
            .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
            .foregroundColor(AppTheme.textPrimary.opacity(0.88))
            .kerning(0.3)
        Spacer()
    }
}

@ViewBuilder func sectionHeader(sfIcon:String, title:String) -> some View {
    HStack(spacing:6) {
        Image(systemName:sfIcon)
            .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
            .foregroundColor(AppTheme.accent.opacity(0.60))
        Text(title)
            .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
            .foregroundColor(AppTheme.textPrimary.opacity(0.88))
            .kerning(0.3)
        Spacer()
    }
}

@ViewBuilder func summaryTile(label:String, value:String, color:Color) -> some View {
    VStack(alignment:.leading, spacing:3) {
        Text(value).font(.system(size:DSTSize.displaySmall,weight:.light,design:.rounded)).foregroundColor(color).monospacedDigit()
        Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
    }
    .frame(maxWidth:.infinity, alignment:.leading)
    .padding(8).background(AppTheme.bg2.opacity(0.6)).cornerRadius(10)
}

@ViewBuilder func kwRow(icon:String, color:Color, label:String, kws:[String]) -> some View {
    HStack(alignment:.top, spacing:6) {
        Image(systemName:icon).font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(color).padding(.top,2)
        Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color).frame(width:26,alignment:.leading)
        FlowLayout(spacing:4) {
            ForEach(kws,id:\.self) { kw in
                Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                    .padding(.horizontal,5).padding(.vertical,2)
                    .background(color.opacity(0.1)).cornerRadius(8)
            }
        }
    }
}

var cardBG: some View {
    ZStack {
        RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
        RoundedRectangle(cornerRadius:20).fill(LinearGradient(colors:[Color.white.opacity(0.03),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
    }
}



struct UnifiedBarChart: View {
    let data:[(String,Double)];let accentIdx:Int?
    var maxVal:Double{data.map(\.1).max() ?? 1}
    var body: some View {
        HStack(alignment:.bottom,spacing:6){
            ForEach(data.indices,id:\.self){ i in
                let val=data[i].1
                let isAccent=(accentIdx==i)||(accentIdx==nil && val==maxVal && val>0)
                VStack(spacing:5){
                    if val>0{Text("\(Int(val*100))%").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)}
                    else{Text("").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))}
                    RoundedRectangle(cornerRadius:5)
                        .fill(val<0.5 && val>0 ? AppTheme.danger.opacity(0.5):isAccent ? AppTheme.accent:val>0 ? AppTheme.accent.opacity(0.35):AppTheme.bg2)
                        .frame(height:max(4,val*72))
                    Text(data[i].0).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                }.frame(maxWidth:.infinity)
            }
        }.frame(height:110)
    }
}

struct AISummaryCard: View {
    let summary:String;let store:AppStore
    var lines:[String] {
        summary.components(separatedBy:"\n").filter{ !$0.trimmingCharacters(in:.whitespaces).isEmpty }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:12){
            HStack(spacing:6){
                Image(systemName:"sparkles")
                    .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.60))
                Text(store.t(key: L10n.smartSummaryLabel))
                    .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                    .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                    .kerning(0.3)
            }
            VStack(alignment:.leading, spacing:8){
                ForEach(Array(lines.enumerated()), id:\.offset){ _, line in
                    Text(line).font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary).lineSpacing(4)
                }
            }
        }.padding(16).background(AppTheme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16).stroke(AppTheme.accent.opacity(0.12),lineWidth:1))
    }
}

struct LowCompletionCard: View {
    let lowDays:[(String,Double)];let store:AppStore
    @State private var show=false;@State private var reason=""
    var body: some View {
        VStack(alignment:.leading,spacing:11){
            HStack{
                Image(systemName:"exclamationmark.circle").foregroundColor(AppTheme.danger)
                Text(L10n.lowCompletionFmt(lowDays.count, store.language)).font(.subheadline).foregroundColor(AppTheme.danger)
                Spacer()
                Button(action:{withAnimation{show.toggle()}}){Text(show ? store.t(key: L10n.collapseHide):store.t(key: L10n.recordReason)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)}
            }
            ForEach(lowDays,id:\.0){d in HStack{Text(d.0).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary);Text("\(Int(d.1*100))%").font(.caption).foregroundColor(AppTheme.danger);Spacer()}}
            if show{
                ZStack(alignment:.topLeading){
                    if reason.isEmpty{Text(store.t(key: L10n.reasonPlaceholder)).foregroundColor(AppTheme.textTertiary).font(.subheadline).padding(.horizontal,12).padding(.vertical,10)}
                    TextEditor(text:$reason).frame(minHeight:60).padding(8).scrollContentBackground(.hidden).foregroundColor(AppTheme.textPrimary).font(.subheadline)
                }.background(AppTheme.bg2).cornerRadius(10).overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border1,lineWidth:1))
                Button(store.t(key: L10n.save)){show=false}.frame(maxWidth:.infinity).padding(.vertical,9).background(AppTheme.accent).cornerRadius(10).foregroundColor(AppTheme.bg0).fontWeight(.medium)
            }
        }.padding(13).background(AppTheme.danger.opacity(0.06)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.danger.opacity(0.2),lineWidth:1))
    }
}


// ============================================================
// ============================================================
// MARK: - 目标进度卡（可折叠 · 精修版）
// ============================================================
//
// Design contract:
//  • Collapsed (default): header row + 2-row ghost peek + gradient mask
//  • Expanded: sort toggle + staggered goal rows
//  • Every child has .frame(height:34) → no row height variance
//  • Progress bar: 72pt fixed, .clipShape(Capsule) — never overflows
//  • Stat column: 48pt fixed, right-aligned — all rows perfectly grid
//  • Spring animations: response 0.40, dampingFraction 0.80
//  • Medal/streak column always in tree → no layout jump at 100%
//
// Summary chips (collapsed header):
//  [📅 月%] [✓ 今日/总] [⚡ 待决]   — compact, monospaced, colored
//
// Row layout:
//  [◉ dot 28w] [name flex] [bar 72w] [stat 48w right-aligned]
// ============================================================
struct GoalProgressCard: View {
    @EnvironmentObject var store: AppStore
    @State private var expanded: Bool = false

    private var today: Date { store.today }
    private var goals: [Goal] { store.goals }

    // ── Summary metrics for collapsed view ──────────────────────────────
    private var totalTasks: Int {
        goals.flatMap { store.tasks(for: today, goal: $0) }.count
    }
    private var doneTasks: Int {
        goals.flatMap { store.tasks(for: today, goal: $0) }
             .filter { store.progress(for: today, taskId: $0.id) >= 1.0 }.count
    }
    private var overallPct: Int {
        guard !goals.isEmpty else { return 0 }
        let s = goals.reduce(0.0) { $0 + store.goalProgress(for: $1, on: today) }
        return Int(min(s / Double(goals.count), 1.0) * 100)
    }
    private var allDone: Bool { !goals.isEmpty && doneTasks == totalTasks && totalTasks > 0 }

    var body: some View {
        VStack(spacing:0) {
            // ── Header — always visible ─────────────────────────────
            headerRow
            // ── Expanded: full goal list ────────────────────────────
            if expanded {
                goalList
                    .transition(.asymmetric(
                        insertion:.opacity.combined(with:.move(edge:.top))
                            .animation(.spring(response:0.32, dampingFraction:0.80)),
                        removal:.opacity.animation(.easeOut(duration:0.15))
                    ))
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                // Same Monet luminism wash as cardStyle()
                RoundedRectangle(cornerRadius:20)
                    .fill(LinearGradient(
                        colors:[Color.white.opacity(0.028), Color.clear],
                        startPoint:.topLeading, endPoint:.center
                    ))
            }
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0, lineWidth:0.8))
        .shadow(color:.black.opacity(0.18), radius:10, x:0, y:4)
        .animation(.spring(response:0.36, dampingFraction:0.80), value:expanded)
    }

    // ── Header row ───────────────────────────────────────────────────────
    // Collapsed: section title left | [%] [✓N/N tasks] [chevron] right
    // Expanded:  section title left | [sort hint]      [chevron] right
    private var headerRow: some View {
        Button(action:{
            UIImpactFeedbackGenerator(style:.light).impactOccurred()
            withAnimation(.spring(response:0.36, dampingFraction:0.80)) { expanded.toggle() }
        }) {
            HStack(alignment:.center, spacing:0) {
                // ── Section icon + title ─────────────────────────────
                HStack(spacing:6) {
                    Image(systemName:"chart.bar.fill")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent.opacity(0.60))
                    Text(store.t(key: L10n.goalProgressLabel))
                        .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                        .kerning(0.3)
                }
                Spacer(minLength: 8)

                if !goals.isEmpty {
                    // % pill — always accent background, text turns gold at 100%
                    Text("\(overallPct)%")
                        .font(.system(size: DSTSize.caption, weight: .semibold, design: .rounded))
                        .foregroundColor(allDone ? AppTheme.gold.opacity(0.92) : AppTheme.accent.opacity(0.88))
                        .monospacedDigit()
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.09))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.accent.opacity(0.15), lineWidth: 0.5))
                        .animation(.spring(response:0.28), value: overallPct)
                }

                // Chevron indicator
                Image(systemName: "chevron.down")
                    .font(.system(size: DSTSize.nano, weight: .bold, design: .rounded))
                    .foregroundColor(expanded ? AppTheme.accent.opacity(0.65) : AppTheme.textTertiary.opacity(0.35))
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .animation(.spring(response:0.30, dampingFraction:0.72), value:expanded)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ── Expanded goal list ───────────────────────────────────────────────
    private var goalList: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.border0.opacity(0.50))
                .frame(height: 0.4)
                .padding(.horizontal, 16)

            if goals.isEmpty {
                Text(store.t(key: L10n.noGoalsYet))
                    .font(.system(size: DSTSize.caption, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.50))
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                // Each goal = glass card mirroring TodayGoalSection aesthetics:
                //   left color strip | title | right done/total | progress bar below
                VStack(spacing: 6) {
                    ForEach(goals) { goal in
                        let pct        = store.goalProgress(for: goal, on: today)
                        let isDoneGoal = pct >= 1.0  // strict: 100% only
                        let tasks      = store.tasks(for: today, goal: goal)
                        let done       = tasks.filter { store.progress(for: today, taskId: $0.id) >= 1.0 }.count
                        let total      = tasks.count
                        let streak     = store.currentStreak(for: goal)

                        VStack(alignment: .leading, spacing: 0) {
                            // ── Top row: name + stat ─────────────────────
                            HStack(alignment: .center, spacing: 8) {
                                Text(goal.title)
                                    .font(.system(size: DSTSize.label, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary.opacity(isDoneGoal ? 0.78 : 0.88))
                                    .lineLimit(1)

                                Spacer(minLength: 6)

                                if goal.goalType == .longterm && streak > 0 {
                                    HStack(spacing: 3) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: DSTSize.nano, weight: .regular, design: .rounded))
                                            .foregroundColor(AppTheme.gold.opacity(0.75))
                                        Text("\(streak)")
                                            .font(.system(size: DSTSize.caption, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.gold.opacity(0.70))
                                            .monospacedDigit()
                                    }
                                } else if total > 0 {
                                    HStack(spacing: 3) {
                                        // Checkmark ONLY when fully done (strict badge rule)
                                        if isDoneGoal {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: DSTSize.nano, weight: .bold, design: .rounded))
                                                .foregroundColor(goal.color.opacity(0.88))
                                                .shadow(color: goal.color.opacity(0.45), radius: 3)
                                        }
                                        Text("\(done)/\(total)")
                                            .font(.system(size: DSTSize.caption,
                                                          weight: isDoneGoal ? .medium : .regular,
                                                          design: .rounded))
                                            .foregroundColor(isDoneGoal
                                                ? goal.color.opacity(0.80)
                                                : AppTheme.textTertiary.opacity(0.55))
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 6)

                            // ── Progress bar ─────────────────────────────
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AppTheme.bg3.opacity(0.70))
                                    if pct > 0 {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(LinearGradient(
                                                colors: isDoneGoal
                                                    ? [goal.color.opacity(0.75), goal.color]
                                                    : [goal.color.opacity(0.45), goal.color.opacity(0.78)],
                                                startPoint: .leading, endPoint: .trailing))
                                            .frame(width: max(4, geo.size.width * CGFloat(min(pct, 1.0))))
                                            .shadow(color: isDoneGoal ? goal.color.opacity(0.45) : .clear, radius: 3)
                                            .animation(.spring(response: 0.50, dampingFraction: 0.78), value: pct)
                                    }
                                }
                            }
                            .frame(height: 3)
                            .padding(.horizontal, 12).padding(.bottom, 9)
                        }
                        // Glass card background (same layering as TodayGoalSection)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(AppTheme.bg1)
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color.white.opacity(0.04), Color.clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(RadialGradient(
                                        colors: [goal.color.opacity(isDoneGoal ? 0.16 : 0.05), Color.clear],
                                        center: .topLeading, startRadius: 0, endRadius: 90))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isDoneGoal ? goal.color.opacity(0.30) : AppTheme.border0.opacity(0.60),
                                        lineWidth: isDoneGoal ? 0.9 : 0.6)
                        )
                        // Left accent strip — signature of Today page style
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [goal.color, goal.color.opacity(0.22)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: 3)
                                .padding(.vertical, 8)
                        }
                        .shadow(color: isDoneGoal ? goal.color.opacity(0.14) : .black.opacity(0.07),
                                radius: isDoneGoal ? 8 : 4, x: 0, y: 2)
                        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: isDoneGoal)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
    }
}


// ============================================================
// ============================================================
// MARK: - 智能洞察卡 — 3-Section Model (Hero · Insights · Next Step)
// ============================================================
//
// ══ OUTPUT MODEL ══════════════════════════════════════════
// InsightOutput is the single contract between data layer and UI.
// Future: replace ruleEngine() with an API call returning the
// same InsightOutput struct.
//
// struct InsightOutput {
//   hero:      String          // 1–2 sentence verdict
//   insights:  [InsightItem]   // max 3 items
//   nextStep:  String          // 1 concrete action
//   confidence: Double         // 0–1 (rule=0.6, AI=1.0)
// }
// struct InsightItem {
//   icon:  String   // SF Symbol name
//   label: String   // short label  e.g. "完成率"
//   value: String   // metric       e.g. "87%"
//   note:  String   // 1-sentence explanation
// }
// ═══════════════════════════════════════════════════════════

struct InsightItem {
    let icon:  String
    let label: String
    let value: String
    let note:  String
}

struct InsightOutput {
    let hero:       String
    let insights:   [InsightItem]
    let nextStep:   String
    let confidence: Double  // 0–1
}

// ── Rule-based insight engine — pure function, no side-effects ──
// Input:  all raw metrics as named params
// Output: InsightOutput — hero/insights/nextStep
// ─────────────────────────────────────────────────────────────────
func ruleEngine(
    lang: AppLanguage,
    pct: Int, done: Int, total: Int,
    pending: Int, resolved: Int,
    gains: Int, streak: Int,
    mood: Double, range: Int   // range: -1=day 0=week 1=month 2=year
) -> InsightOutput {

    func loc(_ zh:String,_ en:String,_ ja:String,_ ko:String,_ es:String)->String {
        switch lang {
        case .chinese: return zh; case .english: return en
        case .japanese: return ja; case .korean: return ko; case .spanish: return es
        }
    }
    let rangeName = loc(
        range == -1 ? "今日" : range == 0 ? "本周" : range == 1 ? "本月" : "今年",
        range == -1 ? "Today" : range == 0 ? "This week" : range == 1 ? "This month" : "This year",
        range == -1 ? "今日" : range == 0 ? "今週" : range == 1 ? "今月" : "今年",
        range == -1 ? "오늘" : range == 0 ? "이번 주" : range == 1 ? "이번 달" : "올해",
        range == -1 ? "Hoy" : range == 0 ? "Esta semana" : range == 1 ? "Este mes" : "Este año"
    )

    // ── Hero sentence ─────────────────────────────────────────────
    let hero: String
    if total == 0 {
        hero = loc(
            "还没有记录任务，开始规划\(rangeName)吧",
            "No tasks recorded — start planning \(rangeName)",
            "タスクはまだありません。\(rangeName)の計画を始めよう",
            "기록된 작업 없음 — \(rangeName) 계획을 시작해요",
            "Sin tareas registradas — comienza a planear \(rangeName)"
        )
    } else if pct >= 90 {
        hero = loc(
            "\(rangeName)完成率 \(pct)%，近乎完美，节奏极佳",
            "\(pct)% completion \(rangeName) — near-perfect execution",
            "\(rangeName)達成率\(pct)%、ほぼ完璧なペース",
            "\(rangeName) 달성률 \(pct)% — 거의 완벽한 실행력",
            "\(pct)% de logros \(rangeName) — ejecución casi perfecta"
        )
    } else if pct >= 70 {
        hero = loc(
            "\(rangeName)完成率 \(pct)%，稳健推进，保持节奏",
            "\(pct)% \(rangeName) — solid pace, keep the momentum",
            "\(rangeName)\(pct)%達成、安定したペースで前進中",
            "\(rangeName) \(pct)% — 안정적인 페이스로 진행 중",
            "\(pct)% \(rangeName) — ritmo sólido, mantén el impulso"
        )
    } else if pct >= 40 {
        hero = loc(
            "\(rangeName)完成率 \(pct)%，进度中等，聚焦核心任务有提升空间",
            "\(pct)% \(rangeName) — moderate pace, focus on core tasks",
            "\(rangeName)\(pct)%、まずまずのペース。コアタスクに集中しよう",
            "\(rangeName) \(pct)% — 중간 페이스, 핵심 작업에 집중하세요",
            "\(pct)% \(rangeName) — ritmo moderado, enfócate en tareas clave"
        )
    } else if pct > 0 {
        hero = loc(
            "\(rangeName)完成率 \(pct)%，目标有点多？试试聚焦3件最重要的事",
            "\(pct)% \(rangeName) — try focusing on just 3 priorities",
            "\(rangeName)\(pct)%。目標を絞って3つの優先事項に集中してみよう",
            "\(rangeName) \(pct)% — 3가지 우선순위에만 집중해보세요",
            "\(pct)% \(rangeName) — prueba enfocarte en solo 3 prioridades"
        )
    } else {
        hero = loc(
            "\(rangeName)还没有完成记录，开始第一步吧",
            "No completions recorded \(rangeName) — take the first step",
            "\(rangeName)はまだ完了記録なし。最初の一歩を踏み出そう",
            "\(rangeName) 완료 기록 없음 — 첫 발을 내딛어봐요",
            "Sin registros de logros \(rangeName) — da el primer paso"
        )
    }

    // ── Insight items (max 3) ─────────────────────────────────────
    var items: [InsightItem] = []

    // Item 1: Completion rate
    if total > 0 {
        let note: String
        if pct >= 80 {
            note = loc("完成率优秀，状态稳定","Excellent — stay consistent","素晴らしい達成率","훌륭한 달성률","Excelente tasa de logro")
        } else if pct >= 50 {
            note = loc("进展稳定，还有提升空间","Steady progress, room to grow","安定した進捗、伸びしろあり","꾸준한 진행, 성장 여지 있음","Progreso estable, hay margen de mejora")
        } else {
            note = loc("完成率偏低，考虑减少目标数量","Low rate — consider fewer goals","達成率低め、目標数を減らそう","달성률 낮음 — 목표 수 줄이기 검토","Tasa baja — considera menos objetivos")
        }
        items.append(InsightItem(
            icon: "checkmark.circle.fill",
            label: loc("完成率","Rate","達成率","달성률","Logros"),
            value: "\(pct)%",
            note: note
        ))
    }

    // Item 2: Task count or pending
    if pending > 0 {
        let note = pending >= 3
            ? loc("\(pending)项待决，先攻最卡的那个","\(pending) pending — tackle the most stuck first","\(pending)件保留中、詰まっているものから","\(pending)개 보류 — 막힌 것부터","\(pending) pendientes — ataca el más bloqueado")
            : loc("少量待决，可集中处理","Few pending — handle them in one session","少数保留、まとめて対処できる","소수 보류 — 한 번에 처리 가능","Pocos pendientes — manéjalos en una sesión")
        items.append(InsightItem(
            icon: pending >= 3 ? "exclamationmark.triangle.fill" : "clock.fill",
            label: loc("待决","Pending","保留中","보류","Pendientes"),
            value: "\(pending)",
            note: note
        ))
    } else if done > 0 && total > 0 {
        items.append(InsightItem(
            icon: "bolt.fill",
            label: loc("已完成","Tasks done","完了","완료","Tareas"),
            value: "\(done)/\(total)",
            note: loc("全部任务已完成","All tasks complete","全タスク完了","모든 작업 완료","Todas las tareas completadas")
        ))
    }

    // Item 3: Gains / streak
    if streak > 1 {
        let note = streak >= 7
            ? loc("连续\(streak)天记录，习惯已成型","\(streak)-day streak — habit is forming","\(streak)日連続、習慣が定着してきた","\(streak)일 연속 — 습관이 형성되고 있어요","Racha de \(streak) días — el hábito se está formando")
            : loc("连续\(streak)天，继续保持","\(streak) days running — keep going","\(streak)日連続、このまま続けよう","\(streak)일 연속 — 계속 유지해요","\(streak) días seguidos — sigue así")
        items.append(InsightItem(
            icon: "flame.fill",
            label: loc("连续","Streak","連続","연속","Racha"),
            value: "\(streak)d",
            note: note
        ))
    } else if gains > 0 {
        items.append(InsightItem(
            icon: "star.fill",
            label: loc("收获","Wins","成果","성과","Logros"),
            value: "\(gains)",
            note: loc("\(gains)条收获，记得复盘沉淀","\(gains) wins — take time to reflect","\(gains)個の成果、振り返りを","\(gains)개 성과 — 복기 시간을 가져요","\(gains) logros — reflexiona sobre ellos")
        ))
    }

    // ── Next step (1 concrete action) ────────────────────────────
    let nextStep: String
    if total == 0 {
        nextStep = loc("打开计划页，添加今天的第一个任务","Open Plan and add your first task for today","プランページを開いて最初のタスクを追加しよう","플랜 페이지를 열고 첫 번째 작업을 추가하세요","Abre Plan y añade tu primera tarea de hoy")
    } else if pending >= 3 {
        nextStep = loc("选一件最卡的待决事项，今天专注解决它","Pick the most stuck pending item — resolve it today","最も詰まっている保留件を一つ選んで今日解決しよう","가장 막힌 보류 항목 하나를 선택해 오늘 해결하세요","Elige el pendiente más bloqueado y resuélvelo hoy")
    } else if pct < 50 && total > 0 {
        nextStep = loc("把任务列表缩减到3件核心，先完成最重要的","Reduce your list to 3 core tasks, do the most important first","タスクを3つに絞り、最重要なものから始めよう","작업을 핵심 3개로 줄이고 가장 중요한 것부터 시작","Reduce tu lista a 3 tareas clave, empieza por la más importante")
    } else if pct >= 80 && gains == 0 {
        nextStep = loc("完成率很高，花5分钟记录一条今天的收获","High completion — spend 5 min recording a win","達成率高め、今日の成果を5分で記録しよう","달성률 높음 — 5분 동안 오늘의 성과를 기록하세요","Alta tasa — dedica 5 min a registrar un logro de hoy")
    } else if streak > 0 {
        nextStep = loc("继续\(streak+1)天连续记录的目标，今天别断","Keep the \(streak+1)-day streak going — don't break it today","\(streak+1)日連続記録を目指そう、今日も続けて","\(streak+1)일 연속 기록 목표 — 오늘도 이어가세요","Mantén la racha de \(streak+1) días — no la rompas hoy")
    } else {
        nextStep = loc("今天完成一个目标的所有任务，体验100%的感觉","Complete all tasks for one goal today — feel the 100%","今日は一つの目標を全て完了しよう","오늘 한 가지 목표의 모든 작업을 완료해 보세요","Completa todas las tareas de un objetivo hoy — siente el 100%")
    }

    return InsightOutput(
        hero: hero,
        insights: Array(items.prefix(3)),
        nextStep: nextStep,
        confidence: 0.65
    )
}

// ── Tappable metric tile (used by MergedSummaryCard 6-grid) ──────
struct MetricTile: View {
    let value: String
    let label: String
    let color: Color
    var items: [String] = []
    var noteItems: [(kw:String, note:String)] = []
    var extraText: String = ""
    @State private var expanded = false
    var tappable: Bool { !items.isEmpty || !noteItems.isEmpty || !extraText.isEmpty }

    var body: some View {
        VStack(spacing:0) {
            Button(action:{
                guard tappable else { return }
                withAnimation(.spring(response:0.28)){ expanded.toggle() }
            }) {
                VStack(spacing:3) {
                    // stat value — statValue token
                    Text(value)
                        .font(.system(size:DSTSize.statValue, weight:.light, design:.rounded))
                        .foregroundColor(color)
                        .monospacedDigit()
                    // label — cardMicro token
                    HStack(spacing:3) {
                        Text(label)
                            .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.82))
                        if tappable {
                            Image(systemName: expanded ? "chevron.up":"chevron.down")
                                .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                        }
                    }
                }
                .frame(maxWidth:.infinity)
                .padding(.vertical,11)
            }
            .buttonStyle(.plain)

            if expanded && tappable {
                Rectangle().fill(Color.white.opacity(0.07)).frame(height:0.5).padding(.horizontal,8)
                VStack(alignment:.leading, spacing:5) {
                    if !items.isEmpty {
                        FlowLayout(spacing:4) {
                            ForEach(items, id:\.self) { kw in
                                Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color.opacity(0.9))
                                    .padding(.horizontal,7).padding(.vertical,3)
                                    .background(color.opacity(0.1)).cornerRadius(12)
                            }
                        }
                    }
                    ForEach(noteItems, id:\.kw) { item in
                        HStack(alignment:.top, spacing:5) {
                            Image(systemName:"checkmark.circle.fill").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                .foregroundColor(color).padding(.top,1)
                            VStack(alignment:.leading, spacing:1) {
                                Text(item.kw).font(.system(size:DSTSize.micro,weight:.medium, design:.rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .strikethrough(true, color:.white.opacity(0.3))
                                if !item.note.isEmpty {
                                    Text(item.note).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(.white.opacity(0.4)).lineLimit(2)
                                }
                            }
                        }
                    }
                    if !extraText.isEmpty {
                        Text(extraText).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(.white.opacity(0.4)).lineSpacing(2)
                    }
                }
                .padding(.horizontal,9).padding(.vertical,7)
                .frame(maxWidth:.infinity, alignment:.leading)
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
    }
}

// ── Smart Insight Card ────────────────────────────────────────────
struct MergedSummaryCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let range: Int          // -1=日, 0=週, 1=月, 2=年
    var periodDates: [Date]? = nil
    var singleDate: Date? = nil
    @State private var showSummary = false
    @State private var summaryCtx: SummaryContext = SummaryContext(periodType:-1, periodLabel:"", dates:[], sheetTitle:"")

    var dates: [Date] {
        if range == -1, let d = singleDate { return [d] }
        return periodDates ?? (range==0 ? store.weekDates() : range==1 ? store.monthDates() : store.yearDates())
    }

    var hasData: Bool {
        dates.contains { store.completionRate(for:$0) > 0 || store.review(for:$0)?.isSubmitted == true }
    }

    // ── Raw metrics ──────────────────────────────────────────────
    var completionPct: Int { Int(store.avgCompletion(for: dates) * 100) }

    var taskStats: (done: Int, total: Int) {
        var done = 0; var total = 0
        for d in dates {
            let tasks = store.goals(for:d).flatMap { store.tasks(for:d, goal:$0) }
            total += tasks.count
            done  += tasks.filter { store.progress(for:d, taskId:$0.id) >= 1.0 }.count
        }
        return (done, total)
    }

    var pendingCount: Int {
        store.dailyChallenges.filter { $0.resolvedOnDate == nil }.count
    }

    var resolvedCount: Int {
        store.resolvedEntriesInPeriod(dates: dates).count
    }

    var gainCount: Int {
        store.allGainKeywords(for: dates).count
    }

    var currentStreak: Int {
        store.goals.map { store.currentStreak(for: $0) }.max() ?? 0
    }

    var avgMood: Double {
        let rs = dates.compactMap { store.review(for:$0) }.filter { $0.isSubmitted && $0.rating > 0 }
        guard !rs.isEmpty else { return 0 }
        return Double(rs.map(\.rating).reduce(0,+)) / Double(rs.count)
    }

    // ── Computed insight ─────────────────────────────────────────
    var insight: InsightOutput {
        let ts = taskStats
        return ruleEngine(
            lang: store.language,
            pct: completionPct, done: ts.done, total: ts.total,
            pending: pendingCount, resolved: resolvedCount,
            gains: gainCount, streak: currentStreak,
            mood: avgMood, range: range
        )
    }

    // ── Bottom insight line (mood-aware, rule-based) ─────────────
    var insightLine: String {
        let pct   = completionPct
        let cs    = challengeState
        let lang  = store.language
        let mood  = avgMood
        let toneHigh = mood >= 4.0
        let toneLow  = mood > 0 && mood < 2.5
        let resolvedNoted = resolvedEntries.filter { !$0.resolvedNote.isEmpty }
        var parts: [String] = []

        func hi(_ zh: String, _ en: String, _ ja: String, _ ko: String, _ es: String) -> String {
            switch lang { case .chinese: return zh; case .english: return en; case .japanese: return ja; case .korean: return ko; case .spanish: return es }
        }

        if toneHigh {
            parts.append(pct >= 80
                ? hi("状态绝佳，势头超强，继续冲！", "On fire — keep charging!", "絶好調！その勢いで突き進もう！", "최상의 상태! 계속 달려가!", "¡En racha — sigue adelante!")
                : hi("心态很好，调整节奏就能更上层楼！", "Great energy — tune the pace and you'll soar!", "前向きな姿勢！リズムを整えてさらに高みへ！", "에너지 넘쳐! 페이스 조절하면 더 높이 날 수 있어!", "¡Buena energía — ajusta el ritmo y llegarás más lejos!"))
        } else if toneLow {
            parts.append(pct >= 60
                ? hi("难关中仍完成了\(pct)%，这份韧劲很了不起", "\(pct)% through tough times — that resilience is real", "辛い時でも\(pct)%達成、その粘り強さは本物だ", "힘든 중에도 \(pct)% 완료 — 그 끈기가 진짜야", "\(pct)% en tiempos difíciles — esa resiliencia es real")
                : hi("状态低谷很正常，休息也是进步，你在坚持", "Low days are part of it — rest is progress too", "調子が悪い日もある、休息も前進の一部だよ", "저조한 날도 괜찮아 — 휴식도 성장의 일부야", "Los días bajos son normales — descansar también es avanzar"))
        } else {
            if pct >= 80      { parts.append(hi("\(pct)%完成率，节奏稳健，保持！", "\(pct)% — solid and steady!", "\(pct)%達成、安定したペース！", "\(pct)% 완료 — 안정적인 페이스!", "\(pct)% — ¡sólido y constante!")) }
            else if pct >= 50 { parts.append(hi("稳步推进中，\(pct)%，还有空间", "Steady at \(pct)% — room to grow", "着実に前進中、\(pct)%、まだ伸びしろがある", "꾸준히 \(pct)% 진행 중 — 성장 여지 있어", "Avanzando a \(pct)% — hay espacio para crecer")) }
            else if pct > 0   { parts.append(hi("目标有点多？聚焦3件最重要的事", "Too many goals? Focus on your top 3", "目標が多すぎ？重要な3つに絞ろう", "목표가 너무 많아? 가장 중요한 3가지에 집중해", "¿Demasiadas metas? Enfócate en las 3 más importantes")) }
            else              { parts.append(hi("开始记录，每一天都算数 💪", "Start logging — every day counts 💪", "記録を始めよう、毎日が大切だ 💪", "기록 시작해 — 매일이 소중해 💪", "Empieza a registrar — cada día cuenta 💪")) }
        }
        if cs.active.count >= 3 {
            parts.append(toneLow
                ? hi("有\(cs.active.count)项待决，不急，一件件来", "\(cs.active.count) pending — no rush, one at a time", "\(cs.active.count)件保留中、焦らず一つずつ", "\(cs.active.count)개 보류 중 — 서두르지 말고 하나씩", "\(cs.active.count) pendientes — sin prisa, de a uno")
                : hi("\(cs.active.count)项待决，先攻最卡的那个", "\(cs.active.count) pending — tackle the most stuck one", "\(cs.active.count)件保留中、一番詰まっているものから", "\(cs.active.count)개 보류 — 가장 막힌 것부터 해결해", "\(cs.active.count) pendientes — ataca el más bloqueado"))
        } else if cs.active.count > 0 {
            let p = cs.active.prefix(2).joined(separator: "、")
            parts.append(hi("记得推进：\(p)", "Push forward: \(p)", "進めよう：\(p)", "진행 기억해: \(p)", "Avanza con: \(p)"))
        }
        if !resolvedNoted.isEmpty, !cs.active.isEmpty,
           let m = resolvedNoted.first(where:{ re in cs.active.contains{ $0.contains(re.keyword)||re.keyword.contains($0) }}),
           !m.resolvedNote.isEmpty {
            parts.append(hi("以往经验：\(m.resolvedNote)", "Past insight: \(m.resolvedNote)", "過去の経験：\(m.resolvedNote)", "이전 경험: \(m.resolvedNote)", "Experiencia pasada: \(m.resolvedNote)"))
        }
        if gainKW.count >= 3 {
            parts.append(toneHigh
                ? hi("收获\(gainKW.count)条，高速成长中！", "\(gainKW.count) wins — you're growing fast!", "\(gainKW.count)個の成果、急成長中！", "\(gainKW.count)개 성과 — 빠르게 성장하고 있어!", "\(gainKW.count) logros — ¡estás creciendo rápido!")
                : hi("收获\(gainKW.count)条，记得复盘沉淀", "\(gainKW.count) wins — take time to reflect", "\(gainKW.count)個の成果、振り返りを忘れずに", "\(gainKW.count)개 성과 — 복기할 시간을 가져", "\(gainKW.count) logros — tómate tiempo para reflexionar"))
        }
        return parts.joined(separator: " · ")
    }

    var challengeState: (active:[String], resolved:[String]) {
        if range == -1, let d = singleDate ?? dates.first {
            let s = store.dailyChallengeState(for:d); return (s.active, s.resolved)
        }
        return store.periodChallengeState(dates:dates)
    }
    var gainKW: [String] { store.allGainKeywords(for: dates) }
    var resolvedEntries: [DailyChallengeEntry] { store.resolvedEntriesInPeriod(dates:dates) }
    var moodEmoji: String {
        switch avgMood {
        case 4.5...: return "✨"; case 3.5...: return "🤍"
        case 2.5...: return "🙂"; case 1.0...: return "😶"
        default: return ""
        }
    }

    var body: some View {
        if !hasData { EmptyView() } else {
            VStack(alignment:.leading, spacing:0) {
                // ── Header — sectionTitle token ──────────────────────
                HStack(spacing:8) {
                    Image(systemName:"sparkles")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent.opacity(0.60))
                        .frame(width:20, alignment:.center)
                    Text(store.t(key: L10n.smartSummaryLabel))
                        .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                        .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                        .kerning(0.3)
                    Spacer()
                    if !moodEmoji.isEmpty {
                        Text(moodEmoji)
                            .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                    }
                    Text(store.t(key: L10n.doubleTapExpand))
                        .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.62))
                }
                .padding(.horizontal,14).padding(.top,14).padding(.bottom,10)

                Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(height:0.5)

                // ── 6格数据 3×2 ─────────────────────────────
                let ts = taskStats
                let cs = challengeState
                let accentGreen  = Color(red:0.420, green:0.730, blue:0.550)
                let accentPurple = Color(red:0.750, green:0.580, blue:0.780)
                let pendingColor = cs.active.isEmpty ? accentGreen : AppTheme.gold.opacity(0.85)

                VStack(spacing:0) {
                    HStack(spacing:0) {
                        MetricTile(value:"\(completionPct)%",
                            label:store.t(key: L10n.completionRate), color:AppTheme.accent,
                            extraText:completionPct >= 85 ? store.t(key: L10n.excellentStatus) :
                                      completionPct >= 60 ? store.t(key: L10n.steadyStatus) :
                                      store.t(key: L10n.keepGoingStatus))
                        vDivider
                        MetricTile(value:"\(ts.done)/\(ts.total)",
                            label:store.t(key: L10n.tasksDoneLabel), color:AppTheme.accent,
                            extraText:L10n.taskSummaryFmt(ts.total, ts.done, store.language))
                        vDivider
                        MetricTile(value:"\(cs.active.count + cs.resolved.count)",
                            label:store.t(key: L10n.pendingTotalLabel), color:pendingColor,
                            items: cs.active + cs.resolved)
                    }
                    Rectangle().fill(AppTheme.border0.opacity(0.4)).frame(height:0.5).padding(.horizontal,8)
                    HStack(spacing:0) {
                        MetricTile(value:"\(cs.resolved.count)",
                            label:store.t(key: L10n.resolved), color:accentGreen,
                            noteItems: resolvedEntries.map { (kw:$0.keyword, note:$0.resolvedNote) })
                        vDivider
                        MetricTile(value:"\(gainKW.count)",
                            label:store.t(key: L10n.wins), color:accentGreen,
                            items: gainKW)
                        vDivider
                        MetricTile(value:"\(store.allPlanKeywords(for:dates).count)",
                            label:store.t(key: L10n.plans), color:accentPurple,
                            items: store.allPlanKeywords(for:dates))
                    }
                }
                .background(AppTheme.bg2.opacity(0.35))

                Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(height:0.5)

                // ── 底部洞察 — cardBody token ─────────────────────────
                HStack(alignment:.top, spacing:8) {
                    Image(systemName:"lightbulb.fill")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent.opacity(0.60))
                        .frame(width:20, alignment:.center)
                        .padding(.top,1)
                    Text(insightLine)
                        .font(.system(size:DSTSize.cardBody, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textSecondary.opacity(0.92))
                        .lineSpacing(4)
                        .fixedSize(horizontal:false, vertical:true)
                    Spacer()
                }
                .padding(.horizontal,14).padding(.vertical,11)
            }
            .background(AppTheme.bg1)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius:16).stroke(AppTheme.accent.opacity(0.1),lineWidth:1))
            .contentShape(RoundedRectangle(cornerRadius:16))
            .onTapGesture(count:2) {
                if range == -1, let d = singleDate {
                    summaryCtx = SummaryContext.forDay(d, store:store)
                } else {
                    let label: String; let ds: [Date]
                    switch range {
                    case 0:  label = store.currentWeekLabel;  ds = store.weekDates()
                    case 1:  label = store.currentMonthLabel; ds = store.monthDates()
                    default: label = store.currentYearLabel;  ds = store.yearDates()
                    }
                    switch range {
                    case 0:  summaryCtx = SummaryContext.forWeek(label:label, dates:ds, store:store)
                    case 1:  summaryCtx = SummaryContext.forMonth(label:label, dates:ds, store:store)
                    default: summaryCtx = SummaryContext.forYear(label:label, dates:ds, store:store)
                    }
                }
                showSummary = true
            }
            .sheet(isPresented:$showSummary) {
                SmartSummarySheet(ctx:summaryCtx)
                    .environmentObject(store)
                    .environmentObject(pro)
            }
        }
    }

    @ViewBuilder var vDivider: some View {
        Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(width:0.5).padding(.vertical,5)
    }
}



// MARK: - 本月每周情况卡
// ============================================================
struct MonthlyDigestCard: View {
    @EnvironmentObject var store: AppStore
    @State private var expandedWeek: String? = nil

    var weekEntries: [AppStore.MonthWeekEntry] { store.monthWeekEntries() }
    var monthLabel: String { store.currentMonthLabel }

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            HStack {
                Text(store.t(key: L10n.monthByWeek))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).kerning(1.5)
                Spacer()
                // 未解决困难数
                let unresolved = store.allSubChallengeKeywords(type:1, dates:store.monthDates())
                let resolved = weekEntries.reduce(0) { cnt, we in
                    let ws = store.periodSummary(type:0, label:we.periodLabel)
                    return cnt + (ws?.resolvedChallenges.count ?? 0)
                }
                if !unresolved.isEmpty || resolved > 0 {
                    HStack(spacing:4) {
                        Image(systemName:"checkmark.shield").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                        Text("\(resolved)/\(unresolved.count + resolved)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                    }
                    .padding(.horizontal,7).padding(.vertical,3)
                    .background(AppTheme.gold.opacity(0.08)).cornerRadius(6)
                }
            }

            VStack(spacing:0) {
                ForEach(weekEntries, id:\.periodLabel) { we in
                    let isExp = expandedWeek == we.periodLabel
                    let rate = store.avgCompletion(for: we.dates)
                    let moodAvg = store.avgMood(for: we.dates)
                    let ws = store.periodSummary(type:0, label:we.periodLabel)
                    let challengeKW = ws?.challengeKeywords ?? []
                    let gainKW     = store.allGainKeywords(for:we.dates)
                    let nextKW     = store.allPlanKeywords(for:we.dates)
                    let hasContent = ws != nil || !gainKW.isEmpty || !nextKW.isEmpty

                    VStack(alignment:.leading, spacing:0) {
                        // 主行
                        Button(action:{
                            guard hasContent else { return }
                            withAnimation(.spring(response:0.3)){ expandedWeek = isExp ? nil : we.periodLabel }
                        }) {
                            HStack(spacing:10) {
                                Text(we.weekLabel)
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                    .foregroundColor(AppTheme.textTertiary).frame(width:36,alignment:.leading)
                                GeometryReader { geo in
                                    ZStack(alignment:.leading) {
                                        RoundedRectangle(cornerRadius:2).fill(AppTheme.bg3).frame(height:4)
                                        if rate > 0 {
                                            RoundedRectangle(cornerRadius:2)
                                                .fill(rate >= 0.8 ? AppTheme.accent : rate >= 0.5 ? AppTheme.accent.opacity(0.6) : AppTheme.danger.opacity(0.5))
                                                .frame(width:geo.size.width * rate, height:4)
                                        }
                                    }
                                }.frame(height:4)
                                Text(rate > 0 ? "\(Int(rate*100))%" : "—")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary).frame(width:28)
                                Text(moodAvg > 0 ? ["","😞","😶","🙂","🤍","✨"][min(Int(moodAvg.rounded()),5)] : "")
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).frame(width:18)
                                HStack(spacing:3) {
                                    if !gainKW.isEmpty { Circle().fill(AppTheme.accent.opacity(0.7)).frame(width:5,height:5) }
                                    if !challengeKW.isEmpty { Circle().fill(AppTheme.gold.opacity(0.8)).frame(width:5,height:5) }
                                }.frame(width:16)
                                if hasContent {
                                    Image(systemName:isExp ? "chevron.up":"chevron.down")
                                        .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                                }
                            }.padding(.vertical,9)
                        }.buttonStyle(.plain)

                        // 展开：周总结关键词 + 困难勾选
                        if isExp, let ws = ws {
                            VStack(alignment:.leading, spacing:8) {
                                if !gainKW.isEmpty {
                                    weekMiniKWRow(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.wins),kws:gainKW)
                                }
                                if !challengeKW.isEmpty {
                                    VStack(alignment:.leading,spacing:6) {
                                        weekMiniKWRow(icon:"exclamationmark.triangle.fill",color:AppTheme.gold,label:store.t(key: L10n.pending),kws:challengeKW)
                                        ForEach(challengeKW, id:\.self) { kw in
                                            let solved = ws.resolvedChallenges.contains(kw)
                                            Button(action:{ store.toggleResolvedChallenge(type:0, label:we.periodLabel, keyword:kw) }) {
                                                HStack(spacing:7) {
                                                    Image(systemName:solved ? "checkmark.circle.fill":"circle")
                                                        .font(.caption).foregroundColor(solved ? AppTheme.accent : AppTheme.border1)
                                                    Text(kw).font(.caption)
                                                        .foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textSecondary)
                                                        .strikethrough(solved, color:AppTheme.textTertiary)
                                                    Spacer()
                                                    Text(solved ? store.t(key: L10n.resolvedDone) : store.t(key: L10n.pendingResolve))
                                                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(solved ? AppTheme.accent : AppTheme.gold)
                                                }
                                                .padding(.horizontal,10).padding(.vertical,5)
                                                .background(solved ? AppTheme.accent.opacity(0.05) : AppTheme.gold.opacity(0.06))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                if !nextKW.isEmpty {
                                    weekMiniKWRow(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.plan),kws:nextKW)
                                }
                            }
                            .padding(.leading,36).padding(.bottom,10).padding(.top,2)
                            .transition(.opacity.combined(with:.move(edge:.top)))
                        }

                        if we.periodLabel != weekEntries.last?.periodLabel {
                            Rectangle().fill(AppTheme.border0).frame(height:0.5)
                        }
                    }
                }
            }
        }
        .padding(16).background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                RoundedRectangle(cornerRadius:20).fill(LinearGradient(colors:[Color.white.opacity(0.03),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
            }
        ).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0,lineWidth:1))
        .shadow(color:.black.opacity(0.22),radius:8,x:0,y:3)
    }

    @ViewBuilder
    func weekMiniKWRow(icon:String, color:Color, label:String, kws:[String]) -> some View {
        HStack(alignment:.top, spacing:5) {
            Image(systemName:icon).font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(color).padding(.top,2)
            Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color).frame(width:28,alignment:.leading)
            FlowLayout(spacing:4) {
                ForEach(kws, id:\.self) { kw in
                    Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                        .padding(.horizontal,5).padding(.vertical,2)
                        .background(color.opacity(0.1)).cornerRadius(9)
                }
            }
        }
    }
}

// ============================================================
// MARK: - 本年每月情况卡
// ============================================================
struct YearlyDigestCard: View {
    @EnvironmentObject var store: AppStore
    @State private var expandedMonth: String? = nil

    var monthEntries: [AppStore.YearMonthEntry] { store.yearMonthEntries() }
    var yearLabel: String { store.currentYearLabel }

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            HStack {
                Text(store.t(key: L10n.yearByMonth))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).kerning(1.5)
                Spacer()
                let unresolved = store.allSubChallengeKeywords(type:2, dates:store.yearDates())
                if !unresolved.isEmpty {
                    HStack(spacing:4) {
                        Image(systemName:"checkmark.shield").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                        let resolvedCnt = store.periodSummary(type:2, label:yearLabel)?.resolvedChallenges.count ?? 0
                        Text("\(resolvedCnt)/\(unresolved.count + resolvedCnt)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                    }
                    .padding(.horizontal,7).padding(.vertical,3).background(AppTheme.gold.opacity(0.08)).cornerRadius(6)
                }
            }

            VStack(spacing:0) {
                ForEach(monthEntries, id:\.periodLabel) { me in
                    let isExp = expandedMonth == me.periodLabel
                    let rate = store.avgCompletion(for:me.dates)
                    let moodAvg = store.avgMood(for:me.dates)
                    let ms = store.periodSummary(type:1, label:me.periodLabel)
                    let challengeKW = ms?.challengeKeywords ?? []
                    let gainKW     = store.allGainKeywords(for:me.dates)
                    let nextKW_m   = store.allPlanKeywords(for:me.dates)
                    let hasContent = ms != nil || !gainKW.isEmpty || !nextKW_m.isEmpty
                    let isCurrent = Calendar.current.component(.month, from:store.today) == me.month

                    VStack(alignment:.leading, spacing:0) {
                        Button(action:{
                            guard hasContent else { return }
                            withAnimation(.spring(response:0.3)){ expandedMonth = isExp ? nil : me.periodLabel }
                        }) {
                            HStack(spacing:10) {
                                Text(me.monthLabel)
                                    .font(.system(size:DSTSize.caption, weight:isCurrent ? .semibold:.regular, design:.rounded))
                                    .foregroundColor(isCurrent ? AppTheme.accent : AppTheme.textTertiary)
                                    .frame(width:32, alignment:.leading)
                                GeometryReader { geo in
                                    ZStack(alignment:.leading) {
                                        RoundedRectangle(cornerRadius:2).fill(AppTheme.bg3).frame(height:4)
                                        if rate > 0 {
                                            RoundedRectangle(cornerRadius:2)
                                                .fill(rate >= 0.8 ? AppTheme.accent : rate >= 0.5 ? AppTheme.accent.opacity(0.6) : AppTheme.danger.opacity(0.5))
                                                .frame(width:geo.size.width * rate, height:4)
                                        }
                                    }
                                }.frame(height:4)
                                Text(rate > 0 ? "\(Int(rate*100))%" : "—")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary).frame(width:28)
                                Text(moodAvg > 0 ? ["","😞","😶","🙂","🤍","✨"][min(Int(moodAvg.rounded()),5)] : "")
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).frame(width:18)
                                HStack(spacing:3) {
                                    if !gainKW.isEmpty { Circle().fill(AppTheme.accent.opacity(0.7)).frame(width:5,height:5) }
                                    if !challengeKW.isEmpty { Circle().fill(AppTheme.gold.opacity(0.8)).frame(width:5,height:5) }
                                }.frame(width:16)
                                if hasContent {
                                    Image(systemName:isExp ? "chevron.up":"chevron.down")
                                        .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                                }
                            }.padding(.vertical,9)
                        }.buttonStyle(.plain)

                        if isExp, let ms = ms {
                            VStack(alignment:.leading, spacing:8) {
                                if !gainKW.isEmpty {
                                    monthMiniKWRow(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.wins),kws:gainKW)
                                }
                                if !challengeKW.isEmpty {
                                    VStack(alignment:.leading,spacing:6) {
                                        monthMiniKWRow(icon:"exclamationmark.triangle.fill",color:AppTheme.gold,label:store.t(key: L10n.pending),kws:challengeKW)
                                        ForEach(challengeKW, id:\.self) { kw in
                                            let solved = ms.resolvedChallenges.contains(kw)
                                            Button(action:{ store.toggleResolvedChallenge(type:1, label:me.periodLabel, keyword:kw) }) {
                                                HStack(spacing:7) {
                                                    Image(systemName:solved ? "checkmark.circle.fill":"circle")
                                                        .font(.caption).foregroundColor(solved ? AppTheme.accent : AppTheme.border1)
                                                    Text(kw).font(.caption)
                                                        .foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textSecondary)
                                                        .strikethrough(solved, color:AppTheme.textTertiary)
                                                    Spacer()
                                                    Text(solved ? store.t(key: L10n.resolvedDone) : store.t(key: L10n.pendingResolve))
                                                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(solved ? AppTheme.accent : AppTheme.gold)
                                                }
                                                .padding(.horizontal,10).padding(.vertical,5)
                                                .background(solved ? AppTheme.accent.opacity(0.05) : AppTheme.gold.opacity(0.06))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                if let nextKW = ms.nextKeywords as [String]?, !nextKW.isEmpty {
                                    monthMiniKWRow(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.plan),kws:nextKW)
                                }
                            }
                            .padding(.leading,36).padding(.bottom,10).padding(.top,2)
                            .transition(.opacity.combined(with:.move(edge:.top)))
                        }

                        if me.periodLabel != monthEntries.last?.periodLabel {
                            Rectangle().fill(AppTheme.border0).frame(height:0.5)
                        }
                    }
                }
            }
        }
        .padding(16).background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                RoundedRectangle(cornerRadius:20).fill(LinearGradient(colors:[Color.white.opacity(0.03),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
            }
        ).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0,lineWidth:1))
        .shadow(color:.black.opacity(0.22),radius:8,x:0,y:3)
    }

    @ViewBuilder
    func monthMiniKWRow(icon:String, color:Color, label:String, kws:[String]) -> some View {
        HStack(alignment:.top, spacing:5) {
            Image(systemName:icon).font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(color).padding(.top,2)
            Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color).frame(width:28,alignment:.leading)
            FlowLayout(spacing:4) {
                ForEach(kws, id:\.self) { kw in
                    Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                        .padding(.horizontal,5).padding(.vertical,2)
                        .background(color.opacity(0.1)).cornerRadius(9)
                }
            }
        }
    }
}

// ============================================================
// MARK: - 调试日期行（临时功能，供测试跨天/跨周/跨月逻辑）
// ============================================================
struct DebugDateRow: View {
    @EnvironmentObject var store: AppStore
    @State private var showPicker = false

    var displayText: String {
        guard let d = store.simulatedDate else { return store.t(key: L10n.realTodayLabel) }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from:d)
    }

    var body: some View {
        VStack(alignment:.leading, spacing:0) {
            HStack {
                Image(systemName:"calendar.badge.exclamationmark")
                    .font(.caption).foregroundColor(AppTheme.danger.opacity(0.7))
                Text(store.t(key: L10n.debugDateLabel))
                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.secondary)
                Spacer()
                Button(action:{ withAnimation(.spring(response:0.3)){ showPicker.toggle() }}) {
                    HStack(spacing:4) {
                        Text(displayText).font(.caption).foregroundColor(AppTheme.danger.opacity(0.8))
                        Image(systemName:showPicker ? "chevron.up":"chevron.down")
                            .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                    }
                }
            }
            if showPicker {
                VStack(spacing:8) {
                    Rectangle().fill(AppTheme.border0).frame(height:0.5)
                    DatePicker("", selection: Binding(
                        get:{ store.simulatedDate ?? Date() },
                        set:{ store.simulatedDate = $0 }
                    ), displayedComponents:.date)
                    .datePickerStyle(.graphical)
                    .colorScheme(.dark)
                    .tint(AppTheme.accent)
                    HStack(spacing:10) {
                        Button(store.t(key: L10n.resetToToday)) {
                            store.simulatedDate = nil
                            withAnimation { showPicker = false }
                        }
                        .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                        .padding(.horizontal,12).padding(.vertical,6)
                        .background(AppTheme.bg2).cornerRadius(8)
                        Spacer()
                        Button(store.t(key: L10n.confirm)) {
                            withAnimation { showPicker = false }
                        }
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(AppTheme.bg0)
                        .padding(.horizontal,14).padding(.vertical,6)
                        .background(AppTheme.accent).cornerRadius(8)
                    }
                }.padding(.top,6)
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
    }
}

// ============================================================
// MARK: - 历史心得（折叠树：年→月→周→日）
// ============================================================

// ── 本周每日完成度 + 关键词 + 困难追踪 ──────────────────────
struct WeeklyDigestCard: View {
    @EnvironmentObject var store: AppStore
    @State private var expandedDay: Date? = nil
    let emojis = ["","😞","😶","🙂","🤍","✨"]

    struct DayRow: Identifiable {
        let id = UUID()
        let date: Date; let label: String; let rate: Double; let rating: Int
        let gainKW: [String]; let challengeKW: [String]; let tomorrowKW: [String]
        let isFuture: Bool
    }

    var rows: [DayRow] {
        let wds = store.weekDates()
        let labels: [String]
        switch store.language {
        case .chinese:  labels = ["一","二","三","四","五","六","日"]
        case .english:  labels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        case .japanese: labels = ["月","火","水","木","金","土","日"]
        case .korean:   labels = ["월","화","수","목","금","토","일"]
        case .spanish:  labels = ["Lun","Mar","Mié","Jue","Vie","Sáb","Dom"]
        }
        let tod = Calendar.current.startOfDay(for:store.today)
        return wds.enumerated().map { (i,d) in
            let rev = store.review(for:d)
            return DayRow(
                date:d, label:labels[safe:i] ?? labels[0],
                rate:store.completionRate(for:d),
                rating:rev?.rating ?? 0,
                gainKW:rev?.gainKeywords ?? [],
                challengeKW:rev?.challengeKeywords ?? [],
                tomorrowKW:rev?.tomorrowKeywords ?? [],
                isFuture:Calendar.current.startOfDay(for:d) > tod
            )
        }
    }

    var weekLabel: String { store.currentWeekLabel }
    var weekSummary: PeriodSummary? { store.periodSummary(type:0, label:weekLabel) }
    var allChallengeKW: [String] {
        rows.flatMap(\.challengeKW).reduce(into:[String]()){ if !$0.contains($1){$0.append($1)} }
    }
    var resolvedCount: Int { allChallengeKW.filter { weekSummary?.resolvedChallenges.contains($0) ?? false }.count }


    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            // 标题
            HStack {
                Text(store.t(key: L10n.thisWeekDaily)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).kerning(1.5)
                Spacer()
            }

            // 每日行
            VStack(spacing:0) {
                ForEach(rows) { row in
                    let isTdy = Calendar.current.isDate(row.date, inSameDayAs:store.today)
                    let isExp = expandedDay.map { Calendar.current.isDate($0,inSameDayAs:row.date) } ?? false
                    let hasDetail = !row.gainKW.isEmpty || !row.challengeKW.isEmpty || !row.tomorrowKW.isEmpty

                    VStack(alignment:.leading, spacing:0) {
                        // 主行
                        Button(action:{
                            guard !row.isFuture, hasDetail else { return }
                            withAnimation(.spring(response:0.3)){
                                expandedDay = isExp ? nil : row.date
                            }
                        }) {
                            HStack(spacing:10) {
                                Text(row.label)
                                    .font(.system(size:DSTSize.caption, weight:isTdy ? .semibold:.regular, design:.rounded))
                                    .foregroundColor(isTdy ? AppTheme.accent : AppTheme.textTertiary)
                                    .frame(width:22, alignment:.center)

                                // 完成度进度条
                                GeometryReader { geo in
                                    ZStack(alignment:.leading) {
                                        RoundedRectangle(cornerRadius:2).fill(AppTheme.bg3).frame(height:4)
                                        if !row.isFuture && row.rate > 0 {
                                            RoundedRectangle(cornerRadius:2)
                                                .fill(row.rate >= 0.8 ? AppTheme.accent :
                                                      row.rate >= 0.5 ? AppTheme.accent.opacity(0.6) :
                                                      AppTheme.danger.opacity(0.5))
                                                .frame(width:geo.size.width * row.rate, height:4)
                                        }
                                    }
                                }.frame(height:4)

                                Text(row.isFuture ? "—" : row.rate > 0 ? "\(Int(row.rate*100))%" : "—")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary).frame(width:28)

                                Text(row.rating > 0 ? emojis[min(row.rating,5)] : "").font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).frame(width:18)

                                // 关键词存在指示点
                                HStack(spacing:3) {
                                    if !row.gainKW.isEmpty { Circle().fill(AppTheme.accent.opacity(0.7)).frame(width:5,height:5) }
                                    if !row.challengeKW.isEmpty { Circle().fill(AppTheme.gold.opacity(0.8)).frame(width:5,height:5) }
                                    if !row.tomorrowKW.isEmpty { Circle().fill(Color(red:0.780,green:0.500,blue:0.700).opacity(0.7)).frame(width:5,height:5) }
                                }.frame(width:24)

                                if hasDetail && !row.isFuture {
                                    Image(systemName:isExp ? "chevron.up":"chevron.down")
                                        .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                                }
                            }.padding(.vertical,9)
                        }.buttonStyle(.plain)

                        // 展开：关键词 + 困难勾选
                        if isExp {
                            VStack(alignment:.leading, spacing:8) {
                                if !row.gainKW.isEmpty {
                                    miniKWRow(icon:"star.fill", color:AppTheme.accent,
                                              label:store.t(key: L10n.wins), kws:row.gainKW)
                                }
                                if !row.challengeKW.isEmpty {
                                    VStack(alignment:.leading, spacing:6) {
                                        miniKWRow(icon:"exclamationmark.triangle.fill", color:AppTheme.gold,
                                                  label:store.t(key: L10n.pending), kws:row.challengeKW)
                                        // 困难解决状态
                                        ForEach(row.challengeKW, id:\.self) { kw in
                                            let solved = weekSummary?.resolvedChallenges.contains(kw) ?? false
                                            Button(action:{ store.toggleResolvedChallenge(type:0, label:weekLabel, keyword:kw) }) {
                                                HStack(spacing:7) {
                                                    Image(systemName:solved ? "checkmark.circle.fill":"circle")
                                                        .font(.caption).foregroundColor(solved ? AppTheme.accent : AppTheme.border1)
                                                    Text(kw).font(.caption).foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textSecondary)
                                                        .strikethrough(solved, color:AppTheme.textTertiary)
                                                    Spacer()
                                                    Text(solved ? store.t(key: L10n.resolved) : store.t(key: L10n.pendingResolve))
                                                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(solved ? AppTheme.accent : AppTheme.gold)
                                                }
                                                .padding(.horizontal,10).padding(.vertical,5)
                                                .background(solved ? AppTheme.accent.opacity(0.05) : AppTheme.gold.opacity(0.06))
                                                .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                                if !row.tomorrowKW.isEmpty {
                                    miniKWRow(icon:"arrow.right.circle.fill",
                                              color:Color(red:0.780,green:0.500,blue:0.700),
                                              label:store.t(key: L10n.tomorrowLabel), kws:row.tomorrowKW)
                                }
                            }
                            .padding(.leading,32).padding(.bottom,10).padding(.top,2)
                            .transition(.opacity.combined(with:.move(edge:.top)))
                        }

                        if row.id != rows.last?.id { Rectangle().fill(AppTheme.border0).frame(height:0.5) }
                    }
                }
            }
        }
        .padding(16).background(
            ZStack {
                RoundedRectangle(cornerRadius:20).fill(AppTheme.bg1)
                RoundedRectangle(cornerRadius:20).fill(LinearGradient(colors:[Color.white.opacity(0.03),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
            }
        ).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.border0,lineWidth:1))
        .shadow(color:.black.opacity(0.22),radius:8,x:0,y:3)
    }

    @ViewBuilder
    func miniKWRow(icon:String,color:Color,label:String,kws:[String]) -> some View {
        HStack(alignment:.top, spacing:5) {
            Image(systemName:icon).font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(color).padding(.top,2)
            Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color).frame(width:28,alignment:.leading)
            FlowLayout(spacing:4) {
                ForEach(kws,id:\.self) { kw in
                    Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                        .padding(.horizontal,6).padding(.vertical,2)
                        .background(color.opacity(0.1)).cornerRadius(10)
                }
            }
        }
    }
}

// ── 周期总结卡（关键词 + 心情 + 困难追踪，周/月/年通用）─────
struct PeriodSummaryCard: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let range: Int   // 0=周 1=月 2=年
    var periodDatesOverride: [Date]? = nil   // 传入则使用，否则用默认
    var periodLabelOverride: String? = nil

    @State private var editing = false
    @State private var draftMood = 0
    @State private var draftGainKW: [String] = []
    @State private var draftChallengeKW: [String] = []
    @State private var draftNextKW: [String] = []
    @State private var draftGainDetail = ""
    @State private var draftChallengeDetail = ""
    @State private var draftNextDetail = ""
    @State private var challengeTrackerOpen = false
    @State private var periodNoteKW: String? = nil
    @State private var showSmartSummary = false

    let emojis = ["😞","😶","🙂","🤍","✨"]
    let moodTexts_zh = ["","不太好","一般","还行","不错","很棒"]
    let moodTexts_en = ["","Rough","Okay","Alright","Good","Great"]

    var periodLabel: String {
        if let ov = periodLabelOverride { return ov }
        switch range {
        case 0: return store.currentWeekLabel
        case 1: return store.currentMonthLabel
        default: return store.currentYearLabel
        }
    }
    var typeName: String {
        switch store.language {
        case .chinese:  return range==0 ? "周" : range==1 ? "月" : "年"
        case .japanese: return range==0 ? "週" : range==1 ? "月" : "年"
        case .korean:   return range==0 ? "주" : range==1 ? "월" : "년"
        case .spanish:  return range==0 ? "Semana" : range==1 ? "Mes" : "Año"
        case .english:  return range==0 ? "Week" : range==1 ? "Month" : "Year"
        }
    }
    var typeIcon: String { range==0 ? "calendar.badge.clock" : range==1 ? "calendar" : "star.circle" }
    var existing: PeriodSummary? { store.periodSummary(type:range, label:periodLabel) }
    var periodDates: [Date] { periodDatesOverride ?? (range==0 ? store.weekDates() : range==1 ? store.monthDates() : store.yearDates()) }

    // 已提交才允许勾选困难
    var canMarkChallenges: Bool { existing != nil }

    // 困难追踪：联动每日困难状态（以本周期 periodDates 为准）
    var liveChallengeState: (active: [String], resolved: [String]) {
        store.periodChallengeState(dates: periodDates)
    }
    // 全部困难（含已解决，用于显示划线）
    var subChallengeKW: [String] { liveChallengeState.active + liveChallengeState.resolved }
    var resolvedCount: Int { liveChallengeState.resolved.count }
    // 继承自上周期的困难（不能在本周期总结编辑区删除）
    var inheritedChallengeKW: Set<String> {
        guard let firstDay = periodDates.first else { return [] }
        let dayBefore = Calendar.current.date(byAdding:.day, value:-1, to:Calendar.current.startOfDay(for:firstDay))!
        return Set(store.dailyChallengeActiveRaw(for: dayBefore))
    }
    // 本周期新增的困难（可在编辑区增删）
    var periodNewKW: [String] { store.periodNewChallengeKW(type:range, dates:periodDates) }

    func startEditing() {
        // 今日追踪层新增的词（不含继承的）
        let todayActive = store.dailyChallengeState(for: store.today).active
        let todayNewKW = todayActive.filter { !inheritedChallengeKW.contains($0) }

        if let ex = existing {
            draftMood = ex.mood
            draftGainKW = ex.gainKeywords
            // 合并：existing 里的本期词 ∪ 今日追踪层新增词（去继承、去重）
            var base = ex.challengeKeywords.filter { !inheritedChallengeKW.contains($0) }
            for kw in todayNewKW where !base.contains(kw) { base.append(kw) }
            draftChallengeKW = base
            draftNextKW = ex.nextKeywords
            draftGainDetail = ex.gains; draftChallengeDetail = ex.challenges; draftNextDetail = ex.outlook
        } else {
            // 预填：从下层关键词聚合 ∪ 今日追踪层新增词
            let agg = store.aggregateKeywordsFromPeriods(type:range, dates:periodDates)
            var base = Array(agg.challenges.prefix(5))
            for kw in todayNewKW where !base.contains(kw) { base.append(kw) }
            draftGainKW = Array(agg.gains.prefix(5))
            draftChallengeKW = base
            draftNextKW = Array(agg.nexts.prefix(5))
        }
        editing = true
    }

    func submit() {
        // 记录"上次已保存的本期词"，用于对比删除
        let prevChallengeKW = existing?.challengeKeywords
            .filter { !inheritedChallengeKW.contains($0) } ?? []

        var s = existing ?? PeriodSummary(periodType:range, periodLabel:periodLabel, startDate:Date())
        s.mood = draftMood
        s.gainKeywords = draftGainKW; s.challengeKeywords = draftChallengeKW; s.nextKeywords = draftNextKW
        s.gains = draftGainDetail; s.challenges = draftChallengeDetail; s.outlook = draftNextDetail
        s.avgCompletion = store.avgCompletion(for:periodDates)
        s.submittedAt = Date()
        store.submitPeriodSummary(s)

        // ── 同步到今天的 dailyChallenges 追踪层（提交时才生效）──
        let todayState = store.dailyChallengeState(for: store.today)
        let trackActive = Set(todayState.active)
        let trackResolved = Set(todayState.resolved)
        let draftSet = Set(draftChallengeKW)

        // 新增：draft 有但追踪层没有
        for kw in draftChallengeKW where !trackActive.contains(kw) && !trackResolved.contains(kw) {
            store.addTodayChallengeKeyword(kw)
        }
        // 删除：只删"上次 existing 里有、这次 draft 里没有"的词
        // 不动今日心得或其他来源单独添加的词，避免误删
        for kw in prevChallengeKW where !draftSet.contains(kw) {
            store.removeTodayChallengeKeyword(kw)
        }
        editing = false
        DispatchQueue.main.asyncAfter(deadline:.now()+0.35) { showSmartSummary = true }
    }

    var summaryCtx: SummaryContext {
        switch range {
        case 0: return .forWeek(label:periodLabel, dates:periodDates, store:store)
        case 1: return .forMonth(label:periodLabel, dates:periodDates, store:store)
        default: return .forYear(label:periodLabel, dates:periodDates, store:store)
        }
    }

    // ── body 拆分成子函数，解决 Swift 类型推断超时 ──────────

    var body: some View {
        VStack(alignment:.leading, spacing:14) {
            headerSection
            challengeTrackerSection
            contentSection
        }
        .padding(18).background(AppTheme.bg1).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius:18).stroke(existing != nil ? AppTheme.accent.opacity(0.28) : AppTheme.border0,lineWidth:1))
        .shadow(color: AppTheme.accent.opacity(existing != nil ? 0.08 : 0), radius:12, x:0, y:4)
        .sheet(isPresented:$showSmartSummary) {
            SmartSummarySheet(ctx:summaryCtx)
                .environmentObject(store)
                .environmentObject(pro)
        }
    }

    @ViewBuilder var headerSection: some View {
        HStack(alignment:.center) {
            HStack(spacing:8) {
                // Bare icon — matches sectionHeader(sfIcon:) style across My page
                Image(systemName:typeIcon)
                    .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.60))
                Text(L10n.typeSummaryTitle(typeName, store.language))
                    .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                    .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                    .kerning(0.3)
            }
            Spacer()
            if existing != nil {
                Image(systemName:"checkmark.circle.fill")
                    .font(.system(size:DSTSize.cardCaption, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.55))
            } else {
                Image(systemName:"pencil.circle")
                    .font(.system(size:DSTSize.cardCaption, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.40))
            }
        }
    }

    @ViewBuilder var challengeTrackerSection: some View {
        if !subChallengeKW.isEmpty {
            VStack(alignment:.leading, spacing:0) {
                Button(action:{ withAnimation(.spring(response:0.3)){ challengeTrackerOpen.toggle() }}) {
                    HStack(spacing:8) {
                        Image(systemName:"shield.lefthalf.filled")
                            .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                            .foregroundColor(AppTheme.accent.opacity(0.60))
                            .frame(width: 20)
                        Text(L10n.typePendingTitle(typeName, store.language))
                            .font(.system(size:DSTSize.body, weight:.regular, design:.rounded))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.85))
                        Spacer()
                        if canMarkChallenges {
                            Text("\(resolvedCount)/\(subChallengeKW.count)")
                                .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                                .foregroundColor(AppTheme.textTertiary.opacity(0.50))
                                .monospacedDigit()
                        }
                        Image(systemName:challengeTrackerOpen ? "chevron.up":"chevron.down")
                            .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.40))
                    }.padding(.vertical,6)
                }
                if challengeTrackerOpen {
                    VStack(alignment:.leading, spacing:4) {
                        if subChallengeKW.count > 0 {
                            GeometryReader { geo in
                                ZStack(alignment:.leading) {
                                    RoundedRectangle(cornerRadius:3).fill(AppTheme.bg3).frame(height:4)
                                    RoundedRectangle(cornerRadius:3)
                                        .fill(resolvedCount == subChallengeKW.count ? AppTheme.accent : AppTheme.gold.opacity(0.7))
                                        .frame(width: subChallengeKW.isEmpty ? 0 : geo.size.width * Double(resolvedCount)/Double(subChallengeKW.count), height:4)
                                }
                            }.frame(height:4).padding(.bottom,2)
                        }
                        ForEach(subChallengeKW, id:\.self) { kw in
                            ChallengeTrackRow(
                                kw: kw,
                                solved: liveChallengeState.resolved.contains(kw),
                                isInherited: inheritedChallengeKW.contains(kw),
                                // 找今天解决的记录（周视图里也能撤销今天划掉的）
                                resolvedDate: store.dailyChallenges.first(where:{
                                    $0.keyword == kw && $0.resolvedOnDate != nil &&
                                    Calendar.current.isDate($0.resolvedOnDate!, inSameDayAs: store.today)
                                })?.resolvedOnDate,
                                note: store.dailyChallenges.first(where:{ $0.keyword==kw && $0.resolvedOnDate != nil })?.resolvedNote ?? "",
                                noteExpanded: periodNoteKW == kw,
                                onToggle: { store.toggleDailyChallenge(keyword:kw, on:store.today) },
                                onNoteToggle: { withAnimation(.spring(response:0.25)){ periodNoteKW = periodNoteKW==kw ? nil : kw } },
                                onNoteSave: { note in store.updateResolvedNote(keyword:kw, on:store.today, note:note) }
                            ).environmentObject(store)
                        }
                    }
                    .padding(.top,4)
                    .transition(.opacity.combined(with:.move(edge:.top)))
                }
            }
            .padding(10).background(AppTheme.gold.opacity(0.05)).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.gold.opacity(0.12),lineWidth:1))
        }
    }

    @ViewBuilder var contentSection: some View {
        if let ex = existing, !editing {
            displaySection(ex: ex)
        } else if editing {
            editingSection
        } else {
            emptySection
        }
    }

    func moodLabel(for rating: Int) -> String {
        let arr: [String]
        switch store.language {
        case .chinese:  arr = moodTexts_zh
        case .english:  arr = ["","Rough","Okay","Alright","Good","Great"]
        case .japanese: arr = ["","つらい","普通","まあまあ","良い","最高"]
        case .korean:   arr = ["","힘들어","보통","괜찮아","좋아","최고"]
        case .spanish:  arr = ["","Mal","Regular","Bien","Muy bien","Genial"]
        }
        return arr[safe:rating] ?? ""
    }

    @ViewBuilder func displaySection(ex: PeriodSummary) -> some View {
        // 已提交：mood label + edit button
        HStack(alignment:.center, spacing:10) {
            if ex.mood > 0 {
                Text(emojis[ex.mood-1])
                    .font(.system(size:DSTSize.sectionTitle, weight:.semibold, design:.rounded))
                Text(moodLabel(for: ex.mood))
                    .font(.system(size:DSTSize.cardBody, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.75))
            } else {
                Image(systemName:"checkmark.circle.fill")
                    .font(.system(size:DSTSize.cardCaption, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.55))
                Text(store.t(key: L10n.alreadyRecorded))
                    .font(.system(size:DSTSize.cardBody, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.55))
            }
            Spacer()
            Button(action:startEditing) {
                HStack(spacing:4) {
                    Image(systemName:"arrow.clockwise.circle.fill")
                        .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                    Text(store.t(key: L10n.updateAndInsight))
                        .font(.system(size:DSTSize.cardCaption, weight:.medium, design:.rounded))
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal,10).padding(.vertical,5)
                .background(AppTheme.accent.opacity(0.09)).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius:8).stroke(AppTheme.accent.opacity(0.20),lineWidth:0.5))
            }
        }
    }

    @ViewBuilder var editingSection: some View {
        VStack(alignment:.leading, spacing:14) {
            // 整体心情
            VStack(alignment:.leading, spacing:7) {
                Text(store.t(key: L10n.overallMood)).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                HStack(spacing:8) {
                    ForEach(1...5, id:\.self) { i in
                        Button(action:{draftMood=i}) {
                            Text(emojis[i-1]).font(.title2).frame(maxWidth:.infinity).padding(.vertical,7)
                                .background(draftMood==i ? AppTheme.accent.opacity(0.15):AppTheme.bg2).cornerRadius(9)
                                .overlay(RoundedRectangle(cornerRadius:9).stroke(draftMood==i ? AppTheme.accent.opacity(0.5):AppTheme.border0,lineWidth:1))
                        }.animation(.spring(response:0.2),value:draftMood)
                    }
                }
            }
            // ── 顺序：待决 → 收获 → 计划 ──
            // 待决：用和收获/计划完全相同的 PeriodKeywordField 框框
            // 待决标签区：实时读写今日 challengeKeywords，与日视图完全同步
            ChallengeKeywordSection(
                periodLabel: {
                    let r = range
                    switch store.language {
                    case .chinese:  return r==0 ? "本周" : r==1 ? "本月" : "本年"
                    case .japanese: return r==0 ? "今週" : r==1 ? "今月" : "今年"
                    case .korean:   return r==0 ? "이번 주" : r==1 ? "이번 달" : "올해"
                    case .spanish:  return r==0 ? "Esta semana" : r==1 ? "Este mes" : "Este año"
                    case .english:  return r==0 ? "This Week" : r==1 ? "This Month" : "This Year"
                    }
                }())
            PeriodKeywordField(icon:"star.fill", color:AppTheme.accent,
                title:L10n.typeWinsTitle(typeName, store.language),
                hint:store.t(key: L10n.kwHintWins),
                keywords:$draftGainKW, detail:$draftGainDetail, store:store)
            PeriodKeywordField(icon:"arrow.right.circle.fill", color:Color(red:0.780,green:0.500,blue:0.700),
                title:L10n.typePlanTitle(typeName, store.language),
                hint:store.t(key: L10n.kwHintPlan),
                keywords:$draftNextKW, detail:$draftNextDetail, store:store)
            HStack {
                Button(store.t(key: L10n.cancel)){ editing=false }.font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                Spacer()
                Button(action:submit) {
                    HStack(spacing:5) {
                        Image(systemName:"sparkles").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        Text(store.t(key: L10n.submitAndInsight))
                            .font(.caption).fontWeight(.semibold)
                    }
                    .padding(.horizontal,14).padding(.vertical,7)
                    .background(AppTheme.accent).cornerRadius(10)
                    .foregroundColor(AppTheme.bg0)
                }
            }
        }
    }

    @ViewBuilder var emptySection: some View {
        Button(action:startEditing) {
            HStack(spacing:8) {
                Image(systemName:"pencil.and.list.clipboard")
                    .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.60))
                    .frame(width: 20)
                Text(L10n.trackTitle(typeName, store.language))
                    .font(.system(size:DSTSize.body, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.textSecondary.opacity(0.85))
                Spacer()
                Image(systemName:"chevron.right")
                    .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.62))
            }
            .padding(14)
            .background(AppTheme.accent.opacity(0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.accent.opacity(0.10),lineWidth:0.7))
        }
    }

    @ViewBuilder
    func periodKWRow(icon:String, color:Color, label:String, kws:[String], detail:String) -> some View {
        VStack(alignment:.leading, spacing:5) {
            HStack(alignment:.top, spacing:6) {
                Image(systemName:icon)
                    .font(.system(size:DSTSize.cardMicro, weight:.medium, design:.rounded))
                    .foregroundColor(color.opacity(0.75))
                    .padding(.top,1)
                Text(label)
                    .font(.system(size:DSTSize.cardCaption, weight:.medium, design:.rounded))
                    .foregroundColor(color.opacity(0.75))
                FlowLayout(spacing:4) {
                    ForEach(kws, id:\.self) { kw in
                        Text(kw)
                            .font(.system(size:DSTSize.cardMicro, weight:.regular, design:.rounded))
                            .foregroundColor(color.opacity(0.88))
                            .padding(.horizontal,7).padding(.vertical,3)
                            .background(color.opacity(0.09))
                            .cornerRadius(10)
                    }
                }
            }
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size:DSTSize.cardCaption, weight:.regular, design:.rounded))
                    .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                    .lineSpacing(3)
                    .padding(.leading,22)
            }
        }
    }

    @ViewBuilder
    func challengeKWRow(kw: String, solved: Bool) -> some View {
        HStack(spacing:7) {
            Image(systemName:solved ? "checkmark.circle.fill":"circle")
                .font(.caption).foregroundColor(solved ? AppTheme.accent : AppTheme.border1)
            Text(kw).font(.caption)
                .foregroundColor(solved ? AppTheme.textTertiary : AppTheme.textSecondary)
                .strikethrough(solved, color:AppTheme.textTertiary)
            Spacer()
            Text(solved ? store.t(key: L10n.resolvedDone) : store.t(key: L10n.pendingResolve))
                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(solved ? AppTheme.accent : AppTheme.gold)
        }
        .padding(.horizontal,10).padding(.vertical,5)
        .background(solved ? AppTheme.accent.opacity(0.05) : AppTheme.gold.opacity(0.05)).cornerRadius(8)
    }
}

// ── 周期关键词输入组件（周/月/年通用）──────────────────────
// ── 今日新增困难编辑框（周/月/年总结里用）───────────────────
// 只显示今天日记的 challengeKeywords，长按可编辑单条
// 添加新词 = 直接写入今日 review.challengeKeywords → 自动进困难追踪
// ── 统一困难输入组件（今日/周/月/年总结均使用此入口）──────────────
// 规则：困难只能增删当日日记的 challengeKeywords，过了今天只能通过追踪划掉
// ── 今日待决（与 KeywordInputSection 风格完全统一）────────────────
struct ChallengeKeywordSection: View {
    @EnvironmentObject var store: AppStore
    /// 标题前缀：今日/本周/本月/本年
    var periodLabel: String = ""  // 空=自动用"今日"
    @State private var inputText = ""
    @State private var editingKW: String? = nil
    @State private var editDraft = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var editFocused: Bool

    let color = AppTheme.gold

    // 实时读取：今日 review.challengeKeywords（唯一数据源）
    var todayNewKW: [String] {
        store.review(for: store.today)?.challengeKeywords ?? []
    }
    // 今日已解决的（用于划线显示）
    var resolvedTodayNewKW: [String] {
        let resolved = Set(store.dailyChallengeState(for: store.today).resolved)
        return todayNewKW.filter { resolved.contains($0) }
    }
    var titleText: String {
        let prefix = periodLabel.isEmpty ? store.t(key: L10n.todayWinsLabel) : periodLabel
        let sep = (store.language == .chinese || store.language == .japanese) ? "" : " "
        return prefix + sep + store.t(key: L10n.pending)
    }

    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            headerRow
            chipsOrHint
            inputRow
        }
        .padding(12)
        .background(ZStack {
            RoundedRectangle(cornerRadius:14).fill(AppTheme.bg2)
            RoundedRectangle(cornerRadius:14)
                .fill(LinearGradient(colors:[color.opacity(0.04),Color.clear],
                                     startPoint:.topLeading, endPoint:.bottomTrailing))
        })
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius:14).stroke(color.opacity(0.15),lineWidth:1))
    }

    @ViewBuilder var headerRow: some View {
        HStack(spacing:5) {
            Image(systemName:"exclamationmark.triangle.fill").font(.caption2).foregroundColor(color)
            Text(titleText).font(.caption).fontWeight(.medium).foregroundColor(color)
            Spacer()
            Text(store.t(key: L10n.longPressEdit)).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
        }
    }

    @ViewBuilder var chipsOrHint: some View {
        if todayNewKW.isEmpty {
            Text(store.t(key: L10n.logChallengesHint))
                .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary).lineSpacing(2)
        } else {
            FlowLayout(spacing:6) {
                ForEach(todayNewKW, id:\.self) { kw in
                    chipView(kw: kw)
                }
            }
        }
    }

    @ViewBuilder func chipView(kw: String) -> some View {
        let isResolved = resolvedTodayNewKW.contains(kw)
        let chipColor: Color = isResolved ? AppTheme.textTertiary : color
        if editingKW == kw {
            HStack(spacing:4) {
                TextField("", text:$editDraft)
                    .font(.caption).foregroundColor(color)
                    .focused($editFocused)
                    .onSubmit { commitEdit(from:kw) }
                    .frame(minWidth:60, maxWidth:120)
                Button(action:{ commitEdit(from:kw) }) {
                    Image(systemName:"checkmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(AppTheme.accent)
                }
                Button(action:{ deleteKW(kw) }) {
                    Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal,9).padding(.vertical,5)
            .background(color.opacity(0.15)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(0.5),lineWidth:1))
        } else {
            HStack(spacing:4) {
                if isResolved {
                    Image(systemName:"checkmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
                Text(kw).font(.caption).foregroundColor(chipColor)
                    .strikethrough(isResolved, color:AppTheme.textTertiary)
                Button(action:{ deleteKW(kw) }) {
                    Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(chipColor.opacity(0.7))
                }
            }
            .padding(.horizontal,9).padding(.vertical,5)
            .background(color.opacity(isResolved ? 0.05 : 0.1)).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(isResolved ? 0.15 : 0.3),lineWidth:1))
            .onLongPressGesture(minimumDuration:0.35) {
                editingKW = kw; editDraft = kw
                DispatchQueue.main.asyncAfter(deadline:.now()+0.05){ editFocused = true }
            }
        }
    }

    @ViewBuilder var inputRow: some View {
        HStack(spacing:8) {
            TextField(store.t(key: L10n.typeKeywordReturn), text:$inputText)
                .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                .focused($inputFocused)
                .onSubmit { addKW() }
                .padding(.horizontal,11).padding(.vertical,9)
                .background(AppTheme.bg2).cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius:9).stroke(inputFocused ? color.opacity(0.4) : AppTheme.border1, lineWidth:1))
            if !inputText.isEmpty {
                Button(action:addKW) {
                    Image(systemName:"return").font(.caption).foregroundColor(color)
                        .frame(width:34,height:34).background(color.opacity(0.12)).cornerRadius(9)
                }
            }
        }
    }

    func addKW() {
        let kw = inputText.trimmingCharacters(in:.whitespaces)
        guard !kw.isEmpty, !todayNewKW.contains(kw) else { inputText = ""; return }
        store.addTodayChallengeKeyword(kw)
        inputText = ""
    }
    func deleteKW(_ kw: String) {
        if editingKW == kw { editingKW = nil }
        store.deleteTodayChallengeKeyword(kw)
    }
    func commitEdit(from old: String) {
        let newKW = editDraft.trimmingCharacters(in:.whitespaces)
        if newKW.isEmpty {
            deleteKW(old)
        } else if newKW != old {
            store.renameTodayChallengeKeyword(from: old, to: newKW)
        }
        editingKW = nil
    }
}


struct UnifiedChallengeSection: View {
    @EnvironmentObject var store: AppStore
    @State private var inputText = ""
    @State private var editingKW: String? = nil
    @State private var editDraft = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var editFocused: Bool

    // 今日日记里的 challengeKeywords（唯一可编辑的困难集合）
    var todayKW: [String] {
        store.review(for: store.today)?.challengeKeywords ?? []
    }

    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            HStack(spacing:5) {
                Image(systemName:"exclamationmark.triangle.fill").font(.caption2).foregroundColor(AppTheme.gold)
                Text(store.t(key: L10n.todayPendingLabel))
                    .font(.caption).fontWeight(.medium).foregroundColor(AppTheme.gold)
                Spacer()
                Text(store.t(key: L10n.longPressTodayOnly))
                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }

            if todayKW.isEmpty {
                Text(store.t(key: L10n.logPendingToTrack))
                    .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary).lineSpacing(2)
            } else {
                FlowLayout(spacing:6) {
                    ForEach(todayKW, id:\.self) { kw in
                        Group {
                            if editingKW == kw {
                                // 编辑模式：inline TextField
                                HStack(spacing:4) {
                                    TextField("", text:$editDraft)
                                        .font(.caption).foregroundColor(AppTheme.gold)
                                        .focused($editFocused)
                                        .onSubmit { commitEdit(from: kw) }
                                        .frame(minWidth:60, maxWidth:120)
                                    Button(action:{ commitEdit(from:kw) }) {
                                        Image(systemName:"checkmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded))
                                            .foregroundColor(AppTheme.accent)
                                    }
                                    Button(action:{ removeKW(kw) }) {
                                        Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded))
                                            .foregroundColor(AppTheme.textTertiary)
                                    }
                                }
                                .padding(.horizontal,9).padding(.vertical,5)
                                .background(AppTheme.gold.opacity(0.15)).cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.gold.opacity(0.5),lineWidth:1))
                            } else {
                                HStack(spacing:4) {
                                    Text(kw).font(.caption).foregroundColor(AppTheme.gold)
                                    Button(action:{ removeKW(kw) }) {
                                        Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded))
                                            .foregroundColor(AppTheme.gold.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal,9).padding(.vertical,5)
                                .background(AppTheme.gold.opacity(0.10)).cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius:20).stroke(AppTheme.gold.opacity(0.3),lineWidth:1))
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    editingKW = kw
                                    editDraft = kw
                                    DispatchQueue.main.asyncAfter(deadline:.now()+0.05){
                                        editFocused = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 输入框：新增困难 → 写入今日 challengeKeywords
            HStack(spacing:8) {
                TextField(store.t(key: L10n.addPendingReturn), text:$inputText)
                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                    .focused($inputFocused)
                    .onSubmit { addKW() }
                    .padding(.horizontal,11).padding(.vertical,9)
                    .background(AppTheme.bg2).cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius:9).stroke(inputFocused ? AppTheme.gold.opacity(0.4) : AppTheme.border1,lineWidth:1))
                if !inputText.isEmpty {
                    Button(action:addKW) {
                        Image(systemName:"return").font(.caption).foregroundColor(AppTheme.gold)
                            .frame(width:34,height:34).background(AppTheme.gold.opacity(0.12)).cornerRadius(9)
                    }
                }
            }
        }
    }

    func addKW() {
        let kw = inputText.trimmingCharacters(in:.whitespaces)
        guard !kw.isEmpty else { return }
        // 写入今日 review.challengeKeywords（自动创建 review 若不存在）
        store.addTodayChallengeKeyword(kw)
        inputText = ""
    }

    func removeKW(_ kw: String) {
        store.removeTodayChallengeKeyword(kw)
        if editingKW == kw { editingKW = nil }
    }

    func commitEdit(from old: String) {
        let newKW = editDraft.trimmingCharacters(in:.whitespaces)
        guard !newKW.isEmpty else { removeKW(old); editingKW=nil; return }
        store.renameTodayChallengeKeyword(from:old, to:newKW)
        editingKW = nil
    }
}

// PeriodKeywordField: 与 KeywordInputSection 风格统一（用于周/月/年总结）
struct PeriodKeywordField: View {
    let icon: String; let color: Color; let title: String; let hint: String
    @Binding var keywords: [String]
    @Binding var detail: String
    let store: AppStore
    @State private var input = ""
    @State private var showDetail = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment:.leading, spacing:8) {
            // 标题行
            HStack(spacing:5) {
                Image(systemName:icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(color)
                Spacer()
                Button(action:{ withAnimation(.spring(response:0.3)){ showDetail.toggle() }}) {
                    HStack(spacing:3) {
                        Image(systemName:"text.alignleft").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        Text(store.t(key: L10n.detailLabel)).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                    }
                    .foregroundColor(showDetail ? color : AppTheme.textTertiary)
                    .padding(.horizontal,7).padding(.vertical,3)
                    .background(showDetail ? color.opacity(0.12) : AppTheme.bg2).cornerRadius(6)
                }
            }

            // 已添加的关键词 chips（空时显示提示）
            if keywords.isEmpty {
                Text(hint).font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary).lineSpacing(2)
            } else {
                FlowLayout(spacing:6) {
                    ForEach(keywords, id:\.self) { kw in
                        HStack(spacing:4) {
                            Text(kw).font(.caption).foregroundColor(color)
                            Button(action:{ keywords.removeAll{$0==kw} }) {
                                Image(systemName:"xmark").font(.system(size:DSTSize.nano,weight:.bold, design:.rounded)).foregroundColor(color.opacity(0.6))
                            }
                        }
                        .padding(.horizontal,9).padding(.vertical,5)
                        .background(color.opacity(0.10)).cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius:20).stroke(color.opacity(0.3),lineWidth:1))
                    }
                }
            }

            // 输入框（与 KeywordInputSection 完全一致）
            HStack(spacing:8) {
                TextField(store.t(key: L10n.typeKeywordReturn), text:$input)
                    .font(.system(size: DSTSize.body, weight: .regular, design:.rounded)).misty(.primary)
                    .focused($focused)
                    .onSubmit { addKW() }
                    .padding(.horizontal,11).padding(.vertical,9)
                    .background(AppTheme.bg2).cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius:9).stroke(focused ? color.opacity(0.4) : AppTheme.border1, lineWidth:1))
                if !input.isEmpty {
                    Button(action:addKW) {
                        Image(systemName:"return").font(.caption).foregroundColor(color)
                            .frame(width:34,height:34).background(color.opacity(0.12)).cornerRadius(9)
                    }
                }
            }

            if keywords.count >= 5 {
                Text(store.t(key: L10n.keywordLimitReached))
                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }

            // 详细文本（可选）
            if showDetail {
                ZStack(alignment:.topLeading) {
                    if detail.isEmpty {
                        Text(store.t(key: L10n.addMoreDetails))
                            .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).padding(.horizontal,9).padding(.vertical,8)
                    }
                    TextEditor(text:$detail)
                        .frame(minHeight:52).padding(4).scrollContentBackground(.hidden)
                        .foregroundColor(AppTheme.textPrimary).font(.caption)
                }
                .background(AppTheme.bg2).cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius:9).stroke(AppTheme.border1,lineWidth:1))
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .padding(11).background(AppTheme.bg0.opacity(0.5)).cornerRadius(11)
        .overlay(RoundedRectangle(cornerRadius:11).stroke(color.opacity(0.12),lineWidth:1))
    }

    func addKW() {
        let kw = input.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !kw.isEmpty, !keywords.contains(kw), keywords.count < 8 else { input=""; return }
        withAnimation(.spring(response:0.25)) { keywords.append(kw) }
        input = ""
    }
}

// 安全下标扩展
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ============================================================
// MARK: - 我的成长（四Tab：综合情况 / 我的心得 / 历史收获 / 历史计划）
// ============================================================

struct JournalListView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var tab = 0   // 0综合 1心得 2收获 3计划

    var body: some View {
        NavigationView {
            VStack(spacing:0) {
                // ── Tab bar: SF Symbol icons + sliding indicator ──
                HStack(spacing:0) {
                    ForEach(Array(tabs.enumerated()), id:\.offset) { i, t in
                        Button(action:{ withAnimation(.spring(response:0.26, dampingFraction:0.78)){ tab = i } }) {
                            VStack(spacing:3) {
                                Image(systemName: tab==i ? t.filledSF : t.sf)
                                    .font(.system(size:DSTSize.body, weight: tab==i ? .medium : .regular, design:.rounded))
                                    .foregroundColor(tab==i ? AppTheme.accent : AppTheme.textTertiary)
                                Text(t.label)
                                    .font(.system(size:DSTSize.micro, weight: tab==i ? .semibold : .regular, design:.rounded))
                                    .foregroundColor(tab==i ? AppTheme.accent : AppTheme.textTertiary)
                                Capsule()
                                    .fill(tab==i ? AppTheme.accent : Color.clear)
                                    .frame(height:2)
                                    .animation(.spring(response:0.26), value:tab)
                            }
                        }
                        .frame(maxWidth:.infinity)
                        .padding(.vertical,5)
                    }
                }
                .padding(.horizontal,8)
                .background(AppTheme.bg1)

                Rectangle().fill(AppTheme.border0).frame(height:0.5)

                // ── Content: fade transition on tab switch ────────
                ZStack {
                    switch tab {
                    case 0: OverviewTab().transition(.opacity)
                    case 1: InsightTab().transition(.opacity)
                    case 2: GoalAchievementTab().transition(.opacity)
                    case 3: HistoryKWTab(kwType:.plan).transition(.opacity)
                    default: EmptyView()
                    }
                }
                .animation(.easeInOut(duration:0.18), value:tab)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.principal) {
                    GlassImprintTitle(text: store.t(key: L10n.myGrowth), fontSize: 18)
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(store.t(key: L10n.done)){ dismiss() }.foregroundColor(AppTheme.accent)
                }
            }
        }
    }

    struct TabItem {
        let sf: String         // SF Symbol (normal)
        let filledSF: String   // SF Symbol (selected/filled)
        let label: String
    }
    var tabs: [TabItem] { [
        .init(sf:"chart.bar",           filledSF:"chart.bar.fill",           label:store.t(key: L10n.overviewLabel)),
        .init(sf:"lightbulb",           filledSF:"lightbulb.fill",           label:store.t(key: L10n.insightsLabel)),
        .init(sf:"star",                filledSF:"star.fill",                label:store.t(key: L10n.wins)),
        .init(sf:"arrow.right.circle",  filledSF:"arrow.right.circle.fill",  label:store.t(key: L10n.plans)),
    ]}
}

// ── Tab 0：综合情况 ─────────────────────────────────────────
struct OverviewTab: View {
    @EnvironmentObject var store: AppStore
    @State private var granularity = 0  // 0=日 1=周 2=月 3=年  (default: today)
    @State private var yearIdx   = 0
    @State private var monthIdx  = 0
    @State private var weekIdx   = 0
    @State private var dayOffset = 0

    var allYears: [GrowthYearEntry]  { store.allGrowthYears() }
    var selectedYear: GrowthYearEntry?  { allYears[safe:yearIdx] }
    var monthsOfYear: [GrowthMonthEntry] { selectedYear.map{ store.monthsInYear($0.year) } ?? [] }
    var selectedMonth: GrowthMonthEntry? { monthsOfYear[safe:monthIdx] }
    var weeksOfMonth: [GrowthWeekEntry]  { selectedMonth.map{ store.weeksInMonth($0.dates) } ?? [] }
    var selectedWeek: GrowthWeekEntry?   { weeksOfMonth[safe:weekIdx] }
    var dayDate: Date { Calendar.current.date(byAdding:.day, value:-dayOffset, to:store.today) ?? store.today }
    var focusDates: [Date] {
        switch granularity {
        case 0: return [dayDate]
        case 1: return selectedWeek?.dates ?? []
        case 2: return selectedMonth?.dates ?? []
        default: return selectedYear?.dates ?? []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing:0) {
                if allYears.isEmpty {
                    emptyPlaceholder(icon:"chart.bar.fill", msg:store.t(key: L10n.noDataYet2)).padding(.top,60)
                } else {
                    grainPicker.padding(.horizontal,16).padding(.top,12).padding(.bottom,8)
                    periodNav.padding(.bottom,8)
                    dataContent.padding(.horizontal,16).padding(.bottom,24)
                }
            }
        }
        .background(AppTheme.bg0.ignoresSafeArea())
    }

    @ViewBuilder var grainPicker: some View {
        let labels = [store.t(key: L10n.periodDayLabel),store.t(key: L10n.periodWkLabel),store.t(key: L10n.periodMoLabel),store.t(key: L10n.periodYrLabel)]
        HStack(spacing:0) {
            ForEach(labels.indices, id:\.self) { i in
                Button(action:{ withAnimation(.spring(response:0.22)){ granularity=i }}) {
                    Text(labels[i])
                        .font(.system(size:DSTSize.caption,weight:granularity==i ? .semibold:.regular, design:.rounded))
                        .foregroundColor(granularity==i ? .white : AppTheme.textTertiary)
                        .frame(maxWidth:.infinity).padding(.vertical,8)
                        .background(granularity==i ? AppTheme.accent : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .background(AppTheme.bg2).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border0,lineWidth:1))
    }

    @ViewBuilder var periodNav: some View {
        switch granularity {
        case 0:  // 日 — day nav
            HStack {
                Button(action:{ dayOffset+=1 }) {
                    Image(systemName:"chevron.left").font(.system(size:DSTSize.caption,weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent).frame(width:44,height:36)
                }
                Spacer()
                VStack(spacing:1) {
                    Text(formatDate(dayDate, format:store.language == .chinese ? "M月d日":"MMM d", lang:store.language))
                        .font(.system(size:DSTSize.label,weight:.semibold, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                    Text(formatDate(dayDate, format:"EEEE", lang:store.language))
                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
                Spacer()
                Button(action:{ if dayOffset>0 { dayOffset-=1 }}) {
                    Image(systemName:"chevron.right").font(.system(size:DSTSize.caption,weight:.medium, design:.rounded))
                        .foregroundColor(dayOffset>0 ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(width:44,height:36)
                }
            }
            .background(AppTheme.bg1).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border0,lineWidth:1))
            .padding(.horizontal,16)
        case 1:  // 周
            VStack(spacing:4) {
                chipRow(items:allYears.map{$0.label}, sel:$yearIdx)
                chipRow(items:weeksOfMonth.map{$0.label}, sel:$weekIdx)
            }
        case 2:  // 月
            VStack(spacing:4) {
                chipRow(items:allYears.map{$0.label}, sel:$yearIdx)
                chipRow(items:monthsOfYear.map{$0.label}, sel:$monthIdx)
            }
        default:  // 年
            chipRow(items:allYears.map{$0.label}, sel:$yearIdx)
        }
    }

    @ViewBuilder func chipRow(items:[String], sel:Binding<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing:5) {
                ForEach(items.indices, id:\.self) { i in
                    Button(action:{ withAnimation(.spring(response:0.2)){ sel.wrappedValue=i }}) {
                        Text(items[i])
                            .font(.system(size:DSTSize.caption,weight:sel.wrappedValue==i ? .semibold:.regular, design:.rounded))
                            .foregroundColor(sel.wrappedValue==i ? AppTheme.accent : AppTheme.textSecondary)
                            .padding(.horizontal,10).padding(.vertical,5)
                            .background(sel.wrappedValue==i ? AppTheme.accent.opacity(0.12) : AppTheme.bg2)
                            .cornerRadius(7)
                            .overlay(sel.wrappedValue==i ?
                                RoundedRectangle(cornerRadius:7).stroke(AppTheme.accent.opacity(0.35),lineWidth:1) : nil)
                    }
                }
            }.padding(.horizontal,16)
        }
    }

    @ViewBuilder var dataContent: some View {
        let active = focusDates.filter{$0 <= store.today}
        if active.isEmpty {
            Text(store.t(key: L10n.noDataPeriod))
                .font(.subheadline).foregroundColor(AppTheme.textTertiary)
                .frame(maxWidth:.infinity).padding(.vertical,40)
        } else {
            let rate  = store.avgCompletion(for:active)
            let mood  = store.avgMood(for:active)
            let taskT = active.flatMap{d in store.goals(for:d).flatMap{store.tasks(for:d,goal:$0)}}.count
            let taskD = active.flatMap{d in store.goals(for:d).flatMap{store.tasks(for:d,goal:$0)}.filter{store.progress(for:d,taskId:$0.id)>=1.0}}.count
            let goalC = Set(active.flatMap{store.goals(for:$0).map{$0.id}}).count
            let dist  = store.moodDistribution(for:active)
            let gains = store.allGainKeywords(for:active)
            let plans = store.allPlanKeywords(for:active)
            let activeDays = active.filter{store.completionRate(for:$0)>0}.count

            VStack(alignment:.leading, spacing:12) {
                // ── Rewards showcase (prominent, first) ──────
                rewardsShowcase

                // ── Stats grid ───────────────────────────────
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())], spacing:8) {
                    ovCard(value:rate>0 ? "\(Int(rate*100))%" : "—",
                           label:store.t(key: L10n.completionRate),
                           badge:rate>=0.8 ? "🏆" : rate>=0.6 ? "✨" : rate>0 ? "💪" : "",
                           color:AppTheme.accent)
                    ovCard(value:"\(taskD)/\(taskT)",
                           label:store.t(key: L10n.tasks),
                           badge:L10n.goalCountFmt(goalC, store.language),
                           color:AppTheme.textSecondary)
                    ovCard(value:mood>0 ? String(format:"%.1f",mood) : "—",
                           label:store.t(key: L10n.avgMoodLabel),
                           badge:mood>=4.5 ? "🔥" : mood>=3.5 ? "😊" : mood>=2.5 ? "🙂" : mood>0 ? "😐" : "",
                           color:AppTheme.gold)
                    ovCard(value:"\(activeDays)",
                           label:store.t(key: L10n.activeDaysLabel),
                           badge:L10n.activeDaysOfFmt(active.count, store.language),
                           color:AppTheme.textSecondary)
                }
                if !dist.isEmpty && active.count>1 { moodBarChart(dist:dist) }
                if !gains.isEmpty {
                    kwCloud(icon:"star.fill", color:AppTheme.accent,
                            label:L10n.winsCountFmt(gains.count, store.language), kws:gains)
                }
                if !plans.isEmpty {
                    kwCloud(icon:"arrow.right.circle.fill", color:Color(red:0.6,green:0.5,blue:0.9),
                            label:L10n.plansCountFmt(plans.count, store.language), kws:plans)
                }
            }
        }
    }

    // ── 徽记成就展示区（醒目、简洁、有层次感）──────────────────
    @ViewBuilder var rewardsShowcase: some View {
        let cal = Calendar.current
        let periodRewards: [RewardRecord] = {
            let starts = Set(focusDates.map { cal.startOfDay(for: $0) })
            return store.rewardRecords.filter { starts.contains(cal.startOfDay(for: $0.date)) }
        }()
        let dayCount   = periodRewards.filter { $0.level == .day }.count
        let weekCount  = periodRewards.filter { $0.level == .week }.count
        let monthCount = periodRewards.filter { $0.level == .month }.count
        let yearCount  = periodRewards.filter { $0.level == .year }.count
        let total = dayCount + weekCount + monthCount + yearCount

        if total > 0 {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.gold)
                    Text(store.t(zh:"获得徽记", en:"Badges Earned", ja:"獲得バッジ", ko:"획득 배지", es:"Insignias"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text("\(total)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.gold)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(AppTheme.gold.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Badge grid — only show earned types
                HStack(spacing: 8) {
                    let items: [(RewardLevel, Int)] = [
                        (.day, dayCount), (.week, weekCount),
                        (.month, monthCount), (.year, yearCount)
                    ].filter { $0.1 > 0 }

                    ForEach(items, id: \.0.rawValue) { (lvl, cnt) in
                        rewardTile(level: lvl, count: cnt)
                    }

                    if items.count < 4 {
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(AppTheme.bg1)
                    // Gold shimmer border
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.gold.opacity(0.55), AppTheme.gold.opacity(0.18), AppTheme.gold.opacity(0.40)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.0)
                }
            )
            .shadow(color: AppTheme.gold.opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    @ViewBuilder func rewardTile(level: RewardLevel, count: Int) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(level.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(level.color.opacity(0.30), lineWidth: 1)
                    .frame(width: 44, height: 44)
                RewardBadge(level: level, size: 22)
            }
            Text("\(count)")
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundColor(level.color)
                .monospacedDigit()
            Text(store.t(
                zh: level == .day ? "完美日" : level == .week ? "完美周" : level == .month ? "完美月" : "完美年",
                en: level == .day ? "Days" : level == .week ? "Weeks" : level == .month ? "Months" : "Years",
                ja: level == .day ? "日" : level == .week ? "週" : level == .month ? "月" : "年",
                ko: level == .day ? "일" : level == .week ? "주" : level == .month ? "월" : "년",
                es: level == .day ? "Días" : level == .week ? "Sem." : level == .month ? "Meses" : "Años"
            ))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(level.color.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(level.color.opacity(0.18), lineWidth: 0.8))
    }

    @ViewBuilder func ovCard(value:String, label:String, badge:String, color:Color) -> some View {
        VStack(alignment:.leading, spacing:4) {
            HStack(alignment:.lastTextBaseline, spacing:4) {
                Text(value).font(.system(size:DSTSize.displayMid,weight:.light,design:.rounded))
                    .foregroundColor(color).monospacedDigit()
                Text(badge).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
            Text(label).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth:.infinity, alignment:.leading)
        .padding(12).background(AppTheme.bg1).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
    }

    @ViewBuilder func moodBarChart(dist:[Int:Int]) -> some View {
        let total = max(1, dist.values.reduce(0,+))
        VStack(alignment:.leading, spacing:6) {
            Text(store.t(key: L10n.moodDistribution))
                .font(.system(size:DSTSize.micro,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            GeometryReader { geo in
                HStack(spacing:2) {
                    ForEach([1,2,3,4,5], id:\.self) { v in
                        if let c=dist[v], c>0 {
                            let frac=CGFloat(c)/CGFloat(total)
                            let w=max(4, geo.size.width*frac-2)
                            let col:Color = v>=4 ? AppTheme.accent : v==3 ? AppTheme.accent.opacity(0.5) : AppTheme.gold.opacity(0.5)
                            ZStack {
                                RoundedRectangle(cornerRadius:4).fill(col).frame(width:w,height:22)
                                if w>22 { Text(["","😞","😶","🙂","🤍","✨"][v]).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)) }
                            }.frame(width:w)
                        }
                    }
                }
            }.frame(height:22)
            HStack(spacing:8) {
                ForEach([1,2,3,4,5], id:\.self) { v in
                    if let c=dist[v], c>0 {
                        Text("\(["","😞","😶","🙂","🤍","✨"][v]) \(c)\(store.t(key: L10n.periodDayLabel))")
                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    }
                }
                Spacer()
            }
        }
        .padding(10).background(AppTheme.bg1).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
    }

    @ViewBuilder func kwCloud(icon:String, color:Color, label:String, kws:[String]) -> some View {
        VStack(alignment:.leading, spacing:8) {
            HStack(spacing:5) {
                Image(systemName:icon).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                Text(label).font(.system(size:DSTSize.micro,weight:.semibold, design:.rounded)).foregroundColor(color)
            }
            FlowLayout(spacing:5) {
                ForEach(kws, id:\.self) { kw in
                    Text(kw).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(color)
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(color.opacity(0.1)).cornerRadius(20)
                }
            }
        }
        .padding(12).background(AppTheme.bg1).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.2),lineWidth:1))
    }
}

// ── Tab 1：我的心得 ─────────────────────────────────────────
struct InsightTab: View {
    @EnvironmentObject var store: AppStore
    @State private var granularity = 0  // 0=日 1=周 2=月 3=年
    @State private var yearIdx   = 0
    @State private var monthIdx  = 0
    @State private var weekIdx   = 0
    @State private var dayOffset = 0
    // Section collapse states
    @State private var goalsCollapsed     = false
    @State private var journalsCollapsed  = false
    @State private var challengesCollapsed = false
    // Challenge note editing
    @State private var editingChallengeId: UUID? = nil
    @State private var challengeNoteInput = ""

    var allYears: [GrowthYearEntry] {
        store.allGrowthYears().filter{store.resolvedEntriesInPeriod(dates:$0.dates).count>0}
    }
    var selectedYear: GrowthYearEntry?   { allYears[safe:yearIdx] }
    var monthsOfYear: [GrowthMonthEntry] {
        guard let ye=selectedYear else { return [] }
        return store.monthsInYear(ye.year).filter{store.resolvedEntriesInPeriod(dates:$0.dates).count>0}
    }
    var selectedMonth: GrowthMonthEntry? { monthsOfYear[safe:monthIdx] }
    var weeksOfMonth: [GrowthWeekEntry]  {
        guard let me=selectedMonth else { return [] }
        return store.weeksInMonth(me.dates).filter{store.resolvedEntriesInPeriod(dates:$0.dates).count>0}
    }
    var selectedWeek: GrowthWeekEntry?   { weeksOfMonth[safe:weekIdx] }
    var dayDate: Date { Calendar.current.date(byAdding:.day, value:-dayOffset, to:store.today) ?? store.today }
    var focusDates: [Date] {
        switch granularity {
        case 0: return [dayDate]
        case 1: return selectedWeek?.dates ?? []
        case 2: return selectedMonth?.dates ?? []
        default: return selectedYear?.dates ?? []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing:0) {
                if allYears.isEmpty && granularity>0 && granularity<3 {
                    emptyPlaceholder(icon:"lightbulb.fill", msg:store.t(key: L10n.noInsightsYet)).padding(.top,60)
                } else {
                    inGrainPicker.padding(.horizontal,16).padding(.top,12).padding(.bottom,8)
                    inPeriodNav.padding(.bottom,8)
                    insightContent.padding(.horizontal,16).padding(.bottom,24)
                }
            }
        }
        .background(AppTheme.bg0.ignoresSafeArea())
    }

    @ViewBuilder var inGrainPicker: some View {
        let labels=[store.t(key: L10n.periodDayLabel),store.t(key: L10n.periodWkLabel),store.t(key: L10n.periodMoLabel),store.t(key: L10n.periodYrLabel)]
        HStack(spacing:0) {
            ForEach(labels.indices, id:\.self) { i in
                Button(action:{ withAnimation(.spring(response:0.22)){ granularity=i }}) {
                    Text(labels[i])
                        .font(.system(size:DSTSize.caption,weight:granularity==i ? .semibold:.regular, design:.rounded))
                        .foregroundColor(granularity==i ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(maxWidth:.infinity).padding(.vertical,8)
                        .background(granularity==i ? AppTheme.accent.opacity(0.12) : Color.clear)
                }.cornerRadius(8)
            }
        }
        .background(AppTheme.bg2).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border0,lineWidth:1))
    }

    @ViewBuilder var inPeriodNav: some View {
        switch granularity {
        case 0:  // 日 default
            HStack {
                Button(action:{ dayOffset+=1 }) {
                    Image(systemName:"chevron.left").font(.system(size:DSTSize.caption,weight:.medium, design:.rounded))
                        .foregroundColor(AppTheme.accent).frame(width:44,height:36)
                }
                Spacer()
                Text(formatDate(dayDate, format:store.language == .chinese ? "M月d日 EEEE":"EEE, MMM d", lang:store.language))
                    .font(.system(size:DSTSize.label,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button(action:{ if dayOffset>0 { dayOffset-=1 }}) {
                    Image(systemName:"chevron.right").font(.system(size:DSTSize.caption,weight:.medium, design:.rounded))
                        .foregroundColor(dayOffset>0 ? AppTheme.accent : AppTheme.textTertiary)
                        .frame(width:44,height:36)
                }
            }
            .background(AppTheme.bg1).cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius:10).stroke(AppTheme.border0,lineWidth:1))
            .padding(.horizontal,16)
        case 1:  // 周
            VStack(spacing:4) {
                inChipRow(items:allYears.map{$0.label}, sel:$yearIdx)
                inChipRow(items:weeksOfMonth.map{$0.label}, sel:$weekIdx)
            }
        case 2:  // 月
            VStack(spacing:4) {
                inChipRow(items:allYears.map{$0.label}, sel:$yearIdx)
                inChipRow(items:monthsOfYear.map{$0.label}, sel:$monthIdx)
            }
        default:  // 年
            inChipRow(items:allYears.map{$0.label}, sel:$yearIdx)
        }
    }

    @ViewBuilder func inChipRow(items:[String], sel:Binding<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing:5) {
                ForEach(items.indices, id:\.self) { i in
                    Button(action:{ withAnimation(.spring(response:0.2)){ sel.wrappedValue=i }}) {
                        Text(items[i])
                            .font(.system(size:DSTSize.caption,weight:sel.wrappedValue==i ? .semibold:.regular, design:.rounded))
                            .foregroundColor(sel.wrappedValue==i ? AppTheme.accent : AppTheme.textSecondary)
                            .padding(.horizontal,10).padding(.vertical,5)
                            .background(sel.wrappedValue==i ? AppTheme.accent.opacity(0.12) : AppTheme.bg2)
                            .cornerRadius(7)
                    }
                }
            }.padding(.horizontal,16)
        }
    }

    @ViewBuilder var insightContent: some View {
        if granularity==3 { yearInsightView }
        else {
            let entries = store.resolvedEntriesInPeriod(dates:focusDates)
            let journals = store.planJournalsInPeriod(dates:focusDates)
            let goalSummaries = goalCompletionSummaries(dates: focusDates)

            VStack(alignment:.leading, spacing:10) {
                // ── 目标完成情况 (collapsible) ────────────────
                if !goalSummaries.isEmpty {
                    let goalsPct = goalSummaries.isEmpty ? 0
                        : Int(goalSummaries.map{$0.avgCompletion}.reduce(0,+) / Double(goalSummaries.count) * 100)
                    let goalsFullDone = goalSummaries.filter{$0.avgCompletion>=1.0}.count
                    let goalsHint = store.t(
                        zh: "均完成率 \(goalsPct)%，\(goalsFullDone)/\(goalSummaries.count) 个目标达标",
                        en: "Avg \(goalsPct)% · \(goalsFullDone)/\(goalSummaries.count) goals done",
                        ja: "平均\(goalsPct)% · \(goalsFullDone)/\(goalSummaries.count)達成",
                        ko: "평균 \(goalsPct)% · \(goalsFullDone)/\(goalSummaries.count)개 완료",
                        es: "Promedio \(goalsPct)% · \(goalsFullDone)/\(goalSummaries.count) metas"
                    )
                    collapsibleSection(
                        icon: "target", iconColor: AppTheme.accent,
                        title: store.t(zh:"目标完成", en:"Goal Progress", ja:"目標達成", ko:"목표달성", es:"Metas"),
                        count: goalSummaries.count,
                        badge: {
                            let p = goalSummaries.filter{$0.avgCompletion>=1.0}.count
                            return p>0 ? "\(p) ✓" : nil
                        }(),
                        badgeColor: AppTheme.accent,
                        isCollapsed: $goalsCollapsed,
                        summaryHint: goalsHint
                    ) {
                        VStack(spacing:8) {
                            ForEach(goalSummaries, id:\.goalId) { gs in goalSummaryRow(gs) }
                        }
                    }
                }

                // ── 目标心得 (collapsible) ────────────────────
                if !journals.isEmpty {
                    let journalsHint = journals.prefix(2).map{$0.goalTitle}.joined(separator: " · ")
                    collapsibleSection(
                        icon: "lightbulb.fill", iconColor: AppTheme.gold,
                        title: store.t(zh:"目标心得", en:"Insights", ja:"目標の気づき", ko:"인사이트", es:"Reflexiones"),
                        count: journals.count, badge: nil, badgeColor: AppTheme.gold,
                        isCollapsed: $journalsCollapsed,
                        summaryHint: journalsHint.isEmpty ? nil : journalsHint
                    ) {
                        VStack(spacing:8) {
                            ForEach(journals, id:\.id) { j in journalRow(j) }
                        }
                    }
                }

                // ── 解决事项 (collapsible, with note input) ──
                if !entries.isEmpty {
                    let entriesHint = entries.prefix(2).map{$0.keyword}.joined(separator: " · ")
                    collapsibleSection(
                        icon: "checkmark.circle.fill", iconColor: AppTheme.accent,
                        title: L10n.resolvedCountFmt(entries.count, store.language),
                        count: nil, badge: nil, badgeColor: AppTheme.accent,
                        isCollapsed: $challengesCollapsed,
                        summaryHint: entriesHint.isEmpty ? nil : entriesHint
                    ) {
                        VStack(spacing:8) {
                            ForEach(entries, id:\.id) { e in
                                challengeRowWithNote(e)
                            }
                        }
                    }
                }

                if goalSummaries.isEmpty && journals.isEmpty && entries.isEmpty {
                    Text(store.t(key: L10n.noResolved))
                        .font(.subheadline).foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth:.infinity).padding(.vertical,36)
                }
            }
            // Challenge note edit sheet
            .sheet(isPresented: .init(
                get: { editingChallengeId != nil },
                set: { if !$0 { editingChallengeId = nil; challengeNoteInput = "" } }
            )) {
                challengeNoteSheet
            }
        }
    }

    struct GoalPeriodSummary {
        let goalId: UUID; let goalTitle: String; let color: Color
        let avgCompletion: Double; let activeDays: Int; let totalDays: Int
    }

    func goalCompletionSummaries(dates: [Date]) -> [GoalPeriodSummary] {
        let pastDates = dates.filter { $0 <= store.today }
        guard !pastDates.isEmpty else { return [] }
        var summaries: [GoalPeriodSummary] = []

        // Collect goals from date-filtered + all active longterm goals
        var goalIds = Set(pastDates.flatMap { store.goals(for:$0).map { $0.id } })
        // Also include any longterm goals active during the period
        for g in store.goals where g.goalType == .longterm {
            let inPeriod = pastDates.contains { d in
                let cal = Calendar.current
                return cal.startOfDay(for: g.startDate) <= cal.startOfDay(for: d)
            }
            if inPeriod { goalIds.insert(g.id) }
        }

        for gid in goalIds {
            guard let goal = store.goals.first(where:{ $0.id == gid }) else { continue }
            let cal = Calendar.current
            // For longterm goals: use all pastDates from goal's start date
            let goalDays: [Date]
            if goal.goalType == .longterm {
                goalDays = pastDates.filter { d in
                    cal.startOfDay(for: goal.startDate) <= cal.startOfDay(for: d)
                }
            } else {
                goalDays = pastDates.filter { d in
                    store.goals(for:d).contains(where:{ $0.id == gid })
                }
            }
            guard !goalDays.isEmpty else { continue }
            let avg = goalDays.map { store.goalProgress(for:goal, on:$0) }.reduce(0,+) / Double(goalDays.count)
            let active = goalDays.filter { store.goalProgress(for:goal, on:$0) > 0 }.count
            summaries.append(GoalPeriodSummary(
                goalId: gid, goalTitle: goal.title, color: goal.color,
                avgCompletion: avg, activeDays: active, totalDays: goalDays.count))
        }
        return summaries.sorted { $0.avgCompletion > $1.avgCompletion }
    }

    @ViewBuilder func goalSummaryRow(_ s: GoalPeriodSummary) -> some View {
        let journalCount = store.planJournals.filter { $0.goalId == s.goalId }.count
        let pct = CGFloat(s.avgCompletion)

        VStack(alignment:.leading, spacing:0) {
            // ── Top row: title + ring ─────────────────────────
            HStack(alignment:.center, spacing:10) {
                // Left accent bar
                RoundedRectangle(cornerRadius:2).fill(s.color).frame(width:3, height:38)

                VStack(alignment:.leading, spacing:4) {
                    Text(s.goalTitle)
                        .font(.system(size:DSTSize.label,weight:.semibold, design:.rounded))
                        .foregroundColor(AppTheme.textPrimary).lineLimit(1)
                    HStack(spacing:8) {
                        // Completion percentage badge
                        Text("\(Int(s.avgCompletion*100))%")
                            .font(.system(size:DSTSize.caption,weight:.bold,design:.rounded))
                            .foregroundColor(s.color)
                            .padding(.horizontal,6).padding(.vertical,2)
                            .background(s.color.opacity(0.12)).cornerRadius(5)
                        // Active days
                        HStack(spacing:3) {
                            Image(systemName:"calendar").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                            Text(store.t(zh:"\(s.activeDays)/\(s.totalDays)天",
                                        en:"\(s.activeDays)/\(s.totalDays)d",
                                        ja:"\(s.activeDays)/\(s.totalDays)日",
                                        ko:"\(s.activeDays)/\(s.totalDays)일",
                                        es:"\(s.activeDays)/\(s.totalDays)d"))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        }.foregroundColor(AppTheme.textTertiary)
                        // Journal badge
                        if journalCount > 0 {
                            HStack(spacing:3) {
                                Image(systemName:"lightbulb.fill").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                                Text("\(journalCount)")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                            }.foregroundColor(AppTheme.gold.opacity(0.85))
                        }
                    }
                }
                Spacer()

                // Donut ring
                ZStack {
                    Circle().stroke(AppTheme.bg3, lineWidth:3).frame(width:36,height:36)
                    Circle()
                        .trim(from:0, to:pct)
                        .stroke(s.color, style:StrokeStyle(lineWidth:3,lineCap:.round))
                        .frame(width:36,height:36).rotationEffect(.degrees(-90))
                    Text("\(Int(s.avgCompletion*100))")
                        .font(.system(size:DSTSize.nano,weight:.bold,design:.rounded))
                        .foregroundColor(s.color)
                }
            }
            .padding(.horizontal,12).padding(.top,10).padding(.bottom,8)

            // ── Progress bar (full width) ─────────────────────
            GeometryReader { g in
                ZStack(alignment:.leading) {
                    RoundedRectangle(cornerRadius:2).fill(AppTheme.bg3).frame(height:3)
                    RoundedRectangle(cornerRadius:2)
                        .fill(LinearGradient(
                            colors:[s.color.opacity(0.55), s.color, s.color.opacity(0.8)],
                            startPoint:.leading, endPoint:.trailing))
                        .frame(width:max(0, g.size.width*pct), height:3)
                        .shadow(color:s.color.opacity(0.4), radius:3)
                }
            }.frame(height:3)
        }
        .background(AppTheme.bg1).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius:14)
            .stroke(s.avgCompletion >= 1.0 ? s.color.opacity(0.3) : AppTheme.border0, lineWidth:0.8))
        .shadow(color:s.avgCompletion >= 1.0 ? s.color.opacity(0.08) : .clear, radius:6, x:0, y:2)
    }

    @ViewBuilder func journalRow(_ j: PlanJournalEntry) -> some View {
        HStack(alignment:.top, spacing:8) {
            VStack(spacing:0) {
                Image(systemName:"lightbulb.fill").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                    .padding(.top,4)
                Rectangle().fill(AppTheme.border0).frame(width:1).frame(maxHeight:.infinity)
            }.frame(width:12)
            VStack(alignment:.leading, spacing:4) {
                HStack(spacing:6) {
                    Text(j.goalTitle)
                        .font(.system(size:DSTSize.micro,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    if let t = j.taskTitle {
                        Text("› \(t)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.7))
                    }
                    Spacer()
                    Text(formatDate(j.date, format:"M/d", lang:store.language))
                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
                Text(j.note)
                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textSecondary)
                    .lineLimit(4).padding(8)
                    .background(AppTheme.gold.opacity(0.07)).cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius:8)
                        .stroke(AppTheme.gold.opacity(0.18),lineWidth:0.8))
            }
            .padding(10).background(AppTheme.bg1).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
            .frame(maxWidth:.infinity)
        }
    }

    @ViewBuilder var yearInsightView: some View {
        if let ye=selectedYear {
            let months=store.monthsInYear(ye.year)
            let counts=months.map{ store.resolvedEntriesInPeriod(dates:$0.dates).count }
            let maxC=max(1, counts.max() ?? 1)
            let total=counts.reduce(0,+)
            let bestI=counts.enumerated().max(by:{$0.element<$1.element})?.offset
            let allE=store.resolvedEntriesInPeriod(dates:ye.dates)
            let withNote=allE.filter{!$0.resolvedNote.isEmpty}.count

            VStack(alignment:.leading, spacing:12) {
                HStack(alignment:.top, spacing:8) {
                    yrCard(value:"\(total)", label:store.t(key: L10n.annualResolved))
                    if let bi=bestI, counts[bi]>0 { yrCard(value:months[bi].label, label:store.t(key: L10n.topMonth)) }
                    yrCard(value:"\(withNote)", label:store.t(key: L10n.withInsights))
                }
                VStack(alignment:.leading, spacing:6) {
                    Text(store.t(key: L10n.monthlyTrend))
                        .font(.system(size:DSTSize.micro,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    HStack(alignment:.bottom, spacing:4) {
                        ForEach(months.indices, id:\.self) { i in
                            let c=counts[i]; let h=CGFloat(c)/CGFloat(maxC)*52
                            VStack(spacing:3) {
                                if c>0 { Text("\(c)").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary) }
                                else   { Text("").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)) }
                                RoundedRectangle(cornerRadius:3)
                                    .fill(bestI==i && c>0 ? AppTheme.accent : c>0 ? AppTheme.accent.opacity(0.35) : AppTheme.bg2)
                                    .frame(height:max(3,h))
                                Text(months[i].label.prefix(2)).font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }.frame(maxWidth:.infinity)
                        }
                    }.frame(height:70)
                }
                .padding(10).background(AppTheme.bg1).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
                if !allE.isEmpty {
                    VStack(alignment:.leading, spacing:8) {
                        Text(store.t(key: L10n.yearHighlights))
                            .font(.system(size:DSTSize.micro,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                        ForEach(allE.prefix(5), id:\.id) { e in timelineRow(e) }
                        if allE.count>5 {
                            Text(L10n.moreItemsFmt(allE.count-5, store.language))
                                .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary).padding(.top,2)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder func yrCard(value:String, label:String) -> some View {
        VStack(alignment:.leading, spacing:3) {
            Text(value)
                .font(.system(size:DSTSize.titleCard,weight:.light,design:.rounded))
                .foregroundColor(AppTheme.accent)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth:.infinity, minHeight:52, alignment:.leading)
        .padding(.horizontal,12).padding(.vertical,10)
        .background(AppTheme.bg1).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
    }

    @ViewBuilder func timelineRow(_ e: DailyChallengeEntry) -> some View {
        HStack(alignment:.top, spacing:8) {
            VStack(spacing:0) {
                Circle().fill(AppTheme.accent).frame(width:7,height:7).padding(.top,5)
                Rectangle().fill(AppTheme.border0).frame(width:1).frame(maxHeight:.infinity)
            }.frame(width:7)
            VStack(alignment:.leading, spacing:4) {
                HStack(spacing:6) {
                    Text(e.keyword)
                        .font(.system(size:DSTSize.caption,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                        .strikethrough(true, color:AppTheme.textTertiary.opacity(0.4))
                    Spacer()
                    if let rd=e.resolvedOnDate {
                        Text(formatDate(rd, format:"M/d", lang:store.language))
                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    }
                }
                if !e.resolvedNote.isEmpty {
                    Text(e.resolvedNote).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textSecondary)
                        .lineLimit(3).padding(8)
                        .background(AppTheme.accent.opacity(0.06)).cornerRadius(8)
                }
            }
            .padding(10).background(AppTheme.bg1).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
            .frame(maxWidth:.infinity)
        }
    }

    // ── Collapsible section container ──────────────────────────────────────
    //
    // Design contract:
    //  ALWAYS visible: header row (icon · title · count badge · chevron)
    //  COLLAPSED:      1-line summary hint row (ghost opacity, gradient fade)
    //  EXPANDED:       full content(), appears instantly (no transition delay)
    //
    // Data-safety rule:
    //  content() is ALWAYS in the view tree when expanded = true.
    //  We use a simple `if collapsed` branch. The @State that tracks
    //  collapsed lives in InsightTab (parent) — it persists across re-renders.
    //  content() itself references computed vars on InsightTab, which are
    //  re-evaluated fresh on each render — this is correct and intentional.
    //  There is NO data loss. The only issue was the collapsed branch showing
    //  nothing — fixed below by adding a summary hint row.
    //
    // Parameter `summaryHint`: optional short string shown when collapsed.
    // Pass nil to show a generic "tap to expand" hint.
    // ─────────────────────────────────────────────────────────────────────────
    @ViewBuilder func collapsibleSection<Content: View>(
        icon: String, iconColor: Color, title: String,
        count: Int?, badge: String?, badgeColor: Color,
        isCollapsed: Binding<Bool>,
        summaryHint: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let collapsed = isCollapsed.wrappedValue

        VStack(alignment: .leading, spacing: 0) {

            // ── Header row — always visible, full tap target ──────────
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.36, dampingFraction: 0.80)) {
                    isCollapsed.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    // Icon in tinted circle
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.13))
                            .frame(width: 26, height: 26)
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(iconColor)
                    }

                    // Title
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    // Count badge
                    if let c = count {
                        Text("\(c)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.textTertiary)
                            .monospacedDigit()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.bg3.opacity(0.80))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    // Badge (e.g. "3 ✓")
                    if let b = badge {
                        Text(b)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(badgeColor.opacity(0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }

                    Spacer(minLength: 4)

                    // Chevron — rotates, never switches icon name (avoids flicker)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary.opacity(0.82))
                        .rotationEffect(.degrees(collapsed ? 0 : 180))
                        .animation(.spring(response: 0.36, dampingFraction: 0.80),
                                   value: collapsed)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(minHeight: 44)          // iOS touch-target standard
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Hairline divider ──────────────────────────────────────
            Rectangle()
                .fill(AppTheme.border0.opacity(0.55))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            if collapsed {
                // ── Collapsed summary — clearly visible, data-rich ───────
                //
                // Layout (2 rows):
                //  Row 1: 3 metric pills (count · summary stats · badge)
                //  Row 2: ghost preview  (hint text, gradient-faded right)
                //
                // Design rules:
                //  • Pill foreground opacity ≥ 0.80 — must be readable
                //  • Icon tint matches section color
                //  • Row 2 is optional decoration — Row 1 carries the data
                // ──────────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {

                    // Row 1 — metric pills
                    HStack(spacing: 6) {
                        // Count pill
                        if let c = count, c > 0 {
                            collapsedPill(
                                label: "\(c)",
                                icon: icon,
                                color: iconColor
                            )
                        }

                        // Summary stat pill (from summaryHint — first segment)
                        if let hint = summaryHint, !hint.isEmpty {
                            let segment = String(hint.prefix(32))
                            collapsedPill(
                                label: segment,
                                icon: nil,
                                color: iconColor
                            )
                        }

                        // Badge pill
                        if let b = badge {
                            collapsedPill(
                                label: b,
                                icon: "checkmark",
                                color: badgeColor
                            )
                        }

                        Spacer(minLength: 0)
                    }

                    // Row 2 — ghost preview (secondary, right-fade)
                    if let hint = summaryHint, hint.count > 32 {
                        let previewText = hint.count > 32
                            ? String(hint.dropFirst(0)) : hint
                        Text(previewText)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.textTertiary.opacity(0.30))
                            .lineLimit(1)
                            .mask(
                                LinearGradient(
                                    colors: [.white.opacity(0.70), .white.opacity(0.0)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 9)
                .padding(.bottom, 11)
                .transition(.opacity)

            } else {
                // ── Expanded content ──────────────────────────────────
                // Content appears immediately (no delayed animation).
                // Transition only on removal (collapse) — feels snappier.
                content()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeIn(duration: 0.12)),
                            removal:   .opacity.animation(.easeOut(duration: 0.10))
                        )
                    )
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.bg1)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.03), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border0.opacity(0.70), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    // ── Collapsed metric pill — used in collapsibleSection collapsed branch ──
    // A small labeled chip with optional icon, colored to match the section.
    // This is purely visual — no state. Color opacity 0.85 ensures legibility.
    @ViewBuilder
    private func collapsedPill(label: String, icon: String?, color: Color) -> some View {
        HStack(spacing: 4) {
            if let ic = icon {
                Image(systemName: ic)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(color.opacity(0.80))
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(color.opacity(0.85))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }


    // ── Challenge row with note display + edit button ──────
    @ViewBuilder func challengeRowWithNote(_ e: DailyChallengeEntry) -> some View {
        VStack(alignment:.leading, spacing:0) {
            HStack(alignment:.top, spacing:10) {
                // Strike-through dot timeline
                VStack(spacing:0) {
                    Circle().fill(AppTheme.accent.opacity(0.7))
                        .frame(width:6,height:6).padding(.top,6)
                    Rectangle().fill(AppTheme.border0.opacity(0.5))
                        .frame(width:1).frame(maxHeight:.infinity)
                }.frame(width:6)

                VStack(alignment:.leading, spacing:5) {
                    HStack(spacing:6) {
                        Text(e.keyword)
                            .font(.system(size:DSTSize.label,weight:.medium, design:.rounded))
                            .foregroundColor(AppTheme.textTertiary)
                            .strikethrough(true, color:AppTheme.textTertiary.opacity(0.45))
                        Spacer()
                        if let rd = e.resolvedOnDate {
                            Text(formatDate(rd, format:"M/d", lang:store.language))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.7))
                        }
                    }

                    // Note display or add-note prompt
                    if e.resolvedNote.isEmpty {
                        Button(action:{
                            editingChallengeId = e.id
                            challengeNoteInput = ""
                        }) {
                            HStack(spacing:5) {
                                Image(systemName:"plus.circle").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                Text(store.t(zh:"添加解决心得", en:"Add insight", ja:"気づきを追加", ko:"인사이트 추가", es:"Añadir nota"))
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                            }
                            .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                            .padding(.horizontal,8).padding(.vertical,5)
                            .background(AppTheme.bg3)
                            .cornerRadius(7)
                            .overlay(RoundedRectangle(cornerRadius:7)
                                .stroke(AppTheme.border0,lineWidth:0.7))
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment:.leading, spacing:4) {
                            Text(e.resolvedNote)
                                .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textSecondary)
                                .lineLimit(4)
                                .padding(9)
                                .frame(maxWidth:.infinity, alignment:.leading)
                                .background(AppTheme.accent.opacity(0.06))
                                .cornerRadius(9)
                                .overlay(RoundedRectangle(cornerRadius:9)
                                    .stroke(AppTheme.accent.opacity(0.15),lineWidth:0.8))
                            Button(action:{
                                editingChallengeId = e.id
                                challengeNoteInput = e.resolvedNote
                            }) {
                                HStack(spacing:4) {
                                    Image(systemName:"pencil").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded))
                                    Text(store.t(zh:"编辑心得", en:"Edit", ja:"編集", ko:"편집", es:"Editar"))
                                        .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                }
                                .foregroundColor(AppTheme.accent.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth:.infinity)
            }
        }
        .padding(.vertical,6)
    }

    // ── Challenge note edit sheet ──────────────────────────
    @ViewBuilder var challengeNoteSheet: some View {
        let entry = store.dailyChallenges.first(where:{ $0.id == editingChallengeId })
        NavigationView {
            VStack(spacing:16) {
                // Challenge keyword
                if let e = entry {
                    HStack(spacing:8) {
                        Image(systemName:"checkmark.circle.fill")
                            .font(.system(size:DSTSize.label, weight:.medium, design:.rounded)).foregroundColor(AppTheme.accent)
                        Text(e.keyword)
                            .font(.system(size:DSTSize.label,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                            .strikethrough(true)
                        Spacer()
                    }
                    .padding(.horizontal,16).padding(.top,8)
                }

                // Text editor
                ZStack(alignment:.topLeading) {
                    TextEditor(text: $challengeNoteInput)
                        .font(.system(size:DSTSize.label, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                        .padding(10)
                        .background(AppTheme.bg1)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border0,lineWidth:1))
                        .frame(minHeight:120, maxHeight:200)
                    if challengeNoteInput.isEmpty {
                        Text(store.t(zh:"写下你的解决心得…", en:"Write your insight…", ja:"気づきを記入…", ko:"인사이트를 입력…", es:"Escribe tu insight…"))
                            .font(.system(size:DSTSize.label, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.5))
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal,16)

                Spacer()
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t(zh:"解决心得", en:"Challenge Insight", ja:"解決の気づき", ko:"해결 인사이트", es:"Insight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) {
                    Button(store.t(key: L10n.cancel)) {
                        editingChallengeId = nil; challengeNoteInput = ""
                    }.foregroundColor(AppTheme.textTertiary)
                }
                ToolbarItem(placement:.confirmationAction) {
                    Button(store.t(key: L10n.save)) {
                        if let e = entry, let rd = e.resolvedOnDate {
                            store.updateResolvedNote(keyword:e.keyword, on:rd, note:challengeNoteInput)
                        }
                        editingChallengeId = nil; challengeNoteInput = ""
                    }.foregroundColor(AppTheme.accent).fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder func emptyPlaceholder(icon:String, msg:String) -> some View {
        VStack(spacing:12) {
            Image(systemName:icon).font(.system(size:DSTSize.displayLarge, weight:.ultraLight, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.4))
            Text(msg).font(.subheadline).foregroundColor(AppTheme.textTertiary)
        }.frame(maxWidth:.infinity).padding(.vertical,40)
    }

}

// ── Tab 2/3：历史收获 / 历史计划 ────────────────────────────
// ── Tab 2: 目标成就 ─────────────────────────────────────────────
struct GoalAchievementTab: View {
    @EnvironmentObject var store: AppStore
    // 0=今日 1=本周 2=本月 3=本年 4=全部 — default TODAY
    @State private var period = 0
    @State private var expandedGoals: Set<UUID> = []

    var cal: Calendar { Calendar.current }
    var today: Date { store.today }

    var periodDates: [Date] {
        switch period {
        case 0: // 今日
            return [cal.startOfDay(for: today)]
        case 1: // 本周 Mon–today
            let wd = cal.component(.weekday, from: today)
            let daysToMon = wd == 1 ? 6 : wd - 2
            guard let mon = cal.date(byAdding:.day, value:-daysToMon, to:cal.startOfDay(for:today)) else { return [today] }
            return (0...daysToMon).compactMap { cal.date(byAdding:.day, value:$0, to:mon) }
        case 2: // 本月
            guard let monthStart = cal.date(from: cal.dateComponents([.year,.month], from:today)),
                  let range = cal.range(of:.day, in:.month, for:monthStart) else { return [today] }
            return range.compactMap { cal.date(byAdding:.day, value:$0-1, to:monthStart) }
                .filter { $0 <= today }
        case 3: // 本年
            guard let yearStart = cal.date(from: cal.dateComponents([.year], from:today)) else { return [today] }
            var d = yearStart; var result: [Date] = []
            while d <= today { result.append(d); d = cal.date(byAdding:.day, value:1, to:d)! }
            return result
        default: // 全部
            guard let earliest = store.goals.map(\.startDate).min() else { return [today] }
            var d = cal.startOfDay(for: earliest); var result: [Date] = []
            while d <= today { result.append(d); d = cal.date(byAdding:.day, value:1, to:d)! }
            return result
        }
    }

    var activeGoals: [Goal] {
        store.goals.filter { g in
            periodDates.contains { d in cal.startOfDay(for:g.startDate) <= cal.startOfDay(for:d) }
        }
    }

    // Badges that apply to the selected period
    var periodBadges: [RewardRecord] {
        switch period {
        case 0: // Today: day badges only
            let label = { let f=DateFormatter(); f.dateFormat="yyyy-MM-dd"; return f.string(from:today) }()
            return store.rewardRecords.filter { $0.level == .day && $0.periodLabel == label }
        case 1: // This week: day badges in week + week badge
            let starts = Set(periodDates.map { cal.startOfDay(for:$0) })
            let dayBadges = store.rewardRecords.filter { $0.level == .day && starts.contains(cal.startOfDay(for:$0.date)) }
            let wl = store.weekLabelFor(today)
            let weekBadge = store.rewardRecords.filter { $0.level == .week && $0.periodLabel == wl }
            return (dayBadges + weekBadge).sorted { $0.date > $1.date }
        case 2: // This month: day + week + month badges
            let starts = Set(periodDates.map { cal.startOfDay(for:$0) })
            let dayBadges = store.rewardRecords.filter { $0.level == .day && starts.contains(cal.startOfDay(for:$0.date)) }
            let ml = store.monthLabelFor(today)
            let monthBadge = store.rewardRecords.filter { $0.level == .month && $0.periodLabel == ml }
            return (dayBadges + monthBadge).sorted { $0.date > $1.date }
        case 3: // This year: all badge types
            let starts = Set(periodDates.map { cal.startOfDay(for:$0) })
            let dayBadges = store.rewardRecords.filter { $0.level == .day && starts.contains(cal.startOfDay(for:$0.date)) }
            let yl = store.yearLabelFor(today)
            let yearBadge = store.rewardRecords.filter { $0.level == .year && $0.periodLabel == yl }
            let wl = store.weekLabelFor(today)
            let weekBadge = store.rewardRecords.filter { $0.level == .week && $0.periodLabel == wl }
            return (dayBadges + weekBadge + yearBadge).sorted { $0.date > $1.date }
        default: // All: everything
            return store.rewardRecords.sorted { $0.date > $1.date }
        }
    }

    // Period summary stats
    var totalDaysWithData: Int {
        periodDates.filter { d in
            !store.goals(for:d).flatMap { store.tasks(for:d, goal:$0) }.isEmpty
        }.count
    }
    var perfectDays: Int {
        periodDates.filter { d in
            let tasks = store.goals(for:d).flatMap { store.tasks(for:d, goal:$0) }
            guard !tasks.isEmpty else { return false }
            return store.completionRate(for:d) >= 1.0
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing:0) {
                // ── Period picker ────────────────────────────
                periodPicker.padding(.horizontal,16).padding(.top,12).padding(.bottom,10)

                // ── Period stats summary ──────────────────────
                periodStatRow.padding(.horizontal,16).padding(.bottom,12)

                // ── Achievement badges ────────────────────────
                badgesSection.padding(.horizontal,16).padding(.bottom,12)

                // ── Per-goal cards ────────────────────────────
                if activeGoals.isEmpty {
                    emptyPlaceholder(icon:"target", msg:store.t(zh:"暂无目标记录", en:"No goals yet", ja:"目標なし", ko:"목표 없음", es:"Sin metas"))
                        .padding(.top,40)
                } else {
                    VStack(spacing:10) {
                        ForEach(activeGoals) { goal in goalCard(goal) }
                    }.padding(.horizontal,16).padding(.bottom,24)
                }
            }
        }
        .background(AppTheme.bg0.ignoresSafeArea())
    }

    @ViewBuilder var periodPicker: some View {
        let labels = [
            store.t(zh:"今日", en:"Today", ja:"今日", ko:"오늘", es:"Hoy"),
            store.t(zh:"本周", en:"Week",  ja:"今週", ko:"이번주", es:"Semana"),
            store.t(zh:"本月", en:"Month", ja:"今月", ko:"이번달", es:"Mes"),
            store.t(zh:"本年", en:"Year",  ja:"今年", ko:"올해",   es:"Año"),
            store.t(zh:"全部", en:"All",   ja:"全て", ko:"전체",   es:"Todo"),
        ]
        HStack(spacing:0) {
            ForEach(labels.indices, id:\.self) { i in
                Button(action:{ withAnimation(.spring(response:0.22)){ period = i }}) {
                    Text(labels[i])
                        .font(.system(size:DSTSize.caption, weight: period==i ? .semibold : .regular, design:.rounded))
                        .foregroundColor(period==i ? .white : AppTheme.textTertiary)
                        .frame(maxWidth:.infinity).padding(.vertical,7)
                        .background(period==i ? AppTheme.accent : Color.clear)
                        .cornerRadius(7)
                }
            }
        }
        .background(AppTheme.bg2).cornerRadius(9)
        .overlay(RoundedRectangle(cornerRadius:9).stroke(AppTheme.border0, lineWidth:1))
    }

    @ViewBuilder var periodStatRow: some View {
        HStack(spacing:8) {
            statChip(
                value: "\(perfectDays)",
                label: store.t(zh:"全完成天", en:"Perfect Days", ja:"完璧な日", ko:"완벽한 날", es:"Días perfectos"),
                color: AppTheme.accent
            )
            statChip(
                value: "\(periodBadges.filter{$0.level == .day}.count)",
                label: store.t(zh:"天徽章", en:"Day Badges", ja:"日バッジ", ko:"일 배지", es:"Insignias día"),
                color: AppTheme.gold
            )
            statChip(
                value: "\(periodBadges.filter{$0.level != .day}.count)",
                label: store.t(zh:"高阶徽章", en:"Tier Badges", ja:"上位バッジ", ko:"상위 배지", es:"Insignias tier"),
                color: AppTheme.cyberPurple
            )
        }
    }

    @ViewBuilder func statChip(value: String, label: String, color: Color) -> some View {
        VStack(spacing:3) {
            Text(value)
                .font(.system(size:DSTSize.titleCard, weight:.semibold, design:.rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth:.infinity)
        .padding(.vertical,10)
        .background(color.opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(0.18), lineWidth:0.8))
    }

    @ViewBuilder var badgesSection: some View {
        // Group badges by level for display
        let days  = periodBadges.filter { $0.level == .day   }.prefix(14)
        let weeks = periodBadges.filter { $0.level == .week  }
        let months = periodBadges.filter { $0.level == .month }
        let years = periodBadges.filter { $0.level == .year  }

        if periodBadges.isEmpty {
            // Show badge requirements explanation
            VStack(alignment:.leading, spacing:8) {
                HStack(spacing:5) {
                    Image(systemName:"medal").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    Text(store.t(zh:"成就徽章规则", en:"Badge Rules", ja:"バッジルール", ko:"배지 규칙", es:"Reglas de insignias"))
                        .font(.system(size:DSTSize.caption, weight:.semibold, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                }
                VStack(alignment:.leading, spacing:5) {
                    badgeRuleRow(level:.day)
                    badgeRuleRow(level:.week)
                    badgeRuleRow(level:.month)
                    badgeRuleRow(level:.year)
                }
            }
            .padding(12).background(AppTheme.bg1).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0, lineWidth:0.8))
        } else {
            VStack(alignment:.leading, spacing:10) {
                HStack(spacing:5) {
                    Image(systemName:"medal.fill").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                    Text(store.t(zh:"成就徽章", en:"Achievements", ja:"実績", ko:"업적", es:"Logros"))
                        .font(.system(size:DSTSize.caption, weight:.semibold, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                    Text("· \(periodBadges.count)")
                        .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    Spacer()
                }
                // High-tier badges first (year/month/week)
                if !years.isEmpty || !months.isEmpty || !weeks.isEmpty {
                    ScrollView(.horizontal, showsIndicators:false) {
                        HStack(spacing:8) {
                            ForEach(years) { b in badgeCell(b) }
                            ForEach(months) { b in badgeCell(b) }
                            ForEach(weeks) { b in badgeCell(b) }
                        }.padding(.horizontal,2)
                    }
                }
                // Day badges in grid
                if !days.isEmpty {
                    HStack(spacing:5) {
                        Image(systemName:"sun.max.fill").font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(RewardLevel.day.color)
                        Text(store.t(zh:"日徽章 \(periodBadges.filter{$0.level == .day}.count)个", en:"Day Badges \(periodBadges.filter{$0.level == .day}.count)", ja:"日バッジ", ko:"일 배지", es:"Día"))
                            .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    }
                    LazyVGrid(columns: Array(repeating:.init(.flexible(minimum:44, maximum:60)),count:7), spacing:6) {
                        ForEach(Array(days)) { b in badgeCell(b, compact:true) }
                    }
                }
            }
            .padding(12).background(AppTheme.bg1).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.gold.opacity(0.18), lineWidth:1))
        }
    }

    @ViewBuilder func badgeRuleRow(level: RewardLevel) -> some View {
        HStack(spacing:8) {
            ZStack {
                Circle().fill(level.color.opacity(0.12)).frame(width:24,height:24)
                Image(systemName:level.symbol).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(level.color)
            }
            Text(badgeRuleText(level))
                .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    func badgeRuleText(_ level: RewardLevel) -> String {
        switch level {
        case .day:   return store.t(zh:"当天所有目标100%完成", en:"100% all goals in one day",   ja:"その日全目標完了", ko:"하루 모든 목표 100%", es:"100% objetivos en un día")
        case .week:  return store.t(zh:"周内每天都100%完成",   en:"100% every day of the week",  ja:"週の全日完了",     ko:"주간 매일 100%",     es:"100% cada día de la semana")
        case .month: return store.t(zh:"月内每周都完美完成",   en:"Perfect every week in month", ja:"月の全週完了",     ko:"월간 매주 완벽",     es:"Semanas perfectas en el mes")
        case .year:  return store.t(zh:"年内每月都完美完成",   en:"Perfect every month in year", ja:"年の全月完了",     ko:"연간 매달 완벽",     es:"Meses perfectos en el año")
        }
    }

    @ViewBuilder func badgeCell(_ b: RewardRecord, compact: Bool = false) -> some View {
        VStack(spacing:3) {
            ZStack {
                Circle().fill(b.level.color.opacity(0.15)).frame(width:compact ? 36:44, height:compact ? 36:44)
                Circle().stroke(b.level.color.opacity(0.4), lineWidth:1).frame(width:compact ? 36:44, height:compact ? 36:44)
                Image(systemName:b.level.symbol)
                    .font(.system(size:compact ? 12:16, weight:.medium))
                    .foregroundColor(b.level.color)
            }
            Text(b.periodLabel)
                .font(.system(size:DSTSize.nano, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width:compact ? 44:54)
    }

    // Per-day completion dot color
    func dotColor(_ rate: Double, _ goal: Goal) -> Color {
        if rate <= 0   { return AppTheme.bg3 }
        if rate >= 1.0 { return goal.color }
        if rate >= 0.5 { return goal.color.opacity(0.5) }
        return goal.color.opacity(0.25)
    }

    @ViewBuilder func goalCard(_ goal: Goal) -> some View {
        let activeDays = periodDates.filter { d in
            cal.startOfDay(for:goal.startDate) <= cal.startOfDay(for:d)
        }
        // Use store.tasks(for:date,goal:) so pinned tasks and skips are respected per day
        let taskList = period == 0
            ? store.tasks(for: today, goal: goal)
            : goal.tasks  // for multi-day periods use full task set (pinned tasks are date-specific)
        let completions: [Double] = period == 0
            ? taskList.map { store.progress(for:today, taskId:$0.id) }
            : activeDays.map { d in
                let dayTasks = store.tasks(for:d, goal:goal)
                guard !dayTasks.isEmpty else { return 0.0 }
                return dayTasks.map { store.progress(for:d, taskId:$0.id) }.reduce(0,+) / Double(dayTasks.count)
            }
        let avg = completions.isEmpty ? 0.0 : completions.reduce(0,+) / Double(completions.count)
        let doneTasksToday = period == 0 ? taskList.filter { store.progress(for:today, taskId:$0.id) >= 1.0 }.count : 0
        let starts = Set(activeDays.map { cal.startOfDay(for:$0) })
        let filteredJournals = store.planJournals
            .filter { $0.goalId == goal.id && starts.contains(cal.startOfDay(for:$0.date)) }
            .sorted { $0.createdAt > $1.createdAt }
        let isExpanded = expandedGoals.contains(goal.id)

        VStack(alignment:.leading, spacing:0) {
            // ── Card header ───────────────────────────────────
            Button(action:{
                withAnimation(.spring(response:0.3, dampingFraction:0.8)){
                    if isExpanded { expandedGoals.remove(goal.id) }
                    else          { expandedGoals.insert(goal.id) }
                }
            }) {
                HStack(spacing:10) {
                    RoundedRectangle(cornerRadius:2).fill(goal.color).frame(width:3, height:44)
                    VStack(alignment:.leading, spacing:5) {
                        HStack {
                            Text(goal.title)
                                .font(.system(size:DSTSize.label, weight:.semibold, design:.rounded))
                                .foregroundColor(AppTheme.textPrimary).lineLimit(1)
                            Spacer()
                            ZStack {
                                Circle().stroke(AppTheme.bg3, lineWidth:2.5).frame(width:32,height:32)
                                Circle().trim(from:0, to:CGFloat(avg))
                                    .stroke(goal.color, style:StrokeStyle(lineWidth:2.5, lineCap:.round))
                                    .frame(width:32,height:32).rotationEffect(.degrees(-90))
                                Text("\(Int(avg*100))")
                                    .font(.system(size:DSTSize.nano, weight:.bold, design:.rounded))
                                    .foregroundColor(goal.color)
                            }
                        }
                        HStack(spacing:10) {
                            if period == 0 {
                                Label("\(doneTasksToday)/\(taskList.count)", systemImage:"checkmark.circle")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            } else {
                                let activeDaysCount = completions.filter{$0>0}.count
                                Label("\(activeDaysCount)/\(activeDays.count)", systemImage:"calendar")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }
                            if !filteredJournals.isEmpty {
                                Label("\(filteredJournals.count)", systemImage:"lightbulb.fill")
                                    .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal,12).padding(.vertical,10)
            }
            .buttonStyle(.plain)

            GeometryReader { g in
                ZStack(alignment:.leading) {
                    Rectangle().fill(AppTheme.bg3).frame(height:2)
                    Rectangle()
                        .fill(LinearGradient(colors:[goal.color.opacity(0.5),goal.color], startPoint:.leading, endPoint:.trailing))
                        .frame(width:max(0, g.size.width*CGFloat(avg)), height:2)
                }
            }.frame(height:2)

            if isExpanded {
                VStack(alignment:.leading, spacing:12) {
                    Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(height:0.5)

                    // For today: show task list
                    if period == 0 {
                        VStack(alignment:.leading, spacing:6) {
                            Text(store.t(zh:"今日任务", en:"Tasks Today", ja:"今日のタスク", ko:"오늘 할 일", es:"Tareas de hoy"))
                                .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            ForEach(taskList) { task in
                                let prog = store.progress(for:today, taskId:task.id)
                                HStack(spacing:8) {
                                    Circle()
                                        .fill(prog >= 1.0 ? goal.color : goal.color.opacity(0.2))
                                        .frame(width:6, height:6)
                                    Text(task.title)
                                        .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                        .foregroundColor(prog >= 1.0 ? AppTheme.textTertiary : AppTheme.textSecondary)
                                        .strikethrough(prog >= 1.0, color:AppTheme.textTertiary.opacity(0.4))
                                    Spacer()
                                    if task.estimatedMinutes != nil {
                                        Text("\(Int(prog*100))%")
                                            .font(.system(size:DSTSize.micro, weight:.regular, design:.monospaced))
                                            .foregroundColor(goal.color.opacity(0.7))
                                    }
                                }
                            }
                        }
                    } else {
                        // Heatmap for week/month/year/all
                        VStack(alignment:.leading, spacing:6) {
                            Text(store.t(zh:"每日完成", en:"Daily", ja:"日別", ko:"일별", es:"Diario"))
                                .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            let displayDays = Array(activeDays.suffix(28))
                            let rows = stride(from:0, to:displayDays.count, by:7).map {
                                Array(displayDays[$0..<min($0+7,displayDays.count)])
                            }
                            VStack(alignment:.leading, spacing:3) {
                                ForEach(rows.indices, id:\.self) { ri in
                                    HStack(spacing:3) {
                                        ForEach(rows[ri].indices, id:\.self) { di in
                                            let d = rows[ri][di]
                                            let rate: Double = {
                                                guard !taskList.isEmpty else { return 0 }
                                                return taskList.map { store.progress(for:d, taskId:$0.id) }.reduce(0,+) / Double(taskList.count)
                                            }()
                                            let isToday = cal.isDateInToday(d)
                                            ZStack {
                                                RoundedRectangle(cornerRadius:3)
                                                    .fill(dotColor(rate, goal)).frame(width:28, height:16)
                                                if isToday {
                                                    RoundedRectangle(cornerRadius:3)
                                                        .stroke(goal.color, lineWidth:1.2).frame(width:28, height:16)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Journals
                    if !filteredJournals.isEmpty {
                        Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(height:0.5)
                        VStack(alignment:.leading, spacing:6) {
                            HStack(spacing:5) {
                                Image(systemName:"lightbulb.fill").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.gold)
                                Text(store.t(zh:"心得记录", en:"Insights", ja:"気づき", ko:"노트", es:"Notas"))
                                    .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                                Text("(\(filteredJournals.count))").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }
                            ForEach(filteredJournals.prefix(3)) { j in
                                HStack(alignment:.top, spacing:8) {
                                    VStack(spacing:2) {
                                        Circle().fill(AppTheme.gold.opacity(0.5)).frame(width:5,height:5).padding(.top,5)
                                        Rectangle().fill(AppTheme.border0).frame(width:1).frame(maxHeight:.infinity)
                                    }.frame(width:5)
                                    VStack(alignment:.leading, spacing:3) {
                                        Text({ let f=DateFormatter(); f.dateFormat="M/d"; return f.string(from:j.date) }())
                                            .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                                        Text(j.note)
                                            .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textSecondary)
                                            .lineLimit(4).padding(8)
                                            .frame(maxWidth:.infinity, alignment:.leading)
                                            .background(AppTheme.gold.opacity(0.06)).cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius:8).stroke(AppTheme.gold.opacity(0.15), lineWidth:0.8))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal,12).padding(.top,8).padding(.bottom,12)
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .background(AppTheme.bg1)
        .clipShape(RoundedRectangle(cornerRadius:14))
        .overlay(RoundedRectangle(cornerRadius:14)
            .stroke(avg >= 1.0 ? goal.color.opacity(0.3) : AppTheme.border0, lineWidth:0.8))
        .shadow(color:avg >= 1.0 ? goal.color.opacity(0.08) : .black.opacity(0.08), radius:6, x:0, y:2)
    }

    @ViewBuilder func emptyPlaceholder(icon: String, msg: String) -> some View {
        VStack(spacing:12) {
            Image(systemName:icon).font(.system(size:DSTSize.displayLarge, weight:.ultraLight, design:.rounded)).foregroundColor(AppTheme.textTertiary.opacity(0.4))
            Text(msg).font(.subheadline).foregroundColor(AppTheme.textTertiary)
        }.frame(maxWidth:.infinity).padding(.vertical,40)
    }
}


struct HistoryKWTab: View {
    enum KWType { case gain, plan }
    @EnvironmentObject var store: AppStore
    let kwType: KWType

    @State private var expandedYears:  Set<Int>    = []
    @State private var expandedMonths: Set<String> = []
    @State private var expandedWeeks:  Set<String> = []
    @State private var editingDate: Date? = nil
    @State private var editKWs: [String] = []
    @State private var editInput = ""
    @FocusState private var editFocused: Bool

    var color: Color  { kwType == .gain ? AppTheme.accent : Color(red:0.6,green:0.5,blue:0.9) }
    var icon:  String { kwType == .gain ? "star.fill" : "arrow.right.circle.fill" }
    var kwDates: [Date] { kwType == .gain ? store.datesWithGains : store.datesWithPlans }
    var allYears: [GrowthYearEntry] {
        store.allGrowthYears().filter{ ye in kwDates.contains{ Calendar.current.component(.year,from:$0)==ye.year } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment:.leading, spacing:0) {
                if allYears.isEmpty {
                    emptyPlaceholder(icon:icon, msg:store.t(key: L10n.noRecordsYet))
                } else {
                    globalCloud.padding(.horizontal,16).padding(.top,12).padding(.bottom,6)
                    Rectangle().fill(AppTheme.border0).frame(height:0.5).padding(.horizontal,16).padding(.bottom,4)
                    ForEach(allYears, id:\.year) { ye in yearBlock(ye) }
                }
            }.padding(.bottom,24)
        }
        .background(AppTheme.bg0.ignoresSafeArea())
        .onAppear{ if let y=allYears.first { expandedYears.insert(y.year) } }
        .sheet(isPresented:.init(get:{ editingDate != nil }, set:{ if !$0 { editingDate=nil } })) {
            if let d=editingDate { editSheet(date:d) }
        }
    }

    @ViewBuilder var globalCloud: some View {
        let allKWs=kwDates.prefix(180).flatMap{ kwsFor(dates:[$0]) }
        let freq:[String:Int]=allKWs.reduce(into:[:]){ $0[$1,default:0]+=1 }
        let sorted=freq.sorted{$0.value>$1.value}.map{$0.key}

        VStack(alignment:.leading, spacing:8) {
            HStack {
                Image(systemName:icon).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                Text({
                    let isGain = kwType == .gain
                    switch store.language {
                    case .chinese:  return isGain ? "高频收获词" : "高频计划词"
                    case .japanese: return isGain ? "よくある成果" : "よくある計画"
                    case .korean:   return isGain ? "주요 성과 키워드" : "주요 계획 키워드"
                    case .spanish:  return isGain ? "Logros frecuentes" : "Planes frecuentes"
                    case .english:  return isGain ? "Top wins" : "Top plans"
                    }
                }())
                    .font(.system(size:DSTSize.caption,weight:.semibold, design:.rounded)).foregroundColor(color)
                Spacer()
                Text("\(sorted.count) \(store.t(key: L10n.keywordWord))").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
            }
            if sorted.isEmpty {
                Text(store.t(key: L10n.noDataYet2)).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
            } else {
                FlowLayout(spacing:5) {
                    ForEach(sorted.prefix(24), id:\.self) { kw in
                        let f=freq[kw] ?? 1
                        Text(f>1 ? "\(kw) \(f)" : kw)
                            .font(.system(size:f>3 ? 13:11))
                            .foregroundColor(f>1 ? color : color.opacity(0.6))
                            .padding(.horizontal,8).padding(.vertical,4)
                            .background(color.opacity(f>2 ? 0.16:0.08))
                            .cornerRadius(20)
                    }
                }
            }
        }
        .padding(12).background(AppTheme.bg1).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius:14).stroke(color.opacity(0.2),lineWidth:1))
    }

    @ViewBuilder func yearBlock(_ ye: GrowthYearEntry) -> some View {
        let isOpen=expandedYears.contains(ye.year)
        let kws=kwsFor(dates:ye.dates)
        VStack(alignment:.leading, spacing:0) {
            Button(action:{withAnimation(.spring(response:0.28)){
                if isOpen { expandedYears.remove(ye.year) } else { expandedYears.insert(ye.year) }
            }}) {
                HStack(spacing:8) {
                    Text(ye.label).font(.system(size:DSTSize.label,weight:.semibold, design:.rounded)).foregroundColor(AppTheme.textPrimary)
                    kwBadge(kws.count)
                    Spacer()
                    if !isOpen {
                        HStack(spacing:3) {
                            ForEach(kws.prefix(4), id:\.self) { kw in
                                Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color.opacity(0.7))
                                    .padding(.horizontal,5).padding(.vertical,2)
                                    .background(color.opacity(0.08)).cornerRadius(8)
                            }
                            if kws.count>4 {
                                Text("+\(kws.count-4)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                    Image(systemName:isOpen ? "chevron.up":"chevron.down").font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                }
                .padding(.vertical,10).padding(.horizontal,16)
                .background(AppTheme.bg0)
            }
            if isOpen {
                let months=store.monthsInYear(ye.year)
                ForEach(months, id:\.key) { me in monthBlock(me) }
            }
        }
    }

    @ViewBuilder func monthBlock(_ me: GrowthMonthEntry) -> some View {
        let isOpen=expandedMonths.contains(me.key)
        let kws=kwsFor(dates:me.dates)
        let hasKWDates=me.dates.contains(where:{ d in kwDates.contains{ Calendar.current.isDate(d,inSameDayAs:$0) } })
        if !kws.isEmpty || hasKWDates {
            VStack(alignment:.leading, spacing:0) {
                Button(action:{withAnimation(.spring(response:0.25)){
                    if isOpen { expandedMonths.remove(me.key) } else { expandedMonths.insert(me.key) }
                }}) {
                    HStack(spacing:6) {
                        Rectangle().fill(color.opacity(0.45)).frame(width:3,height:14).cornerRadius(2)
                        Text(me.label).font(.system(size:DSTSize.label,weight:.medium, design:.rounded)).foregroundColor(AppTheme.textSecondary)
                        kwBadge(kws.count)
                        Spacer()
                        if !isOpen {
                            Text(kws.prefix(3).joined(separator:" · "))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color.opacity(0.7)).lineLimit(1)
                        }
                        Image(systemName:isOpen ? "chevron.up":"chevron.down").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.vertical,8).padding(.horizontal,16)
                    .background(AppTheme.bg1.opacity(0.7))
                }
                if isOpen {
                    VStack(alignment:.leading, spacing:4) {
                        if !kws.isEmpty {
                            FlowLayout(spacing:5) {
                                ForEach(kws, id:\.self) { kw in
                                    Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                                        .padding(.horizontal,7).padding(.vertical,3)
                                        .background(color.opacity(0.1)).cornerRadius(12)
                                }
                            }.padding(.horizontal,16).padding(.top,6)
                        }
                        let weeks=store.weeksInMonth(me.dates)
                        ForEach(weeks, id:\.key) { we in weekBlock(we) }
                    }
                    .transition(.opacity.combined(with:.move(edge:.top)))
                }
            }
        }
    }

    @ViewBuilder func weekBlock(_ we: GrowthWeekEntry) -> some View {
        let isOpen=expandedWeeks.contains(we.key)
        let kws=kwsFor(dates:we.dates)
        let days=store.daysInDates(we.dates).filter{ de in kwDates.contains{ Calendar.current.isDate(de.date,inSameDayAs:$0) } }
        if !kws.isEmpty || !days.isEmpty {
            VStack(alignment:.leading, spacing:0) {
                Button(action:{withAnimation(.spring(response:0.22)){
                    if isOpen { expandedWeeks.remove(we.key) } else { expandedWeeks.insert(we.key) }
                }}) {
                    HStack(spacing:5) {
                        Rectangle().fill(color.opacity(0.2)).frame(width:2,height:12).cornerRadius(1)
                        Text(we.label).font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary)
                        kwBadge(kws.count)
                        Spacer()
                        if !isOpen && !kws.isEmpty {
                            Text(kws.prefix(2).joined(separator:" · "))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color.opacity(0.6)).lineLimit(1)
                        }
                        Image(systemName:isOpen ? "chevron.up":"chevron.down").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                    }
                    .padding(.vertical,6).padding(.horizontal,16)
                }
                if isOpen {
                    VStack(alignment:.leading, spacing:4) {
                        if !kws.isEmpty {
                            FlowLayout(spacing:4) {
                                ForEach(kws, id:\.self) { kw in
                                    Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                                        .padding(.horizontal,6).padding(.vertical,2)
                                        .background(color.opacity(0.1)).cornerRadius(10)
                                }
                            }.padding(.horizontal,16).padding(.top,4)
                        }
                        ForEach(days, id:\.date as KeyPath<GrowthDayEntry,Date>) { de in dayRow(de) }
                    }
                    .transition(.opacity.combined(with:.move(edge:.top)))
                }
            }.padding(.leading,8)
        }
    }

    @ViewBuilder func dayRow(_ de: GrowthDayEntry) -> some View {
        let kws=kwsFor(dates:[de.date])
        if !kws.isEmpty {
            HStack(alignment:.top, spacing:8) {
                Text(formatDate(de.date, format:store.language == .chinese ? "M/d EEE":"EEE M/d", lang:store.language))
                    .font(.system(size: DSTSize.micro, weight: .regular, design:.rounded)).misty(.tertiary)
                    .frame(width:58,alignment:.leading).padding(.top,3)
                FlowLayout(spacing:4) {
                    ForEach(kws, id:\.self) { kw in
                        Text(kw).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(color)
                            .padding(.horizontal,6).padding(.vertical,2)
                            .background(color.opacity(0.1)).cornerRadius(10)
                    }
                }
                Spacer()
                Button(action:{ openEdit(date:de.date) }) {
                    Image(systemName:"pencil").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                        .padding(5).background(AppTheme.bg2).cornerRadius(6)
                }
            }
            .padding(.horizontal,16).padding(.vertical,4)
        }
    }

    func kwsFor(dates:[Date]) -> [String] {
        kwType == .gain ? store.allGainKeywords(for:dates) : store.allPlanKeywords(for:dates)
    }

    @ViewBuilder func kwBadge(_ n:Int) -> some View {
        if n>0 {
            Text("\(n)")
                .font(.system(size:DSTSize.cardMicro, weight:.semibold, design:.rounded))
                .foregroundColor(color)
                .padding(.horizontal,5).padding(.vertical,2)
                .background(color.opacity(0.12)).cornerRadius(6)
        }
    }

    func openEdit(date:Date) {
        editKWs = kwType == .gain ? store.gainKeywords(for:date) : store.planKeywords(for:date)
        editingDate = date
    }

    @ViewBuilder func editSheet(date:Date) -> some View {
        NavigationView {
            VStack(alignment:.leading, spacing:12) {
                Text(formatDate(date, format:store.language == .chinese ? "yyyy年M月d日":"MMM d, yyyy", lang:store.language))
                    .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded)).misty(.tertiary).padding(.horizontal,16)
                FlowLayout(spacing:8) {
                    ForEach(editKWs, id:\.self) { kw in
                        HStack(spacing:4) {
                            Text(kw).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded)).foregroundColor(color)
                            Button(action:{ editKWs.removeAll{$0==kw} }) {
                                Image(systemName:"xmark").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            }
                        }
                        .padding(.horizontal,8).padding(.vertical,4).background(color.opacity(0.1)).cornerRadius(12)
                    }
                }.padding(.horizontal,16)
                HStack {
                    TextField(store.t(key: L10n.newKeyword), text:$editInput)
                        .focused($editFocused).font(.system(size:DSTSize.label, weight:.medium, design:.rounded))
                        .padding(10).background(AppTheme.bg2).cornerRadius(10)
                    Button(action:{
                        let kw=editInput.trimmingCharacters(in:.whitespaces)
                        if !kw.isEmpty && !editKWs.contains(kw) { editKWs.append(kw) }
                        editInput=""
                    }) {
                        Image(systemName:"plus.circle.fill").font(.system(size:DSTSize.titleCard, weight:.light, design:.rounded)).foregroundColor(color)
                    }
                }.padding(.horizontal,16)
                Spacer()
            }
            .padding(.top,16)
            .navigationTitle({
                let isGain = kwType == .gain
                switch store.language {
                case .chinese:  return isGain ? "编辑收获" : "编辑计划"
                case .japanese: return isGain ? "成果を編集" : "計画を編集"
                case .korean:   return isGain ? "성과 편집" : "계획 편집"
                case .spanish:  return isGain ? "Editar logros" : "Editar planes"
                case .english:  return isGain ? "Edit Wins" : "Edit Plans"
                }
            }())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){ Button(store.t(key: L10n.cancel)){ editingDate=nil } }
                ToolbarItem(placement:.confirmationAction){
                    Button(store.t(key: L10n.save)){
                        if kwType == .gain { store.replaceGainKeywords(editKWs, for:date) }
                        else               { store.replacePlanKeywords(editKWs, for:date) }
                        editingDate=nil
                    }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}


// ============================================================
// MARK: - SmartSummarySheet（提交心得/总结后弹出，日/周/月/年）
// ============================================================

struct SummaryContext {
    let periodType: Int        // -1=日  0=周  1=月  2=年
    let periodLabel: String    // 用于 smartSummary(type:label:dates:)
    let dates: [Date]
    let sheetTitle: String

    static func forDay(_ date: Date, store: AppStore) -> SummaryContext {
        let lang = store.language
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: lang.localeIdentifier)
        switch lang {
        case .chinese, .japanese, .korean: fmt.dateFormat = "M月d日"
        case .english, .spanish:           fmt.dateFormat = "MMM d"
        }
        return SummaryContext(
            periodType: -1,
            periodLabel: fmt.string(from: date),
            dates: [date],
            sheetTitle: L10n.dailySummaryTitle(lang)
        )
    }
    static func forWeek(label: String, dates: [Date], store: AppStore) -> SummaryContext {
        SummaryContext(periodType:0, periodLabel:label, dates:dates,
                       sheetTitle: L10n.weeklySummaryTitle(store.language))
    }
    static func forMonth(label: String, dates: [Date], store: AppStore) -> SummaryContext {
        SummaryContext(periodType:1, periodLabel:label, dates:dates,
                       sheetTitle: L10n.monthlySummaryTitle(store.language))
    }
    static func forYear(label: String, dates: [Date], store: AppStore) -> SummaryContext {
        SummaryContext(periodType:2, periodLabel:label, dates:dates,
                       sheetTitle: L10n.yearlySummaryTitle(store.language))
    }
}

struct SmartSummarySheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @Environment(\.dismiss) var dismiss
    let ctx: SummaryContext

    // ── 数据 ────────────────────────────────────────────────
    var completionPct: Int { Int(store.avgCompletion(for:ctx.dates) * 100) }
    var mood: Double { store.avgMood(for:ctx.dates) }
    var moodEmoji: String {
        mood >= 4.5 ? "✨" : mood >= 3.5 ? "🤍" : mood >= 2.5 ? "🙂" : mood >= 1.5 ? "😶" : mood > 0 ? "😞" : ""
    }
    var taskStats: (done:Int, total:Int) {
        var d = 0; var t = 0
        for date in ctx.dates {
            let tasks = store.goals(for:date).flatMap{ store.tasks(for:date, goal:$0) }
            t += tasks.count
            d += tasks.filter{ store.progress(for:date, taskId:$0.id) >= 1.0 }.count
        }
        return (d, t)
    }
    var challengeState: (active:[String], resolved:[String]) {
        if ctx.periodType == -1, let d = ctx.dates.first {
            let s = store.dailyChallengeState(for:d); return (s.active, s.resolved)
        }
        return store.periodChallengeState(dates:ctx.dates)
    }
    var gainKW:  [String] { store.allGainKeywords(for:ctx.dates) }
    var planKW:  [String] { store.allPlanKeywords(for:ctx.dates) }
    var insight: String   { store.smartSummary(type:max(0,ctx.periodType), label:ctx.periodLabel, dates:ctx.dates) }

    // Palette
    let accentGreen  = Color(red:0.420, green:0.730, blue:0.550)
    let accentPurple = Color(red:0.750, green:0.580, blue:0.780)

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators:false) {
                VStack(spacing:14) {

                    // ── 心情 + 完成率 Hero ──────────────────
                    HStack(spacing:16) {
                        // 心情
                        VStack(spacing:4) {
                            Text(moodEmoji.isEmpty ? "—" : moodEmoji)
                                .font(.system(size:DSTSize.displayLarge, weight:.ultraLight, design:.rounded))
                            Text(store.t(key: L10n.moodShort))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            if mood > 0 {
                                Text(String(format:"%.1f/5", mood))
                                    .font(.system(size:DSTSize.caption, weight:.medium, design:.rounded))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .frame(maxWidth:.infinity)
                        .padding(.vertical,14)
                        .background(AppTheme.bg1)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0, lineWidth:1))

                        // 完成率
                        VStack(spacing:4) {
                            Text("\(completionPct)%")
                                .dsNumberLarge(color: completionPct >= 80 ? accentGreen : completionPct >= 50 ? AppTheme.accent : AppTheme.gold)
                            Text(store.t(key: L10n.completionRateShort))
                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
                            Text(completionPct >= 80 ? "🏆" : completionPct >= 60 ? "✨" : completionPct > 0 ? "💪" : "—")
                                .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                        }
                        .frame(maxWidth:.infinity)
                        .padding(.vertical,14)
                        .background(AppTheme.bg1)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0, lineWidth:1))
                    }
                    .padding(.horizontal,16)

                    // ── 5格核心指标（去掉 task，加成就）─────────
                    let ts = taskStats
                    let cs = challengeState
                    VStack(spacing:0) {
                        HStack(spacing:0) {
                            // 成就 = 收获关键词数量（gainKW）
                            statCell("\(gainKW.count)", store.t(key: L10n.wins), accentGreen)
                            statDivider
                            statCell("\(cs.active.count)", store.t(key: L10n.pending),
                                     cs.active.isEmpty ? accentGreen : AppTheme.gold)
                            statDivider
                            statCell("\(cs.resolved.count)", store.t(key: L10n.resolved), accentGreen)
                        }
                        Rectangle().fill(AppTheme.border0.opacity(0.5)).frame(height:0.5).padding(.horizontal,8)
                        HStack(spacing:0) {
                            statCell("\(ts.done)/\(ts.total)", store.t(key: L10n.tasks), AppTheme.accent)
                            statDivider
                            statCell("\(planKW.count)", store.t(key: L10n.plans), accentPurple)
                            statDivider
                            let activeDays = ctx.dates.filter{ store.completionRate(for:$0) > 0 }.count
                            statCell(ctx.dates.count <= 1 ? "—" : "\(activeDays)",
                                     store.t(key: L10n.activeDays), AppTheme.textSecondary)
                        }
                    }
                    .background(AppTheme.bg1)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0, lineWidth:1))
                    .padding(.horizontal,16)

                    // ── 收获词云 ────────────────────────────
                    if !gainKW.isEmpty { kwPanel(accentGreen, "star.fill", store.t(key: L10n.wins), gainKW) }

                    // ── 计划词云 ────────────────────────────
                    if !planKW.isEmpty { kwPanel(accentPurple, "arrow.right.circle.fill", store.t(key: L10n.plans), planKW) }

                    // ── 智能洞察 — 3段式：Hero · Key Insights · Next Step ──
                    let ts2  = taskStats
                    let cs2  = challengeState
                    let sheetInsight = ruleEngine(
                        lang: store.language,
                        pct: completionPct, done: ts2.done, total: ts2.total,
                        pending: cs2.active.count, resolved: cs2.resolved.count,
                        gains: gainKW.count,
                        streak: store.goals.map { store.currentStreak(for:$0) }.max() ?? 0,
                        mood: mood, range: ctx.periodType
                    )
                    VStack(alignment:.leading, spacing:0) {
                        // Card header
                        HStack(spacing:6) {
                            ZStack {
                                Circle().fill(AppTheme.accent.opacity(0.12)).frame(width:20, height:20)
                                Image(systemName:"sparkles")
                                    .font(.system(size:DSTSize.nano, weight:.semibold, design:.rounded))
                                    .foregroundColor(AppTheme.accent)
                            }
                            Text(store.t(key: L10n.smartInsight))
                                .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
                                .foregroundColor(AppTheme.accent.opacity(0.80))
                                .kerning(1.5)
                                .textCase(.uppercase)
                            Spacer()
                            Text("AI")
                                .font(.system(size:DSTSize.nano, weight:.bold, design:.rounded))
                                .foregroundColor(pro.isProSubscriber ? .white : AppTheme.textTertiary)
                                .padding(.horizontal,5).padding(.vertical,2)
                                .background(pro.isProSubscriber ? AppTheme.accent : AppTheme.bg3)
                                .cornerRadius(3)
                        }
                        .padding(.horizontal,14).padding(.top,12).padding(.bottom,10)

                        Rectangle().fill(AppTheme.border0.opacity(0.45)).frame(height:0.5)

                        // Section 1: Hero
                        Text(sheetInsight.hero)
                            .font(.system(size:DSTSize.label, weight:.regular, design:.rounded))
                            .foregroundColor(AppTheme.textPrimary.opacity(0.88))
                            .lineSpacing(4)
                            .fixedSize(horizontal:false, vertical:true)
                            .padding(.horizontal,14).padding(.top,12).padding(.bottom,10)

                        // Section 2: Key insights (max 3)
                        if !sheetInsight.insights.isEmpty {
                            Rectangle().fill(AppTheme.border0.opacity(0.28)).frame(height:0.5)
                                .padding(.horizontal,10)
                            VStack(spacing:0) {
                                ForEach(Array(sheetInsight.insights.enumerated()), id:\.offset) { idx, item in
                                    HStack(alignment:.center, spacing:0) {
                                        ZStack {
                                            Circle().fill(AppTheme.accent.opacity(0.08)).frame(width:24,height:24)
                                            Image(systemName:item.icon)
                                                .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                                                .foregroundColor(AppTheme.accent.opacity(0.72))
                                        }.frame(width:40)
                                        VStack(alignment:.leading, spacing:1) {
                                            Text(item.label)
                                                .font(.system(size:DSTSize.micro, weight:.semibold, design:.rounded))
                                                .foregroundColor(AppTheme.textTertiary.opacity(0.55))
                                                .textCase(.uppercase).kerning(0.4)
                                            Text(item.note)
                                                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                                .foregroundColor(AppTheme.textSecondary.opacity(0.72))
                                                .lineLimit(2)
                                        }.frame(maxWidth:.infinity, alignment:.leading)
                                        Text(item.value)
                                            .font(.system(size:DSTSize.displaySmall, weight:.light, design:.rounded))
                                            .foregroundColor(AppTheme.accent).monospacedDigit()
                                            .frame(width:44, alignment:.trailing)
                                            .padding(.trailing,12)
                                    }
                                    .frame(minHeight:42)
                                    if idx < sheetInsight.insights.count - 1 {
                                        Rectangle().fill(AppTheme.border0.opacity(0.22)).frame(height:0.5)
                                            .padding(.leading,40)
                                    }
                                }
                            }.padding(.vertical,3)
                        }

                        // Section 3: Next step
                        Rectangle().fill(AppTheme.border0.opacity(0.28)).frame(height:0.5)
                            .padding(.horizontal,10)
                        HStack(alignment:.top, spacing:9) {
                            ZStack {
                                RoundedRectangle(cornerRadius:5, style:.continuous)
                                    .fill(AppTheme.gold.opacity(0.12)).frame(width:24,height:24)
                                Image(systemName:"arrow.right.circle.fill")
                                    .font(.system(size:DSTSize.micro, weight:.medium, design:.rounded))
                                    .foregroundColor(AppTheme.gold.opacity(0.82))
                            }
                            VStack(alignment:.leading, spacing:2) {
                                Text(store.t(zh:"下一步", en:"Next step", ja:"次のアクション", ko:"다음 단계", es:"Siguiente paso"))
                                    .font(.system(size:DSTSize.nano, weight:.semibold, design:.rounded))
                                    .foregroundColor(AppTheme.gold.opacity(0.60))
                                    .kerning(0.7).textCase(.uppercase)
                                Text(sheetInsight.nextStep)
                                    .font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                                    .foregroundColor(AppTheme.textSecondary.opacity(0.80))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal:false, vertical:true)
                            }
                        }
                        .padding(.horizontal,12).padding(.vertical,11)

                        // Pro upsell (free users only)
                        if !pro.isPro {
                            Rectangle().fill(AppTheme.border0.opacity(0.28)).frame(height:0.5)
                                .padding(.horizontal,10)
                            Button(action:{ pro.showPaywall = true }) {
                                HStack(spacing:5) {
                                    Image(systemName:"crown.fill").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                                    Text(store.t(key: L10n.upgradePro)).font(.system(size:DSTSize.caption, weight:.medium, design:.rounded))
                                }
                                .foregroundColor(AppTheme.gold)
                                .padding(.horizontal,12).padding(.vertical,7)
                                .frame(maxWidth:.infinity)
                                .background(AppTheme.gold.opacity(0.09))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius:8).stroke(AppTheme.gold.opacity(0.22), lineWidth:1))
                            }
                            .padding(.horizontal,12).padding(.bottom,10)
                        }
                    }
                    .background(AppTheme.bg1)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius:14)
                        .stroke(AppTheme.accent.opacity(0.14), lineWidth:0.8))
                    .padding(.horizontal,16)

                    Color.clear.frame(height:16)
                }
                .padding(.top,8)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(ctx.sheetTitle)
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(store.t(key: L10n.done)) { dismiss() }
                        .foregroundColor(AppTheme.accent).fontWeight(.medium)
                }
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    @ViewBuilder var statDivider: some View {
        Rectangle().fill(AppTheme.border0.opacity(0.6))
            .frame(width:0.5).padding(.vertical,8)
    }

    @ViewBuilder func statCell(_ val:String, _ lbl:String, _ col:Color) -> some View {
        VStack(spacing:3) {
            Text(val)
                .font(.system(size: DSTSize.numberMid, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundColor(col.opacity(0.90))
            Text(lbl)
                .font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth:.infinity).padding(.vertical,11)
    }

    @ViewBuilder func kwPanel(_ col:Color, _ icon:String, _ lbl:String, _ kws:[String]) -> some View {
        VStack(alignment:.leading, spacing:8) {
            HStack(spacing:5) {
                Image(systemName:icon).font(.system(size:DSTSize.micro, weight:.regular, design:.rounded)).foregroundColor(col)
                Text("\(lbl) · \(kws.count)")
                    .font(.system(size:DSTSize.caption, weight:.semibold, design:.rounded)).foregroundColor(col)
            }
            FlowLayout(spacing:5) {
                ForEach(kws.prefix(24), id:\.self) { kw in
                    Text(kw).font(.system(size:DSTSize.caption, weight:.regular, design:.rounded))
                        .foregroundColor(col)
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(col.opacity(0.1)).cornerRadius(20)
                }
                if kws.count > 24 {
                    Text("+\(kws.count-24)").font(.system(size:DSTSize.micro, weight:.regular, design:.rounded))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.bg1)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius:14).stroke(col.opacity(0.15), lineWidth:1))
        .padding(.horizontal,16)
    }
}

struct JournalEntryCard: View {
    let entry:DayReview;@EnvironmentObject var store:AppStore
    var body: some View {
        VStack(alignment:.leading,spacing:10){
            HStack{
                Text(formatDate(entry.date,format:store.language == .chinese ? "M月d日 EEEE":"EEE, MMM d",lang:store.language)).font(.subheadline).fontWeight(.medium).foregroundColor(AppTheme.textPrimary)
                Spacer()
                if entry.rating>0{let e=["😞","😶","🙂","🤍","✨"];Text(e[min(entry.rating-1,4)]).font(.body)}
            }
            if !entry.journalGains.isEmpty{JSnippet(icon:"star.fill",color:AppTheme.accent,label:store.t(key: L10n.winsShort),text:entry.journalGains)}
            if !entry.journalChallenges.isEmpty{JSnippet(icon:"exclamationmark.triangle.fill",color:AppTheme.gold,label:store.t(key: L10n.pending),text:entry.journalChallenges)}
            if !entry.journalTomorrow.isEmpty{JSnippet(icon:"arrow.right.circle.fill",color:Color(red:0.780,green:0.500,blue:0.700),label:store.t(key: L10n.tomorrowLabel),text:entry.journalTomorrow)}
        }.padding(14).background(AppTheme.bg1).cornerRadius(14).overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0,lineWidth:1))
    }
}

struct JSnippet: View {
    let icon:String;let color:Color;let label:String;let text:String
    var body: some View {
        HStack(alignment:.top,spacing:8){
            Image(systemName:icon).font(.caption2).foregroundColor(color).padding(.top,1)
            VStack(alignment:.leading,spacing:2){Text(label).font(.caption2).foregroundColor(color);Text(text).font(.caption).foregroundColor(AppTheme.textSecondary).lineLimit(3)}
        }
    }
}

// ============================================================
// MARK: - 灵感页
// ============================================================

// ============================================================
// MARK: - 灵感页（网络语录 + 本地备用）
// ============================================================

struct OnlineQuote: Identifiable {
    let id = UUID()
    let text: String
    let author: String
}

struct InspireView: View {
    @EnvironmentObject var store:AppStore
    @EnvironmentObject var pro:ProStore
    @State private var savedLocalIndices:Set<Int>=[0,3]
    @State private var savedOnlineQuotes:[OnlineQuote]=[]
    @State private var onlineQuotes:[OnlineQuote]=[]
    @State private var isLoadingOnline=false
    @State private var onlineError=false
    @State private var showOnline=false
    @State private var dailyPool:[Int]=[]
    @State private var poolPosition=0
    @State private var showArtLayer:Bool = true   // configurable art layer

    var currentIndex:Int { dailyPool.isEmpty ? 0 : dailyPool[poolPosition] }
    var localQuote:Quote { quoteLibrary[currentIndex] }

    var displayText:String{
        if showOnline, let q=onlineQuotes.first { return q.text }
        return store.language == .chinese ? localQuote.zh : localQuote.en
    }
    var displayAuthor:String{
        if showOnline, let q=onlineQuotes.first { return q.author }
        return store.language == .chinese ? localQuote.author : localQuote.authorEn
    }
    var canViewMore:Bool{ pro.isPro || poolPosition < ProStore.freeQuoteLimit }

    func refreshPool() {
        let pool = dailyQuotes(saved: savedLocalIndices, language: store.language)
        dailyPool = pool
        if poolPosition >= pool.count { poolPosition = 0 }
    }

    func nextQuote() {
        guard canViewMore else { pro.showPaywall=true; return }
        withAnimation(.easeInOut(duration:0.55)){ poolPosition = (poolPosition + 1) % max(1, dailyPool.count) }
    }
    func prevQuote() {
        guard canViewMore else { pro.showPaywall=true; return }
        withAnimation(.easeInOut(duration:0.55)){ poolPosition = poolPosition > 0 ? poolPosition - 1 : max(0, dailyPool.count - 1) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ── Glass imprint page title ─────────────────
                    PageHeaderView(title: store.t(key: L10n.inspire), accentColor: AppTheme.dreamGlow)

                    // ──────────────────────────────────────
                    // MARK: Main quote card
                    // ──────────────────────────────────────
                    DreamGlassCard(artVisible: showArtLayer) {
                        ZStack(alignment: .topLeading) {

                            // Art atmosphere — impressionist backdrop
                            ArtAtmosphereLayer(visible: showArtLayer)
                                .frame(maxWidth: .infinity)
                                .frame(height: 340)
                                .cornerRadius(AppTheme.cornerXL)

                            VStack(spacing: 0) {

                                // ── Source mode selector ─────────────
                                HStack(spacing: 8) {
                                    // Segmented control pill container
                                    HStack(spacing: 0) {
                                        Button(action:{ withAnimation(.spring(response:0.25)){ showOnline=true }; if onlineQuotes.isEmpty { fetchOnlineQuote() }}) {
                                            Text(store.t(key: L10n.inspireOnline))
                                                .font(.system(size: 12, weight: showOnline ? .semibold : .regular))
                                                .padding(.horizontal, 14).padding(.vertical, 7)
                                                .background(showOnline ? AppTheme.accent : Color.clear)
                                                .foregroundColor(showOnline ? .black : Color.white.opacity(0.65))
                                                .cornerRadius(8)
                                        }
                                        Button(action:{ withAnimation(.spring(response:0.25)){ showOnline=false }}) {
                                            Text(store.t(key: L10n.inspireClassic))
                                                .font(.system(size: 12, weight: !showOnline ? .semibold : .regular))
                                                .padding(.horizontal, 14).padding(.vertical, 7)
                                                .background(!showOnline ? AppTheme.accent : Color.clear)
                                                .foregroundColor(!showOnline ? .black : Color.white.opacity(0.65))
                                                .cornerRadius(8)
                                        }
                                    }
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                                    Spacer()
                                    if isLoadingOnline {
                                        ProgressView().scaleEffect(0.7).tint(AppTheme.accent)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.top, 18)

                                // ═══════════════════════════════════════
                                // Quote content — optical balance layout
                                //
                                // Uses golden ratio (0.382 : 0.618) for
                                // vertical space distribution instead of
                                // mechanical centering.
                                //
                                // The "content island" (quote + author) sits
                                // at ~44% of the content zone height, giving
                                // a stable, grounded, magazine-like feel.
                                // ═══════════════════════════════════════
                                GeometryReader { cardGeo in
                                    let typo = QuoteTypography.forText(displayText)
                                    let cardW = cardGeo.size.width
                                    let cardH = cardGeo.size.height

                                    // Detect if text is likely CJK (Chinese/Japanese/Korean)
                                    let isCJK = displayText.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                                    // CJK quotes use tighter width; Latin quotes slightly wider
                                    let widthRatio = isCJK ? min(typo.maxWidthRatio, 0.60) : min(typo.maxWidthRatio, 0.66)

                                    if isLoadingOnline && showOnline {
                                        VStack(spacing: 10) {
                                            ProgressView().tint(AppTheme.accent.opacity(0.6))
                                            Text(store.t(key: L10n.inspireFetching))
                                                .font(.system(size: DSTSize.caption, weight: .light, design: .rounded))
                                                .misty(.tertiary)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    } else {
                                        ZStack {
                                            // ── Ambient quote mark ──
                                            // Closer to the text block's top-left corner,
                                            // not banished to the card edge.
                                            Text("\u{201C}")
                                                .font(.system(size: 40, weight: .ultraLight, design: .serif))
                                                .foregroundColor(AppTheme.accent.opacity(0.055))
                                                .shadow(color: AppTheme.accent.opacity(0.02), radius: 6, x: 0, y: 0)
                                                .position(x: cardW * 0.18, y: cardH * 0.24)

                                            // ── Content island ──
                                            // Golden ratio: top spacer 0.382 / bottom spacer 0.618
                                            // This pushes the content island's visual center to ~44%
                                            // of the card height — optically stable, not floating.
                                            VStack(spacing: 0) {
                                                // Upper breathing space — slightly larger to push text down
                                                Spacer()
                                                    .frame(minHeight: 14, maxHeight: cardH * 0.40)

                                                // ── Quote body ──
                                                Text(displayText)
                                                    .font(.system(size: typo.fontSize, weight: .light, design: .serif))
                                                    .italic()
                                                    .lineSpacing(typo.lineSpacing)
                                                    .kerning(typo.fontSize > 18 ? 0.35 : 0.15)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(Color(red: 0.86, green: 0.87, blue: 0.90).opacity(0.82))
                                                    .shadow(color: Color.black.opacity(0.22), radius: 3, x: 0, y: 1)
                                                    .shadow(color: AppTheme.accent.opacity(0.02), radius: 8, x: 0, y: 0)
                                                    .frame(maxWidth: cardW * widthRatio)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(maxWidth: .infinity)
                                                    .animation(.easeInOut(duration: 0.55), value: displayText)

                                                // ── Author whisper ──
                                                HStack(spacing: 5) {
                                                    Rectangle()
                                                        .fill(Color(red: 0.40, green: 0.65, blue: 0.60).opacity(0.18))
                                                        .frame(width: 14, height: 0.6)
                                                    Text(displayAuthor)
                                                        .font(.system(size: 11.5, weight: .light, design: .serif))
                                                        .foregroundColor(Color(red: 0.50, green: 0.68, blue: 0.63).opacity(0.60))
                                                        .tracking(1.8)
                                                }
                                                .padding(.top, typo.authorSpacing)
                                                .animation(.easeInOut(duration: 0.55), value: displayAuthor)

                                                // Lower breathing space — shorter to balance
                                                Spacer()
                                                    .frame(minHeight: 10, maxHeight: cardH * 0.44)
                                            }
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        }
                                    }
                                }
                                .frame(minHeight: 210, maxHeight: 340)

                                Spacer().frame(height: 20)

                                // ── Pro limit warning ────────────────
                                if !pro.isPro && poolPosition >= ProStore.freeQuoteLimit && !showOnline {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill").font(.caption2)
                                        Text(L10n.inspireFreeLimitHit(ProStore.freeQuoteLimit, store.language)).font(.caption2)
                                    }
                                    .foregroundColor(AppTheme.gold)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(AppTheme.gold.opacity(0.10)).cornerRadius(8)
                                    .padding(.bottom, 4)
                                }

                                // ── Error notice ─────────────────────
                                if onlineError && showOnline {
                                    Text(store.t(key: L10n.inspireNetworkFail))
                                        .font(.system(size: DSTSize.micro, weight: .light, design:.rounded))
                                        .misty(.tertiary)
                                        .multilineTextAlignment(.center)
                                        .padding(.bottom, 4)
                                }

                                // ── Action bar ───────────────────────
                                HStack(spacing: 8) {
                                    // Prev / refresh
                                    GlassActionButton(
                                        icon: showOnline ? "arrow.clockwise" : "arrow.left",
                                        action: { if showOnline { fetchOnlineQuote() } else { prevQuote() } }
                                    )

                                    // Next / shuffle
                                    GlassActionButton(
                                        icon: "shuffle",
                                        label: store.t(key: L10n.inspireNext),
                                        action: { if showOnline { fetchOnlineQuote() } else { nextQuote() } }
                                    )

                                    Spacer()

                                    // Save / heart
                                    let isSaved = showOnline
                                        ? savedOnlineQuotes.contains(where:{$0.text==displayText})
                                        : savedLocalIndices.contains(currentIndex)
                                    GlassActionButton(
                                        icon: isSaved ? "heart.fill" : "heart",
                                        label: isSaved ? store.t(key: L10n.inspireAlreadySaved) : store.t(key: L10n.inspireSave),
                                        isActive: isSaved,
                                        activeColor: AppTheme.palette[8],
                                        action: {
                                            if showOnline, let q = onlineQuotes.first {
                                                if savedOnlineQuotes.contains(where:{$0.text==q.text}) {
                                                    savedOnlineQuotes.removeAll{$0.text==q.text}
                                                } else {
                                                    savedOnlineQuotes.append(q)
                                                    // Fetch next after save
                                                    DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
                                                        fetchOnlineQuote()
                                                    }
                                                }
                                            } else {
                                                if savedLocalIndices.contains(currentIndex) {
                                                    savedLocalIndices.remove(currentIndex)
                                                } else {
                                                    savedLocalIndices.insert(currentIndex)
                                                    // Advance to next quote after save
                                                    DispatchQueue.main.asyncAfter(deadline:.now()+0.4) {
                                                        nextQuote()
                                                    }
                                                }
                                                refreshPool()
                                            }
                                        }
                                    )

                                    // Next (classic only)
                                    if !showOnline {
                                        GlassActionButton(icon: "arrow.right", action: { nextQuote() })
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                            }
                        }
                    }
                    // Breathing glow on the whole card
                    .breathingGlow(color: AppTheme.dreamGlow, radius: 32)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // ──────────────────────────────────────
                    // MARK: Saved list
                    // ──────────────────────────────────────
                    let allSaved:[Any] = savedOnlineQuotes.map{$0 as Any} + Array(savedLocalIndices).sorted().map{$0 as Any}
                    if !allSaved.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.t(key: L10n.inspireSaved))
                                .font(.system(size: DSTSize.caption, weight: .regular, design:.rounded))
                                .misty(.tertiary)
                                .kerning(2)
                            ForEach(savedOnlineQuotes) { q in
                                savedRow(text: q.text, author: q.author, onTap: {})
                            }
                            ForEach(Array(savedLocalIndices).sorted(), id: \.self) { i in
                                let q = quoteLibrary[i]
                                savedRow(
                                    text: displayTextFor(q),
                                    author: displayAuthorFor(q),
                                    onTap: {
                                        if let pos = dailyPool.firstIndex(of: i) { poolPosition = pos }
                                        else { dailyPool.append(i); poolPosition = dailyPool.count - 1 }
                                        showOnline = false
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 10)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .onAppear { if dailyPool.isEmpty { refreshPool() } }
        }
    }

    // ── Helpers for saved list ───────────────────────────────
    func displayTextFor(_ q: Quote) -> String {
        store.language == .chinese ? q.zh : q.en
    }
    func displayAuthorFor(_ q: Quote) -> String {
        store.language == .chinese ? q.author : q.authorEn
    }

    func savedRow(text: String, author: String, onTap: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundColor(AppTheme.palette[8])
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(text.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: DSTSize.body, weight: .light, design:.rounded))
                    .misty(.secondary)
                    .lineLimit(2)
                Text("— \(author)")
                    .font(.system(size: DSTSize.micro, weight: .ultraLight, design:.rounded))
                    .misty(.tertiary)
                    .tracking(0.8)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AppTheme.bg1)
        .cornerRadius(AppTheme.cornerM)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cornerM).stroke(AppTheme.border0, lineWidth: 0.7))
        .onTapGesture(perform: onTap)
    }

    // ── Network ──────────────────────────────────────────────
    func fetchOnlineQuote() {
        guard !isLoadingOnline else { return }
        isLoadingOnline = true
        onlineError = false

        // Try APIs in sequence: forismatic (very stable) → quotable → zen
        fetchFromAPI(attempt: 0)
    }

    private func fetchFromAPI(attempt: Int) {
        struct APIConfig {
            let url: String
            let parseData: (Data) -> (String, String)?
        }
        let apis: [APIConfig] = [
            // API 1: DummyJSON quotes（稳定、无需 key、全球可访问）
            APIConfig(
                url: "https://dummyjson.com/quotes/random",
                parseData: { data in
                    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                          let q = obj["quote"] as? String,
                          let a = obj["author"] as? String,
                          !q.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return nil }
                    return (q.trimmingCharacters(in:.whitespacesAndNewlines), a)
                }
            ),
            // API 2: Game of Thrones quotes（备用）
            APIConfig(
                url: "https://api.gameofthronesquotes.xyz/v1/random",
                parseData: { data in
                    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                          let sentence = obj["sentence"] as? String,
                          let charObj = obj["character"] as? [String:Any],
                          let name = charObj["name"] as? String else { return nil }
                    return (sentence, name)
                }
            ),
            // API 3: 本地随机（终极兜底，绝不失败）
            APIConfig(
                url: "",
                parseData: { _ in
                    let fallbacks = [
                        ("The only way to do great work is to love what you do.", "Steve Jobs"),
                        ("In the middle of difficulty lies opportunity.", "Albert Einstein"),
                        ("What we achieve inwardly will change outer reality.", "Plutarch"),
                        ("It does not matter how slowly you go as long as you do not stop.", "Confucius"),
                        ("The secret of getting ahead is getting started.", "Mark Twain"),
                        ("Believe you can and you're halfway there.", "Theodore Roosevelt"),
                        ("Act as if what you do makes a difference. It does.", "William James"),
                        ("Hardships often prepare ordinary people for an extraordinary destiny.", "C.S. Lewis"),
                    ]
                    return fallbacks.randomElement()
                }
            ),
        ]
        guard attempt < apis.count else {
            DispatchQueue.main.async { self.isLoadingOnline = false; self.onlineError = true }
            return
        }
        let api = apis[attempt]

        // 最后一个是本地兜底，不走网络
        if api.url.isEmpty {
            if let (q, a) = api.parseData(Data()) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration:0.4)) {
                        self.onlineQuotes = [OnlineQuote(text: q, author: a)]
                        self.showOnline = true; self.onlineError = false; self.isLoadingOnline = false
                    }
                }
            }
            return
        }

        guard let url = URL(string: api.url) else { fetchFromAPI(attempt: attempt + 1); return }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async { self.fetchFromAPI(attempt: attempt + 1) }
                return
            }
            if let (q, a) = api.parseData(data) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration:0.4)) {
                        self.onlineQuotes = [OnlineQuote(text: q, author: a)]
                        self.showOnline = true; self.onlineError = false; self.isLoadingOnline = false
                    }
                }
                return
            }
            DispatchQueue.main.async { self.fetchFromAPI(attempt: attempt + 1) }
        }.resume()
    }
}
