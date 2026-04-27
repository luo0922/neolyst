ALTER TABLE "kong"."hmacauth_credentials" ADD CONSTRAINT "hmacauth_credentials_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."hmacauth_credentials" ADD CONSTRAINT "hmacauth_credentials_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "hmacauth_tags_idex_tags_idx" ON "kong"."hmacauth_credentials" (tags);
CREATE INDEX "hmacauth_credentials_consumer_id_idx" ON "kong"."hmacauth_credentials" (consumer_id);