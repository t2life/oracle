-- 001_expand_persistence_down.sql
-- ロールバック手順（依存関係の薄い順でDROP）

DROP TABLE IF EXISTS reading_history;
DROP TABLE IF EXISTS reading_results;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS inquiries;
DROP TABLE IF EXISTS announcements;
DROP TABLE IF EXISTS ticket_wallets;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS users;
