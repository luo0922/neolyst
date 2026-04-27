ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_analyst_id_fkey" FOREIGN KEY (analyst_id) REFERENCES analyst(id) ON DELETE RESTRICT;
ALTER TABLE "public"."coverage_analyst" ADD CONSTRAINT "coverage_analyst_coverage_id_fkey" FOREIGN KEY (coverage_id) REFERENCES coverage(id) ON DELETE CASCADE;
CREATE INDEX "idx_cov_analyst_coverage" ON "public"."coverage_analyst" (coverage_id);
CREATE INDEX "idx_cov_analyst_analyst" ON "public"."coverage_analyst" (analyst_id);