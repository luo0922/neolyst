CREATE TABLE IF NOT EXISTS "_analytics"."teams"(
 "id" bigserial   NOT NULL ,
 "name" character varying(255)   ,
 "user_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "token" character varying(255)  DEFAULT gen_random_uuid()   
);
