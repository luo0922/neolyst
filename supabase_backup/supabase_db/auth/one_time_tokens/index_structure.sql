ALTER TABLE "auth"."one_time_tokens" ADD CONSTRAINT "one_time_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX "one_time_tokens_relates_to_hash_idx" ON "auth"."one_time_tokens" (relates_to);
CREATE INDEX "one_time_tokens_token_hash_hash_idx" ON "auth"."one_time_tokens" (token_hash);
CREATE INDEX "one_time_tokens_user_id_token_type_key" ON "auth"."one_time_tokens" (user_id, token_type);