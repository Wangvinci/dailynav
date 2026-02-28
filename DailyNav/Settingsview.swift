import SwiftUI

// ============================================================
// MARK: - Pro 付费墙
// ============================================================

struct ProPaywallSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    @State private var selectedPlan = 1  // 0=月付 1=年付

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color(red:1,green:0.85,blue:0.3).opacity(0.15)).frame(width:80,height:80)
                            Image(systemName:"crown.fill").font(.system(size:36)).foregroundColor(Color(red:1,green:0.85,blue:0.3))
                        }.padding(.top, 24)
                        Text("DailyNav Pro").font(.title).fontWeight(.bold).foregroundColor(AppTheme.textPrimary)
                        Text(store.t("解锁全部功能，成为更好的自己","Unlock everything. Become your best self."))
                            .font(.subheadline).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
                    }

                    // 功能对比
                    VStack(spacing: 0) {
                        ProFeatureRow(icon:"chart.bar.fill",   color:AppTheme.accent,      text:store.t("月度/年度数据分析","Monthly & yearly analytics"))
                        ProFeatureRow(icon:"sparkles",          color:Color(red:0.7,green:0.5,blue:1), text:store.t("AI智能周/月/年总结","AI weekly, monthly & yearly summary"))
                        ProFeatureRow(icon:"book.fill",         color:Color(red:1,green:0.85,blue:0.3), text:store.t("今日心得 + 历史回顾","Daily journal + history"))
                        ProFeatureRow(icon:"quote.bubble.fill", color:Color(red:0.9,green:0.4,blue:0.6), text:store.t("灵感语录无限解锁","Unlimited inspiration quotes"))
                        ProFeatureRow(icon:"square.and.arrow.up", color:.teal, text:store.t("分享目标成就卡片","Share goal achievement cards"))
                        ProFeatureRow(icon:"target",            color:AppTheme.accent,      text:store.t("无限目标（免费版最多3个）","Unlimited goals (free: 3 max)"), isLast:true)
                    }
                    .background(AppTheme.bg1).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0,lineWidth:1))
                    .padding(.horizontal)

                    // 方案选择
                    VStack(spacing: 10) {
                        PlanOption(
                            isSelected: selectedPlan==1,
                            badge: store.t("最划算","Best Value"),
                            title: store.t("年付订阅","Annual"),
                            price: store.t("¥98 / 年","$14.99 / year"),
                            sub: store.t("相当于 ¥8.2/月，省 37%","= $1.25/mo · Save 37%"),
                            onTap: { selectedPlan=1 }
                        )
                        PlanOption(
                            isSelected: selectedPlan==0,
                            badge: nil,
                            title: store.t("月付订阅","Monthly"),
                            price: store.t("¥14 / 月","$1.99 / month"),
                            sub: store.t("随时可取消","Cancel anytime"),
                            onTap: { selectedPlan=0 }
                        )
                    }.padding(.horizontal)

                    // 订阅按钮
                    Button(action: {
                        pro.isPro = true
                        dismiss()
                    }) {
                        Text(store.t("开始 7 天免费试用","Start 7-Day Free Trial"))
                            .font(.headline).fontWeight(.bold)
                            .frame(maxWidth:.infinity).padding(.vertical,16)
                            .background(LinearGradient(colors:[Color(red:1,green:0.85,blue:0.3),Color(red:1,green:0.6,blue:0.2)],startPoint:.leading,endPoint:.trailing))
                            .cornerRadius(16).foregroundColor(Color(red:0.1,green:0.05,blue:0.0))
                    }.padding(.horizontal)

                    Text(store.t("试用后自动续费，随时可在设置中取消","Auto-renews after trial. Cancel anytime in Settings."))
                        .font(.caption2).foregroundColor(AppTheme.textTertiary).multilineTextAlignment(.center).padding(.horizontal)

                    Spacer(minLength:20)
                }
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(store.t("关闭","Close")) { dismiss() }.foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}

struct ProFeatureRow: View {
    let icon:String; let color:Color; let text:String; var isLast:Bool=false
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:12) {
                Image(systemName:icon).foregroundColor(color).frame(width:20).padding(8)
                    .background(color.opacity(0.12)).cornerRadius(8)
                Text(text).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Image(systemName:"checkmark.circle.fill").foregroundColor(color).font(.body)
            }.padding(.horizontal,16).padding(.vertical,12)
            if !isLast { Divider().background(AppTheme.border0).padding(.leading,52) }
        }
    }
}

struct PlanOption: View {
    let isSelected:Bool; let badge:String?; let title:String; let price:String; let sub:String; let onTap:()->Void
    var body: some View {
        Button(action:onTap) {
            HStack {
                VStack(alignment:.leading, spacing:3) {
                    HStack(spacing:8) {
                        Text(title).font(.subheadline).fontWeight(.medium).foregroundColor(AppTheme.textPrimary)
                        if let b=badge {
                            Text(b).font(.caption2).padding(.horizontal,7).padding(.vertical,3)
                                .background(Color(red:1,green:0.85,blue:0.3).opacity(0.2))
                                .foregroundColor(Color(red:1,green:0.85,blue:0.3)).cornerRadius(5)
                        }
                    }
                    Text(sub).font(.caption2).foregroundColor(AppTheme.textTertiary)
                }
                Spacer()
                Text(price).font(.headline).fontWeight(.semibold).foregroundColor(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                Image(systemName:isSelected ? "checkmark.circle.fill":"circle")
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textTertiary).padding(.leading,8)
            }
            .padding(16).background(isSelected ? AppTheme.accentSoft : AppTheme.bg2).cornerRadius(13)
            .overlay(RoundedRectangle(cornerRadius:13).stroke(isSelected ? AppTheme.accent.opacity(0.4):AppTheme.border0,lineWidth:1.5))
        }
    }
}

// ── Pro锁定组件 ──────────────────────────────────────────

struct ProLockedOverlay: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let message: String
    var body: some View {
        VStack(spacing:12) {
            Image(systemName:"crown.fill").font(.title2).foregroundColor(Color(red:1,green:0.85,blue:0.3))
            Text(message).font(.subheadline).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
            Button(action:{ pro.showPaywall=true }) {
                Text(store.t("升级 Pro 解锁","Upgrade to Pro"))
                    .font(.caption).fontWeight(.semibold)
                    .padding(.horizontal,20).padding(.vertical,9)
                    .background(Color(red:1,green:0.85,blue:0.3).opacity(0.15))
                    .foregroundColor(Color(red:1,green:0.85,blue:0.3)).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius:20).stroke(Color(red:1,green:0.85,blue:0.3).opacity(0.3),lineWidth:1))
            }
        }
        .frame(maxWidth:.infinity).padding(.vertical,32)
        .background(AppTheme.bg1).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius:16).stroke(AppTheme.border0,lineWidth:1))
    }
}

// ============================================================
// MARK: - 分享卡片
// ============================================================

struct ShareGoalCard: View {
    let goal: Goal
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment:.leading, spacing:16) {
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text("DailyNav").font(.caption2).foregroundColor(goal.color).kerning(2)
                    Text(goal.title).font(.title3).fontWeight(.semibold).foregroundColor(.white)
                    Text(goal.category.uppercased()).font(.caption2).foregroundColor(.white.opacity(0.5)).kerning(1.5)
                }
                Spacer()
                ZStack {
                    Circle().stroke(goal.color.opacity(0.3),lineWidth:3).frame(width:56,height:56)
                    Circle().trim(from:0,to:goal.progress)
                        .stroke(goal.color,style:StrokeStyle(lineWidth:3,lineCap:.round))
                        .frame(width:56,height:56).rotationEffect(.degrees(-90))
                    Text("\(Int(goal.progress*100))%").font(.system(size:12,weight:.bold)).foregroundColor(goal.color)
                }
            }
            // 任务列表
            VStack(spacing:5) {
                ForEach(goal.tasks.prefix(4)) { task in
                    HStack(spacing:8) {
                        Image(systemName:task.isCompleted ? "checkmark.circle.fill":"circle")
                            .font(.caption).foregroundColor(task.isCompleted ? goal.color:.white.opacity(0.3))
                        Text(task.title).font(.caption).foregroundColor(task.isCompleted ? .white.opacity(0.9):.white.opacity(0.5))
                            .strikethrough(task.isCompleted)
                        Spacer()
                    }
                }
            }
            // 底部标签
            HStack {
                if goal.goalType == .longterm {
                    HStack(spacing:4){Image(systemName:"flame").font(.caption2);Text(store.t("坚持 \(goal.daysSinceStart) 天","\(goal.daysSinceStart) day streak")).font(.caption2)}.foregroundColor(goal.color)
                } else {
                    HStack(spacing:4){Image(systemName:"clock").font(.caption2);Text(store.t("还有 \(goal.daysLeft) 天","\(goal.daysLeft) days left")).font(.caption2)}.foregroundColor(goal.color)
                }
                Spacer()
                Text(formatDate(Date(),format:"yyyy.M.d")).font(.caption2).foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(20)
        .background(LinearGradient(colors:[Color(red:0.1,green:0.1,blue:0.15),goal.color.opacity(0.2)],startPoint:.topLeading,endPoint:.bottomTrailing))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius:20).stroke(goal.color.opacity(0.3),lineWidth:1))
        .frame(width:300)
    }
}

struct ShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var pro: ProStore
    let goal: Goal

    var body: some View {
        NavigationView {
            VStack(spacing:24) {
                Text(store.t("分享目标卡片","Share Goal Card")).font(.headline).foregroundColor(AppTheme.textPrimary).padding(.top,20)

                ShareGoalCard(goal:goal)

                VStack(spacing:12) {
                    ShareRow(icon:"message.fill", color:.green, label:store.t("发送给朋友","Send to a Friend"), action:{ dismiss() })
                    ShareRow(icon:"photo.fill",   color:Color(red:0.5,green:0.7,blue:1), label:store.t("保存到相册","Save to Photos"), action:{ dismiss() })
                    ShareRow(icon:"square.and.arrow.up", color:AppTheme.accent, label:store.t("更多分享方式","More Options"), action:{ dismiss() })
                }
                .background(AppTheme.bg1).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius:14).stroke(AppTheme.border0,lineWidth:1))
                .padding(.horizontal)

                Spacer()
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button(store.t("关闭","Close")) { dismiss() }.foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }
}

struct ShareRow: View {
    let icon:String; let color:Color; let label:String; let action:()->Void
    var body: some View {
        VStack(spacing:0) {
            Button(action:action) {
                HStack(spacing:12) {
                    Image(systemName:icon).foregroundColor(color).frame(width:20).padding(8).background(color.opacity(0.12)).cornerRadius(8)
                    Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName:"chevron.right").font(.caption2).foregroundColor(AppTheme.textTertiary)
                }.padding(.horizontal,16).padding(.vertical,12)
            }
            Divider().background(AppTheme.border0).padding(.leading,52)
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

                    // ── Pro 横幅 ─────────────────────────────────
                    if pro.isPro {
                        // 已订阅：简洁徽章
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.gold.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.gold)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DailyNav Pro")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(store.t("已激活订阅", "Active subscription"))
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button(action: { pro.isPro = false }) {
                                Text(store.t("取消", "Cancel"))
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textTertiary)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(AppTheme.bg2)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border0, lineWidth: 0.8))
                            }
                        }
                        .padding(16)
                        .background(AppTheme.bg1)
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.gold.opacity(0.18), lineWidth: 0.8))

                    } else {
                        // 升级入口：克制但吸引
                        Button(action: { pro.showPaywall = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.gold.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.gold)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.t("升级到 Pro", "Upgrade to Pro"))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text(store.t("7 天免费体验", "7-day free trial"))
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                            .background(AppTheme.bg1)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(AppTheme.gold.opacity(0.22), lineWidth: 0.8)
                            )
                        }
                    }

                    // ── 语言选择 ─────────────────────────────────
                    SettingsSection(title: store.t("语言", "Language")) {
                        VStack(spacing: 0) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                LanguageRow(
                                    lang: lang,
                                    isSelected: store.language == lang,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            store.language = lang
                                        }
                                    }
                                )
                                if lang != AppLanguage.allCases.last {
                                    Divider()
                                        .background(AppTheme.border0)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(AppTheme.bg1)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    // ── 操作列表 ─────────────────────────────────
                    SettingsSection(title: store.t("支持", "Support")) {
                        VStack(spacing: 0) {
                            SRow2(icon: "star", label: store.t("给我们评分", "Rate This App"), action: {})
                            SRowDivider()
                            SRow2(icon: "envelope", label: store.t("联系我们", "Contact Us"), action: {})
                            SRowDivider()
                            SRow2(icon: "doc.text", label: store.t("隐私政策", "Privacy Policy"), action: {})
                            SRowDivider()
                            SRow2(icon: "info.circle", label: "Version 1.0.0", action: nil)
                        }
                        .background(AppTheme.bg1)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    // ── Coming Soon ──────────────────────────────
                    SettingsSection(title: store.t("即将推出", "Coming Soon")) {
                        VStack(spacing: 0) {
                            ComingSoonRow(icon: "icloud", label: store.t("云端同步", "Cloud Sync"))
                            SRowDivider()
                            ComingSoonRow(icon: "sparkles", label: store.t("AI 智能规划", "AI Task Planning"))
                            SRowDivider()
                            ComingSoonRow(icon: "timer", label: store.t("专注模式", "Focus Mode"))
                            SRowDivider()
                            ComingSoonRow(icon: "rectangle.on.rectangle", label: store.t("桌面小组件", "Home Widget"))
                            SRowDivider()
                            ComingSoonRow(icon: "square.and.arrow.up", label: store.t("数据导出", "Export Data"))
                        }
                        .background(AppTheme.bg1)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border0, lineWidth: 0.8))
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(AppTheme.bg0.ignoresSafeArea())
            .navigationTitle(store.t("设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.t("完成", "Done")) { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
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
    
    var langDisplayFull: String {
        switch lang {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
    
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
        Divider()
            .background(AppTheme.border0)
            .padding(.leading, 16)
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
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textTertiary)
            Spacer()
            Text("Soon")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary.opacity(0.5))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(AppTheme.bg2)
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SRow: View {
    let icon:String;let color:Color;let label:String;let action:(()->Void)?
    var body: some View {
        VStack(spacing:0) {
            Button(action:action ?? {}){
                HStack(spacing:12){
                    Image(systemName:icon).foregroundColor(color).frame(width:20).padding(8).background(color.opacity(0.12)).cornerRadius(8)
                    Text(label).font(.subheadline).foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if action != nil { Image(systemName:"chevron.right").font(.caption2).foregroundColor(AppTheme.textTertiary) }
                }.padding(.horizontal,16).padding(.vertical,13)
            }.disabled(action==nil)
            Divider().background(AppTheme.border0).padding(.leading,56)
        }
    }
}

struct GPTextField: View {
    let placeholder:String;@Binding var text:String
    var keyboardType:UIKeyboardType = .default;var isSecure:Bool=false
    var body: some View {
        Group {
            if isSecure { SecureField(placeholder,text:$text) }
            else { TextField(placeholder,text:$text).keyboardType(keyboardType).autocapitalization(.none) }
        }
        .textFieldStyle(.plain).padding(13).background(AppTheme.bg2).cornerRadius(12)
        .foregroundColor(AppTheme.textPrimary)
        .overlay(RoundedRectangle(cornerRadius:12).stroke(AppTheme.border1,lineWidth:1))
    }
}
