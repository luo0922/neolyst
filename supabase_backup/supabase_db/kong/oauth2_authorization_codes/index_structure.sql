ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_credential_id_fkey" FOREIGN KEY (credential_id, ws_id) REFERENCES kong.oauth2_credentials(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_plugin_id_fkey" FOREIGN KEY (plugin_id) REFERENCES kong.plugins(id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_service_id_fkey" FOREIGN KEY (service_id, ws_id) REFERENCES kong.services(id, ws_id) ON DELETE CASCADE;
ALTER TABLE "kong"."oauth2_authorization_codes" ADD CONSTRAINT "oauth2_authorization_codes_ws_id_fkey" FOREIGN KEY (ws_id) REFERENCES kong.workspaces(id);
CREATE INDEX "oauth2_authorization_service_id_idx" ON "kong"."oauth2_authorization_codes" (service_id);
CREATE INDEX "oauth2_authorization_codes_ttl_idx" ON "kong"."oauth2_authorization_codes" (ttl);
CREATE INDEX "oauth2_authorization_credential_id_idx" ON "kong"."oauth2_authorization_codes" (credential_id);
CREATE INDEX "oauth2_authorization_codes_authenticated_userid_idx" ON "kong"."oauth2_authorization_codes" (authenticated_userid);