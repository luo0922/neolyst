ALTER TABLE "kong"."snis" ADD CONSTRAINT "snis_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."snis" ADD CONSTRAINT "snis_name_key" UNIQUE (name);
ALTER TABLE "kong"."snis" ADD CONSTRAINT "snis_pkey" PRIMARY KEY (id);