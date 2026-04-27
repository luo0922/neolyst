ALTER TABLE "kong"."hmacauth_credentials" ADD CONSTRAINT "hmacauth_credentials_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."hmacauth_credentials" ADD CONSTRAINT "hmacauth_credentials_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."hmacauth_credentials" ADD CONSTRAINT "hmacauth_credentials_ws_id_username_unique" UNIQUE (ws_id, username);