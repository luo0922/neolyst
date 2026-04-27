ALTER TABLE "kong"."jwt_secrets" ADD CONSTRAINT "jwt_secrets_consumer_id_fkey" FOREIGN KEY (consumer_id, ws_id) REFERENCES kong.consumers(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."jwt_secrets" ADD CONSTRAINT "jwt_secrets_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "jwt_secrets_secret_idx" ON "kong"."jwt_secrets" (secret);
CREATE INDEX "jwt_secrets_consumer_id_idx" ON "kong"."jwt_secrets" (consumer_id);
CREATE INDEX "jwtsecrets_tags_idex_tags_idx" ON "kong"."jwt_secrets" (tags);