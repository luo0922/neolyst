ALTER TABLE "public"."report_version" ADD CONSTRAINT "report_version_changed_by_fkey" FOREIGN KEY (changed_by) REFERENCES auth.users(id) ON DELETE RESTRICT;
ALTER TABLE "public"."report_version" ADD CONSTRAINT "report_version_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
CREATE INDEX "idx_report_version_report_version_desc" ON "public"."report_version" (report_id, version_no);
CREATE INDEX "idx_report_version_changed_at_desc" ON "public"."report_version" (changed_at);
CREATE INDEX "idx_report_version_pdf_file_path" ON "public"."report_version" (pdf_file_path);
CREATE INDEX "idx_report_version_report" ON "public"."report_version" (report_id);