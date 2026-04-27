ALTER TABLE "kong"."upstreams" ADD CONSTRAINT "upstreams_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."upstreams" ADD CONSTRAINT "upstreams_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."upstreams" ADD CONSTRAINT "upstreams_ws_id_name_unique" UNIQUE (ws_id, name);