ALTER TABLE "auth"."sessions" ADD CONSTRAINT "sessions_oauth_client_id_fkey" FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;
ALTER TABLE "auth"."sessions" ADD CONSTRAINT "sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX "user_id_created_at_idx" ON "auth"."sessions" (user_id, created_at);
CREATE INDEX "sessions_not_after_idx" ON "auth"."sessions" (not_after);
CREATE INDEX "sessions_oauth_client_id_idx" ON "auth"."sessions" (oauth_client_id);
CREATE INDEX "sessions_user_id_idx" ON "auth"."sessions" (user_id);