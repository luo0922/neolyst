ALTER TABLE "kong"."oauth2_credentials" ADD CONSTRAINT "oauth2_credentials_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_credentials" ADD CONSTRAINT "oauth2_credentials_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "oauth2_credentials_tags_idex_tags_idx" ON "kong"."oauth2_credentials" (tags);
CREATE INDEX "oauth2_credentials_secret_idx" ON "kong"."oauth2_credentials" (client_secret);
CREATE INDEX "oauth2_credentials_consumer_id_idx" ON "kong"."oauth2_credentials" (consumer_id);