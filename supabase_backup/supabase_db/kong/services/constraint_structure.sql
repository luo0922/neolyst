ALTER TABLE "kong"."services" ADD CONSTRAINT "services_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."services" ADD CONSTRAINT "services_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."services" ADD CONSTRAINT "services_ws_id_name_unique" UNIQUE (ws_id, name);