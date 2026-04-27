ALTER TABLE "kong"."consumers" ADD CONSTRAINT "consumers_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."consumers" ADD CONSTRAINT "consumers_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."consumers" ADD CONSTRAINT "consumers_ws_id_custom_id_unique" UNIQUE (ws_id, custom_id);
ALTER TABLE "kong"."consumers" ADD CONSTRAINT "consumers_ws_id_username_unique" UNIQUE (ws_id, username);