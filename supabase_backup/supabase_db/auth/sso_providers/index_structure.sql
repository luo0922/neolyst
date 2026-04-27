CREATE INDEX "sso_providers_resource_id_pattern_idx" ON "auth"."sso_providers" (resource_id);
CREATE INDEX "sso_providers_resource_id_idx" ON "auth"."sso_providers" (lower);