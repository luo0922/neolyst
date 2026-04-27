ALTER TABLE "kong"."jwt_secrets" ADD CONSTRAINT "jwt_secrets_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."jwt_secrets" ADD CONSTRAINT "jwt_secrets_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."jwt_secrets" ADD CONSTRAINT "jwt_secrets_ws_id_key_unique" UNIQUE (ws_id, key);