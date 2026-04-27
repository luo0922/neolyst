ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_analyst_id_fkey" FOREIGN KEY (analyst_id) REFERENCES analyst(id) ON DELETE RESTRICT;
ALTER TABLE "public"."report_analyst" ADD CONSTRAINT "report_analyst_report_id_fkey" FOREIGN KEY (report_id) REFERENCES report(id) ON DELETE CASCADE;
CREATE INDEX "idx_report_analyst_analyst" ON "public"."report_analyst" (analyst_id);
CREATE INDEX "idx_report_analyst_report" ON "public"."report_analyst" (report_id);