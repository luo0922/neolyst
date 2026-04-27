ALTER TABLE "auth"."refresh_tokens" ADD CONSTRAINT "refresh_tokens_session_id_fkey" FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;
CREATE INDEX "refresh_tokens_session_id_revoked_idx" ON "auth"."refresh_tokens" (session_id, revoked);
CREATE INDEX "refresh_tokens_instance_id_idx" ON "auth"."refresh_tokens" (instance_id);
CREATE INDEX "refresh_tokens_updated_at_idx" ON "auth"."refresh_tokens" (updated_at);
CREATE INDEX "refresh_tokens_parent_idx" ON "auth"."refresh_tokens" (parent);
CREATE INDEX "refresh_tokens_instance_id_user_id_idx" ON "auth"."refresh_tokens" (instance_id, user_id);