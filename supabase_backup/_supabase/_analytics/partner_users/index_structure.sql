ALTER TABLE "_analytics"."partner_users" ADD CONSTRAINT "partner_users_partner_id_fkey" FOREIGN KEY (partner_id) REFERENCES _analytics.partners(id);
ALTER TABLE "_analytics"."partner_users" ADD CONSTRAINT "partner_users_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "partner_users_partner_id_user_id_index" ON "_analytics"."partner_users" (partner_id, user_id);
CREATE INDEX "partner_users_partner_id_user_id_upgraded_index" ON "_analytics"."partner_users" (partner_id, user_id, upgraded);