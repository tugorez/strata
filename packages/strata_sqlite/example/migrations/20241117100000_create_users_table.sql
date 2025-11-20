-- Migration: create_users_table
-- Description: Creates the users table with basic user information

-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_users_email ON users(email);

-- @Down()
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
