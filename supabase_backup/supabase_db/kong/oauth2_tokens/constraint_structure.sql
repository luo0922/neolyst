ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_ws_id_access_token_unique" UNIQUE (ws_id, access_token);
ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_ws_id_refresh_token_unique" UNIQUE (ws_id, refresh_token);