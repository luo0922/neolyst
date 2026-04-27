CREATE TABLE IF NOT EXISTS "_analytics"."billing_accounts"(
 "id" bigserial   NOT NULL ,
 "latest_successful_stripe_session" jsonb   ,
 "stripe_customer" character varying(255)   ,
 "user_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "stripe_subscriptions" jsonb   ,
 "stripe_invoices" jsonb   ,
 "lifetime_plan?" boolean  DEFAULT false   ,
 "lifetime_plan_invoice" character varying(255)   ,
 "default_payment_method" character varying(255)   ,
 "custom_invoice_fields" jsonb[]  DEFAULT ARRAY[]::jsonb[]   ,
 "lifetime_plan" boolean  DEFAULT false   NOT NULL 
);
