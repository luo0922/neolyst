ALTER TABLE "public"."rqc_approve" ADD CONSTRAINT "rqc_approve_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
CREATE INDEX "idx_rqc_approve_created_at" ON "public"."rqc_approve" (created_at);
CREATE INDEX "idx_rqc_approve_report_id" ON "public"."rqc_approve" (report_id);