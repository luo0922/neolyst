ALTER TABLE "public"."region" ADD CONSTRAINT "region_pkey" PRIMARY KEY (id);
ALTER TABLE "public"."region" ADD CONSTRAINT "uk_region_code" UNIQUE (code);
ALTER TABLE "public"."region" ADD CONSTRAINT "uk_region_name_cn" UNIQUE (name_cn);
ALTER TABLE "public"."region" ADD CONSTRAINT "uk_region_name_en" UNIQUE (name_en);