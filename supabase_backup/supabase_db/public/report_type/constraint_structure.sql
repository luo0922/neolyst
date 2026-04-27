ALTER TABLE "public"."report_type" ADD CONSTRAINT "report_type_code_key" UNIQUE (code);
ALTER TABLE "public"."report_type" ADD CONSTRAINT "report_type_pkey" PRIMARY KEY (id);