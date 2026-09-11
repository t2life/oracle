-- 002 の取り消し。列を落とすだけで、他の列には触れない。
ALTER TABLE reading_history
  DROP COLUMN IF EXISTS spread_id;
