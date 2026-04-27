CREATE TABLE IF NOT EXISTS "vault"."secrets"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "name" text   ,
 "description" text  DEFAULT ''::text   NOT NULL ,
 "secret" text   NOT NULL ,
 "key_id" uuid   ,
 "nonce" bytea  DEFAULT vault._crypto_aead_det_noncegen()   ,
 "created_at" timestamp with time zone  DEFAULT CURRENT_TIMESTAMP   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT CURRENT_TIMESTAMP   NOT NULL 
);
