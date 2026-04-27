ALTER TABLE "_analytics"."billing_accounts" ADD CONSTRAINT "billing_accounts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES _analytics.users(id) ON DELETE CASCADE;
CREATE INDEX "billing_accounts_user_id_index" ON "_analytics"."billing_accounts" (user_id);
CREATE INDEX "billing_accounts_stripe_customer_index" ON "_analytics"."billing_accounts" (stripe_customer);