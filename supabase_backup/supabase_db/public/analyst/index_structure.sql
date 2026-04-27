ALTER TABLE "public"."analyst" ADD CONSTRAINT "analyst_region_code_fkey" FOREIGN KEY (region_code) REFERENCES region(code) ON DELETE SET NULL;
CREATE INDEX "idx_analyst_sfc" ON "public"."analyst" (sfc);
CREATE INDEX "idx_analyst_chinese_name" ON "public"."analyst" (chinese_name);
CREATE INDEX "idx_analyst_created_at_desc" ON "public"."analyst" (created_at);
CREATE INDEX "idx_analyst_email" ON "public"."analyst" (email);
CREATE INDEX "idx_analyst_suffix" ON "public"."analyst" (suffix);
CREATE INDEX "idx_analyst_full_name" ON "public"."analyst" (full_name);