-- 履歴一覧に「託宣／リーディング」を出すための種別（2026-09-12 承認オ）。
-- 新しい概念を作らず既存のスプレッドIDを使う（daily＝託宣／それ以外＝リーディング）。
-- 既存行は daily（託宣）として扱う。欠損で画面が壊れないようにするため。
ALTER TABLE reading_history
  ADD COLUMN IF NOT EXISTS spread_id VARCHAR(64) NOT NULL DEFAULT 'daily';
