ALTER TABLE "public"."template" ADD CONSTRAINT "template_uploaded_by_fkey" FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE RESTRICT;
CREATE INDEX "idx_template_created_at_desc" ON "public"."template" (created_at);
CREATE INDEX "idx_template_group" ON "public"."template" (report_type, language);