ALTER TABLE "public"."report" ADD CONSTRAINT "report_current_version_no_check" CHECK ((current_version_no >= 0));
ALTER TABLE "public"."report" ADD CONSTRAINT "report_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."report" ADD CONSTRAINT "report_report_language_check" CHECK ((report_language = ANY (ARRAY['zh'::text, 'en'::text])));
ALTER TABLE "public"."report" ADD CONSTRAINT "report_status_check" CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'published'::text, 'rejected'::text])));
ALTER TABLE "public"."report" ADD CONSTRAINT "report_target_price_check" CHECK (((target_price IS NULL) OR (target_price > (0)::numeric)));