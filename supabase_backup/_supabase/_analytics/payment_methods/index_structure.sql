ALTER TABLE "_analytics"."payment_methods" ADD CONSTRAINT "payment_methods_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES _analytics.billing_accounts(stripe_customer) ON DELETE CASCADE;
CREATE INDEX "payment_methods_stripe_id_index" ON "_analytics"."payment_methods" (stripe_id);
CREATE INDEX "payment_methods_customer_id_index" ON "_analytics"."payment_methods" (customer_id);