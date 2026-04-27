ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_cache_key_key" UNIQUE (cache_key);
ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_name_key" UNIQUE (name);
ALTER TABLE "kong"."filter_chains" ADD CONSTRAINT "filter_chains_pkey" PRIMARY KEY (id);