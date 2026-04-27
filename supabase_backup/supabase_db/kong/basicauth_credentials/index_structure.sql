ALTER TABLE "kong"."basicauth_credentials" ADD CONSTRAINT "basicauth_credentials_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."basicauth_credentials" ADD CONSTRAINT "basicauth_credentials_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "basicauth_consumer_id_idx" ON "kong"."basicauth_credentials" (consumer_id);
CREATE INDEX "basicauth_tags_idex_tags_idx" ON "kong"."basicauth_credentials" (tags);