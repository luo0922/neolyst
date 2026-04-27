ALTER TABLE "kong"."basicauth_credentials" ADD CONSTRAINT "basicauth_credentials_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."basicauth_credentials" ADD CONSTRAINT "basicauth_credentials_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."basicauth_credentials" ADD CONSTRAINT "basicauth_credentials_ws_id_username_unique" UNIQUE (ws_id, username);