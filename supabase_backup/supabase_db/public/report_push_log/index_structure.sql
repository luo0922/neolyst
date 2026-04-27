ALTER TABLE "public"."report_push_log" ADD CONSTRAINT "report_push_log_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
ALTER TABLE "public"."report_push_log" ADD CONSTRAINT "report_push_log_triggered_by_fkey" FOREIGN KEY (triggered_by) REFERENCES auth.users(id) ON DELETE RESTRICT;
CREATE INDEX "idx_report_push_log_triggered_by_created" ON "public"."report_push_log" (triggered_by, created_at);
CREATE INDEX "idx_report_push_log_report_created" ON "public"."report_push_log" (report_id, created_at);