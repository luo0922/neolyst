ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_id_ws_id_unique" UNIQUE (id, ws_id);
ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_pkey" PRIMARY KEY (id);
ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_ws_id_code_unique" UNIQUE (ws_id, code);