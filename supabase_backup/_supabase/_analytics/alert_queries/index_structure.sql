ALTER TABLE "_analytics"."alert_queries" ADD CONSTRAINT "alert_queries_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "alert_queries_user_id_index" ON "_analytics"."alert_queries" (user_id);
CREATE INDEX "alert_queries_token_index" ON "_analytics"."alert_queries" (token);