ALTER TABLE "_analytics"."oauth_access_tokens" ADD CONSTRAINT "oauth_access_tokens_application_id_fkey" FOREIGN KEY (application_id) REFERENCES _analytics.oauth_applications(id);
CREATE INDEX "oauth_access_tokens_refresh_token_index" ON "_analytics"."oauth_access_tokens" (refresh_token);
CREATE INDEX "oauth_access_tokens_token_index" ON "_analytics"."oauth_access_tokens" (token);
CREATE INDEX "oauth_access_tokens_resource_owner_id_index" ON "_analytics"."oauth_access_tokens" (resource_owner_id);