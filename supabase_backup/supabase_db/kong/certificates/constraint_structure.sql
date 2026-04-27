ALTER TABLE "kong"."certificates" ADD CONSTRAINT "certificates_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."certificates" ADD CONSTRAINT "certificates_pkey" PRIMARY KEY (id);