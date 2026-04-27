ALTER TABLE "_analytics"."billing_counts" ADD CONSTRAINT "billing_counts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "billing_counts_source_id_index" ON "_analytics"."billing_counts" (source_id);
CREATE INDEX "billing_counts_inserted_at_index" ON "_analytics"."billing_counts" (inserted_at);
CREATE INDEX "billing_counts_user_id_index" ON "_analytics"."billing_counts" (user_id);