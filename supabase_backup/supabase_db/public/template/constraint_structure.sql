ALTER TABLE "public"."template" ADD CONSTRAINT "template_language_check" CHECK ((language = ANY (ARRAY['en'::text, 'zh'::text])));
ALTER TABLE "public"."template" ADD CONSTRAINT "template_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."template" ADD CONSTRAINT "template_uniq_version" UNIQUE (report_type, language, version);