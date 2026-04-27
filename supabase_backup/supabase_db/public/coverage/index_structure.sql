ALTER TABLE "public"."coverage" ADD CONSTRAINT "coverage_approved_by_fkey" FOREIGN KEY (approved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE "public"."coverage" ADD CONSTRAINT "coverage_sector_id_fkey" FOREIGN KEY (sector_id) REFERENCES sector(id) ON DELETE RESTRICT;
CREATE INDEX "idx_coverage_index_code" ON "public"."coverage" (index_code);
CREATE INDEX "idx_coverage_name_lower" ON "public"."coverage" (lower);
CREATE INDEX "idx_coverage_updated_at_desc" ON "public"."coverage" (updated_at);
CREATE INDEX "idx_coverage_sector" ON "public"."coverage" (sector_id);
CREATE INDEX "uidx_coverage_ticker_lower" ON "public"."coverage" (lower);
CREATE INDEX "uidx_coverage_isin_upper" ON "public"."coverage" (upper);