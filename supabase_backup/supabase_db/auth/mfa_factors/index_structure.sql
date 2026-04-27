ALTER TABLE "auth"."mfa_factors" ADD CONSTRAINT "mfa_factors_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX "unique_phone_factor_per_user" ON "auth"."mfa_factors" (user_id, phone);
CREATE INDEX "factor_id_created_at_idx" ON "auth"."mfa_factors" (user_id, created_at);
CREATE INDEX "mfa_factors_user_friendly_name_unique" ON "auth"."mfa_factors" (friendly_name, user_id);
CREATE INDEX "mfa_factors_user_id_idx" ON "auth"."mfa_factors" (user_id);