ALTER TABLE "_analytics"."sources" ADD CONSTRAINT "sources_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "sources_user_id_index" ON "_analytics"."sources" (user_id);
CREATE INDEX "sources_name_index" ON "_analytics"."sources" (id, name);
CREATE INDEX "sources_public_token_index" ON "_analytics"."sources" (public_token);
CREATE INDEX "sources_token_index" ON "_analytics"."sources" (token);