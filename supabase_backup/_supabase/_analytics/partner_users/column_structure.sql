CREATE TABLE IF NOT EXISTS "_analytics"."partner_users"(
 "id" bigserial   NOT NULL ,
 "partner_id" bigint   ,
 "user_id" bigint   ,
 "upgraded" boolean  DEFAULT false   NOT NULL 
);
