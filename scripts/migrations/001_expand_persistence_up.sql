-- 001_expand_persistence_up.sql
-- 次ラウンド: 完全永続化拡張（users/subscriptions/ticket_wallets/announcements/inquiries/audit_logs）

CREATE TABLE IF NOT EXISTS users (
  user_id VARCHAR(128) PRIMARY KEY,
  plan VARCHAR(32) NOT NULL,
  tickets INTEGER NOT NULL,
  subscription_expires_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  visit_count INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS subscriptions (
  user_id VARCHAR(128) PRIMARY KEY,
  plan_id VARCHAR(64) NOT NULL,
  status VARCHAR(32) NOT NULL,
  expires_at TIMESTAMPTZ NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS ticket_wallets (
  user_id VARCHAR(128) PRIMARY KEY,
  balance INTEGER NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS announcements (
  announcement_id VARCHAR(64) PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  category VARCHAR(64) NOT NULL,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  is_important BOOLEAN NOT NULL,
  link_url TEXT NULL
);
CREATE INDEX IF NOT EXISTS idx_announcements_start_at ON announcements(start_at);

CREATE TABLE IF NOT EXISTS inquiries (
  inquiry_id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  category VARCHAR(128) NOT NULL,
  body TEXT NOT NULL,
  email VARCHAR(255) NULL,
  created_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_inquiries_user_id ON inquiries(user_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_created_at ON inquiries(created_at);

CREATE TABLE IF NOT EXISTS audit_logs (
  audit_id VARCHAR(64) PRIMARY KEY,
  actor_type VARCHAR(64) NOT NULL,
  actor_id VARCHAR(128) NOT NULL,
  action VARCHAR(128) NOT NULL,
  resource_type VARCHAR(64) NOT NULL,
  resource_id VARCHAR(128) NULL,
  detail_json TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_occurred_at ON audit_logs(occurred_at);

CREATE TABLE IF NOT EXISTS reading_results (
  session_id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  theme_id VARCHAR(64) NOT NULL,
  deck_id VARCHAR(64) NOT NULL,
  card_id VARCHAR(128) NOT NULL,
  card_name VARCHAR(255) NOT NULL,
  keywords_json TEXT NOT NULL,
  interpretation_text TEXT NOT NULL,
  caution_text TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  copied BOOLEAN NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_reading_results_user_id ON reading_results(user_id);

CREATE TABLE IF NOT EXISTS reading_history (
  history_id VARCHAR(64) PRIMARY KEY,
  user_id VARCHAR(128) NOT NULL,
  session_id VARCHAR(64) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  theme_id VARCHAR(64) NOT NULL,
  deck_id VARCHAR(64) NOT NULL,
  card_id VARCHAR(128) NOT NULL,
  summary TEXT NOT NULL,
  full_text TEXT NOT NULL,
  plan_at_creation VARCHAR(32) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_reading_history_user_id ON reading_history(user_id);
CREATE INDEX IF NOT EXISTS idx_reading_history_created_at ON reading_history(created_at);
