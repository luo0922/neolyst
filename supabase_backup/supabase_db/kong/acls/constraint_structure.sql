ALTER TABLE "kong"."acls" ADD CONSTRAINT "acls_cache_key_key" UNIQUE (cache_key);
ALTER TABLE "kong"."acls" ADD CONSTRAINT "acls_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."acls" ADD CONSTRAINT "acls_pkey" PRIMARY KEY (id);