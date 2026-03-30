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
    nonisolated static func goalTypeDeadline(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "时间段"
        case .english:  return "Deadline"
        case .japanese: return "期限あり"
        case .korean:   return "기한 있음"
        case .spanish:  return "Con fecha"
        }
    }
    nonisolated static func goalTypeOngoing(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "长期"
        case .english:  return "Ongoing"
        case .japanese: return "継続"
        case .korean:   return "지속형"
        case .spanish:  return "Continuo"
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
    nonisolated static func refreshTips(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "刷新建议"
        case .english:  return "Refresh"
        case .japanese: return "更新する"
        case .korean:   return "새로고침"
        case .spanish:  return "Actualizar"
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
    nonisolated static func submitShort(_ l: AppLanguage) -> String {
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

// (new L10n functions below — still inside enum L10n)

    // ── Goals page ─────────────────────────────────────────────
    nonisolated static func today(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日"
        case .english: return "Today"
        case .japanese: return "今日"
        case .korean: return "오늘"
        case .spanish: return "Hoy"
        }
    }
    nonisolated static func addGoalLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "添加目标"
        case .english: return "Add Goal"
        case .japanese: return "目標を追加"
        case .korean: return "목표 추가"
        case .spanish: return "Añadir meta"
        }
    }
    nonisolated static func editGoalLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "编辑目标"
        case .english: return "Edit Goal"
        case .japanese: return "目標を編集"
        case .korean: return "목표 편집"
        case .spanish: return "Editar meta"
        }
    }
    nonisolated static func upgradeLimit(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "已达上限  ·  升级 Pro"
        case .english: return "Limit reached · Upgrade Pro"
        case .japanese: return "上限達成 · Pro にアップグレード"
        case .korean: return "한도 초과 · Pro로 업그레이드"
        case .spanish: return "Límite · Actualizar a Pro"
        }
    }
    nonisolated static func goalsCount(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "\(n) 个目标"
        case .english: return "\(n) goal\(n == 1 ? "" : "s")"
        case .japanese: return "\(n) 個の目標"
        case .korean: return "\(n)개 목표"
        case .spanish: return "\(n) meta\(n == 1 ? "" : "s")"
        }
    }
    nonisolated static func noGoalsDay(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "这天暂无目标"
        case .english: return "No goals for this day"
        case .japanese: return "この日は目標なし"
        case .korean: return "이날 목표 없음"
        case .spanish: return "Sin metas este día"
        }
    }
    nonisolated static func noTasksToday(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今天暂无任务"
        case .english: return "No tasks today"
        case .japanese: return "今日タスクなし"
        case .korean: return "오늘 할 일 없음"
        case .spanish: return "Sin tareas hoy"
        }
    }
    nonisolated static func editHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "双击编辑  拖拽改日期"
        case .english: return "Double-tap to edit, drag to change date"
        case .japanese: return "ダブルタップで編集、ドラッグで日付変更"
        case .korean: return "더블탭 편집, 드래그로 날짜 변경"
        case .spanish: return "Doble toque para editar, arrastrar para cambiar fecha"
        }
    }
    nonisolated static func share(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "分享"
        case .english: return "Share"
        case .japanese: return "シェア"
        case .korean: return "공유"
        case .spanish: return "Compartir"
        }
    }
    nonisolated static func deleteShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除"
        case .english: return "Del"
        case .japanese: return "削除"
        case .korean: return "삭제"
        case .spanish: return "Borrar"
        }
    }
    nonisolated static func deleteGoalTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除目标"
        case .english: return "Delete Goal"
        case .japanese: return "目標を削除"
        case .korean: return "목표 삭제"
        case .spanish: return "Eliminar meta"
        }
    }
    nonisolated static func cannotUndo(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除后无法恢复"
        case .english: return "This cannot be undone"
        case .japanese: return "削除後は復元できません"
        case .korean: return "삭제 후 복구 불가"
        case .spanish: return "No se puede deshacer"
        }
    }
    // ── GoalEditSheet ──────────────────────────────────────────
    nonisolated static func goalTitlePlaceholderLocal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "比如：每天健身"
        case .english: return "e.g. Exercise daily"
        case .japanese: return "例：毎日運動する"
        case .korean: return "예: 매일 운동하기"
        case .spanish: return "ej. Ejercicio diario"
        }
    }
    nonisolated static func colorLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "颜色"
        case .english: return "Color"
        case .japanese: return "カラー"
        case .korean: return "색상"
        case .spanish: return "Color"
        }
    }
    nonisolated static func goalTypeLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "目标类型"
        case .english: return "Goal Type"
        case .japanese: return "目標タイプ"
        case .korean: return "목표 유형"
        case .spanish: return "Tipo de meta"
        }
    }
    nonisolated static func startDateLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "开始日期"
        case .english: return "Start Date"
        case .japanese: return "開始日"
        case .korean: return "시작일"
        case .spanish: return "Fecha inicio"
        }
    }
    nonisolated static func endDateLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "截止日期"
        case .english: return "End Date"
        case .japanese: return "終了日"
        case .korean: return "종료일"
        case .spanish: return "Fecha límite"
        }
    }
    nonisolated static func addLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "添加"
        case .english: return "Add"
        case .japanese: return "追加"
        case .korean: return "추가"
        case .spanish: return "Añadir"
        }
    }
    nonisolated static func noTasksYet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "还没有任务"
        case .english: return "No tasks yet"
        case .japanese: return "タスクなし"
        case .korean: return "아직 할 일 없음"
        case .spanish: return "Sin tareas aún"
        }
    }
    nonisolated static func calendarDotLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "日历光点"
        case .english: return "Calendar Dot"
        case .japanese: return "カレンダードット"
        case .korean: return "캘린더 점"
        case .spanish: return "Punto en calendario"
        }
    }
    nonisolated static func calendarDotHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "在日历上显示有任务的天数"
        case .english: return "Show dot on days with tasks"
        case .japanese: return "タスクがある日にドットを表示"
        case .korean: return "할 일 있는 날 점 표시"
        case .spanish: return "Mostrar punto en días con tareas"
        }
    }
    nonisolated static func deleteThisGoal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除此目标"
        case .english: return "Delete this Goal"
        case .japanese: return "この目標を削除"
        case .korean: return "이 목표 삭제"
        case .spanish: return "Eliminar esta meta"
        }
    }
    nonisolated static func longtermGoalHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "从选定日起，所有历史和未来日期都会显示此目标"
        case .english: return "Goal appears on all dates from start date onward"
        case .japanese: return "選択日以降のすべての日付に目標が表示されます"
        case .korean: return "시작일부터 모든 날짜에 목표가 표시됩니다"
        case .spanish: return "La meta aparece en todas las fechas desde el inicio"
        }
    }
    nonisolated static func cannotChangeAfter(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "创建后不可修改"
        case .english: return "Cannot change after creation"
        case .japanese: return "作成後は変更不可"
        case .korean: return "생성 후 변경 불가"
        case .spanish: return "No se puede cambiar tras crear"
        }
    }
    // ── Task edit ─────────────────────────────────────────────
    nonisolated static func taskNameLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "任务名称"
        case .english: return "Task Name"
        case .japanese: return "タスク名"
        case .korean: return "할 일 이름"
        case .spanish: return "Nombre de tarea"
        }
    }
    nonisolated static func taskNamePlaceholderLocal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "比如：早晨跑步"
        case .english: return "e.g. Morning run"
        case .japanese: return "例：朝のランニング"
        case .korean: return "예: 아침 달리기"
        case .spanish: return "ej. Carrera matutina"
        }
    }
    nonisolated static func estimatedTimeLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "预计完成时间"
        case .english: return "Estimated Time"
        case .japanese: return "予想所要時間"
        case .korean: return "예상 소요 시간"
        case .spanish: return "Tiempo estimado"
        }
    }
    nonisolated static func maxLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "最长"
        case .english: return "Max"
        case .japanese: return "最大"
        case .korean: return "최대"
        case .spanish: return "Máx"
        }
    }
    nonisolated static func minuteLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "分钟"
        case .english: return "min"
        case .japanese: return "分"
        case .korean: return "분"
        case .spanish: return "min"
        }
    }
    nonisolated static func minuteWithNumber(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "\(n) 分钟"
        case .english: return "\(n) min"
        case .japanese: return "\(n) 分"
        case .korean: return "\(n) 분"
        case .spanish: return "\(n) min"
        }
    }
    // ── Today page ────────────────────────────────────────────
    nonisolated static func todayNav(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日"
        case .english: return "Today"
        case .japanese: return "今日"
        case .korean: return "오늘"
        case .spanish: return "Hoy"
        }
    }
    nonisolated static func pendingItems(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "待决事项"
        case .english: return "Pending Items"
        case .japanese: return "保留中の事項"
        case .korean: return "보류 항목"
        case .spanish: return "Pendientes"
        }
    }
    nonisolated static func noChallengesLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日无待解决困难"
        case .english: return "No challenges today"
        case .japanese: return "今日の課題なし"
        case .korean: return "오늘 과제 없음"
        case .spanish: return "Sin retos hoy"
        }
    }
    nonisolated static func resolvedLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "已解决"
        case .english: return "Resolved"
        case .japanese: return "解決済み"
        case .korean: return "해결됨"
        case .spanish: return "Resuelto"
        }
    }
    nonisolated static func todoLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "待处理"
        case .english: return "Todo"
        case .japanese: return "未処理"
        case .korean: return "처리 중"
        case .spanish: return "Por hacer"
        }
    }
    nonisolated static func weekLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "周"
        case .english: return "Week"
        case .japanese: return "週"
        case .korean: return "주"
        case .spanish: return "Sem."
        }
    }
    nonisolated static func expandCalendar(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "展开月历"
        case .english: return "Expand"
        case .japanese: return "月を展開"
        case .korean: return "달력 펼치기"
        case .spanish: return "Expandir"
        }
    }
    nonisolated static func collapseCalendar(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "收起月历"
        case .english: return "Collapse"
        case .japanese: return "月を閉じる"
        case .korean: return "달력 접기"
        case .spanish: return "Contraer"
        }
    }


    // ── TodayView strings ──────────────────────────────────────
    nonisolated static func howAreYouFeeling(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今天感觉怎么样？"
        case .english: return "How are you feeling?"
        case .japanese: return "今日の気分は？"
        case .korean: return "오늘 기분이 어때요?"
        case .spanish: return "¿Cómo te sientes hoy?"
        }
    }
    nonisolated static func todayJournal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日心得"
        case .english: return "Today's Journal"
        case .japanese: return "今日の日記"
        case .korean: return "오늘의 기록"
        case .spanish: return "Diario de hoy"
        }
    }
    nonisolated static func winsToday(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日收获"
        case .english: return "Wins Today"
        case .japanese: return "今日の成果"
        case .korean: return "오늘의 성과"
        case .spanish: return "Logros de hoy"
        }
    }
    nonisolated static func winsHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "用3-5个词总结收获（如：完成提案、突破瓶颈）"
        case .english: return "3-5 words summing up wins (e.g. proposal done, hit milestone)"
        case .japanese: return "成果を3〜5語でまとめて（例：提案完了、壁を突破）"
        case .korean: return "성과를 3-5단어로 (예: 제안 완료, 한계 돌파)"
        case .spanish: return "3-5 palabras sobre logros (ej. propuesta lista, meta alcanzada)"
        }
    }
    nonisolated static func tomorrowPlan(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "明日计划"
        case .english: return "Tomorrow's Plan"
        case .japanese: return "明日の計画"
        case .korean: return "내일 계획"
        case .spanish: return "Plan de mañana"
        }
    }
    nonisolated static func tomorrowHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "用3-5个词写明日重点（如：早起跑步、完成报告）"
        case .english: return "3-5 words for tomorrow (e.g. morning run, finish report)"
        case .japanese: return "明日の重点を3〜5語で（例：早起きランニング、レポート完了）"
        case .korean: return "내일 핵심을 3-5단어로 (예: 아침 달리기, 보고서 완성)"
        case .spanish: return "3-5 palabras para mañana (ej. correr mañana, terminar informe)"
        }
    }
    nonisolated static func submitJournal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "提交心得 · 激活总结"
        case .english: return "Submit & View Summary"
        case .japanese: return "記録を提出 · サマリーを表示"
        case .korean: return "기록 제출 · 요약 보기"
        case .spanish: return "Enviar y ver resumen"
        }
    }
    nonisolated static func updateJournal(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "更新今日心得"
        case .english: return "Update Journal"
        case .japanese: return "日記を更新"
        case .korean: return "기록 업데이트"
        case .spanish: return "Actualizar diario"
        }
    }
    nonisolated static func typeKeyword(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "输入词语，回车添加"
        case .english: return "Type keyword, hit return"
        case .japanese: return "キーワードを入力してEnter"
        case .korean: return "키워드 입력 후 엔터"
        case .spanish: return "Escribe y presiona Enter"
        }
    }
    nonisolated static func keywordLimit(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "已达5词建议上限"
        case .english: return "5 keywords — recommended limit"
        case .japanese: return "5語の推奨上限に達しました"
        case .korean: return "5개 키워드 권장 한도 달성"
        case .spanish: return "5 palabras — límite recomendado"
        }
    }
    nonisolated static func moreThanHalfway(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "过半了，继续加油"
        case .english: return "More than halfway"
        case .japanese: return "半分以上達成、続けよう"
        case .korean: return "절반 이상, 계속 화이팅"
        case .spanish: return "Más de la mitad, ¡adelante!"
        }
    }
    nonisolated static func noTasksYetShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "暂无任务"
        case .english: return "No tasks yet"
        case .japanese: return "タスクなし"
        case .korean: return "할 일 없음"
        case .spanish: return "Sin tareas"
        }
    }
    nonisolated static func todayStillYours(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今天还有机会"
        case .english: return "Today's still yours"
        case .japanese: return "今日はまだ間に合う"
        case .korean: return "오늘은 아직 기회가 있어요"
        case .spanish: return "El día todavía es tuyo"
        }
    }
    nonisolated static func pendingShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "待决"
        case .english: return "Pending"
        case .japanese: return "保留"
        case .korean: return "보류"
        case .spanish: return "Pend."
        }
    }
    nonisolated static func tapToResolve(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "点击标记解决"
        case .english: return "Tap to resolve"
        case .japanese: return "タップして解決"
        case .korean: return "탭하여 해결"
        case .spanish: return "Toca para resolver"
        }
    }
    nonisolated static func addDetails(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "可以补充更多细节…"
        case .english: return "Add more details if you like…"
        case .japanese: return "詳細を補足できます…"
        case .korean: return "더 자세히 추가할 수 있어요…"
        case .spanish: return "Puedes añadir más detalles…"
        }
    }
    nonisolated static func detailLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "详细"
        case .english: return "Detail"
        case .japanese: return "詳細"
        case .korean: return "상세"
        case .spanish: return "Detalle"
        }
    }
    nonisolated static func typeKeywordPlan(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "输入关键词，回车添加"
        case .english: return "Type keyword, press return"
        case .japanese: return "キーワードを入力してEnter"
        case .korean: return "키워드 입력 후 엔터"
        case .spanish: return "Escribe y presiona Enter"
        }
    }
    // ── PlanView strings ───────────────────────────────────────
    nonisolated static func selectGoalsLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "选择目标"
        case .english: return "Select Goals"
        case .japanese: return "目標を選択"
        case .korean: return "목표 선택"
        case .spanish: return "Seleccionar metas"
        }
    }
    nonisolated static func taskNameShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "任务名称"
        case .english: return "Task Name"
        case .japanese: return "タスク名"
        case .korean: return "할 일 이름"
        case .spanish: return "Nombre tarea"
        }
    }
    nonisolated static func taskNamePH(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "任务名"
        case .english: return "Task name"
        case .japanese: return "タスク名"
        case .korean: return "할 일 이름"
        case .spanish: return "Nombre de tarea"
        }
    }
    nonisolated static func goalBelongsTo(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "所属目标"
        case .english: return "Goal"
        case .japanese: return "所属目標"
        case .korean: return "목표"
        case .spanish: return "Meta"
        }
    }
    nonisolated static func deleteTaskLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除此任务"
        case .english: return "Delete task"
        case .japanese: return "タスクを削除"
        case .korean: return "할 일 삭제"
        case .spanish: return "Eliminar tarea"
        }
    }
    nonisolated static func editTask(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "编辑任务"
        case .english: return "Edit Task"
        case .japanese: return "タスクを編集"
        case .korean: return "할 일 편집"
        case .spanish: return "Editar tarea"
        }
    }
    nonisolated static func deleteTask(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "删除任务"
        case .english: return "Delete Task"
        case .japanese: return "タスクを削除"
        case .korean: return "할 일 삭제"
        case .spanish: return "Eliminar tarea"
        }
    }
    nonisolated static func noTasks(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "暂无任务"
        case .english: return "No tasks"
        case .japanese: return "タスクなし"
        case .korean: return "할 일 없음"
        case .spanish: return "Sin tareas"
        }
    }
    nonisolated static func doubleTapDragHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "双击编辑 · 长按拖动"
        case .english: return "Double-tap edit · drag to move"
        case .japanese: return "ダブルタップ編集 · ドラッグ移動"
        case .korean: return "더블탭 편집 · 드래그 이동"
        case .spanish: return "Doble toque = editar · arrastrar"
        }
    }
    nonisolated static func pastLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "已过"
        case .english: return "Past"
        case .japanese: return "過去"
        case .korean: return "지난"
        case .spanish: return "Pasado"
        }
    }
    nonisolated static func chooseGoalTitle(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "选择目标"
        case .english: return "Choose Goal"
        case .japanese: return "目標を選択"
        case .korean: return "목표 선택"
        case .spanish: return "Elegir meta"
        }
    }
    nonisolated static func noteLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "心得"
        case .english: return "Note"
        case .japanese: return "メモ"
        case .korean: return "메모"
        case .spanish: return "Nota"
        }
    }
    nonisolated static func noteDoneLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "心得✓"
        case .english: return "Note✓"
        case .japanese: return "メモ✓"
        case .korean: return "메모✓"
        case .spanish: return "Nota✓"
        }
    }
    nonisolated static func todoShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "待处理"
        case .english: return "Todo"
        case .japanese: return "未処理"
        case .korean: return "처리 중"
        case .spanish: return "Por hacer"
        }
    }
    nonisolated static func saveNote(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "保存心得"
        case .english: return "Save Note"
        case .japanese: return "メモを保存"
        case .korean: return "메모 저장"
        case .spanish: return "Guardar nota"
        }
    }


    nonisolated static func allDoneToday(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日全部完成 🎉"
        case .english: return "All done today 🎉"
        case .japanese: return "今日すべて完了 🎉"
        case .korean: return "오늘 모두 완료 🎉"
        case .spanish: return "Todo listo hoy 🎉"
        }
    }
    nonisolated static func estimatedTimeShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "预计时间"
        case .english: return "Estimated time"
        case .japanese: return "予想時間"
        case .korean: return "예상 시간"
        case .spanish: return "Tiempo est."
        }
    }
    nonisolated static func weekLabel2(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "本周"
        case .english: return "Week"
        case .japanese: return "今週"
        case .korean: return "이번 주"
        case .spanish: return "Semana"
        }
    }
    nonisolated static func monthLabel2(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "本月"
        case .english: return "Month"
        case .japanese: return "今月"
        case .korean: return "이번 달"
        case .spanish: return "Mes"
        }
    }
    nonisolated static func yearLabel2(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今年"
        case .english: return "Year"
        case .japanese: return "今年"
        case .korean: return "올해"
        case .spanish: return "Año"
        }
    }
    nonisolated static func avgCompletion(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "平均完成率"
        case .english: return "avg completion"
        case .japanese: return "平均達成率"
        case .korean: return "평균 달성률"
        case .spanish: return "completado prom."
        }
    }


    // ── Inspire page ─────────────────────────────────────────────
    nonisolated static func inspireOnline(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "网络"
        case .english: return "Online"
        case .japanese: return "ネット"
        case .korean: return "온라인"
        case .spanish: return "En línea"
        }
    }
    nonisolated static func inspireClassic(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "经典"
        case .english: return "Classic"
        case .japanese: return "クラシック"
        case .korean: return "클래식"
        case .spanish: return "Clásico"
        }
    }
    nonisolated static func inspireFetching(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "正在获取语录…"
        case .english: return "Fetching quote…"
        case .japanese: return "名言を取得中…"
        case .korean: return "명언 불러오는 중…"
        case .spanish: return "Obteniendo cita…"
        }
    }
    nonisolated static func inspireNext(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "换一条"
        case .english: return "Next"
        case .japanese: return "次へ"
        case .korean: return "다음"
        case .spanish: return "Siguiente"
        }
    }
    nonisolated static func inspireNetworkFail(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "网络语录获取失败，显示本地经典"
        case .english: return "Offline · showing classic quotes"
        case .japanese: return "オフライン · クラシック表示中"
        case .korean: return "오프라인 · 클래식 명언 표시"
        case .spanish: return "Sin red · mostrando clásicos"
        }
    }
    nonisolated static func inspireFreeLimitHit(_ limit: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "今日已浏览 \(limit) 条，升级 Pro 无限查看"
        case .english: return "\(limit) quotes today · Upgrade Pro for unlimited"
        case .japanese: return "本日\(limit)件閲覧 · Pro で無制限"
        case .korean: return "오늘 \(limit)개 봄 · Pro로 무제한"
        case .spanish: return "\(limit) citas hoy · Pro para ilimitado"
        }
    }
    nonisolated static func inspireSaved(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "我的收藏"
        case .english: return "Saved"
        case .japanese: return "お気に入り"
        case .korean: return "저장됨"
        case .spanish: return "Guardados"
        }
    }
    nonisolated static func inspireSave(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "收藏"
        case .english: return "Save"
        case .japanese: return "保存"
        case .korean: return "저장"
        case .spanish: return "Guardar"
        }
    }
    nonisolated static func inspireAlreadySaved(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "已收藏"
        case .english: return "Saved"
        case .japanese: return "保存済"
        case .korean: return "저장됨"
        case .spanish: return "Guardado"
        }
    }


    // ── Stats / Monthly Summary page ─────────────────────────────
    nonisolated static func proFeatureSmartSummary(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "智能总结是 Pro 功能"
        case .english: return "Smart Summary is a Pro feature"
        case .japanese: return "スマート要約はPro機能です"
        case .korean: return "스마트 요약은 Pro 기능입니다"
        case .spanish: return "Resumen inteligente es función Pro"
        }
    }
    nonisolated static func myGrowth(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "我的成长"
        case .english: return "My Growth"
        case .japanese: return "私の成長"
        case .korean: return "나의 성장"
        case .spanish: return "Mi crecimiento"
        }
    }
    nonisolated static func settingsLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "设置"
        case .english: return "Settings"
        case .japanese: return "設定"
        case .korean: return "설정"
        case .spanish: return "Configuración"
        }
    }
    nonisolated static func weekCompletionRate(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "本周完成率"
        case .english: return "This Week"
        case .japanese: return "今週の完了率"
        case .korean: return "이번 주 완료율"
        case .spanish: return "Esta semana"
        }
    }
    nonisolated static func monthCompletionRate(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "本月完成率"
        case .english: return "This Month"
        case .japanese: return "今月の完了率"
        case .korean: return "이번 달 완료율"
        case .spanish: return "Este mes"
        }
    }
    nonisolated static func yearCompletionRate(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "本年完成率"
        case .english: return "This Year"
        case .japanese: return "今年の完了率"
        case .korean: return "올해 완료율"
        case .spanish: return "Este año"
        }
    }
    nonisolated static func noDataYet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "暂无记录"
        case .english: return "No data yet"
        case .japanese: return "まだ記録なし"
        case .korean: return "아직 기록 없음"
        case .spanish: return "Sin datos aún"
        }
    }
    nonisolated static func goalProgressLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "目标进度"
        case .english: return "Goal Progress"
        case .japanese: return "目標の進捗"
        case .korean: return "목표 진행률"
        case .spanish: return "Progreso de metas"
        }
    }
    nonisolated static func collapseLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "收起"
        case .english: return "Collapse"
        case .japanese: return "閉じる"
        case .korean: return "접기"
        case .spanish: return "Contraer"
        }
    }
    nonisolated static func expandLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "展开"
        case .english: return "Expand"
        case .japanese: return "展開"
        case .korean: return "펼치기"
        case .spanish: return "Expandir"
        }
    }
    // ── Plan page ────────────────────────────────────────────────
    nonisolated static func futureDateLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "未来日期"
        case .english: return "Future date"
        case .japanese: return "将来の日付"
        case .korean: return "미래 날짜"
        case .spanish: return "Fecha futura"
        }
    }
    // ── Settings page ────────────────────────────────────────────
    nonisolated static func ageLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "年龄"
        case .english: return "Age"
        case .japanese: return "年齢"
        case .korean: return "나이"
        case .spanish: return "Edad"
        }
    }
    nonisolated static func skipLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese: return "不设置"
        case .english: return "Skip"
        case .japanese: return "スキップ"
        case .korean: return "건너뛰기"
        case .spanish: return "Omitir"
        }
    }


    // ── Extended i18n: Stats / Today / Plan / Settings pages ─
    nonisolated static func doneLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "完成"
        case .english:  return "Done"
        case .japanese: return "完了"
        case .korean:   return "완료"
        case .spanish:  return "Hecho"
        }
    }
    nonisolated static func pendingLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "未完成"
        case .english:  return "Pending"
        case .japanese: return "未完了"
        case .korean:   return "미완료"
        case .spanish:  return "Pendiente"
        }
    }
    nonisolated static func taskNameThisDay(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "任务名称（仅此日）"
        case .english:  return "Name (this day only)"
        case .japanese: return "タスク名（この日のみ）"
        case .korean:   return "작업명（이날만）"
        case .spanish:  return "Nombre (solo este día)"
        }
    }
    nonisolated static func taskNamePlain(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "任务名称"
        case .english:  return "Task name"
        case .japanese: return "タスク名"
        case .korean:   return "작업명"
        case .spanish:  return "Nombre de tarea"
        }
    }
    nonisolated static func estimatedTimeLabel2(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "预计时间"
        case .english:  return "Estimated time"
        case .japanese: return "予定時間"
        case .korean:   return "예상 시간"
        case .spanish:  return "Tiempo estimado"
        }
    }
    nonisolated static func cancelLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "取消"
        case .english:  return "Cancel"
        case .japanese: return "キャンセル"
        case .korean:   return "취소"
        case .spanish:  return "Cancelar"
        }
    }
    nonisolated static func checkedInNoKW(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "已打卡，暂无关键词"
        case .english:  return "Checked in, no keywords"
        case .japanese: return "チェックイン済み、キーワードなし"
        case .korean:   return "체크인 완료, 키워드 없음"
        case .spanish:  return "Registrado, sin palabras clave"
        }
    }
    nonisolated static func monthlyDataPro(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本月数据是 Pro 功能"
        case .english:  return "Monthly data is a Pro feature"
        case .japanese: return "月次データはPro機能です"
        case .korean:   return "월간 데이터는 Pro 기능입니다"
        case .spanish:  return "Datos mensuales son función Pro"
        }
    }
    nonisolated static func noWeeklySummary(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本周暂无总结"
        case .english:  return "No weekly summary"
        case .japanese: return "今週の要約なし"
        case .korean:   return "이번 주 요약 없음"
        case .spanish:  return "Sin resumen semanal"
        }
    }
    nonisolated static func yearlyDataPro(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本年数据是 Pro 功能"
        case .english:  return "Yearly data is a Pro feature"
        case .japanese: return "年間データはPro機能です"
        case .korean:   return "연간 데이터는 Pro 기능입니다"
        case .spanish:  return "Datos anuales son función Pro"
        }
    }
    nonisolated static func noMonthlySummary(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本月暂无总结"
        case .english:  return "No monthly summary"
        case .japanese: return "今月の要約なし"
        case .korean:   return "이번 달 요약 없음"
        case .spanish:  return "Sin resumen mensual"
        }
    }
    nonisolated static func smartSummaryLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "智能总结"
        case .english:  return "Smart Summary"
        case .japanese: return "スマート要約"
        case .korean:   return "스마트 요약"
        case .spanish:  return "Resumen inteligente"
        }
    }
    nonisolated static func collapseHide(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "收起"
        case .english:  return "Hide"
        case .japanese: return "閉じる"
        case .korean:   return "접기"
        case .spanish:  return "Contraer"
        }
    }
    nonisolated static func recordReason(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "记录原因"
        case .english:  return "Record"
        case .japanese: return "記録する"
        case .korean:   return "기록하기"
        case .spanish:  return "Registrar razón"
        }
    }
    nonisolated static func reasonPlaceholder(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "原因…"
        case .english:  return "Reason…"
        case .japanese: return "理由…"
        case .korean:   return "이유…"
        case .spanish:  return "Razón…"
        }
    }
    nonisolated static func doubleTapExpand(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "双击展开"
        case .english:  return "tap ×2"
        case .japanese: return "ダブルタップ展開"
        case .korean:   return "두 번 탭"
        case .spanish:  return "Toca ×2"
        }
    }
    nonisolated static func excellentStatus(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "保持得很好"
        case .english:  return "Excellent"
        case .japanese: return "素晴らしい"
        case .korean:   return "훌륭해요"
        case .spanish:  return "Excelente"
        }
    }
    nonisolated static func steadyStatus(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "节奏稳定"
        case .english:  return "Steady"
        case .japanese: return "安定中"
        case .korean:   return "꾸준해요"
        case .spanish:  return "Constante"
        }
    }
    nonisolated static func keepGoingStatus(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "继续坚持"
        case .english:  return "Keep going"
        case .japanese: return "続けよう"
        case .korean:   return "계속 가세요"
        case .spanish:  return "Sigue adelante"
        }
    }
    nonisolated static func tasksDoneLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "任务完成"
        case .english:  return "Tasks done"
        case .japanese: return "タスク完了"
        case .korean:   return "작업 완료"
        case .spanish:  return "Tareas hechas"
        }
    }
    nonisolated static func pendingTotalLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "待决总数"
        case .english:  return "Pending"
        case .japanese: return "保留中"
        case .korean:   return "보류 중 합계"
        case .spanish:  return "Total pendiente"
        }
    }
    nonisolated static func monthByWeek(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本月每周情况"
        case .english:  return "This Month by Week"
        case .japanese: return "今月週次"
        case .korean:   return "이번 달 주별"
        case .spanish:  return "Este mes por semana"
        }
    }
    nonisolated static func resolvedDone(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "✓ 已解决"
        case .english:  return "✓ Done"
        case .japanese: return "✓ 解決済み"
        case .korean:   return "✓ 해결됨"
        case .spanish:  return "✓ Resuelto"
        }
    }
    nonisolated static func pendingResolve(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "待解决"
        case .english:  return "Pending"
        case .japanese: return "未解決"
        case .korean:   return "해결 대기"
        case .spanish:  return "Por resolver"
        }
    }
    nonisolated static func yearByMonth(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本年每月情况"
        case .english:  return "This Year by Month"
        case .japanese: return "今年月次"
        case .korean:   return "올해 월별"
        case .spanish:  return "Este año por mes"
        }
    }
    nonisolated static func thisWeekDaily(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本周每日情况"
        case .english:  return "This Week"
        case .japanese: return "今週の日別"
        case .korean:   return "이번 주 일별"
        case .spanish:  return "Esta semana"
        }
    }
    nonisolated static func alreadyRecorded(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "已记录"
        case .english:  return "Recorded"
        case .japanese: return "記録済み"
        case .korean:   return "기록됨"
        case .spanish:  return "Registrado"
        }
    }
    nonisolated static func updateAndInsight(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "更新并激活智能总结"
        case .english:  return "Update & Insight"
        case .japanese: return "更新＆インサイト"
        case .korean:   return "업데이트＆인사이트"
        case .spanish:  return "Actualizar e Insight"
        }
    }
    nonisolated static func overallMood(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "整体心情"
        case .english:  return "Overall mood"
        case .japanese: return "全体的な気分"
        case .korean:   return "전체 기분"
        case .spanish:  return "Estado de ánimo general"
        }
    }
    nonisolated static func typeKeywordReturn(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "输入词语，回车添加"
        case .english:  return "Type keyword, hit return"
        case .japanese: return "キーワード入力、Returnで追加"
        case .korean:   return "키워드 입력, Enter로 추가"
        case .spanish:  return "Escribe palabra clave, Enter"
        }
    }
    nonisolated static func todayPendingLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "今日待办"
        case .english:  return "Today's Pending"
        case .japanese: return "今日の保留"
        case .korean:   return "오늘의 보류"
        case .spanish:  return "Pendientes de hoy"
        }
    }
    nonisolated static func longPressTodayOnly(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "长按编辑 · 仅今日可增删"
        case .english:  return "Long-press · today only"
        case .japanese: return "長押し編集・今日のみ"
        case .korean:   return "길게 눌러 편집 · 오늘만"
        case .spanish:  return "Mantén pulsado · solo hoy"
        }
    }
    nonisolated static func keywordLimitReached(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "已达建议上限（5词）"
        case .english:  return "Recommended limit: 5 keywords"
        case .japanese: return "推奨上限（5語）に達しました"
        case .korean:   return "추천 한도（5개 키워드）"
        case .spanish:  return "Límite recomendado: 5 palabras"
        }
    }
    nonisolated static func addMoreDetails(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "可以补充更多细节…"
        case .english:  return "Add more details if needed…"
        case .japanese: return "詳細を追加できます…"
        case .korean:   return "더 많은 세부 정보 추가 가능…"
        case .spanish:  return "Añade más detalles si es necesario…"
        }
    }
    nonisolated static func overviewLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "综合"
        case .english:  return "Overview"
        case .japanese: return "概要"
        case .korean:   return "개요"
        case .spanish:  return "Resumen general"
        }
    }
    nonisolated static func insightsLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "心得"
        case .english:  return "Insights"
        case .japanese: return "インサイト"
        case .korean:   return "인사이트"
        case .spanish:  return "Perspectivas"
        }
    }
    nonisolated static func noDataYet2(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "暂无数据"
        case .english:  return "No data yet"
        case .japanese: return "データなし"
        case .korean:   return "데이터 없음"
        case .spanish:  return "Sin datos"
        }
    }
    nonisolated static func periodYrLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "年"
        case .english:  return "Yr"
        case .japanese: return "年"
        case .korean:   return "년"
        case .spanish:  return "Año"
        }
    }
    nonisolated static func periodMoLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "月"
        case .english:  return "Mo"
        case .japanese: return "月"
        case .korean:   return "월"
        case .spanish:  return "Mes"
        }
    }
    nonisolated static func periodWkLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "周"
        case .english:  return "Wk"
        case .japanese: return "週"
        case .korean:   return "주"
        case .spanish:  return "Sem"
        }
    }
    nonisolated static func periodDayLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "日"
        case .english:  return "Day"
        case .japanese: return "日"
        case .korean:   return "일"
        case .spanish:  return "Día"
        }
    }
    nonisolated static func noDataPeriod(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "该时段暂无数据"
        case .english:  return "No data for this period"
        case .japanese: return "この期間のデータなし"
        case .korean:   return "해당 기간 데이터 없음"
        case .spanish:  return "Sin datos para este período"
        }
    }
    nonisolated static func avgMoodLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "平均心情"
        case .english:  return "Avg Mood"
        case .japanese: return "平均気分"
        case .korean:   return "평균 기분"
        case .spanish:  return "Ánimo promedio"
        }
    }
    nonisolated static func activeDaysLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "活跃天数"
        case .english:  return "Active Days"
        case .japanese: return "活動日数"
        case .korean:   return "활성 일수"
        case .spanish:  return "Días activos"
        }
    }
    nonisolated static func moodDistribution(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "心情分布"
        case .english:  return "Mood Distribution"
        case .japanese: return "気分分布"
        case .korean:   return "기분 분포"
        case .spanish:  return "Distribución de ánimo"
        }
    }
    nonisolated static func noInsightsYet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "还没有解决记录"
        case .english:  return "No insights yet"
        case .japanese: return "まだ解決記録なし"
        case .korean:   return "아직 해결 기록 없음"
        case .spanish:  return "Sin perspectivas aún"
        }
    }
    nonisolated static func noResolved(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "该时段无解决记录"
        case .english:  return "No resolved items here"
        case .japanese: return "この期間の解決記録なし"
        case .korean:   return "해당 기간 해결 기록 없음"
        case .spanish:  return "Sin elementos resueltos aquí"
        }
    }
    nonisolated static func annualResolved(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "年度解决"
        case .english:  return "Resolved"
        case .japanese: return "年間解決"
        case .korean:   return "연간 해결"
        case .spanish:  return "Resuelto anual"
        }
    }
    nonisolated static func topMonth(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "最多月"
        case .english:  return "Top month"
        case .japanese: return "最多月"
        case .korean:   return "최다 달"
        case .spanish:  return "Mes top"
        }
    }
    nonisolated static func withInsights(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "有心得"
        case .english:  return "With insights"
        case .japanese: return "インサイトあり"
        case .korean:   return "인사이트 있음"
        case .spanish:  return "Con perspectivas"
        }
    }
    nonisolated static func monthlyTrend(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "月度趋势"
        case .english:  return "Monthly trend"
        case .japanese: return "月次傾向"
        case .korean:   return "월간 추세"
        case .spanish:  return "Tendencia mensual"
        }
    }
    nonisolated static func yearHighlights(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "本年心得摘要"
        case .english:  return "Year highlights"
        case .japanese: return "年間ハイライト"
        case .korean:   return "올해 하이라이트"
        case .spanish:  return "Destacados del año"
        }
    }
    nonisolated static func keywordWord(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "词"
        case .english:  return "words"
        case .japanese: return "語"
        case .korean:   return "개"
        case .spanish:  return "palabras"
        }
    }
    nonisolated static func newKeyword(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "新增关键词"
        case .english:  return "New keyword"
        case .japanese: return "新しいキーワード"
        case .korean:   return "새 키워드"
        case .spanish:  return "Nueva palabra clave"
        }
    }
    nonisolated static func moodShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "心情"
        case .english:  return "Mood"
        case .japanese: return "気分"
        case .korean:   return "기분"
        case .spanish:  return "Ánimo"
        }
    }
    nonisolated static func completionRateShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "完成率"
        case .english:  return "Done %"
        case .japanese: return "完了率"
        case .korean:   return "완료율"
        case .spanish:  return "Tasa"
        }
    }
    nonisolated static func winsShort(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "收获"
        case .english:  return "Wins"
        case .japanese: return "成果"
        case .korean:   return "성과"
        case .spanish:  return "Logros"
        }
    }
    nonisolated static func submitAndInsight(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "提交并激活总结"
        case .english:  return "Submit & Insight"
        case .japanese: return "提出＆インサイト"
        case .korean:   return "제출＆인사이트"
        case .spanish:  return "Enviar e Insight"
        }
    }
    nonisolated static func realTodayLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "真实今日"
        case .english:  return "Real Today"
        case .japanese: return "本日"
        case .korean:   return "실제 오늘"
        case .spanish:  return "Hoy real"
        }
    }
    nonisolated static func debugDateLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "模拟日期（调试）"
        case .english:  return "Debug Date"
        case .japanese: return "デバッグ日付"
        case .korean:   return "디버그 날짜"
        case .spanish:  return "Fecha debug"
        }
    }
    nonisolated static func resetToToday(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "重置为今日"
        case .english:  return "Reset to Today"
        case .japanese: return "今日にリセット"
        case .korean:   return "오늘로 재설정"
        case .spanish:  return "Restablecer a hoy"
        }
    }
    nonisolated static func longPressEdit(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "长按编辑"
        case .english:  return "Long-press to edit"
        case .japanese: return "長押しで編集"
        case .korean:   return "길게 눌러 편집"
        case .spanish:  return "Mantén pulsado para editar"
        }
    }
    nonisolated static func addPendingReturn(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "新增待决/困难，回车确认"
        case .english:  return "Add pending item, return"
        case .japanese: return "保留/困難を追加、Enterで確認"
        case .korean:   return "보류/어려움 추가, Enter"
        case .spanish:  return "Agregar pendiente, Enter"
        }
    }
    nonisolated static func logPendingToTrack(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "记录待决事项，自动进入追踪"
        case .english:  return "Log pending items to track"
        case .japanese: return "保留事項を記録して追跡"
        case .korean:   return "보류 항목 기록 후 추적"
        case .spanish:  return "Registra pendientes para rastrear"
        }
    }
    nonisolated static func logChallengesHint(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "记录待决事项和挑战（如：完成报告、解决bug）"
        case .english:  return "Log pending items (e.g. finish report, fix bug)"
        case .japanese: return "保留事項を記録（例：報告完了、バグ修正）"
        case .korean:   return "보류 항목 기록 (예: 보고서 완성, 버그 수정)"
        case .spanish:  return "Registra pendientes (ej: terminar informe, arreglar bug)"
        }
    }
    nonisolated static func todayWinsLabel(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "今日"
        case .english:  return "Today's"
        case .japanese: return "今日の"
        case .korean:   return "오늘의"
        case .spanish:  return "De hoy"
        }
    }
    nonisolated static func lowCompletionMsg(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "天完成度较低"
        case .english:  return "days with low completion"
        case .japanese: return "日は完了率が低い"
        case .korean:   return "일은 완료율이 낮음"
        case .spanish:  return "días con baja completitud"
        }
    }

    // ── Parameterized i18n (with value interpolation) ─────────
    nonisolated static func minutesFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(n) 分钟"
        case .english:  return "\(n) min"
        case .japanese: return "\(n) 分"
        case .korean:   return "\(n) 분"
        case .spanish:  return "\(n) min"
        }
    }
    nonisolated static func winsCountFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "收获 · \(n)"
        case .english:  return "Wins · \(n)"
        case .japanese: return "成果 · \(n)"
        case .korean:   return "성과 · \(n)"
        case .spanish:  return "Logros · \(n)"
        }
    }
    nonisolated static func plansCountFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "计划 · \(n)"
        case .english:  return "Plans · \(n)"
        case .japanese: return "計画 · \(n)"
        case .korean:   return "계획 · \(n)"
        case .spanish:  return "Planes · \(n)"
        }
    }
    nonisolated static func resolvedCountFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "解决 \(n) 项"
        case .english:  return "Resolved \(n)"
        case .japanese: return "\(n) 件解決"
        case .korean:   return "\(n)개 해결"
        case .spanish:  return "Resuelto \(n)"
        }
    }
    nonisolated static func moreItemsFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "还有 \(n) 条"
        case .english:  return "+ \(n) more"
        case .japanese: return "他 \(n) 件"
        case .korean:   return "+ \(n)개 더"
        case .spanish:  return "+ \(n) más"
        }
    }
    nonisolated static func daysSinceStartFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(n) 天"
        case .english:  return "\(n)d"
        case .japanese: return "\(n) 日"
        case .korean:   return "\(n)일"
        case .spanish:  return "\(n)d"
        }
    }
    nonisolated static func goalCountFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(n)目标"
        case .english:  return "\(n) goals"
        case .japanese: return "\(n)目標"
        case .korean:   return "\(n)개 목표"
        case .spanish:  return "\(n) metas"
        }
    }
    nonisolated static func activeDaysOfFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "/\(n)天"
        case .english:  return "/\(n)d"
        case .japanese: return "/\(n)日"
        case .korean:   return "/\(n)일"
        case .spanish:  return "/\(n)d"
        }
    }
    nonisolated static func typeSummaryTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(typeName)总结"
        case .english:  return "\(typeName) Review"
        case .japanese: return "\(typeName)まとめ"
        case .korean:   return "\(typeName) 요약"
        case .spanish:  return "Resumen \(typeName)"
        }
    }
    nonisolated static func typePendingTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(typeName)待决事项"
        case .english:  return "\(typeName) Pending"
        case .japanese: return "\(typeName)保留事項"
        case .korean:   return "\(typeName) 보류"
        case .spanish:  return "Pendiente \(typeName)"
        }
    }
    nonisolated static func typeWinsTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "这\(typeName)的收获"
        case .english:  return "Wins This \(typeName)"
        case .japanese: return "今\(typeName)の成果"
        case .korean:   return "이번 \(typeName)의 성과"
        case .spanish:  return "Logros del \(typeName)"
        }
    }
    nonisolated static func typePlanTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "下\(typeName)的计划"
        case .english:  return "Plan For Next \(typeName)"
        case .japanese: return "次\(typeName)の計画"
        case .korean:   return "다음 \(typeName) 계획"
        case .spanish:  return "Plan para siguiente \(typeName)"
        }
    }
    nonisolated static func trackTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "记录这\(typeName)的总结"
        case .english:  return "Write your \(typeName) review"
        case .japanese: return "\(typeName)のまとめを記録"
        case .korean:   return "이번 \(typeName) 요약 작성"
        case .spanish:  return "Escribe tu resumen del \(typeName)"
        }
    }
    nonisolated static func growthTitle(_ typeName: String, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "记录这\(typeName)的成长"
        case .english:  return "Track your \(typeName)"
        case .japanese: return "\(typeName)の成長を記録"
        case .korean:   return "이번 \(typeName) 성장 기록"
        case .spanish:  return "Registra tu \(typeName)"
        }
    }


    nonisolated static func notSet(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "未设置"
        case .english:  return "Not set"
        case .japanese: return "未設定"
        case .korean:   return "설정 안 됨"
        case .spanish:  return "No definido"
        }
    }
    nonisolated static func ageFmt(_ age: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(age)岁"
        case .english:  return "\(age) yrs"
        case .japanese: return "\(age)歳"
        case .korean:   return "\(age)세"
        case .spanish:  return "\(age) años"
        }
    }
    nonisolated static func birthYearFmt(_ yr: Int, _ age: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "\(yr)年（\(age)岁）"
        case .english:  return "\(yr) (\(age)y)"
        case .japanese: return "\(yr)年（\(age)歳）"
        case .korean:   return "\(yr)년（\(age)세）"
        case .spanish:  return "\(yr) (\(age)a)"
        }
    }
    nonisolated static func taskSummaryFmt(_ total: Int, _ done: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "共\(total)项，完成\(done)项"
        case .english:  return "\(done)/\(total) tasks done"
        case .japanese: return "全\(total)件、\(done)件完了"
        case .korean:   return "전체 \(total)개, \(done)개 완료"
        case .spanish:  return "\(done)/\(total) tareas hechas"
        }
    }


    // ── Additional parameterized & hint keys ─────────────────
    nonisolated static func kwHintWins(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "3-5词，如：突破瓶颈、完成目标"
        case .english:  return "3-5 keywords: hit goal, key win"
        case .japanese: return "3〜5語: 目標達成、ブレイクスルー"
        case .korean:   return "3~5개: 목표달성, 돌파구"
        case .spanish:  return "3-5 palabras: lograr meta, avance"
        }
    }
    nonisolated static func kwHintPlan(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "3-5词，如：每天冥想、完成项目"
        case .english:  return "3-5 keywords: daily meditate, ship it"
        case .japanese: return "3〜5語: 毎日瞑想、プロジェクト完了"
        case .korean:   return "3~5개: 매일 명상, 프로젝트 완성"
        case .spanish:  return "3-5 palabras: meditar diario, terminar"
        }
    }
    nonisolated static func lowCompletionFmt(_ n: Int, _ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "有 \(n) 天完成度较低"
        case .english:  return "Low completion: \(n) days"
        case .japanese: return "\(n) 日は完了率が低い"
        case .korean:   return "\(n)일은 완료율이 낮음"
        case .spanish:  return "\(n) días con baja completitud"
        }
    }

    nonisolated static func doubleTapSmartSummary(_ l: AppLanguage) -> String {
        switch l {
        case .chinese:  return "双击查看完整智能总结"
        case .english:  return "Double-tap for Smart Summary"
        case .japanese: return "ダブルタップでスマート要約"
        case .korean:   return "두 번 탭으로 스마트 요약"
        case .spanish:  return "Toca dos veces para resumen"
        }
    }
} // end enum L10n


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
