ALTER TABLE "_analytics"."users" ADD CONSTRAINT "users_partner_id_fkey" FOREIGN KEY (partner_id) REFERENCES _analytics.partners(id);
CREATE INDEX "users_lower_email_index" ON "_analytics"."users" (lower);
CREATE INDEX "users_api_key_index" ON "_analytics"."users" (api_key);