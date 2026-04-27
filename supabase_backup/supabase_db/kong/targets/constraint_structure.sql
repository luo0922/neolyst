ALTER TABLE "kong"."targets" ADD CONSTRAINT "targets_cache_key_key" UNIQUE (cache_key);
ALTER TABLE "kong"."targets" ADD CONSTRAINT "targets_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."targets" ADD CONSTRAINT "targets_pkey" PRIMARY KEY (id);