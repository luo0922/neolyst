ALTER TABLE "public"."rating" ADD CONSTRAINT "rating_code_key" UNIQUE (code);
ALTER TABLE "public"."rating" ADD CONSTRAINT "rating_pkey" PRIMARY KEY (id);