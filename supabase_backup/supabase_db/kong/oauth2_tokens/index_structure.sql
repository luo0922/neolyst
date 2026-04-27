ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_credential_id_fkey" FOREIGN KEY (credential_id, ws_id) REFERENCES kong.oauth2_credentials(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_service_id_fkey" FOREIGN KEY (service_id, ws_id) REFERENCES kong.services(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_tokens" ADD CONSTRAINT "oauth2_tokens_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "oauth2_tokens_authenticated_userid_idx" ON "kong"."oauth2_tokens" (authenticated_userid);
CREATE INDEX "oauth2_tokens_service_id_idx" ON "kong"."oauth2_tokens" (service_id);
CREATE INDEX "oauth2_tokens_credential_id_idx" ON "kong"."oauth2_tokens" (credential_id);
CREATE INDEX "oauth2_tokens_ttl_idx" ON "kong"."oauth2_tokens" (ttl);