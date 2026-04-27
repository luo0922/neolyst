ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_cache_key_key" UNIQUE (cache_key);
ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_kid_set_id_key" UNIQUE (kid, set_id);
ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_name_key" UNIQUE (name);
ALTER TABLE "kong"."keys" ADD CONSTRAINT "keys_pkey" PRIMARY KEY (id);