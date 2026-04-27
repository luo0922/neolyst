ALTER TABLE "public"."chief_approve" ADD CONSTRAINT "chief_approve_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
CREATE INDEX "idx_chief_approve_created_at" ON "public"."chief_approve" (created_at);
CREATE INDEX "idx_chief_approve_report_id" ON "public"."chief_approve" (report_id);