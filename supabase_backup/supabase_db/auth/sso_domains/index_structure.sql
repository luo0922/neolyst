ALTER TABLE "auth"."sso_domains" ADD CONSTRAINT "sso_domains_sso_provider_id_fkey" FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;
CREATE INDEX "sso_domains_domain_idx" ON "auth"."sso_domains" (lower);
CREATE INDEX "sso_domains_sso_provider_id_idx" ON "auth"."sso_domains" (sso_provider_id);