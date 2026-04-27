ALTER TABLE "kong"."oauth2_credentials" ADD CONSTRAINT "oauth2_credentials_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."oauth2_credentials" ADD CONSTRAINT "oauth2_credentials_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."oauth2_credentials" ADD CONSTRAINT "oauth2_credentials_ws_id_client_id_unique" UNIQUE (ws_id, client_id);