ALTER TABLE "public"."report_status_log" ADD CONSTRAINT "report_status_log_action_by_fkey" FOREIGN KEY (action_by) REFERENCES auth.users(id) ON DELETE RESTRICT;
ALTER TABLE "public"."report_status_log" ADD CONSTRAINT "report_status_log_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
CREATE INDEX "idx_report_status_log_action_at_desc" ON "public"."report_status_log" (action_at);
CREATE INDEX "idx_report_status_log_action_by_name" ON "public"."report_status_log" (action_by_name);
CREATE INDEX "idx_report_status_log_report" ON "public"."report_status_log" (report_id);