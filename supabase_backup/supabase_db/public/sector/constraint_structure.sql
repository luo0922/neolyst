ALTER TABLE "public"."sector" ADD CONSTRAINT "sector_level_check" CHECK ((level = ANY (ARRAY[1, 2])));
ALTER TABLE "public"."sector" ADD CONSTRAINT "sector_level_parent_check" CHECK ((((level = 1) AND (parent_id IS NULL)) OR ((level = 2) AND (parent_id IS NOT NULL))));
ALTER TABLE "public"."sector" ADD CONSTRAINT "sector_pkey" PRIMARY KEY (id);