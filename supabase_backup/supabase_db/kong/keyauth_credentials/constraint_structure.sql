ALTER TABLE "kong"."keyauth_credentials" ADD CONSTRAINT "keyauth_credentials_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."keyauth_credentials" ADD CONSTRAINT "keyauth_credentials_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."keyauth_credentials" ADD CONSTRAINT "keyauth_credentials_ws_id_key_unique" UNIQUE (ws_id, key);