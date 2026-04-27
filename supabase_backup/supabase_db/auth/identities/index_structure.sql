ALTER TABLE "auth"."identities" ADD CONSTRAINT "identities_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
CREATE INDEX "identities_email_idx" ON "auth"."identities" (email);
CREATE INDEX "identities_user_id_idx" ON "auth"."identities" (user_id);