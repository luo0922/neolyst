ALTER TABLE "_analytics"."teams" ADD CONSTRAINT "teams_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "teams_user_id_index" ON "_analytics"."teams" (user_id);
CREATE INDEX "teams_token_index" ON "_analytics"."teams" (token);