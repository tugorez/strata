-- Migration: create_users_with_rollback
-- Version: 3

-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_users_email ON users(email);

CREATE INDEX idx_users_username ON users(username);

-- @Down()
DROP INDEX IF EXISTS idx_users_username;

DROP INDEX IF EXISTS idx_users_email;

DROP TABLE IF EXISTS users;
