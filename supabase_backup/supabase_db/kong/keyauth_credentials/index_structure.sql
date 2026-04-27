ALTER TABLE "kong"."keyauth_credentials" ADD CONSTRAINT "keyauth_credentials_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."keyauth_credentials" ADD CONSTRAINT "keyauth_credentials_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "keyauth_credentials_ttl_idx" ON "kong"."keyauth_credentials" (ttl);
CREATE INDEX "keyauth_tags_idex_tags_idx" ON "kong"."keyauth_credentials" (tags);
CREATE INDEX "keyauth_credentials_consumer_id_idx" ON "kong"."keyauth_credentials" (consumer_id);