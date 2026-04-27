ALTER TABLE "auth"."oauth_consents" ADD CONSTRAINT "oauth_consents_client_id_fkey" FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;
ALTER TABLE "auth"."oauth_consents" ADD CONSTRAINT "oauth_consents_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX "oauth_consents_active_user_client_idx" ON "auth"."oauth_consents" (user_id, client_id);
CREATE INDEX "oauth_consents_user_order_idx" ON "auth"."oauth_consents" (user_id, granted_at);
CREATE INDEX "oauth_consents_active_client_idx" ON "auth"."oauth_consents" (client_id);