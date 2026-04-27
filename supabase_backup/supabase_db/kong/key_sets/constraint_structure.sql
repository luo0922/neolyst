ALTER TABLE "kong"."key_sets" ADD CONSTRAINT "key_sets_name_key" UNIQUE (name);
ALTER TABLE "kong"."key_sets" ADD CONSTRAINT "key_sets_pkey" PRIMARY KEY (id);