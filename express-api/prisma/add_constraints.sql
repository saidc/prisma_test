-- ============================================
-- ADD CHECK CONSTRAINTS
-- ============================================

ALTER TABLE users
  ADD CONSTRAINT check_username_length 
    CHECK (LENGTH(username) >= 3),
  ADD CONSTRAINT check_email_format 
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

