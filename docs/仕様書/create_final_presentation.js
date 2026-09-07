// PptxGenJS - オラクルカード占いアプリ 最終企画書
// 分析内容・広告戦略を反映した最終系企画書

const PptxGenJS = require("pptxgenjs");

// 1. プレゼンテーション初期化
const prs = new PptxGenJS();
prs.defineLayout({ name: "LAYOUT1", width: 10, height: 7.5 });
prs.defineLayout({ name: "LAYOUT2", width: 10, height: 7.5 });

// 2. カラーパレット定義（占い・スピリチュアル系）
const colors = {
  primary: "2C3E50",      // 深紺（神聖性・信頼）
  secondary: "8B6F9E",    // 紫（スピリチュアル）
  accent: "D4AF37",       // ゴールド（高級感）
  light: "F5F3F0",        // クリーム（背景）
  white: "FFFFFF",
  text: "2C3E50",
  success: "27AE60",      // グリーン（正）
  warning: "E67E22",      // オレンジ（警告）
  error: "E74C3C"         // レッド（エラー）
};

// 3. フォント設定
prs.defineLayout({ name: "DEFAULT", width: 10, height: 7.5 });

// ========================================
// SLIDE 1: タイトルスライド
// ========================================
let slide = prs.addSlide();
slide.background = { color: colors.primary };

slide.addText("オラクルカード占いアプリ", {
  x: 0.5, y: 2.5, w: 9, h: 1,
  fontSize: 54, bold: true, color: colors.accent, align: "center",
  fontFace: "Cambria"
});

slide.addText("最終企画書 ～分析・実装・マネタイズ戦略～", {
  x: 0.5, y: 3.7, w: 9, h: 0.6,
  fontSize: 28, color: colors.light, align: "center",
  fontFace: "Calibri"
});

slide.addText("2026年7月2日 / Claude Code分析版", {
  x: 0.5, y: 6.5, w: 9, h: 0.4,
  fontSize: 14, color: colors.light, align: "center", italic: true,
  fontFace: "Calibri"
});

// ========================================
// SLIDE 2: プロジェクト概要
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

// ヘッダー
slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("プロジェクト概要", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria", align: "left"
});

// コンテンツ
const overviewItems = [
  { title: "アプリ名", desc: "オラクルカード・リーディングアプリ（VTuber「ロン」連携）" },
  { title: "プラットフォーム", desc: "iOS / Android (Flutter)" },
  { title: "バックエンド", desc: "Python FastAPI + PostgreSQL/Redis" },
  { title: "管理画面", desc: "Next.js (React/TypeScript)" },
  { title: "主要機能", desc: "占い・課金・通知・分析・管理画面・外部導線" },
  { title: "ビジネスモデル", desc: "課金 (サブスク/チケット) + 広告収益 (段階的導入)" }
];

let yPos = 1.3;
overviewItems.forEach((item, idx) => {
  slide.addText(item.title + ":", {
    x: 0.7, y: yPos, w: 2, h: 0.35,
    fontSize: 13, bold: true, color: colors.primary,
    fontFace: "Calibri"
  });
  slide.addText(item.desc, {
    x: 3, y: yPos, w: 6.3, h: 0.35,
    fontSize: 12, color: colors.text,
    fontFace: "Calibri", align: "left"
  });
  yPos += 0.5;
});

// ========================================
// SLIDE 3: 現状分析（実装状況）
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("現状分析：実装状況", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

// テーブル データ
const implStatus = [
  ["レイヤー", "実装状態", "判定"],
  ["モバイルアプリ", "18画面すべて実装済み（API接続完了）", "✅ 実装済み"],
  ["バックエンドAPI", "32エンドポイント実装済み", "✅ 実装済み"],
  ["管理画面", "10ページ実装済み（権限制御未）", "🟡 部分実装"],
  ["DB/キャッシュ", "InMemory既定 + Hybrid (Postgres/Redis対応)", "🟡 部分実装"],
  ["認証", "基本/Apple/Google対応", "✅ 実装済み"],
  ["決済検証", "形式チェックのみ (公式API未接続)", "🟡 部分実装"],
  ["通知配信", "作成・一覧・ディスパッチ済み (実送信未実装)", "🟡 部分実装"],
  ["分析基盤", "イベント記録のみ (DB永続化未)", "🟡 部分実装"]
];

const tableOptions = {
  x: 0.4, y: 1.2, w: 9.2, h: 5.8,
  colW: [2.2, 5.2, 1.8],
  border: { pt: 1, color: colors.primary },
  fill: { color: colors.white },
  rowH: 0.6
};

// ヘッダー行
const headerStyle = {
  fontSize: 11, bold: true, color: colors.white,
  fill: { color: colors.secondary },
  align: "center", fontFace: "Calibri"
};

// データ行
const dataStyle = {
  fontSize: 10, color: colors.text,
  fontFace: "Calibri", align: "left"
};

slide.addTable(implStatus, {
  ...tableOptions,
  rowH: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
  border: { pt: 1, color: colors.secondary },
  colW: [2, 5.5, 1.7]
});

// ========================================
// SLIDE 4: 機能ギャップ分析 (1/2)
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("機能ギャップ分析：Google Play比較", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

// ギャップ1：占い形式
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 1.2, w: 9, h: 1.4,
  fill: { color: "#FFF3E0" },
  line: { color: colors.warning, width: 2 }
});

slide.addText("❌ 占い形式の多様性が不足", {
  x: 0.7, y: 1.35, w: 8.6, h: 0.35,
  fontSize: 14, bold: true, color: colors.warning,
  fontFace: "Calibri"
});

slide.addText("現状：1～3枚選択のシンプルなスプレッドのみ\nGoogle Play標準：ケルト十字・7枚・イエス/ノー・愛情等10種類以上", {
  x: 0.7, y: 1.75, w: 8.6, h: 0.7,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri"
});

// ギャップ2：外部連携
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 2.8, w: 9, h: 1.4,
  fill: { color: "#FFEBEE" },
  line: { color: colors.error, width: 2 }
});

slide.addText("❌ 外部連携（決済・通知・URL）が未実装", {
  x: 0.7, y: 2.95, w: 8.6, h: 0.35,
  fontSize: 14, bold: true, color: colors.error,
  fontFace: "Calibri"
});

slide.addText("決済検証・プッシュ通知・外部導線URLが全てダミー値・未接続状態\nストア審査前に必須対応", {
  x: 0.7, y: 3.35, w: 8.6, h: 0.7,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri"
});

// ギャップ3：ソーシャル
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 4.4, w: 9, h: 1.4,
  fill: { color: "#F3E5F5" },
  line: { color: colors.secondary, width: 2 }
});

slide.addText("❌ ソーシャル機能がない", {
  x: 0.7, y: 4.55, w: 8.6, h: 0.35,
  fontSize: 14, bold: true, color: colors.secondary,
  fontFace: "Calibri"
});

slide.addText("SNS共有・コメント・いいね・フォロー等のユーザー間インタラクション皆無\n初期MVP段階では後回しも正当", {
  x: 0.7, y: 4.95, w: 8.6, h: 0.7,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri"
});

// ========================================
// SLIDE 5: 機能ギャップ分析 (2/2) - 曖昧な仕様
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("仕様書の曖昧・矛盾点", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const ambiguousItems = [
  "正逆判定ロジックが不明確（サーバー側？クライアント側？）",
  "シャッフル終了判定のしきい値が仕様書に記載なし",
  "課金プランの「1日1回」定義が曖昧（JST基準？24時間？）",
  "テーマ×デッキの関連性が不明（同デッキを複数テーマで選べるか？）",
  "通知セグメント値が \"all\" のみ記載（他バリエーション未定義）",
  "分析イベント properties フィールドが自由形式（スキーマ不定）",
  "Apple/Google認証の provider_user_id フォーマットが不明",
  "U-11 (履歴詳細)の実装状態が未確定（推定状態）",
  "subscription_expires_at が UserResponse に含まれない",
  "広告掲載機能が仕様書に記載されていない ← 重大な欠落"
];

yPos = 1.3;
ambiguousItems.forEach((item, idx) => {
  const marker = idx < 9 ? "⚠️ " : "🔴 ";
  slide.addText(marker + item, {
    x: 0.7, y: yPos, w: 8.8, h: 0.35,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri", align: "left"
  });
  yPos += 0.4;
});

// ========================================
// SLIDE 6: 最大の課題 - 広告戦略の欠落
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.error }
});
slide.addText("重大な欠落：広告戦略・マネタイズ方針がない", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.white,
  fontFace: "Cambria"
});

slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 1.3, w: 9, h: 2,
  fill: { color: "#FFF3E0" },
  line: { color: colors.warning, width: 2 }
});

slide.addText("現状の問題", {
  x: 0.7, y: 1.45, w: 8.6, h: 0.35,
  fontSize: 14, bold: true, color: colors.warning,
  fontFace: "Calibri"
});

slide.addText("✗ Google Play標準アプリの90%以上が広告を実装\n✗ 本仕様書では広告に関する記載が完全にない\n✗ ビジネスモデルが「課金のみ」に限定されている\n✗ ユーザー基盤の拡大時に収益化戦略がない", {
  x: 0.7, y: 1.85, w: 8.6, h: 1.35,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 3.5, w: 9, h: 2,
  fill: { color: "#E8F5E9" },
  line: { color: colors.success, width: 2 }
});

slide.addText("解決策：段階的広告導入戦略", {
  x: 0.7, y: 3.65, w: 8.6, h: 0.35,
  fontSize: 14, bold: true, color: colors.success,
  fontFace: "Calibri"
});

slide.addText("✓ Phase 1 (0-6ヶ月)：広告なし ← ブランド構築・体験最優先\n✓ Phase 2 (6-12ヶ月)：リワード広告のみ ← 新規収益+1.5-2倍\n✓ Phase 3 (12+ヶ月)：バナー+リワード ← 最大+160%の収益化", {
  x: 0.7, y: 4.05, w: 8.6, h: 1.35,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

// ========================================
// SLIDE 7: 広告戦略の詳細 - メリット
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("広告導入のメリット（段階的導入時）", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

// メリット1
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 1.2, w: 4.3, h: 1.8,
  fill: { color: "#E3F2FD" },
  line: { color: colors.primary, width: 1 }
});

slide.addText("💰 収益の多元化", {
  x: 0.7, y: 1.35, w: 3.9, h: 0.3,
  fontSize: 13, bold: true, color: colors.primary,
  fontFace: "Calibri"
});

slide.addText("月$15,750 → $24,660\n(+57%)\n\nPhase 3で\n月$41,400\n(+163%)", {
  x: 0.7, y: 1.7, w: 3.9, h: 1.2,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// メリット2
slide.addShape(prs.ShapeType.rect, {
  x: 5.2, y: 1.2, w: 4.3, h: 1.8,
  fill: { color: "#F3E5F5" },
  line: { color: colors.secondary, width: 1 }
});

slide.addText("👥 ユーザーLTV向上", {
  x: 5.4, y: 1.35, w: 3.9, h: 0.3,
  fontSize: 13, bold: true, color: colors.secondary,
  fontFace: "Calibri"
});

slide.addText("無料ユーザーも\n長期継続で\n価値化\n\nUA単価を\n$5→$1-2\nに低減可能", {
  x: 5.4, y: 1.7, w: 3.9, h: 1.2,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// メリット3
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 3.3, w: 4.3, h: 1.8,
  fill: { color: "#FFF3E0" },
  line: { color: colors.warning, width: 1 }
});

slide.addText("✨ UX向上の可能性", {
  x: 0.7, y: 3.45, w: 3.9, h: 0.3,
  fontSize: 13, bold: true, color: colors.warning,
  fontFace: "Calibri"
});

slide.addText("リワード広告で\n「広告視聴＝\n追加占い」\nに設計\n\nユーザー満足度↑", {
  x: 0.7, y: 3.8, w: 3.9, h: 1.2,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// メリット4
slide.addShape(prs.ShapeType.rect, {
  x: 5.2, y: 3.3, w: 4.3, h: 1.8,
  fill: { color: "#F0F4C3" },
  line: { color: "#9CCC65", width: 1 }
});

slide.addText("🎯 有料版の差別化", {
  x: 5.4, y: 3.45, w: 3.9, h: 0.3,
  fontSize: 13, bold: true, color: "#558B2F",
  fontFace: "Calibri"
});

slide.addText("「広告なし」が\n強い購入動機に\n\nサブスク転換率↑\n転換単価↑", {
  x: 5.4, y: 3.8, w: 3.9, h: 1.2,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// ========================================
// SLIDE 8: 広告導入のデメリット
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("広告導入のデメリット（過度な導入時の懸念）", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const demerits = [
  { icon: "📉", title: "ユーザー体験悪化", desc: "初日離脱率 +15-30% のリスク" },
  { icon: "🎨", title: "ブランド低下", desc: "スピリチュアル系の神聖性破壊" },
  { icon: "💳", title: "課金転換率低下", desc: "サブスク 2.0% → 0.8% のリスク" },
  { icon: "⚠️", title: "ネットワーク依存", desc: "CPM変動・規制リスク・収入不安定" },
  { icon: "💼", title: "運用コスト増", desc: "初期$3.5K-10K + 月$500-1.5K" },
  { icon: "⚔️", title: "競合優位性喪失", desc: "「広告あり」で競合と同じに" }
];

yPos = 1.3;
demerits.forEach((item) => {
  slide.addText(item.icon + " " + item.title, {
    x: 0.7, y: yPos, w: 2.5, h: 0.3,
    fontSize: 12, bold: true, color: colors.warning,
    fontFace: "Calibri"
  });
  slide.addText(item.desc, {
    x: 3.3, y: yPos, w: 6, h: 0.3,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });
  yPos += 0.65;
});

slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 5.8, w: 9, h: 1.3,
  fill: { color: "#FFEBEE" },
  line: { color: colors.error, width: 1 }
});

slide.addText("⚠️ 重要：「段階的導入」が必須", {
  x: 0.7, y: 5.95, w: 8.6, h: 0.3,
  fontSize: 13, bold: true, color: colors.error,
  fontFace: "Calibri"
});

slide.addText("即座のインタースティシャル広告・過度な広告配置は避けるべき。\nリワード広告をメインにし、ユーザー選択可能にすることで、デメリットを最小化。", {
  x: 0.7, y: 6.3, w: 8.6, h: 0.7,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri"
});

// ========================================
// SLIDE 9: 段階的導入シナリオ
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("推奨：段階的広告導入シナリオ", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

// Phase 1
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 1.2, w: 2.8, h: 4.8,
  fill: { color: "#E3F2FD" },
  line: { color: colors.primary, width: 2 }
});

slide.addText("Phase 1", {
  x: 0.7, y: 1.35, w: 2.4, h: 0.35,
  fontSize: 16, bold: true, color: colors.primary,
  fontFace: "Calibri"
});

slide.addText("0～6ヶ月", {
  x: 0.7, y: 1.75, w: 2.4, h: 0.25,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

slide.addText("広告なし\n\nブランド構築・ユーザー体験最優先\n\nKPI:DAU, 課金転換率", {
  x: 0.7, y: 2.1, w: 2.4, h: 3,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// Phase 2
slide.addShape(prs.ShapeType.rect, {
  x: 3.6, y: 1.2, w: 2.8, h: 4.8,
  fill: { color: "#F3E5F5" },
  line: { color: colors.secondary, width: 2 }
});

slide.addText("Phase 2", {
  x: 3.8, y: 1.35, w: 2.4, h: 0.35,
  fontSize: 16, bold: true, color: colors.secondary,
  fontFace: "Calibri"
});

slide.addText("6～12ヶ月", {
  x: 3.8, y: 1.75, w: 2.4, h: 0.25,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

slide.addText("リワード広告のみ\n\nユーザー選択可能\n\n期待: +57%\n月$24,660", {
  x: 3.8, y: 2.1, w: 2.4, h: 3,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// Phase 3
slide.addShape(prs.ShapeType.rect, {
  x: 6.7, y: 1.2, w: 2.8, h: 4.8,
  fill: { color: "#FFF3E0" },
  line: { color: colors.warning, width: 2 }
});

slide.addText("Phase 3", {
  x: 6.9, y: 1.35, w: 2.4, h: 0.35,
  fontSize: 16, bold: true, color: colors.warning,
  fontFace: "Calibri"
});

slide.addText("12ヶ月以降", {
  x: 6.9, y: 1.75, w: 2.4, h: 0.25,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

slide.addText("バナー+リワード\n\n（DAU≥5,000時）\n\n期待: +163%\n月$41,400", {
  x: 6.9, y: 2.1, w: 2.4, h: 3,
  fontSize: 11, color: colors.text,
  fontFace: "Calibri", align: "center"
});

// ========================================
// SLIDE 10: 実装ロードマップ（優先度）
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("実装ロードマップ：優先度別", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const roadmap = [
  { priority: "🔴 P0", items: "決済検証(Apple/Google) / 法務文書 / 外部URL設定 / 仕様書精緻化(10項目)", timeline: "ストア申請前（必須）", weeks: "3-4週間" },
  { priority: "🟠 P1", items: "DB永続化(themes/decks) / FCM/APNs実装 / 広告戦略ドキュメント", timeline: "初期運用(6ヶ月)", weeks: "4-6週間" },
  { priority: "🟡 P2", items: "スプレッド多様化 / ソーシャル機能 / リワード広告API", timeline: "成長期(6-12ヶ月)", weeks: "2-6週間" }
];

yPos = 1.3;
roadmap.forEach((row) => {
  slide.addShape(prs.ShapeType.rect, {
    x: 0.5, y: yPos, w: 9, h: 1.2,
    fill: { color: colors.white },
    line: { color: colors.primary, width: 1 }
  });

  slide.addText(row.priority, {
    x: 0.7, y: yPos + 0.1, w: 1.2, h: 0.35,
    fontSize: 12, bold: true, color: colors.primary,
    fontFace: "Calibri"
  });

  slide.addText(row.items, {
    x: 2, y: yPos + 0.1, w: 5.5, h: 1,
    fontSize: 10, color: colors.text,
    fontFace: "Calibri", align: "left"
  });

  slide.addText(row.timeline, {
    x: 7.6, y: yPos + 0.35, w: 1.8, h: 0.5,
    fontSize: 10, color: colors.secondary, bold: true,
    fontFace: "Calibri", align: "center"
  });

  yPos += 1.35;
});

// ========================================
// SLIDE 11: 収益シミュレーション
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("収益シミュレーション（段階的導入効果）", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const chartData = [
  { scenario: "現状\n（広告なし）", monthly: "$15,750", growth: "—", experience: "⭐⭐⭐⭐⭐" },
  { scenario: "Phase 2\n（リワード）", monthly: "$24,660", growth: "+57%", experience: "⭐⭐⭐⭐⭐" },
  { scenario: "Phase 3\n（バナー+リワード）", monthly: "$41,400", growth: "+163%", experience: "⭐⭐⭐⭐☆" }
];

let xPos = 0.8;
const colWidth = 2.8;

chartData.forEach((data) => {
  // カード背景
  const bgColor = data.scenario.includes("現状") ? "#E3F2FD" : data.scenario.includes("Phase 2") ? "#F3E5F5" : "#FFF3E0";
  slide.addShape(prs.ShapeType.rect, {
    x: xPos, y: 1.3, w: colWidth, h: 4,
    fill: { color: bgColor },
    line: { color: colors.primary, width: 1 }
  });

  slide.addText(data.scenario, {
    x: xPos + 0.1, y: 1.45, w: colWidth - 0.2, h: 0.5,
    fontSize: 12, bold: true, color: colors.primary,
    fontFace: "Calibri", align: "center"
  });

  slide.addShape(prs.ShapeType.rect, {
    x: xPos + 0.1, y: 2.05, w: colWidth - 0.2, h: 0.8,
    fill: { color: colors.accent }
  });

  slide.addText(data.monthly, {
    x: xPos + 0.1, y: 2.2, w: colWidth - 0.2, h: 0.5,
    fontSize: 18, bold: true, color: colors.white,
    fontFace: "Cambria", align: "center"
  });

  slide.addText(data.growth, {
    x: xPos + 0.1, y: 2.95, w: colWidth - 0.2, h: 0.35,
    fontSize: 13, bold: true, color: colors.success,
    fontFace: "Calibri", align: "center"
  });

  slide.addText("UX\n" + data.experience, {
    x: xPos + 0.1, y: 3.45, w: colWidth - 0.2, h: 0.8,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri", align: "center"
  });

  xPos += colWidth + 0.3;
});

// 注記
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 5.5, w: 9, h: 1,
  fill: { color: "#F0F4C3" },
  line: { color: "#9CCC65", width: 1 }
});

slide.addText("📊 年間ベース：Phase 2で +$110K、Phase 3で +$300K+ の追加収益機会", {
  x: 0.7, y: 5.65, w: 8.6, h: 0.7,
  fontSize: 12, bold: true, color: "#558B2F",
  fontFace: "Calibri"
});

// ========================================
// SLIDE 12: ベストプラクティス（実装上の注意）
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("広告実装のベストプラクティス", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

// やるべき
slide.addShape(prs.ShapeType.rect, {
  x: 0.5, y: 1.2, w: 4.3, h: 4.8,
  fill: { color: "#E8F5E9" },
  line: { color: colors.success, width: 2 }
});

slide.addText("✅ やるべき実装", {
  x: 0.7, y: 1.35, w: 3.9, h: 0.35,
  fontSize: 13, bold: true, color: colors.success,
  fontFace: "Calibri"
});

const doItems = [
  "リワード広告をメイン",
  "ユーザー選択可能",
  "占い系商品のみ配置",
  "iOS ATT対応",
  "GDPR/個人情報保護法対応",
  "広告品質の厳格管理"
];

yPos = 1.8;
doItems.forEach((item) => {
  slide.addText("• " + item, {
    x: 0.7, y: yPos, w: 3.9, h: 0.3,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });
  yPos += 0.4;
});

// やってはいけない
slide.addShape(prs.ShapeType.rect, {
  x: 5.2, y: 1.2, w: 4.3, h: 4.8,
  fill: { color: "#FFEBEE" },
  line: { color: colors.error, width: 2 }
});

slide.addText("❌ やってはいけない実装", {
  x: 5.4, y: 1.35, w: 3.9, h: 0.35,
  fontSize: 13, bold: true, color: colors.error,
  fontFace: "Calibri"
});

const dontItems = [
  "占い結果直後に全画面広告",
  "バナー画面の30%以上占有",
  "スキップボタン小型化",
  "報酬額の誇大表示",
  "不適切な広告（ゲーム等）",
  "ユーザー強制閲覧"
];

yPos = 1.8;
dontItems.forEach((item) => {
  slide.addText("• " + item, {
    x: 5.4, y: yPos, w: 3.9, h: 0.3,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });
  yPos += 0.4;
});

// ========================================
// SLIDE 13: 最終推奨対応表
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("最終推奨：実装対応プラン", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const actions = [
  { phase: "ストア申請前", action: "決済検証・法務文書・仕様書精緻化・外部URL実装", checkbox: "🔲" },
  { phase: "初期運用(0-6m)", action: "DB永続化・通知実装・課金体験最適化・広告なし方針", checkbox: "🔲" },
  { phase: "成長期(6-12m)", action: "リワード広告準備・効果測定・段階的導入", checkbox: "🔲" },
  { phase: "安定期(12m+)", action: "バナー広告検討（DAU≥5K時）・継続最適化", checkbox: "🔲" },
  { phase: "通年", action: "新規ドキュメント「13_広告戦略・マネタイズ方針書」作成", checkbox: "🔲" }
];

yPos = 1.35;
actions.forEach((row) => {
  slide.addShape(prs.ShapeType.rect, {
    x: 0.5, y: yPos, w: 9, h: 0.7,
    fill: { color: colors.white },
    line: { color: colors.primary, width: 1 }
  });

  slide.addText(row.checkbox + " " + row.phase, {
    x: 0.7, y: yPos + 0.15, w: 2, h: 0.4,
    fontSize: 11, bold: true, color: colors.primary,
    fontFace: "Calibri"
  });

  slide.addText(row.action, {
    x: 2.8, y: yPos + 0.15, w: 6.7, h: 0.4,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });

  yPos += 0.8;
});

// ========================================
// SLIDE 14: 結論
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.primary };

slide.addText("結論", {
  x: 0.5, y: 1, w: 9, h: 0.6,
  fontSize: 44, bold: true, color: colors.accent, align: "center",
  fontFace: "Cambria"
});

slide.addShape(prs.ShapeType.rect, {
  x: 1, y: 1.8, w: 8, h: 3.2,
  fill: { color: colors.light }
});

slide.addText("本オラクルカード占いアプリは、バックエンド・モバイルUIの実装度は良好（MVP合格）ですが、以下を必須対応すべきです：", {
  x: 1.3, y: 2.0, w: 7.4, h: 0.6,
  fontSize: 12, color: colors.text,
  fontFace: "Calibri"
});

const conclusions = [
  "✓ Google Play標準との機能ギャップの埋め込み（スプレッド多様化、社会機能等）",
  "✓ 外部連携の本実装（決済検証、通知送信、URL設定）",
  "✓ 仕様書の曖昧性10項目の精緻化",
  "✓ 段階的広告導入戦略の確立（年間+$300K機会）"
];

yPos = 2.7;
conclusions.forEach((item) => {
  slide.addText(item, {
    x: 1.5, y: yPos, w: 7, h: 0.35,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });
  yPos += 0.45;
});

slide.addShape(prs.ShapeType.rect, {
  x: 1, y: 5.2, w: 8, h: 0.8,
  fill: { color: colors.secondary }
});

slide.addText("段階的広告導入により、ユーザー体験を保ちながら\n年間$300K+の追加収益が実現可能", {
  x: 1.3, y: 5.35, w: 7.4, h: 0.5,
  fontSize: 13, bold: true, color: colors.white,
  fontFace: "Calibri", align: "center"
});

// ========================================
// SLIDE 15: 付録 - 仕様書改修チェックリスト
// ========================================
slide = prs.addSlide();
slide.background = { color: colors.light };

slide.addShape(prs.ShapeType.rect, {
  x: 0, y: 0, w: 10, h: 1,
  fill: { color: colors.primary }
});
slide.addText("付録：仕様書改修チェックリスト", {
  x: 0.5, y: 0.25, w: 9, h: 0.5,
  fontSize: 36, bold: true, color: colors.accent,
  fontFace: "Cambria"
});

const checklist = [
  "□ 正逆判定ロジックの明確化（API仕様に追加）",
  "□ シャッフル終了判定のしきい値を仕様書に記載",
  "□ 課金プラン「1日1回」の定義明確化（JST基準）",
  "□ テーマ×デッキの関連性定義（中間テーブル仕様化）",
  "□ 通知セグメント値の列挙型定義（free/premium等）",
  "□ 分析イベント properties のスキーマ定義",
  "□ Apple/Google認証 provider_user_id フォーマット規定",
  "□ U-11（履歴詳細）の実装状態確定",
  "□ UserResponse に subscription_expires_at を追加",
  "□ 13_広告戦略・マネタイズ方針書を新規作成"
];

yPos = 1.3;
checklist.forEach((item) => {
  slide.addText(item, {
    x: 0.7, y: yPos, w: 8.8, h: 0.3,
    fontSize: 11, color: colors.text,
    fontFace: "Calibri"
  });
  yPos += 0.4;
});

// 保存
prs.writeFile({ fileName: "リーディングアプリ開発企画書_最終版_20260702.pptx" });

console.log("✅ PowerPoint企画書を作成しました");
console.log("📁 出力ファイル: リーディングアプリ開発企画書_最終版_20260702.pptx");
