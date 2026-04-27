ALTER TABLE "public"."report_version" ADD CONSTRAINT "report_version_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."report_version" ADD CONSTRAINT "report_version_uniq" UNIQUE (report_id, version_no);
ALTER TABLE "public"."report_version" ADD CONSTRAINT "report_version_version_no_check" CHECK ((version_no >= 1));