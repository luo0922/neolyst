ALTER TABLE "kong"."routes" ADD CONSTRAINT "routes_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."routes" ADD CONSTRAINT "routes_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."routes" ADD CONSTRAINT "routes_ws_id_name_unique" UNIQUE (ws_id, name);