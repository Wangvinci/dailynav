import Foundation

// ============================================================
// MARK: - AppLanguage  (extended to 5 languages)
// ============================================================
// To add a 6th language:
//   1. Add case here  e.g.  case french = "fr"
//   2. Add displayName, locale, aiInstruction
//   3. Add the new key to every switch in L10n + SuggestionProvider
// ============================================================

enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case chinese  = "zh"
    case english  = "en"
    case japanese = "ja"
    case korean   = "ko"
    case spanish  = "es"

    /// Display name shown in Settings  (native script only, no flags)
    nonisolated var displayName: String {
        switch self {
        case .chinese:  return "中文"
        case .english:  return "English"
        case .japanese: return "日本語"
        case .korean:   return "한국어"
        case .spanish:  return "Español"
        }
    }

    /// Apple locale identifier for DateFormatter / Calendar
    nonisolated var localeIdentifier: String {
        switch self {
        case .chinese:  return "zh_CN"
        case .english:  return "en_US"
        case .japanese: return "ja_JP"
        case .korean:   return "ko_KR"
        case .spanish:  return "es_ES"
        }
    }

    /// Instruction injected into every AI prompt so the model responds in this language
    nonisolated var aiInstruction: String {
        switch self {
        case .chinese:  return "请全程用简体中文回答，不要混入其他语言。"
        case .english:  return "Respond entirely in English. Do not use any other language."
        case .japanese: return "すべて日本語で回答してください。他の言語を混入しないでください。"
        case .korean:   return "모든 내용을 한국어로 답변해 주세요. 다른 언어를 섞지 마세요."
        case .spanish:  return "Responde completamente en español. No mezcles otros idiomas."
        }
    }

    /// Short tag printed to console for debugging
    nonisolated var debugTag: String { rawValue.uppercased() }
}

// ============================================================
// MARK: - L10n  (Localisation dictionary — single source of truth)
// All UI strings live here.  Access via  L10n.key(lang)
// or via AppStore.t(key:)
//
// HOW TO ADD A STRING:
//   1. Add a static func returning [AppLanguage: String]
//   2. Call  store.t(key: .yourKey)  from views
//
// HOW TO ADD A LANGUAGE:
//   Add a case to every switch below (or it won't compile).
// ============================================================
enum L10n {
    // ── Core navigation ──────────────────────────────────────
    nonisolated static func goals(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "目标"
        case .english:  return "Goals"
        case .japanese: return "目標"
        case .korean:   return "목표"
        case .spanish:  return "Metas"
        }
    }
    nonisolated static func plan(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "计划"
        case .english:  return "Plan"
        case .japanese: return "計画"
        case .korean:   return "계획"
        case .spanish:  return "Plan"
        }
    }
    nonisolated static func myPage(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "我的"
        case .english:  return "Me"
        case .japanese: return "マイページ"
        case .korean:   return "나의"
        case .spanish:  return "Yo"
        }
    }
    nonisolated static func inspire(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "灵感"
        case .english:  return "Inspire"
        case .japanese: return "インスピレーション"
        case .korean:   return "영감"
        case .spanish:  return "Inspirar"
        }
    }

    // ── Settings ─────────────────────────────────────────────
    nonisolated static func settings(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "设置"
        case .english:  return "Settings"
        case .japanese: return "設定"
        case .korean:   return "설정"
        case .spanish:  return "Ajustes"
        }
    }
    nonisolated static func language(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "语言"
        case .english:  return "Language"
        case .japanese: return "言語"
        case .korean:   return "언어"
        case .spanish:  return "Idioma"
        }
    }
    nonisolated static func done(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "完成"
        case .english:  return "Done"
        case .japanese: return "完了"
        case .korean:   return "완료"
        case .spanish:  return "Listo"
        }
    }
    nonisolated static func cancel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "取消"
        case .english:  return "Cancel"
        case .japanese: return "キャンセル"
        case .korean:   return "취소"
        case .spanish:  return "Cancelar"
        }
    }
    nonisolated static func confirm(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "确认"
        case .english:  return "Confirm"
        case .japanese: return "確認"
        case .korean:   return "확인"
        case .spanish:  return "Confirmar"
        }
    }
    nonisolated static func save(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "保存"
        case .english:  return "Save"
        case .japanese: return "保存"
        case .korean:   return "저장"
        case .spanish:  return "Guardar"
        }
    }
    nonisolated static func delete(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "删除"
        case .english:  return "Delete"
        case .japanese: return "削除"
        case .korean:   return "삭제"
        case .spanish:  return "Eliminar"
        }
    }
    nonisolated static func close(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "关闭"
        case .english:  return "Close"
        case .japanese: return "閉じる"
        case .korean:   return "닫기"
        case .spanish:  return "Cerrar"
        }
    }

    // ── Goal page ─────────────────────────────────────────────
    nonisolated static func addGoal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "添加目标"
        case .english:  return "Add Goal"
        case .japanese: return "目標を追加"
        case .korean:   return "목표 추가"
        case .spanish:  return "Añadir meta"
        }
    }
    nonisolated static func goalTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "目标名称"
        case .english:  return "Goal Title"
        case .japanese: return "目標名"
        case .korean:   return "목표 이름"
        case .spanish:  return "Nombre de la meta"
        }
    }
    nonisolated static func goalTitlePlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "例如：每天健身、读完10本书"
        case .english:  return "e.g. Daily workout, Read 10 books"
        case .japanese: return "例：毎日運動、10冊読む"
        case .korean:   return "예: 매일 운동, 책 10권 읽기"
        case .spanish:  return "ej. Ejercicio diario, Leer 10 libros"
        }
    }
    nonisolated static func category(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "分类"
        case .english:  return "Category"
        case .japanese: return "カテゴリ"
        case .korean:   return "카테고리"
        case .spanish:  return "Categoría"
        }
    }
    nonisolated static func longterm(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "长期"
        case .english:  return "Long-term"
        case .japanese: return "長期"
        case .korean:   return "장기"
        case .spanish:  return "Largo plazo"
        }
    }
    nonisolated static func deadline(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "截止日"
        case .english:  return "Deadline"
        case .japanese: return "期限"
        case .korean:   return "마감일"
        case .spanish:  return "Fecha límite"
        }
    }
    nonisolated static func addTask(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "添加任务"
        case .english:  return "Add Task"
        case .japanese: return "タスクを追加"
        case .korean:   return "할 일 추가"
        case .spanish:  return "Añadir tarea"
        }
    }
    nonisolated static func taskNamePlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "任务名称"
        case .english:  return "Task name"
        case .japanese: return "タスク名"
        case .korean:   return "할 일 이름"
        case .spanish:  return "Nombre de la tarea"
        }
    }
    nonisolated static func noGoalsYet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "还没有目标，点击 + 开始"
        case .english:  return "No goals yet — tap + to start"
        case .japanese: return "目標なし — + をタップして始めましょう"
        case .korean:   return "아직 목표 없음 — +를 눌러 시작하세요"
        case .spanish:  return "Sin metas aún — toca + para empezar"
        }
    }
    nonisolated static func dragToDate(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "拖到日期可设为截止日"
        case .english:  return "Drag to a date to set deadline"
        case .japanese: return "日付にドラッグして期限を設定"
        case .korean:   return "날짜로 드래그하여 마감일 설정"
        case .spanish:  return "Arrastra a una fecha para definir el plazo"
        }
    }
    nonisolated static func sort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "排序"
        case .english:  return "Sort"
        case .japanese: return "並び替え"
        case .korean:   return "정렬"
        case .spanish:  return "Ordenar"
        }
    }

    // ── Plan page ─────────────────────────────────────────────
    nonisolated static func aiTips(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "AI 建议"
        case .english:  return "AI Tips"
        case .japanese: return "AI のヒント"
        case .korean:   return "AI 제안"
        case .spanish:  return "Sugerencias AI"
        }
    }
    nonisolated static func doubleTapEdit(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "双击编辑/删除 · 长按拖入周几"
        case .english:  return "Double-tap edit/delete · drag to a day"
        case .japanese: return "ダブルタップで編集/削除 · 長押しで曜日に移動"
        case .korean:   return "더블탭 편집/삭제 · 길게 눌러 요일에 드래그"
        case .spanish:  return "Doble toque editar/borrar · arrastra al día"
        }
    }

    // ── Today / Journal ──────────────────────────────────────
    nonisolated static func todayFeeling(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "今日感觉"
        case .english:  return "Today's Mood"
        case .japanese: return "今日の気分"
        case .korean:   return "오늘 기분"
        case .spanish:  return "Estado de hoy"
        }
    }
    nonisolated static func journalGainsPlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "今天有什么收获？（可写关键词）"
        case .english:  return "What did you gain today? (keywords OK)"
        case .japanese: return "今日の収穫は？（キーワードでOK）"
        case .korean:   return "오늘 얻은 것은? (키워드 가능)"
        case .spanish:  return "¿Qué ganaste hoy? (palabras clave OK)"
        }
    }
    nonisolated static func journalChallengesPlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "遇到什么困难？（可写关键词）"
        case .english:  return "Any challenges? (keywords OK)"
        case .japanese: return "困ったことは？（キーワードでOK）"
        case .korean:   return "어떤 어려움이 있었나요? (키워드 가능)"
        case .spanish:  return "¿Algún reto? (palabras clave OK)"
        }
    }
    nonisolated static func journalTomorrowPlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "明天的重点是？"
        case .english:  return "Tomorrow's focus?"
        case .japanese: return "明日のフォーカスは？"
        case .korean:   return "내일의 집중 포인트는?"
        case .spanish:  return "¿Enfoque para mañana?"
        }
    }
    nonisolated static func submitJournal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "提交"
        case .english:  return "Submit"
        case .japanese: return "提出"
        case .korean:   return "제출"
        case .spanish:  return "Enviar"
        }
    }
    nonisolated static func editJournal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "编辑"
        case .english:  return "Edit"
        case .japanese: return "編集"
        case .korean:   return "편집"
        case .spanish:  return "Editar"
        }
    }

    // ── My page / Stats ──────────────────────────────────────
    nonisolated static func thisWeek(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本周"
        case .english:  return "This Week"
        case .japanese: return "今週"
        case .korean:   return "이번 주"
        case .spanish:  return "Esta semana"
        }
    }
    nonisolated static func thisMonth(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本月"
        case .english:  return "This Month"
        case .japanese: return "今月"
        case .korean:   return "이번 달"
        case .spanish:  return "Este mes"
        }
    }
    nonisolated static func thisYear(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本年"
        case .english:  return "This Year"
        case .japanese: return "今年"
        case .korean:   return "올해"
        case .spanish:  return "Este año"
        }
    }
    nonisolated static func completionRate(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "完成率"
        case .english:  return "Completion"
        case .japanese: return "完了率"
        case .korean:   return "완료율"
        case .spanish:  return "Cumplimiento"
        }
    }
    nonisolated static func wins(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "成就"
        case .english:  return "Wins"
        case .japanese: return "成果"
        case .korean:   return "성과"
        case .spanish:  return "Logros"
        }
    }
    nonisolated static func pending(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "待决"
        case .english:  return "Pending"
        case .japanese: return "保留中"
        case .korean:   return "보류"
        case .spanish:  return "Pendiente"
        }
    }
    nonisolated static func resolved(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "已解决"
        case .english:  return "Resolved"
        case .japanese: return "解決済み"
        case .korean:   return "해결됨"
        case .spanish:  return "Resuelto"
        }
    }
    nonisolated static func activeDays(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "活跃天"
        case .english:  return "Active"
        case .japanese: return "活動日"
        case .korean:   return "활동일"
        case .spanish:  return "Días activos"
        }
    }
    nonisolated static func tasks(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "任务"
        case .english:  return "Tasks"
        case .japanese: return "タスク"
        case .korean:   return "할 일"
        case .spanish:  return "Tareas"
        }
    }
    nonisolated static func plans(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "计划"
        case .english:  return "Plans"
        case .japanese: return "プラン"
        case .korean:   return "계획"
        case .spanish:  return "Planes"
        }
    }
    nonisolated static func smartInsight(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "智能洞察"
        case .english:  return "Smart Insight"
        case .japanese: return "スマートインサイト"
        case .korean:   return "스마트 인사이트"
        case .spanish:  return "Perspectiva inteligente"
        }
    }
    nonisolated static func doubleTabExpand(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "双击展开"
        case .english:  return "Double-tap"
        case .japanese: return "ダブルタップ"
        case .korean:   return "더블탭"
        case .spanish:  return "Doble toque"
        }
    }

    // ── Pro / Paywall ─────────────────────────────────────────
    nonisolated static func upgradePro(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "升级到 Pro"
        case .english:  return "Upgrade to Pro"
        case .japanese: return "Proにアップグレード"
        case .korean:   return "Pro로 업그레이드"
        case .spanish:  return "Actualizar a Pro"
        }
    }
    nonisolated static func sevenDayTrial(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "7 天免费体验"
        case .english:  return "7-day free trial"
        case .japanese: return "7日間無料トライアル"
        case .korean:   return "7일 무료 체험"
        case .spanish:  return "7 días gratis"
        }
    }
    nonisolated static func activeSubscription(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "已激活订阅"
        case .english:  return "Active subscription"
        case .japanese: return "サブスクリプション有効"
        case .korean:   return "구독 활성화됨"
        case .spanish:  return "Suscripción activa"
        }
    }

    // ── Mood labels ─────────────────────────────────────────
    nonisolated static func moodLabels(_ l: AppLanguage) -> [String] {
        switch l {
        case .chinese:  return ["低落", "平静", "还好", "愉悦", "极好"]
        case .english:  return ["Low", "Calm", "Okay", "Good", "Great"]
        case .japanese: return ["落ち込む", "穏やか", "まあまあ", "良い", "最高"]
        case .korean:   return ["낮음", "차분", "보통", "좋음", "최고"]
        case .spanish:  return ["Bajo", "Calmado", "Regular", "Bien", "Genial"]
        }
    }

    // ── Coming soon ──────────────────────────────────────────
    nonisolated static func comingSoon(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "即将推出"
        case .english:  return "Coming Soon"
        case .japanese: return "近日公開"
        case .korean:   return "곧 출시"
        case .spanish:  return "Próximamente"
        }
    }
    nonisolated static func cloudSync(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "云端同步"
        case .english:  return "Cloud Sync"
        case .japanese: return "クラウド同期"
        case .korean:   return "클라우드 동기화"
        case .spanish:  return "Sincronización en la nube"
        }
    }
    nonisolated static func aiPlanning(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "AI 智能规划"
        case .english:  return "AI Task Planning"
        case .japanese: return "AI タスクプランニング"
        case .korean:   return "AI 작업 계획"
        case .spanish:  return "Planificación AI"
        }
    }
    nonisolated static func focusMode(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "专注模式"
        case .english:  return "Focus Mode"
        case .japanese: return "フォーカスモード"
        case .korean:   return "집중 모드"
        case .spanish:  return "Modo enfoque"
        }
    }
    nonisolated static func homeWidget(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "桌面小组件"
        case .english:  return "Home Widget"
        case .japanese: return "ホームウィジェット"
        case .korean:   return "홈 위젯"
        case .spanish:  return "Widget de inicio"
        }
    }
    nonisolated static func exportData(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "数据导出"
        case .english:  return "Export Data"
        case .japanese: return "データエクスポート"
        case .korean:   return "데이터 내보내기"
        case .spanish:  return "Exportar datos"
        }
    }
    nonisolated static func support(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "支持"
        case .english:  return "Support"
        case .japanese: return "サポート"
        case .korean:   return "지원"
        case .spanish:  return "Soporte"
        }
    }
    nonisolated static func rateUs(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "给我们评分"
        case .english:  return "Rate This App"
        case .japanese: return "アプリを評価する"
        case .korean:   return "앱 평가하기"
        case .spanish:  return "Valorar la app"
        }
    }
    nonisolated static func contactUs(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "联系我们"
        case .english:  return "Contact Us"
        case .japanese: return "お問い合わせ"
        case .korean:   return "문의하기"
        case .spanish:  return "Contáctanos"
        }
    }
    nonisolated static func privacyPolicy(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "隐私政策"
        case .english:  return "Privacy Policy"
        case .japanese: return "プライバシーポリシー"
        case .korean:   return "개인정보 처리방침"
        case .spanish:  return "Política de privacidad"
        }
    }

    // ── Date / Time labels ──────────────────────────────────
    nonisolated static func weekdayShort(_ l: AppLanguage) -> [String] {
        switch l {
        case .chinese:  return ["日","一","二","三","四","五","六"]
        case .english:  return ["Su","Mo","Tu","We","Th","Fr","Sa"]
        case .japanese: return ["日","月","火","水","木","金","土"]
        case .korean:   return ["일","월","화","수","목","금","토"]
        case .spanish:  return ["Do","Lu","Ma","Mi","Ju","Vi","Sá"]
        }
    }
    nonisolated static func weekdayFull(_ l: AppLanguage) -> [String] {
        switch l {
        case .chinese:  return ["周日","周一","周二","周三","周四","周五","周六"]
        case .english:  return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        case .japanese: return ["日曜","月曜","火曜","水曜","木曜","金曜","土曜"]
        case .korean:   return ["일요일","월요일","화요일","수요일","목요일","금요일","토요일"]
        case .spanish:  return ["Dom","Lun","Mar","Mié","Jue","Vie","Sáb"]
        }
    }

    // ── Misc UI ──────────────────────────────────────────────
    nonisolated static func noRecordsYet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "🌙 尚无记录"
        case .english:  return "🌙 No records yet"
        case .japanese: return "🌙 まだ記録なし"
        case .korean:   return "🌙 아직 기록 없음"
        case .spanish:  return "🌙 Sin registros aún"
        }
    }
    nonisolated static func gainLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "收获"
        case .english:  return "Wins"
        case .japanese: return "収穫"
        case .korean:   return "성과"
        case .spanish:  return "Logros"
        }
    }
    nonisolated static func challengeLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "待决"
        case .english:  return "Challenges"
        case .japanese: return "課題"
        case .korean:   return "도전"
        case .spanish:  return "Retos"
        }
    }
    nonisolated static func tomorrowLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "明日"
        case .english:  return "Tomorrow"
        case .japanese: return "明日"
        case .korean:   return "내일"
        case .spanish:  return "Mañana"
        }
    }
    // ── Summary sheet titles ─────────────────────────────────
    nonisolated static func dailySummaryTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "今日智能总结"
        case .english:  return "Today's Summary"
        case .japanese: return "本日のまとめ"
        case .korean:   return "오늘의 요약"
        case .spanish:  return "Resumen de hoy"
        }
    }
    nonisolated static func weeklySummaryTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本周智能总结"
        case .english:  return "Weekly Summary"
        case .japanese: return "週間まとめ"
        case .korean:   return "이번 주 요약"
        case .spanish:  return "Resumen semanal"
        }
    }
    nonisolated static func monthlySummaryTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本月智能总结"
        case .english:  return "Monthly Summary"
        case .japanese: return "月間まとめ"
        case .korean:   return "이번 달 요약"
        case .spanish:  return "Resumen mensual"
        }
    }
    nonisolated static func yearlySummaryTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "年度智能总结"
        case .english:  return "Annual Summary"
        case .japanese: return "年間まとめ"
        case .korean:   return "연간 요약"
        case .spanish:  return "Resumen anual"
        }
    }

}

// AppStore t(key:) and logCurrentLocale() are defined in DailyNavData.swift


// ============================================================
// MARK: - SuggestionProvider  (language-correct defaults)
// ============================================================
/// All default/seed content lives here — never hard-coded in views.
/// To extend a language: add the translation to each function below.
struct SuggestionProvider {

    // ── Default seed goals (used by initDefaultGoals) ────────
    struct DefaultGoal {
        let title: String
        let category: String
        let tasks: [String]
    }

    nonisolated static func defaultGoals(_ l: AppLanguage) -> [DefaultGoal] {
        switch l {
        case .chinese:
            return [
                DefaultGoal(title:"每天健身", category:"健康",
                            tasks:["早晨跑步","核心训练","拉伸放松"]),
                DefaultGoal(title:"读完10本书", category:"学习",
                            tasks:["每日阅读30分","写读书笔记"]),
                DefaultGoal(title:"学会基础西班牙语", category:"技能",
                            tasks:["Duolingo 15分","听西语播客"]),
            ]
        case .english:
            return [
                DefaultGoal(title:"Daily Workout", category:"Health",
                            tasks:["Morning Run","Core Training","Cool-down Stretch"]),
                DefaultGoal(title:"Read 10 Books", category:"Learning",
                            tasks:["Read 30min","Write Book Notes"]),
                DefaultGoal(title:"Learn Basic Spanish", category:"Skills",
                            tasks:["Duolingo 15min","Spanish Podcast"]),
            ]
        case .japanese:
            return [
                DefaultGoal(title:"毎日運動する", category:"健康",
                            tasks:["朝のランニング","体幹トレーニング","ストレッチ"]),
                DefaultGoal(title:"10冊の本を読む", category:"学習",
                            tasks:["30分読書","読書ノートを書く"]),
                DefaultGoal(title:"基礎英語を習得", category:"スキル",
                            tasks:["Duolingo 15分","英語ポッドキャスト"]),
            ]
        case .korean:
            return [
                DefaultGoal(title:"매일 운동하기", category:"건강",
                            tasks:["아침 달리기","코어 트레이닝","스트레칭"]),
                DefaultGoal(title:"책 10권 읽기", category:"학습",
                            tasks:["30분 독서","독서 노트 작성"]),
                DefaultGoal(title:"기초 영어 배우기", category:"기술",
                            tasks:["Duolingo 15분","영어 팟캐스트"]),
            ]
        case .spanish:
            return [
                DefaultGoal(title:"Ejercicio diario", category:"Salud",
                            tasks:["Carrera matutina","Entrenamiento core","Estiramiento"]),
                DefaultGoal(title:"Leer 10 libros", category:"Aprendizaje",
                            tasks:["Leer 30 min","Tomar notas"]),
                DefaultGoal(title:"Aprender inglés básico", category:"Habilidades",
                            tasks:["Duolingo 15min","Podcast en inglés"]),
            ]
        }
    }

    // ── Default category suggestions ─────────────────────────
    nonisolated static func categoryOptions(_ l: AppLanguage) -> [String] {
        switch l {
        case .chinese:  return ["健康","学习","技能","工作","生活","创作","人际","财务"]
        case .english:  return ["Health","Learning","Skills","Work","Life","Creative","Social","Finance"]
        case .japanese: return ["健康","学習","スキル","仕事","生活","創造","人間関係","財務"]
        case .korean:   return ["건강","학습","기술","업무","생활","창의","인간관계","재정"]
        case .spanish:  return ["Salud","Aprendizaje","Habilidades","Trabajo","Vida","Creativo","Social","Finanzas"]
        }
    }

    // ── Fallback task suggestions when no keyword match ──────
    nonisolated static func fallbackTaskSuggestions(_ l: AppLanguage) -> [String] {
        switch l {
        case .chinese:  return ["记录今日进展","明确今日优先级","专注25分钟","回顾目标动力","写今天的收获"]
        case .english:  return ["Log today's progress","Set today's priority","Focus 25 minutes","Review your motivation","Write today's takeaway"]
        case .japanese: return ["今日の進捗を記録","今日の優先事項を決める","25分集中","モチベーション確認","今日の収穫を書く"]
        case .korean:   return ["오늘 진행상황 기록","오늘 우선순위 설정","25분 집중","동기 확인","오늘의 수확 기록"]
        case .spanish:  return ["Registrar progreso","Fijar prioridad de hoy","Enfocarse 25 min","Revisar motivación","Escribir logro de hoy"]
        }
    }

    // ── Inspire page placeholder quotes ─────────────────────
    nonisolated static func inspirePlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "点击获取今日灵感"
        case .english:  return "Tap for today's inspiration"
        case .japanese: return "タップして今日のインスピレーションを"
        case .korean:   return "탭하여 오늘의 영감 얻기"
        case .spanish:  return "Toca para inspiración de hoy"
        }
    }

    // ── Smart summary template (for offline mode) ────────────
    /// Returns the completion/mood summary string in the correct language.
    /// This is the LOCAL (non-AI) version — always correct regardless of AI.
    nonisolated static func summaryCompletion(_ pct: Int, activeDays: Int, mood: Double, moodEmoji: String, l: AppLanguage) -> String {
        switch l {
        case .chinese:
            var s = ""
            if pct >= 80 { s += "完成率 \(pct)%，非常出色 🏆" }
            else if pct >= 60 { s += "完成率 \(pct)%，节奏稳定 ✨" }
            else if pct >= 30 { s += "完成率 \(pct)%，有所推进 💪" }
            else if activeDays > 0 { s += "🌱 \(activeDays)天有记录，在坚持中" }
            else { s += "🌙 尚无记录" }
            if mood > 0 { s += "\n\(moodEmoji) 平均心情 \(String(format:"%.1f", mood))/5" }
            return s
        case .english:
            var s = ""
            if pct >= 80 { s += "Completion \(pct)% — excellent 🏆" }
            else if pct >= 60 { s += "Completion \(pct)% — steady ✨" }
            else if pct >= 30 { s += "Completion \(pct)% — progressing 💪" }
            else if activeDays > 0 { s += "🌱 \(activeDays) active days" }
            else { s += "🌙 No records yet" }
            if mood > 0 { s += "\n\(moodEmoji) Avg mood \(String(format:"%.1f", mood))/5" }
            return s
        case .japanese:
            var s = ""
            if pct >= 80 { s += "完了率 \(pct)%、素晴らしい 🏆" }
            else if pct >= 60 { s += "完了率 \(pct)%、安定している ✨" }
            else if pct >= 30 { s += "完了率 \(pct)%、進んでいる 💪" }
            else if activeDays > 0 { s += "🌱 \(activeDays)日記録あり、継続中" }
            else { s += "🌙 まだ記録なし" }
            if mood > 0 { s += "\n\(moodEmoji) 平均気分 \(String(format:"%.1f", mood))/5" }
            return s
        case .korean:
            var s = ""
            if pct >= 80 { s += "완료율 \(pct)%, 탁월해요 🏆" }
            else if pct >= 60 { s += "완료율 \(pct)%, 꾸준해요 ✨" }
            else if pct >= 30 { s += "완료율 \(pct)%, 나아가고 있어요 💪" }
            else if activeDays > 0 { s += "🌱 \(activeDays)일 기록, 유지 중" }
            else { s += "🌙 기록 없음" }
            if mood > 0 { s += "\n\(moodEmoji) 평균 기분 \(String(format:"%.1f", mood))/5" }
            return s
        case .spanish:
            var s = ""
            if pct >= 80 { s += "Cumplimiento \(pct)% — excelente 🏆" }
            else if pct >= 60 { s += "Cumplimiento \(pct)% — constante ✨" }
            else if pct >= 30 { s += "Cumplimiento \(pct)% — avanzando 💪" }
            else if activeDays > 0 { s += "🌱 \(activeDays) días activos" }
            else { s += "🌙 Sin registros aún" }
            if mood > 0 { s += "\n\(moodEmoji) Estado promedio \(String(format:"%.1f", mood))/5" }
            return s
        }
    }

    nonisolated static func summaryWins(_ kws: [String], l: AppLanguage) -> String {
        let joined = kws.prefix(5).joined(separator: " · ")
        switch l {
        case .chinese:  return "💡 收获：\(joined)"
        case .english:  return "💡 Wins: \(joined)"
        case .japanese: return "💡 収穫：\(joined)"
        case .korean:   return "💡 성과: \(joined)"
        case .spanish:  return "💡 Logros: \(joined)"
        }
    }
    nonisolated static func summaryChallenges(_ kws: [String], l: AppLanguage) -> String {
        let joined = kws.prefix(5).joined(separator: " · ")
        switch l {
        case .chinese:  return "🔧 困难：\(joined)"
        case .english:  return "🔧 Challenges: \(joined)"
        case .japanese: return "🔧 困難：\(joined)"
        case .korean:   return "🔧 어려움: \(joined)"
        case .spanish:  return "🔧 Retos: \(joined)"
        }
    }
    nonisolated static func summaryPlans(_ kws: [String], l: AppLanguage) -> String {
        let joined = kws.prefix(5).joined(separator: " · ")
        switch l {
        case .chinese:  return "🎯 计划：\(joined)"
        case .english:  return "🎯 Next: \(joined)"
        case .japanese: return "🎯 計画：\(joined)"
        case .korean:   return "🎯 계획: \(joined)"
        case .spanish:  return "🎯 Planes: \(joined)"
        }
    }
}

// ============================================================
// MARK: - AIPromptRouter
// ============================================================
/// Wraps every AI prompt with the language instruction so the model
/// ALWAYS responds in the UI language.  Feed the result to your API call.
///
/// Usage:
///   let prompt = AIPromptRouter.wrap(basePrompt, language: store.language)
///   // → basePrompt + "\n\n" + language.aiInstruction
struct AIPromptRouter {
    /// Prepends the base prompt with a language enforcement instruction.
    /// Place this as the FIRST message in your system/user prompt.
    nonisolated static func wrap(_ base: String, language: AppLanguage) -> String {
        "\(language.aiInstruction)\n\n\(base)"
    }

    /// System-level language lock for multi-turn chat (place in system message)
    nonisolated static func systemInstruction(_ language: AppLanguage) -> String {
        language.aiInstruction
    }

    /// Build a smart-summary prompt in the correct language
    nonisolated static func summaryPrompt(
        periodLabel: String,
        completionPct: Int,
        mood: Double,
        wins: [String],
        challenges: [String],
        plans: [String],
        language: AppLanguage
    ) -> String {
        let lang = language

        // Localised field labels
        let fPeriod: String
        let fCompletion: String
        let fMood: String
        let fWins: String
        let fChallenges: String
        let fPlans: String
        let fInstruction: String

        switch lang {
        case .chinese:
            fPeriod = "周期"; fCompletion = "完成率"; fMood = "心情"
            fWins = "收获"; fChallenges = "困难"; fPlans = "计划"
            fInstruction = "请用 3-4 句话给出温暖、具体、鼓励性的总结，不要废话。"
        case .english:
            fPeriod = "Period"; fCompletion = "Completion"; fMood = "Mood"
            fWins = "Wins"; fChallenges = "Challenges"; fPlans = "Plans"
            fInstruction = "Give a warm, specific, encouraging 3-4 sentence summary. Be concise."
        case .japanese:
            fPeriod = "期間"; fCompletion = "完了率"; fMood = "気分"
            fWins = "収穫"; fChallenges = "困難"; fPlans = "計画"
            fInstruction = "温かく具体的な励ましのまとめを3〜4文でお願いします。簡潔に。"
        case .korean:
            fPeriod = "기간"; fCompletion = "완료율"; fMood = "기분"
            fWins = "성과"; fChallenges = "어려움"; fPlans = "계획"
            fInstruction = "따뜻하고 구체적인 격려의 요약을 3-4 문장으로 써 주세요."
        case .spanish:
            fPeriod = "Período"; fCompletion = "Cumplimiento"; fMood = "Estado"
            fWins = "Logros"; fChallenges = "Retos"; fPlans = "Planes"
            fInstruction = "Escribe un resumen cálido, específico y motivador en 3-4 frases."
        }

        let base = """
        \(fPeriod): \(periodLabel)
        \(fCompletion): \(completionPct)%
        \(fMood): \(String(format:"%.1f", mood))/5
        \(fWins): \(wins.prefix(6).joined(separator:", "))
        \(fChallenges): \(challenges.prefix(6).joined(separator:", "))
        \(fPlans): \(plans.prefix(6).joined(separator:", "))

        \(fInstruction)
        """
        return wrap(base, language: lang)
    }
}
