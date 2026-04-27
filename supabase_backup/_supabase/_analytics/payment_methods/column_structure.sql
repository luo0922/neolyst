CREATE TABLE IF NOT EXISTS "_analytics"."payment_methods"(
 "id" bigserial   NOT NULL ,
 "stripe_id" character varying(255)   ,
 "price_id" character varying(255)   ,
 "last_four" character varying(255)   ,
 "brand" character varying(255)   ,
 "exp_year" integer   ,
 "exp_month" integer   ,
 "customer_id" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
