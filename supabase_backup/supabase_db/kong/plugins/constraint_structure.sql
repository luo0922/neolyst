ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_cache_key_key" UNIQUE (cache_key);
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."plugins" ADD CONSTRAINT "plugins_ws_id_instance_name_unique" UNIQUE (ws_id, instance_name);