ALTER TABLE "public"."sector" ADD CONSTRAINT "sector_parent_id_fkey" FOREIGN KEY (parent_id) REFERENCES sector(id) ON DELETE RESTRICT;
CREATE INDEX "idx_sector_active" ON "public"."sector" (is_active);
CREATE INDEX "idx_sector_name_en_lower" ON "public"."sector" (lower);
CREATE INDEX "idx_sector_level_parent" ON "public"."sector" (level, parent_id);
CREATE INDEX "uidx_sector_l1_name_en" ON "public"."sector" (lower);
CREATE INDEX "uidx_sector_l2_parent_name_en" ON "public"."sector" (parent_id, lower);